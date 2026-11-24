#include "debug/DapSession.h"

#include <iostream>

namespace runtime
{
DapSession::DapSession(asIScriptEngine& engine, asIScriptContext& context, std::string_view rootDir)
    : debugger_(&engine, adapter_, rootDir), context_(context)
{
}

DapSession::~DapSession()
{
    if (attached_)
        debugger_.DetachContext(&context_);
}

bool DapSession::Start(std::string_view host, int port)
{
    if (!debugger_.Start(host, port))
    {
        std::cerr << "Could not listen on " << host << ':' << port << '\n';
        return false;
    }

    std::cout << "DAP listening on " << host << ':' << port << std::endl;
    if (!debugger_.WaitForClient())
    {
        std::cerr << "Could not wait for the DAP client\n";
        return false;
    }

    attached_ = debugger_.AttachContext(&context_);
    if (!attached_)
        std::cerr << "Could not attach the debugger to the script context\n";
    return attached_;
}

void DapSession::Poll()
{
    debugger_.Poll();
}
}
