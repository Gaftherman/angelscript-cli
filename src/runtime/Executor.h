#pragma once

#include <optional>
#include <span>
#include <string_view>

namespace runtime
{
/** @brief Specifies the script, its arguments, and how to execute it. */
struct ExecutionRequest
{
    std::string_view scriptPath;
    std::span<const std::string_view> scriptArgs;
    std::string_view dapHost;
    std::optional<int> dapPort;
    bool checkOnly;
    bool noJit;
    std::string_view aotExport;
    std::string_view aotLoad;
};

/** @brief Compiles the script and returns its process exit code. */
int Execute(const ExecutionRequest& request);
}
