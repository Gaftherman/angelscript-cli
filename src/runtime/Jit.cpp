#include "runtime/Jit.h"

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
    if (inputs.arch != Architecture::X86 && inputs.arch != Architecture::X64)
        return {false, "unsupported architecture"};
    return {true, "provider available"};
}
}
