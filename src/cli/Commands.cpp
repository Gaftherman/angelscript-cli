#include "cli/Commands.h"
#include "cli/CommandLine.h"
#ifdef ANGELSCRIPT_CLI_HAS_DUMP_PREDEFINED
#include "runtime/DumpRegistry.h"
#endif
#include "runtime/Engine.h"
#include "runtime/Executor.h"
#include "runtime/Jit.h"
#include "runtime/Stdlib.h"

#include <angelscript.h>
#include <array>
#include <iostream>

namespace cli
{
static int RunScript(const ScriptOptions& options)
{
    return runtime::Execute({options.path, options.args, options.dapHost, options.dapPort,
                             options.checkOnly, options.noJit, options.aotExport, options.aotLoad});
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
              "  --aot-export BASE  Write BASE.c and BASE.externs for ahead-of-time compilation, then exit\n"
              "  --aot BASE         Load the library built from that export (BASE.dll, BASE.so or BASE.dylib)\n"
              "  --version          Print the runtime version\n"
              "  --dump-predefined  Print the API every script sees as an .as.predefined stub\n"
              "  --help             Print this help\n";
}

static void PrintVersion()
{
    const auto jit = runtime::CreateJitProvider();
    std::cout << "angelscript " ANGELSCRIPT_CLI_VERSION " (AngelScript " ANGELSCRIPT_VERSION_STRING
                 ", jit: " << jit->Name() << ")\n";
}

static int DumpPredefined()
{
#ifndef ANGELSCRIPT_CLI_HAS_DUMP_PREDEFINED
    std::cerr << "--dump-predefined needs an engine built against AngelScript 2.39.0 or later\n";
    return 2;
#else
    const auto engine = runtime::CreateEngine();
    if (!engine)
        return 1;
    runtime::ScriptArguments noArguments;
    if (!runtime::RegisterStdlib(*engine, noArguments))
    {
        std::cerr << "Could not register the standard library\n";
        return 1;
    }
    DumpRegistry(engine.get(), stdout);
    return 0;
#endif
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
    case Action::DumpPredefined:
        return DumpPredefined();
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
