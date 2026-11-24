#include "runtime/ScriptLoader.h"

#include <scriptbuilder.h>

#include <filesystem>
#include <iostream>
#include <system_error>

namespace runtime
{
static std::filesystem::path PathFromUtf8(std::string_view path)
{
    return std::filesystem::path(std::u8string(path.begin(), path.end()));
}

static std::string PathToUtf8(const std::filesystem::path& path)
{
    const auto utf8 = path.generic_u8string();
    return {utf8.begin(), utf8.end()};
}

bool RelativeIncludeResolver::Resolve(std::string_view include, std::string_view from, std::string& outPath)
{
    if (include.empty())
        return false;

    const auto path = PathFromUtf8(from).parent_path() / PathFromUtf8(include);
    outPath = PathToUtf8(path.lexically_normal());
    return true;
}

static int LoadInclude(const char* include, const char* from, CScriptBuilder* builder, void* userData)
{
    auto& resolver = *static_cast<IncludeResolver*>(userData);
    std::string path;
    if (!resolver.Resolve(include, from, path))
    {
        const auto message = "Could not resolve include '" + std::string(include) + "'";
        builder->GetEngine()->WriteMessage(from, 0, 0, asMSGTYPE_ERROR, message.c_str());
        return -1;
    }
    return builder->AddSectionFromFile(path.c_str());
}

LoadedScript LoadScript(asIScriptEngine& engine, std::string_view path, IncludeResolver& resolver)
{
    std::error_code error;
    const auto absolute = std::filesystem::absolute(PathFromUtf8(path), error).lexically_normal();
    if (error)
    {
        std::cerr << "Could not resolve script path '" << path << "': " << error.message() << '\n';
        return {};
    }

    const auto filename = PathToUtf8(absolute);
    CScriptBuilder builder;
    builder.SetIncludeCallback(LoadInclude, &resolver);
    if (builder.StartNewModule(&engine, "script") < 0 ||
        builder.AddSectionFromFile(filename.c_str()) < 0 || builder.BuildModule() < 0)
    {
        std::cerr << "Could not build " << filename << '\n';
        return {};
    }
    return {builder.GetModule(), PathToUtf8(absolute.parent_path())};
}
}
