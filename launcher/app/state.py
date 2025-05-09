import platform
import ctypes
import json

browser = None
hwnd = None

def sendMessage(data):
    message = json.dumps(data)
    browser.ExecuteJavascript(f"window.postMessage({message}, '*');")

def notifyGameLaunched():
    sendMessage({
        "event": "game_status_change",
        "status": "running"
    })

def notifyGameStopped():
    sendMessage({
        "event": "game_status_change",
        "status": "stopped"
    })

def notifyGameError():
    sendMessage({
        "event": "game_status_change",
        "status": "error"
    })
