#include "cli/CommandLine.h"

#include <algorithm>
#include <charconv>
#include <system_error>

namespace cli
{
static CommandLine UsageError(std::string_view message)
{
    CommandLine result;
    result.action = Action::Error;
    result.error = message;
    return result;
}

static std::optional<int> ParsePort(std::string_view value)
{
    int port = 0;
    const auto end = value.data() + value.size();
    const auto parsed = std::from_chars(value.data(), end, port);
    if (parsed.ec != std::errc{} || parsed.ptr != end || port < 1 || port > 65535)
        return std::nullopt;
    return port;
}

CommandLine ParseCommandLine(std::span<const std::string_view> args,
                             std::span<const Command> commands, const Command& defaultCommand)
{
    CommandLine result;
    while (!args.empty())
    {
        const auto arg = args.front();
        args = args.subspan(1);
        if (arg == "--help" || arg == "--version")
        {
            result.action = arg == "--help" ? Action::Help : Action::Version;
            return result;
        }
        if (arg == "--check")
            result.options.checkOnly = true;
        else if (arg == "--no-jit")
            result.options.noJit = true;
        else if (arg == "--dap-port" || arg == "--dap-host")
        {
            if (args.empty() || args.front().empty() || args.front().starts_with("--"))
                return UsageError(std::string(arg) + " requires a value");

            const auto value = args.front();
            args = args.subspan(1);
            if (arg == "--dap-port")
            {
                result.options.dapPort = ParsePort(value);
                if (!result.options.dapPort)
                    return UsageError("--dap-port requires a number from 1 to 65535");
            }
            else
                result.options.dapHost = value;
        }
        else if (arg.starts_with('-'))
            return UsageError("Unknown option " + std::string(arg));
        else
        {
            if (!result.command)
            {
                const auto command = std::ranges::find(commands, arg, &Command::name);
                if (command != commands.end())
                {
                    result.command = &*command;
                    if (!command->takesScript)
                        return result;
                    continue;
                }
                result.command = &defaultCommand;
            }

            if (arg.empty())
                return UsageError("Expected a script path");
            result.options.path = arg;
            result.options.args = args;
            return result;
        }
    }
    return UsageError("Expected a script path");
}
}
