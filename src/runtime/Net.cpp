#include "runtime/Net.h"
#include "runtime/NetSocket.h"

#include <algorithm>
#include <array>
#include <atomic>
#include <cstddef>
#include <exception>
#include <string>
#include <string_view>
#include <utility>

namespace runtime
{
class TcpStream
{
public:
    /** @brief Owns the connected socket and its unread bytes. */
    explicit TcpStream(NetSocket socket) : socket_(std::move(socket)) {}

    /** @brief Sends the entire string and returns the byte count. */
    int Send(std::string_view data) const { return socket_.Send(data); }

    /** @brief Reads up to maxBytes bytes. Zero returns an empty string without reading. */
    std::string Receive(std::size_t maxBytes)
    {
        if (maxBytes == 0)
            return {};

        FillBuffer();
        const auto count = std::min(maxBytes, unread_.size());
        std::string data(unread_.substr(0, count));
        unread_.remove_prefix(count);
        return data;
    }

    /** @brief Reads one line and strips its LF or CRLF terminator.
     * An empty result with isOpen() true is a blank line. At EOF the socket closes
     * and any final unterminated bytes are returned once, including a bare CR.
     * An empty result with isOpen() false means there is no more data.
     */
    std::string ReceiveLine()
    {
        std::string line;
        while (FillBuffer())
        {
            const auto newline = unread_.find('\n');
            line.append(unread_.substr(0, newline));
            if (newline != std::string_view::npos)
            {
                unread_.remove_prefix(newline + 1);
                if (!line.empty() && line.back() == '\r')
                    line.pop_back();
                return line;
            }
            unread_ = {};
        }
        return line;
    }

    /** @brief Closes the connection and drops unread bytes. */
    void Close()
    {
        unread_ = {};
        socket_.Close();
    }

    /** @brief Reports whether the connection is open locally, until close or observed EOF. */
    bool IsOpen() const { return socket_.IsOpen(); }

private:
    bool FillBuffer()
    {
        if (unread_.empty() && socket_.IsOpen())
        {
            const auto count = socket_.Receive(buffer_);
            unread_ = {buffer_.data(), count};
            if (count == 0)
                socket_.Close();
        }
        return !unread_.empty();
    }

    NetSocket socket_;
    std::array<char, 4096> buffer_{};
    std::string_view unread_;
};

template<class T>
class SocketHandle
{
public:
    /** @brief Takes ownership of a socket and starts with one script reference. */
    explicit SocketHandle(NetSocket socket) : socket_(std::move(socket)) {}

    /** @brief Adds a script reference. */
    static void AddRef(asIScriptGeneric* call) { ++Self(call).references_; }

    /** @brief Drops a script reference and destroys the socket when the last one is gone. */
    static void Release(asIScriptGeneric* call)
    {
        auto& object = Self(call);
        if (--object.references_ == 0)
            delete &object;
    }

    /** @brief Closes the underlying socket. */
    static void Close(asIScriptGeneric* call) { Get(call).Close(); }

    /** @brief Returns the socket associated with the script method call. */
    static T& Get(asIScriptGeneric* call) { return Self(call).socket_; }

private:
    static SocketHandle& Self(asIScriptGeneric* call) { return *static_cast<SocketHandle*>(call->GetObject()); }

    T socket_;
    std::atomic<unsigned> references_{1};
};

using ListenerHandle = SocketHandle<NetSocket>;
using StreamHandle = SocketHandle<TcpStream>;

template<class Function>
static void WithScriptException(std::string_view operation, Function invoke)
{
    try
    {
        invoke();
    }
    catch (const std::exception& error)
    {
        const auto message = std::string(operation) + ": " + error.what();
        if (auto* context = asGetActiveContext())
            context->SetException(message.c_str());
    }
}

static std::string_view StringArgument(asIScriptGeneric* call)
{
    return *static_cast<const std::string*>(call->GetArgObject(0));
}

static void Connect(asIScriptGeneric* call)
{
    WithScriptException("tcpConnect", [call] {
        call->SetReturnAddress(new StreamHandle(NetSocket::Connect(StringArgument(call), call->GetArgWord(1))));
    });
}

static void Listen(asIScriptGeneric* call)
{
    WithScriptException("tcpListen", [call] {
        call->SetReturnAddress(new ListenerHandle(NetSocket::Listen(StringArgument(call), call->GetArgWord(1))));
    });
}

static void Port(asIScriptGeneric* call)
{
    WithScriptException("TcpListener.port", [call] {
        call->SetReturnWord(ListenerHandle::Get(call).Port());
    });
}

static void Accept(asIScriptGeneric* call)
{
    WithScriptException("TcpListener.accept", [call] {
        call->SetReturnAddress(new StreamHandle(ListenerHandle::Get(call).Accept()));
    });
}

static void Send(asIScriptGeneric* call)
{
    WithScriptException("TcpSocket.send", [call] {
        call->SetReturnDWord(static_cast<asDWORD>(StreamHandle::Get(call).Send(StringArgument(call))));
    });
}

static void Receive(asIScriptGeneric* call)
{
    WithScriptException("TcpSocket.receive", [call] {
        auto data = StreamHandle::Get(call).Receive(call->GetArgDWord(0));
        call->SetReturnObject(&data);
    });
}

static void ReceiveLine(asIScriptGeneric* call)
{
    WithScriptException("TcpSocket.receiveLine", [call] {
        auto line = StreamHandle::Get(call).ReceiveLine();
        call->SetReturnObject(&line);
    });
}

static void IsOpen(asIScriptGeneric* call)
{
    call->SetReturnByte(StreamHandle::Get(call).IsOpen());
}

template<class Handle>
static bool RegisterSocketType(asIScriptEngine& engine, const char* name)
{
    return engine.RegisterObjectType(name, 0, asOBJ_REF) >= 0 &&
           engine.RegisterObjectBehaviour(name, asBEHAVE_ADDREF, "void f()", asFUNCTION(Handle::AddRef),
                                          asCALL_GENERIC) >= 0 &&
           engine.RegisterObjectBehaviour(name, asBEHAVE_RELEASE, "void f()", asFUNCTION(Handle::Release),
                                          asCALL_GENERIC) >= 0 &&
           engine.RegisterObjectMethod(name, "void close()", asFUNCTION(Handle::Close), asCALL_GENERIC) >= 0;
}

bool RegisterNet(asIScriptEngine& engine)
{
    return RegisterSocketType<StreamHandle>(engine, "TcpSocket") &&
           RegisterSocketType<ListenerHandle>(engine, "TcpListener") &&
           engine.RegisterObjectMethod("TcpSocket", "int send(const string &in data)", asFUNCTION(Send),
                                       asCALL_GENERIC) >= 0 &&
           engine.RegisterObjectMethod("TcpSocket", "string receive(uint maxBytes)", asFUNCTION(Receive),
                                       asCALL_GENERIC) >= 0 &&
           engine.RegisterObjectMethod("TcpSocket", "string receiveLine()", asFUNCTION(ReceiveLine),
                                       asCALL_GENERIC) >= 0 &&
           engine.RegisterObjectMethod("TcpSocket", "bool isOpen() const", asFUNCTION(IsOpen),
                                       asCALL_GENERIC) >= 0 &&
           engine.RegisterObjectMethod("TcpListener", "uint16 port() const", asFUNCTION(Port),
                                       asCALL_GENERIC) >= 0 &&
           engine.RegisterObjectMethod("TcpListener", "TcpSocket@ accept()", asFUNCTION(Accept),
                                       asCALL_GENERIC) >= 0 &&
           engine.RegisterGlobalFunction("TcpSocket@ tcpConnect(const string &in host, uint16 port)",
                                         asFUNCTION(Connect), asCALL_GENERIC) >= 0 &&
           engine.RegisterGlobalFunction("TcpListener@ tcpListen(const string &in host, uint16 port)",
                                         asFUNCTION(Listen), asCALL_GENERIC) >= 0;
}
}
