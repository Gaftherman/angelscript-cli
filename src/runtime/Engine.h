#pragma once

#include <angelscript.h>
#include <memory>

namespace runtime
{
/** @brief Shuts down and releases an AngelScript engine. */
struct EngineRelease
{
    /** @brief Releases the owned engine. */
    void operator()(asIScriptEngine* engine) const;
};

/** @brief Releases an AngelScript context. */
struct ContextRelease
{
    /** @brief Releases the owned context. */
    void operator()(asIScriptContext* context) const;
};

using EnginePtr = std::unique_ptr<asIScriptEngine, EngineRelease>;
using ContextPtr = std::unique_ptr<asIScriptContext, ContextRelease>;

/** @brief Creates an engine with diagnostics and deferred global initialization. */
EnginePtr CreateEngine();
}
