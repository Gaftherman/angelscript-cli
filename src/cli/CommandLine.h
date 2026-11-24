#pragma once

#include <optional>
#include <span>
#include <string>
#include <string_view>

namespace cli
{
/** @brief Holds runtime options and views into the original argument list. */
struct ScriptOptions
{
    std::string_view path;
    std::span<const std::string_view> args;
    std::string_view dapHost = "127.0.0.1";
    std::optional<int> dapPort;
    bool checkOnly = false;
    bool noJit = false;
};

/** @brief Maps a subcommand name to its handler and script requirement. */
struct Command
{
    std::string_view name;
    int (*handler)(const ScriptOptions&);
    bool takesScript;
};

/** @brief Identifies the action selected by command-line parsing. */
enum class Action
{
    Command,
    Help,
    Version,
    Error,
};

/** @brief Holds the selected action, parsed options, or a usage error. */
struct CommandLine
{
    ScriptOptions options;
    const Command* command = nullptr;
    Action action = Action::Command;
    std::string error;
};

/** @brief Parses arguments before the script path, preserving every subsequent argument. */
CommandLine ParseCommandLine(std::span<const std::string_view> args,
                             std::span<const Command> commands, const Command& defaultCommand);
}
