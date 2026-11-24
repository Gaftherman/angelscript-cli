#include "runtime/Engine.h"

#include <iostream>

namespace runtime
{
static void ReportMessage(const asSMessageInfo* message, void*)
{
    const char* kind = "info";
    if (message->type == asMSGTYPE_ERROR)
        kind = "error";
    else if (message->type == asMSGTYPE_WARNING)
        kind = "warning";

    std::cerr << message->section << ':' << message->row << ':' << message->col
              << ": " << kind << ": " << message->message << '\n';
}

void EngineRelease::operator()(asIScriptEngine* engine) const
{
    engine->ShutDownAndRelease();
}

void ContextRelease::operator()(asIScriptContext* context) const
{
    context->Release();
}

EnginePtr CreateEngine()
{
    EnginePtr engine(asCreateScriptEngine());
    if (!engine || engine->SetMessageCallback(asFUNCTION(ReportMessage), nullptr, asCALL_CDECL) < 0 ||
        engine->SetEngineProperty(asEP_INIT_GLOBAL_VARS_AFTER_BUILD, false) < 0)
    {
        std::cerr << "Could not initialize the AngelScript engine\n";
        return {};
    }
    return engine;
}
}
