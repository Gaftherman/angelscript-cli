#pragma once

#include <angelscript.h>
#include <span>
#include <string_view>

namespace runtime
{
using ScriptArguments = std::span<const std::string_view>;

/** @brief Registers the standard add-ons and CLI globals. Keep args alive for the engine's lifetime. */
bool RegisterStdlib(asIScriptEngine& engine, ScriptArguments& args);
}
