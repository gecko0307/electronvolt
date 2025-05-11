import sys
import os
import subprocess
import threading
import time
import datetime
import logging
import json
import socket
import select
import re
import webview
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

is_build = hasattr(sys, "_MEIPASS")

appdata_dir = os.path.join(os.environ["APPDATA"], "Electronvolt")

if is_build:
    # Release version
    launcher_dir = os.path.dirname(sys.executable)
    game_working_dir = launcher_dir
else:
    # Dev version
    launcher_dir = os.path.abspath(os.path.dirname(__file__))
    game_working_dir = os.path.abspath(os.path.join(launcher_dir, ".."))

class StreamToLogger:
    def __init__(self, logger, level):
        self.logger = logger
        self.level = level
        self.buffer = ""

    def write(self, message):
        message = message.rstrip()
        if message:
            self.logger.log(self.level, message)

    def flush(self):
        pass

def setup_logger():
    logger = logging.getLogger("launcher")
    logger.setLevel(logging.DEBUG)
    formatter = logging.Formatter("[%(asctime)s] %(levelname)s: %(message)s")
    if logger.hasHandlers():
        logger.handlers.clear()
    if is_build:
        log_filename = os.path.join(launcher_dir, f"launcher.log")
        file_handler = logging.FileHandler(log_filename, mode = "w", encoding = "utf-8")
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
    else:
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setFormatter(formatter)
        logger.addHandler(console_handler)
    return logger

log = setup_logger()
sys.stdout = StreamToLogger(log, logging.INFO)
sys.stderr = StreamToLogger(log, logging.INFO)

def log_print(*args, level = "info", sep = "", end = ""):
    message = sep.join(str(arg) for arg in args) + end
    if level == "debug":
        log.debug(message)
    elif level == "warning":
        log.warning(message)
    elif level == "error":
        log.error(message)
    else:
        log.info(message)

def packed_resource_path(relative_path):
    if is_build:
        return os.path.join(sys._MEIPASS, relative_path)
    return os.path.join(os.path.abspath("."), relative_path)

if sys.platform == "win32":
    game_executable = "electronvolt.exe"
else:
    game_executable = "electronvolt"

# Important paths
game_path = os.path.join(game_working_dir, game_executable)
game_settings_file = os.path.join(game_working_dir, 'settings.conf')
game_process = None

# Game settings
windowWidth = 1280
windowHeight = 720
fullscreen = False

# GameJolt user data
username = ""
token = ""

# Threads
game_ipc_thread = None
settings_watcher_thread = None

log_print("launcher directory: ", launcher_dir)
log_print("game executable path: ", game_path)
log_print("user data directory: ", appdata_dir)

def loadSettings():
    global game_settings_file
    global windowWidth, windowHeight, fullscreen
    
    if os.path.exists(game_settings_file):
        try:
            with open(game_settings_file, 'r') as file:
                file_contents = file.read()
        except FileNotFoundError:
            log_print(f"{game_settings_file} not found")
            return
    else:
        log_print(f"Settings file {game_settings_file} does not exist. Using default settings")
        return

    settings_dict = {}

    for line in file_contents.splitlines():
        if not line.strip() or not ':' in line:
            continue

        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip().rstrip(";").strip()
        
        if value.isdigit():
            value = int(value)
        elif value.lower() == 'true':
            value = True
        elif value.lower() == 'false':
            value = False

        settings_dict[key] = value

    windowWidth = settings_dict.get('windowWidth', windowWidth)
    windowHeight = settings_dict.get('windowHeight', windowHeight)
    fullscreen = settings_dict.get('fullscreen', fullscreen)
    
    log_print(f"settings reloaded: {windowWidth=} {windowHeight=} {fullscreen=}")

loadSettings()

class SettingsChangeHandler(FileSystemEventHandler):
    def on_modified(self, event):
        if os.path.abspath(event.src_path) == os.path.abspath(game_settings_file):
            print("[Watcher] settings.conf modified")
            loadSettings()
            client_notify_settings()

class Launcher:
    def __init__(self):
        self.running = True
    
    def launchGame(self):
        global game_process
        global game_ipc_thread
        if game_process is None:
            log_print("staring %s..." % game_path)
            try:
                game_process = subprocess.Popen([game_path], cwd=game_working_dir)
                self.minimize()
                game_ipc_thread = threading.Thread(target=game_ipc_loop)
                game_ipc_thread.daemon = True
                game_ipc_thread.start()
                client_notify_game_launched()
            except Exception as e:
                log_print("failed to start the game: ", e)
                client_notify_game_error()
        else:
            log_print("game is already running")
    
    def setUserData(self, data):
        log_print("received user data")
        global appdata_dir
        global username
        global token
        username = data.get("username")
        token = data.get("token")
        os.makedirs(appdata_dir, exist_ok=True)
        userdata_path = os.path.join(appdata_dir, "userdata")
        try:
            with open(userdata_path, "w", encoding="utf-8") as f:
                f.write(f"username: {username}\n")
                f.write(f"token: {token}\n")
            log_print("user data saved to ", userdata_path)
        except Exception as e:
            log_print("failed to save user data:", e)
        pass
    
    def getUserData(self):
        log_print("reading user data...")
        global appdata_dir
        global username
        global token
        userdata_path = os.path.join(appdata_dir, "userdata")
        if not os.path.isfile(userdata_path):
            log_print("no saved user data found")
            return None
        try:
            with open(userdata_path, "r", encoding="utf-8") as f:
                lines = f.readlines()
            data = {}
            for line in lines:
                if ':' in line:
                    key, value = line.strip().split(":", 1)
                    data[key.strip()] = value.strip()
            if "username" in data and "token" in data:
                username = data["username"]
                token = data["token"]
                log_print("loaded user data")
                return data
            else:
                log_print("invalid user data format")
                return None
        except Exception as e:
            log_print("failed to read user data:", e)
            return None
    
    def deleteUserData(self):
        log_print("deleting user data...")
        global appdata_dir
        global username
        global token
        username = ""
        token = ""
        userdata_path = os.path.join(appdata_dir, "userdata")
        try:
            if os.path.exists(userdata_path):
                os.remove(userdata_path)
                log_print("user data deleted")
            else:
                log_print("no user data to delete")
        except Exception as e:
            log_print("failed to delete user data: ", e)
        pass
    
    def updateSettings(self, settings):
        global game_settings_file
        log_print("updating settings to ", settings)
        
        if settings.get("resolution"):
            resolution = settings["resolution"]
            width, height = resolution.split("x")
            windowWidth = int(width)
            windowHeight = int(height)
        
        if settings.get("fullscreen") is not None:
            fullscreen = 1 if settings["fullscreen"] else 0
        
        file_exists = os.path.exists(game_settings_file)
        if file_exists:
            try:
                with open(game_settings_file, 'r') as file:
                    file_contents = file.read()
            except FileNotFoundError:
                log_print(f"{game_settings_file} not found")
                return
        else:
            file_contents = 'fullscreen: 0;\nwindowWidth: 1280;\nwindowHeight: 720;\n'
        
        settings_dict = {}
        
        for line in file_contents.splitlines():
            if not line.strip() or not ':' in line:
                continue

            key, value = line.split(":", 1)
            key = key.strip()
            value = value.strip().rstrip(";").strip()

            if value.isdigit():
                value = int(value)
            elif value.lower() == "true":
                value = True
            elif value.lower() == "false":
                value = False

            settings_dict[key] = value

        if "windowWidth" in locals():
            settings_dict["windowWidth"] = windowWidth
        if "windowHeight" in locals():
            settings_dict["windowHeight"] = windowHeight
        if "fullscreen" in locals():
            settings_dict["fullscreen"] = fullscreen

        try:
            with open(game_settings_file, "w") as file:
                for key, value in settings_dict.items():
                    if isinstance(value, bool):
                        value = "true" if value else "false"
                    elif isinstance(value, int):
                        value = str(value)
                    file.write(f"{key}: {value};\n")
        except Exception as e:
            log_print(f"Error writing to {game_settings_file}: {e}")

        log_print("Settings updated successfully.")
    
    def minimize(self):
        log_print("minimize")
        window.minimize()
    
    def restore(self):
        log_print("restore")
        window.restore()
    
    def close(self):
        log_print("close")
        self.running = False
        window.destroy()

launcher = Launcher()

gj_trophy_id = {
    "SuccessfulLanding": "267023"
}

def parse_ev_message(msg):
    if not msg.startswith("eV:"):
        return None
    try:
        kv_string = msg[3:]
        pairs = kv_string.strip().split("&")
        return {k: v for k, v in (pair.split("=", 1) for pair in pairs)}
    except Exception as e:
        print(f"Failed to parse message: {e}")
        return None

HOST = "127.0.0.1"
PORT = 65432
max_clients = 1

def handle_game_ipc_request(client, address):
    request_bytes = b"" + client.recv(1024)
    if not request_bytes:
        log_print("[IPC] connection closed")
        client.close()
    request_str = request_bytes.decode()
    log_print("[IPC] request: ", request_str)
    payload = parse_ev_message(request_str)
    if payload is not None:
        #log_print("payload: ", payload)
        if "version" in payload:
            log_print(f"[IPC] game version reported: {payload['version']}")
        if "award" in payload:
            log_print(f"[IPC] award unlocked: {payload['award']}")
            if len(username) > 0 and len(token) > 0:
                client_notify_unlock_trophy(username, token, gj_trophy_id[payload["award"]])
            # TODO: if logged out, store trophies in a file, award later

server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server_socket.bind((HOST, PORT))
server_socket.listen(max_clients)

def game_ipc_loop():
    global launcher
    global game_process
    global server_socket
    inputs = [server_socket]
    outputs = []
    log_print("[IPC] started communication loop")
    while True:
        if not launcher.running:
            break;
        elif game_process is not None and game_process.poll() is not None:
            launcher.restore()
            client_notify_game_stopped()
            game_process = None
            break
        else:
            readable, writable, exceptional = select.select(inputs, outputs, inputs, 1)
            for s in readable:
                if s is server_socket:
                    connection, client_address = s.accept()
                    connection.setblocking(0)
                    inputs.append(connection)
                    handle_game_ipc_request(connection, client_address)
            time.sleep(1)

def settings_watch_loop():
    event_handler = SettingsChangeHandler()
    observer = Observer()
    observer.schedule(event_handler, path=game_working_dir, recursive=False)
    observer.start()
    log_print("[Watcher] started watching settings.conf")
    while launcher.running:
        time.sleep(1)
    observer.stop()
    observer.join()

def start_settings_watcher():
    settings_watcher_thread = threading.Thread(target=settings_watch_loop, daemon=True)
    settings_watcher_thread.start()

start_settings_watcher()

SENSITIVE_KEYS = {"token", "password", "secret"}

def mask_sensitive(data):
    def mask(value):
        return "*" * 8 if isinstance(value, str) else "***"

    def recurse(obj):
        if isinstance(obj, dict):
            return {
                k: mask(v) if k.lower() in SENSITIVE_KEYS else recurse(v)
                for k, v in obj.items()
            }
        elif isinstance(obj, list):
            return [recurse(item) for item in obj]
        else:
            return obj

    return recurse(data)

def client_post_message(data):
    message = json.dumps(data)
    masked_message = json.dumps(mask_sensitive(data))
    log_print("client_post_message: ", masked_message)
    window.evaluate_js(f"window.postMessage({message}, '*');")

def client_notify_game_launched():
    client_post_message({
        "event": "game_status_change",
        "status": "running"
    })

def client_notify_game_stopped():
    client_post_message({
        "event": "game_status_change",
        "status": "stopped"
    })

def client_notify_game_error():
    client_post_message({
        "event": "game_status_change",
        "status": "error"
    })

def client_notify_settings():
    client_post_message({
        "event": "settings",
        "resolution": str(windowWidth) + "x" + str(windowHeight),
        "fullscreen": fullscreen
    })

def client_notify_auto_login(username, token):
    client_post_message({
        "event": "autologin",
        "username": username,
        "token": token
    })

def client_notify_unlock_trophy(username, token, trophyId):
    client_post_message({
        "event": "unlock_trophy",
        "username": username,
        "token": token,
        "trophyId": trophyId
    })

def startup_js_logic(window):
    client_notify_settings()
    data = launcher.getUserData()
    if data is not None:
        client_notify_auto_login(data["username"], data["token"])

window = webview.create_window(
    title = "Electronvolt Launcher",
    url = packed_resource_path("static/index.html"),
    js_api = launcher,
    width = 700,
    height = 700,
    resizable = False
)

try:
    import pyi_splash
    pyi_splash.close()
except ImportError:
    pass

webview.start(startup_js_logic, window, http_server = True, debug = not is_build) #gui = "edgechromium"

launcher.running = False

if settings_watcher_thread is not None:
    settings_watcher_thread.join()
if game_ipc_thread is not None:
    game_ipc_thread.join()
