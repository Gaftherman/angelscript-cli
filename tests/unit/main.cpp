#include "cli/CommandLine.h"
#include "runtime/Jit.h"

#include <array>
#include <cstdlib>
#include <initializer_list>
#include <iostream>
#include <span>
#include <string_view>

#define CHECK(expr)                                                                  \
    do                                                                               \
    {                                                                                \
        if (!(expr))                                                                 \
        {                                                                            \
            std::cerr << __FILE__ << ':' << __LINE__ << ": CHECK(" #expr ") failed\n"; \
            std::exit(EXIT_FAILURE);                                                \
        }                                                                            \
    } while (false)

static int StubCommand(const cli::ScriptOptions&)
{
    return 0;
}

static constexpr std::array Commands = {
    cli::Command{"run", StubCommand, true},
    cli::Command{"check", StubCommand, true},
    cli::Command{"install", StubCommand, false},
    cli::Command{"init", StubCommand, false},
};

static cli::CommandLine Parse(std::span<const std::string_view> args)
{
    return cli::ParseCommandLine(args, Commands, Commands.front());
}

static void TestScriptArguments()
{
    const auto scriptOnly = Parse(std::to_array<std::string_view>({"hello.as"}));
    CHECK(scriptOnly.action == cli::Action::Command);
    CHECK(scriptOnly.command == &Commands[0]);
    CHECK(scriptOnly.options.path == "hello.as");
    CHECK(scriptOnly.options.args.empty());
    CHECK(scriptOnly.options.dapHost == "127.0.0.1");
    CHECK(!scriptOnly.options.dapPort);

    constexpr std::string_view args[] = {"--no-jit", "hello.as", "--help", "", "two words", "--dap-port"};
    const auto scriptWithArgs = Parse(args);
    CHECK(scriptWithArgs.action == cli::Action::Command);
    CHECK(scriptWithArgs.options.path == "hello.as");
    CHECK(scriptWithArgs.options.noJit);
    CHECK(!scriptWithArgs.options.dapPort);
    CHECK(scriptWithArgs.options.args.size() == 4);
    CHECK(scriptWithArgs.options.args.data() == args + 2);
}

static void TestOptions()
{
    const auto dap = Parse(std::to_array<std::string_view>({"--dap-port", "9002", "--dap-host", "localhost", "debug.as"}));
    CHECK(dap.action == cli::Action::Command);
    CHECK(dap.options.dapPort == 9002);
    CHECK(dap.options.dapHost == "localhost");
    CHECK(dap.options.path == "debug.as");

    for (const std::string_view port : {"0", "-1", "65536", "9002abc", "99999999999999999999"})
        CHECK(Parse(std::to_array<std::string_view>({"--dap-port", port, "debug.as"})).action == cli::Action::Error);
    CHECK(Parse(std::to_array<std::string_view>({"--dap-port", "1", "debug.as"})).options.dapPort == 1);
    CHECK(Parse(std::to_array<std::string_view>({"--dap-port", "65535", "debug.as"})).options.dapPort == 65535);

    CHECK(Parse({}).action == cli::Action::Error);
    CHECK(Parse(std::to_array<std::string_view>({"--dap-port"})).action == cli::Action::Error);
    CHECK(Parse(std::to_array<std::string_view>({"--dap-port", "--check", "debug.as"})).action == cli::Action::Error);
    CHECK(Parse(std::to_array<std::string_view>({"--dap-host"})).action == cli::Action::Error);
    CHECK(Parse(std::to_array<std::string_view>({"--unknown", "hello.as"})).action == cli::Action::Error);
    CHECK(Parse(std::to_array<std::string_view>({"--check", "hello.as"})).options.checkOnly);
    CHECK(Parse(std::to_array<std::string_view>({"--help"})).action == cli::Action::Help);
    CHECK(Parse(std::to_array<std::string_view>({"--version"})).action == cli::Action::Version);
}

static void TestSubcommands()
{
    const auto run = Parse(std::to_array<std::string_view>({"run", "--no-jit", "hello.as"}));
    CHECK(run.action == cli::Action::Command);
    CHECK(run.command == &Commands[0]);
    CHECK(run.options.noJit);
    CHECK(run.options.path == "hello.as");

    const auto check = Parse(std::to_array<std::string_view>({"check", "run"}));
    CHECK(check.action == cli::Action::Command);
    CHECK(check.command == &Commands[1]);
    CHECK(check.options.path == "run");
    CHECK(Parse(std::to_array<std::string_view>({"check"})).action == cli::Action::Error);
    CHECK(Parse(std::to_array<std::string_view>({"./run"})).options.path == "./run");

    for (const auto& command : Commands)
    {
        if (command.takesScript)
            continue;
        const auto reserved = Parse(std::to_array<std::string_view>({command.name}));
        CHECK(reserved.action == cli::Action::Command);
        CHECK(reserved.command == &command);
        CHECK(reserved.options.path.empty());
    }
}

static void TestJitPolicy()
{
    using runtime::Architecture;
    for (const auto arch : {Architecture::X86, Architecture::X64, Architecture::Arm64, Architecture::Other})
        for (const bool provider : {false, true})
            for (const bool noJit : {false, true})
                for (const bool dap : {false, true})
                {
                    const auto decision = runtime::Decide({provider, arch, noJit, dap});
                    CHECK(decision.enabled == (provider && arch != Architecture::Other && !noJit && !dap));
                    CHECK(!decision.reason.empty());
                }
}

/** @brief Runs the command-line parsing and JIT policy assertions. */
int main()
{
    TestScriptArguments();
    TestOptions();
    TestSubcommands();
    TestJitPolicy();
}
