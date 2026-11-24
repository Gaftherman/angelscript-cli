#pragma once

#include <angelscript.h>
#include <string>
#include <string_view>

namespace runtime
{
/** @brief Maps an include directive and its containing file to an on-disk script. */
class IncludeResolver
{
public:
    /** @brief Destroys the include resolver. */
    virtual ~IncludeResolver() = default;

    /** @brief Resolves include from its containing section filename into a UTF-8 path for CScriptBuilder. */
    virtual bool Resolve(std::string_view include, std::string_view from, std::string& outPath) = 0;
};

/** @brief Resolves relative includes from the directory of the file that contains them. */
class RelativeIncludeResolver final : public IncludeResolver
{
public:
    /** @brief Resolves the path without opening the include file. */
    bool Resolve(std::string_view include, std::string_view from, std::string& outPath) override;
};

/** @brief Holds an engine-owned module and the directory of its entry script. */
struct LoadedScript
{
    asIScriptModule* module = nullptr;
    std::string rootDir;
};

/** @brief Builds the script and its includes, returning a null module if compilation fails. */
LoadedScript LoadScript(asIScriptEngine& engine, std::string_view path, IncludeResolver& resolver);
}
