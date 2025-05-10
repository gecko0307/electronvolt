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
}

private void ipcSendSync(string message)
{
    auto ipcSocket = new TcpSocket();
    try
    {
        ipcSocket.connect(new std.socket.InternetAddress(ipcHost, ipcPort));
        ipcSocket.send(message);
        ipcSocket.close();
    }
    catch(Exception e)
    {
        logWarning("Failed to send message to the launcher. ", e.msg);
    }
}

void ipcInit(string host, ushort port)
{
    ipcHost = host;
    ipcPort = port;
}

void ipcSend(string message)
{
    taskPool.put(task!ipcSendSync(message));
}
