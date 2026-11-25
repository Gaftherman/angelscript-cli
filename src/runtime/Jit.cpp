#include "runtime/Jit.h"

#ifdef ANGELSCRIPT_CLI_HAS_ANGELSEA
#include "runtime/AngelseaJit.h"
#endif

namespace runtime
{
bool NullJit::Attach(asIScriptEngine&)
{
    return false;
}

const char* NullJit::Name()
{
    return "unavailable";
}

Architecture HostArchitecture()
{
#if defined(_M_X64) || defined(__x86_64__)
    return Architecture::X64;
#elif defined(_M_ARM64) || defined(__aarch64__)
    return Architecture::Arm64;
#elif defined(_M_IX86) || defined(__i386__)
    return Architecture::X86;
#else
    return Architecture::Other;
#endif
}

JitPolicy Decide(const JitInputs& inputs)
{
    if (inputs.dapMode)
        return {false, "disabled during DAP debugging"};
    if (inputs.noJitFlag)
        return {false, "disabled by --no-jit"};
    if (!inputs.providerAvailable)
        return {false, "no provider available"};
    if (inputs.arch == Architecture::Other)
        return {false, "unsupported architecture"};
    return {true, "provider available"};
}

bool JitBuiltIn()
{
#ifdef ANGELSCRIPT_CLI_HAS_ANGELSEA
    return true;
#else
    return false;
#endif
}

std::unique_ptr<JitProvider> CreateJitProvider()
{
#ifdef ANGELSCRIPT_CLI_HAS_ANGELSEA
    return std::make_unique<AngelseaJit>();
#else
    return std::make_unique<NullJit>();
#endif
}
}
