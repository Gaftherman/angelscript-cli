#include "cli/Commands.h"
#include "cli/CommandLine.h"
#include "runtime/Executor.h"
#include "runtime/Jit.h"

#include <angelscript.h>
#include <array>
#include <iostream>

namespace cli
{
static int RunScript(const ScriptOptions& options)
{
    return runtime::Execute({options.path, options.args, options.dapHost, options.dapPort,
                             options.checkOnly, options.noJit});
}

static int CheckScript(const ScriptOptions& options)
{
    ScriptOptions check = options;
    check.checkOnly = true;
    return RunScript(check);
}

static int Reserved(const ScriptOptions&)
{
    std::cerr << "planned for a future version\n";
    return 2;
}

static constexpr std::array Commands = {
    Command{"run", RunScript, true},
    Command{"check", CheckScript, true},
    Command{"install", Reserved, false},
    Command{"init", Reserved, false},
};

static void PrintUsage(std::ostream& output)
{
    output << "Usage: angelscript [run | check] [options] <script.as> [args...]\n"
              "  --dap-port <port>  Start a DAP session on a port from 1 to 65535\n"
              "  --dap-host <host>  Set the DAP listen host (default 127.0.0.1)\n"
              "  --check            Compile the script only\n"
              "  --no-jit           Use the interpreter\n"
              "  --version          Print the runtime version\n"
              "  --help             Print this help\n";
}

static void PrintVersion()
{
    runtime::NullJit jit;
    std::cout << "angelscript " ANGELSCRIPT_CLI_VERSION " (AngelScript " ANGELSCRIPT_VERSION_STRING
                 ", jit: " << jit.Name() << ")\n";
}

int Run(std::span<const std::string_view> args)
{
    const auto parsed = ParseCommandLine(args, Commands, Commands.front());
    switch (parsed.action)
    {
    case Action::Help:
        PrintUsage(std::cout);
        return 0;
    case Action::Version:
        PrintVersion();
        return 0;
    case Action::Error:
        std::cerr << parsed.error << '\n';
        PrintUsage(std::cerr);
        return 2;
    case Action::Command:
        return parsed.command->handler(parsed.options);
    }
    return 2;
}
}
