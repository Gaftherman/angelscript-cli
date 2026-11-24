void main()
{
    TcpListener@ server = tcpListen("127.0.0.1", 0);
    TcpSocket@ client = tcpConnect("127.0.0.1", server.port());
    TcpSocket@ peer = server.accept();
    peer.close();
    string rest = client.receive(16);
    println("received=" + rest.length());
    client.close();
    server.close();
}
