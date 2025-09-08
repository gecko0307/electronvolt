module ipc;

import std.socket: TcpSocket, InternetAddress;

import dlib.core.ownership;
import dagon.core.messaging;
import dagon.core.logger;

/**
 * IPC client for asynchronous communication with the launcher
 */
class LauncherClientService: Service
{
    string host;
    ushort port;
    bool launcherResponding = false;

    this(string address, MessageBroker broker, Owner owner, string host, ushort port)
    {
        super(address, broker, owner);
        this.host = host;
        this.port = port;
    }

    override void onMessage(int domain, string sender, string message, void* payload)
    {
        // TODO: make GC-free socket library
        auto ipcSocket = new TcpSocket();
        try
        {
            ipcSocket.connect(new InternetAddress(host, port));
            ipcSocket.send(message);
            ipcSocket.close();
            launcherResponding = true;
        }
        catch(Exception e)
        {
            launcherResponding = false;
            queueLog(LogLevel.Warning, e.msg);
        }
    }
}
