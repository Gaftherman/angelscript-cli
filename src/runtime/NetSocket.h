#pragma once

#include <cstddef>
#include <cstdint>
#include <span>
#include <string_view>

namespace runtime
{
/** @brief Owns a native blocking IPv4 TCP socket. Operations can throw on socket errors. */
class NetSocket
{
public:
    /** @brief Resolves a host and connects to its TCP port. */
    static NetSocket Connect(std::string_view host, std::uint16_t port);

    /** @brief Binds and listens, using an ephemeral port when port is zero. */
    static NetSocket Listen(std::string_view host, std::uint16_t port);

    /** @brief Takes ownership of the native socket. */
    NetSocket(NetSocket&& other) noexcept;

    /** @brief Closes the native socket. */
    ~NetSocket();

    /** @brief Returns the local port assigned to the socket. */
    std::uint16_t Port() const;

    /** @brief Waits for a connection and returns the accepted socket. */
    NetSocket Accept() const;

    /** @brief Sends all bytes and returns the byte count, which must fit in an int. */
    int Send(std::string_view data) const;

    /** @brief Reads up to buffer.size() bytes, with zero indicating EOF for a nonempty buffer. */
    std::size_t Receive(std::span<char> buffer) const;

    /** @brief Closes the socket, with repeated calls having no effect. */
    void Close() noexcept;

    /** @brief Reports whether this object owns an open socket. */
    bool IsOpen() const noexcept;

private:
#ifdef _WIN32
    /** @brief Keeps Winsock initialized while any native socket owner is active. */
    class Winsock
    {
    public:
        /** @brief Acquires a reference to Winsock. */
        Winsock();
        /** @brief Transfers an existing Winsock reference. */
        Winsock(Winsock&& other) noexcept;
        /** @brief Releases the Winsock reference, cleaning up after the last owner. */
        ~Winsock();

    private:
        bool active_ = true;
    };

    Winsock winsock_;
    using Handle = std::uintptr_t;
#else
    using Handle = int;
#endif
    static constexpr Handle Invalid = static_cast<Handle>(-1);

    NetSocket() = default;
    static NetSocket Open(std::string_view host, std::uint16_t port, bool listening);
    void RequireOpen() const;

    Handle handle_ = Invalid;
};
}
