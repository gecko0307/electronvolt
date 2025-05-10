module ipc;

import std.socket;
import std.parallelism;

import dagon.core.logger;

/*
 * IPC client for asynchronous communication with the launcher
 */

private __gshared
{
    string ipcHost = "127.0.0.1";
    ushort ipcPort = 65432;
    bool launcherResponding = true;
}

private void ipcSendSync(string message)
{
    auto ipcSocket = new TcpSocket();
    try
    {
        ipcSocket.connect(new std.socket.InternetAddress(ipcHost, ipcPort));
        ipcSocket.send(message);
        ipcSocket.close();
        launcherResponding = true;
    }
    catch(Exception e)
    {
        launcherResponding = false;
        logWarning("Failed to send message to the launcher. ", e.msg);
    }
}

void ipcInit(string host, ushort port)
{
    ipcHost = host;
    ipcPort = port;
}

void ipcSend(string message, bool ping = false)
{
    if (ping || launcherResponding)
        taskPool.put(task!ipcSendSync(message));
}

void ipcPing(string message)
{
    ipcSend(message, true);
}