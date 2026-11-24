#pragma once

#include <angelscript.h>

namespace runtime
{
/** @brief Registers the blocking IPv4 TCP globals and reference types. */
bool RegisterNet(asIScriptEngine& engine);
}
