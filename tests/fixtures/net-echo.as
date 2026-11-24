void main()
{
    TcpListener@ server = tcpListen("127.0.0.1", 0);
    TcpSocket@ client = tcpConnect("127.0.0.1", server.port());
    TcpSocket@ peer = server.accept();

    client.send("ping\n");
    string line = peer.receiveLine();
    peer.send("pong:" + line + "\n");
    println(client.receiveLine());

    client.close();
    peer.close();
    server.close();
}
