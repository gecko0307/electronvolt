# -*- coding: utf-8 -*-

import os
import sys
#print(sys.stdout.encoding)
#sys.path.append(os.getcwd())

if sys.stdout is None:
    sys.stdout = open("stdout.log", "w")
if sys.stderr is None:
    sys.stderr = open("stderr.log", "w")

import logging

logging.basicConfig(filename='launcher.log', level=logging.DEBUG, format='%(asctime)s - %(message)s')

def log_exception(exc_type, exc_value, exc_tb):
    logging.error("Exception occurred", exc_info=(exc_type, exc_value, exc_tb))

sys.excepthook = log_exception

import io
import threading
import time
import socket
import ctypes
import platform
import subprocess

from cefpython3 import cefpython as cef

import bottle
from bottle import request
from bottle_sqlite import SQLitePlugin

from app.config import *
from app.data import *
from app import state

@bottle.route('/')
def index(db):
    d = profileData(db)
    return bottle.template(load('index.stpl'), data = d)

@bottle.route('/<filename:path>')
def serverStatic(filename):
    return bottle.static_file(filename, root = Config.sitePath)

def resource_path():
    if getattr(sys, 'frozen', False):
        base_path = sys._MEIPASS if hasattr(sys, '_MEIPASS') else os.path.dirname(sys.executable)
    else:
        base_path = os.path.dirname(__file__)
    return os.path.abspath(base_path)

base_dir = resource_path()
game_dir = os.path.join(base_dir, "..")
game_path = os.path.join(game_dir, Config.gameExecutable)
game_process = None
game_status_thread = None

# Windows-olny!
def minimizeLauncher():
    if platform.system() == "Windows":
        if state.hwnd is not None:
            SW_MINIMIZE = 6
            ctypes.windll.user32.ShowWindow(state.hwnd, SW_MINIMIZE)

# Windows-olny!
def restoreLauncher():
    if platform.system() == "Windows":
        if state.hwnd is not None:
            SW_RESTORE = 9
            ctypes.windll.user32.ShowWindow(state.hwnd, SW_RESTORE)
            ctypes.windll.user32.SetForegroundWindow(state.hwnd)

def gameStatusLoop():
    global game_process
    while True:
        if game_process is not None and game_process.poll() is not None:
            restoreLauncher()
            state.notifyGameStopped()
            break
        time.sleep(1)

def launchGame():
    print("Launching %s..." % game_path)
    global game_process
    global game_status_thread
    if game_process is not None and game_process.poll() is None:
        state.notifyGameLaunched()
    try:
        game_process = subprocess.Popen([game_path], cwd=game_dir)
        minimizeLauncher()
        game_status_thread = threading.Thread(target=gameStatusLoop)
        game_status_thread.daemon = True
        game_status_thread.start()
        state.notifyGameLaunched()
    except Exception as e:
        print(e)
        state.notifyGameError()

def setUserData(data):
    username = data.get("username")
    token = data.get("token")
    print("Username: %s" % username)
    print("Token: %s" % token)
    appdata_dir = os.path.join(os.environ["APPDATA"], "Electronvolt")
    os.makedirs(appdata_dir, exist_ok=True)
    userdata_path = os.path.join(appdata_dir, "userdata")
    try:
        with open(userdata_path, "w", encoding="utf-8") as f:
            f.write(f"username: {username}\n")
            f.write(f"token: {token}\n")
        print("User data saved to", userdata_path)
    except Exception as e:
        print("Failed to save user data:", e)

def getUserData():
    appdata_dir = os.path.join(os.environ["APPDATA"], "Electronvolt")
    userdata_path = os.path.join(appdata_dir, "userdata")
    if not os.path.isfile(userdata_path):
        print("No saved user data found")
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
            print("Loaded user data:", data)
            return data
        else:
            print("? Invalid user data format.")
            return None
    except Exception as e:
        print("? Failed to read user data:", e)
        return None

def deleteUserData():
    appdata_dir = os.path.join(os.environ["APPDATA"], "Electronvolt")
    userdata_path = os.path.join(appdata_dir, "userdata")
    try:
        if os.path.exists(userdata_path):
            os.remove(userdata_path)
            print("User data deleted")
        else:
            print("No user data to delete")
    except Exception as e:
        print(f"Failed to delete user data: {e}")

bottle.install(SQLitePlugin(dbfile = Config.databasePath))

def randomPort():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port

def serverMain(port):
    bottle.run(host = "0.0.0.0", port = port)

port = randomPort()
serverThread = threading.Thread(target=serverMain, args=(port,))
serverThread.daemon = True
serverThread.start()

winWidth = 700
winHeight = 700

def cefMain(port):
    sys.excepthook = cef.ExceptHook  # To shutdown all CEF processes on error
    cef.Initialize()
    windowInfo = cef.WindowInfo()
    parentHandle = 0
    url = "http://localhost:%s/" % port
    windowInfo.SetAsChild(parentHandle, [0, 0, winWidth, winHeight]) # For macOS and Linux
    browser = cef.CreateBrowserSync(url = url, window_title = "Electronvolt Launcher")
    browser.SetClientHandler(LifespanHandler())
    bindings = cef.JavascriptBindings()
    bindings.SetFunction("appLaunchGame", launchGame)
    bindings.SetFunction("appSetUserData", setUserData)
    bindings.SetFunction("appDeleteUserData", deleteUserData)
    browser.SetJavascriptBindings(bindings)
    if platform.system() == "Windows":
        state.hwnd = browser.GetOuterWindowHandle()
        insertAfterHandle = 0
        # X and Y parameters are ignored by setting the SWP_NOMOVE flag
        SWP_NOMOVE = 0x0002
        ctypes.windll.user32.SetWindowPos(state.hwnd,
            insertAfterHandle, 0, 0, winWidth, winHeight, SWP_NOMOVE)
    #browser.ShowDevTools() # For debugging
    state.browser = browser
    cef.MessageLoop()
    cef.Shutdown()

class LifespanHandler(object):
    def OnLoadEnd(self, browser, frame, http_code):
        data = getUserData()
        if data is not None:
            state.notifyAutoLogin(data["username"], data["token"])
    
    def OnBeforeClose(self, browser):
        print("shutdown")

cefMain(port)
