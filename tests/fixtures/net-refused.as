void main()
{
    TcpListener@ probe = tcpListen("127.0.0.1", 0);
    uint16 port = probe.port();
    probe.close();
    TcpSocket@ socket = tcpConnect("127.0.0.1", port);
}
