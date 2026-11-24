#include "runtime/NetSocket.h"

#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <winsock2.h>
#include <ws2tcpip.h>
#include <mutex>
#else
#include <netdb.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>
#endif

#include <algorithm>
#include <cerrno>
#include <limits>
#include <memory>
#include <stdexcept>
#include <string>
#include <system_error>
#include <utility>

namespace runtime
{
#ifdef _WIN32
using SocketLength = int;
static constexpr int Interrupted = WSAEINTR;
static std::mutex winsockMutex;
static unsigned winsockUsers = 0;

NetSocket::Winsock::Winsock()
{
    const std::lock_guard lock(winsockMutex);
    if (winsockUsers == 0)
    {
        WSADATA data{};
        const int error = WSAStartup(MAKEWORD(2, 2), &data);
        if (error != 0)
            throw std::system_error(error, std::system_category(), "WSAStartup");
    }
    ++winsockUsers;
}

NetSocket::Winsock::Winsock(Winsock&& other) noexcept
    : active_(std::exchange(other.active_, false))
{
}

NetSocket::Winsock::~Winsock()
{
    if (!active_)
        return;
    const std::lock_guard lock(winsockMutex);
    if (--winsockUsers == 0)
        WSACleanup();
}
#else
using SocketLength = socklen_t;
static constexpr int Interrupted = EINTR;
#endif

static int LastSocketError()
{
#ifdef _WIN32
    return WSAGetLastError();
#else
    return errno;
#endif
}

[[noreturn]] static void ThrowSocketError(std::string_view operation, int error)
{
#ifdef _WIN32
    throw std::system_error(error, std::system_category(), std::string(operation));
#else
    throw std::system_error(error, std::generic_category(), std::string(operation));
#endif
}

template<class Handle>
static int EnableSocketOption(Handle handle, int option)
{
    const int enabled = 1;
    return setsockopt(handle, SOL_SOCKET, option, reinterpret_cast<const char*>(&enabled),
                      static_cast<SocketLength>(sizeof(enabled)));
}

#ifdef MSG_NOSIGNAL
static constexpr int SendFlags = MSG_NOSIGNAL;
#else
static constexpr int SendFlags = 0;
#endif

NetSocket::NetSocket(NetSocket&& other) noexcept
    :
#ifdef _WIN32
      winsock_(std::move(other.winsock_)),
#endif
      handle_(std::exchange(other.handle_, Invalid))
{
}

NetSocket::~NetSocket()
{
    Close();
}

NetSocket NetSocket::Connect(std::string_view host, std::uint16_t port)
{
    return Open(host, port, false);
}

NetSocket NetSocket::Listen(std::string_view host, std::uint16_t port)
{
    return Open(host, port, true);
}

NetSocket NetSocket::Open(std::string_view host, std::uint16_t port, bool listening)
{
    if (host.find('\0') != std::string_view::npos || (!listening && host.empty()))
        throw std::invalid_argument("invalid host");

    NetSocket socket;
    const std::string node(host);
    const std::string service = std::to_string(port);
    addrinfo hints{};
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;
    hints.ai_flags = AI_NUMERICSERV | (listening ? AI_PASSIVE : 0);
    addrinfo* resolved = nullptr;
    const int lookup = getaddrinfo(node.empty() ? nullptr : node.c_str(), service.c_str(), &hints, &resolved);
    if (lookup != 0)
    {
#ifdef _WIN32
        ThrowSocketError("getaddrinfo", lookup);
#else
        throw std::runtime_error(std::string("getaddrinfo: ") + gai_strerror(lookup));
#endif
    }
    const std::unique_ptr<addrinfo, decltype(&freeaddrinfo)> addresses(resolved, freeaddrinfo);

    std::string_view operation = "socket";
    int error = 0;
    for (const addrinfo* address = addresses.get(); address; address = address->ai_next)
    {
        operation = "socket";
        socket.handle_ = ::socket(address->ai_family, address->ai_socktype, address->ai_protocol);
        if (socket.IsOpen())
        {
            const auto length = static_cast<SocketLength>(address->ai_addrlen);
            if (listening)
            {
                operation = "setsockopt(SO_REUSEADDR)";
                if (EnableSocketOption(socket.handle_, SO_REUSEADDR) == 0)
                {
                    operation = "bind";
                    if (bind(socket.handle_, address->ai_addr, length) == 0)
                    {
                        operation = "listen";
                        if (listen(socket.handle_, 8) == 0)
                            return socket;
                    }
                }
            }
            else
            {
#if defined(SO_NOSIGPIPE) && !defined(MSG_NOSIGNAL)
                if (EnableSocketOption(socket.handle_, SO_NOSIGPIPE) != 0)
                    ThrowSocketError("setsockopt(SO_NOSIGPIPE)", LastSocketError());
#endif
                operation = "connect";
                if (connect(socket.handle_, address->ai_addr, length) == 0)
                    return socket;
            }
        }
        error = LastSocketError();
        socket.Close();
    }
    if (!addresses)
        throw std::runtime_error("no IPv4 address found");
    ThrowSocketError(operation, error);
}

std::uint16_t NetSocket::Port() const
{
    RequireOpen();
    sockaddr_in address{};
    auto length = static_cast<SocketLength>(sizeof(address));
    if (getsockname(handle_, reinterpret_cast<sockaddr*>(&address), &length) != 0)
        ThrowSocketError("getsockname", LastSocketError());
    return ntohs(address.sin_port);
}

NetSocket NetSocket::Accept() const
{
    RequireOpen();
    NetSocket client;
    for (;;)
    {
        client.handle_ = accept(handle_, nullptr, nullptr);
        if (client.IsOpen())
            break;
        const int error = LastSocketError();
        if (error != Interrupted)
            ThrowSocketError("accept", error);
    }
#if defined(SO_NOSIGPIPE) && !defined(MSG_NOSIGNAL)
    if (EnableSocketOption(client.handle_, SO_NOSIGPIPE) != 0)
        ThrowSocketError("setsockopt(SO_NOSIGPIPE)", LastSocketError());
#endif
    return client;
}

int NetSocket::Send(std::string_view data) const
{
    RequireOpen();
    if (data.size() > static_cast<std::size_t>(std::numeric_limits<int>::max()))
        throw std::length_error("data exceeds the maximum send size");

    const int total = static_cast<int>(data.size());
    while (!data.empty())
    {
        const auto count = send(handle_, data.data(), static_cast<int>(data.size()), SendFlags);
        if (count > 0)
            data.remove_prefix(static_cast<std::size_t>(count));
        else if (count == 0)
            throw std::runtime_error("send made no progress");
        else if (const int error = LastSocketError(); error != Interrupted)
            ThrowSocketError("send", error);
    }
    return total;
}

std::size_t NetSocket::Receive(std::span<char> buffer) const
{
    RequireOpen();
    if (buffer.empty())
        return 0;

    const auto length = std::min(buffer.size(), static_cast<std::size_t>(std::numeric_limits<int>::max()));
    for (;;)
    {
        const auto count = recv(handle_, buffer.data(), static_cast<int>(length), 0);
        if (count >= 0)
            return static_cast<std::size_t>(count);
        const int error = LastSocketError();
        if (error != Interrupted)
            ThrowSocketError("recv", error);
    }
}

void NetSocket::Close() noexcept
{
    if (!IsOpen())
        return;
#ifdef _WIN32
    closesocket(handle_);
#else
    close(handle_);
#endif
    handle_ = Invalid;
}

bool NetSocket::IsOpen() const noexcept
{
    return handle_ != Invalid;
}

void NetSocket::RequireOpen() const
{
    if (!IsOpen())
        throw std::runtime_error("socket is closed");
}
}
