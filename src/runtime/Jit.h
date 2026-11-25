#pragma once

#include <angelscript.h>
#include <memory>
#include <string_view>

namespace runtime
{
/** @brief Attaches a JIT implementation to an AngelScript engine. */
class JitProvider
{
public:
    /** @brief Destroys the JIT provider. */
    virtual ~JitProvider() = default;

    /** @brief Reports whether the provider successfully attached. */
    virtual bool Attach(asIScriptEngine& engine) = 0;

    /** @brief Returns the provider name for the CLI version output. */
    virtual const char* Name() = 0;
};

/** @brief Represents the interpreter-only build of the CLI. */
class NullJit final : public JitProvider
{
public:
    /** @brief Leaves the engine configured for interpretation. */
    bool Attach(asIScriptEngine& engine) override;

    /** @brief Returns the name used when JIT is unavailable. */
    const char* Name() override;
};

/** @brief Identifies the host architectures relevant to JIT selection. */
enum class Architecture
{
    X86,
    X64,
    Arm64,
    Other,
};

/** @brief Collects the conditions that govern JIT selection. */
struct JitInputs
{
    bool providerAvailable;
    Architecture arch;
    bool noJitFlag;
    bool dapMode;
};

/** @brief Captures the JIT decision and its reason. */
struct JitPolicy
{
    bool enabled;
    std::string_view reason;
};

/** @brief Identifies the architecture for which the CLI was compiled. */
Architecture HostArchitecture();

/** @brief Allows JIT only on x86, x64 or arm64 with a provider and without debugging or --no-jit. */
JitPolicy Decide(const JitInputs& inputs);

/** @brief Reports whether this build includes a JIT compiler (ANGELSCRIPT_CLI_JIT in CMake). */
bool JitBuiltIn();

/** @brief Creates the JIT provider of this build: angelsea when it is built in, NullJit otherwise. */
std::unique_ptr<JitProvider> CreateJitProvider();
}
