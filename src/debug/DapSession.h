#pragma once

#include <adapters/std_host_adapter.h>
#include <as_debugger_host.h>
#include <string_view>

namespace runtime
{
/** @brief Owns a DAP server and its attachment to one script context. */
class DapSession
{
public:
    /** @brief Creates a session for an engine and context that outlive it. */
    DapSession(asIScriptEngine& engine, asIScriptContext& context, std::string_view rootDir);

    /** @brief Detaches the context before closing the DAP server. */
    ~DapSession();

    /** @brief Starts listening, waits for client configuration, and attaches the context. */
    bool Start(std::string_view host, int port);

    /** @brief Processes pending debugger work between script executions. */
    void Poll();

private:
    StdHostAdapter adapter_;
    asIDBHostDebugger debugger_;
    asIScriptContext& context_;
    bool attached_ = false;
};
}
