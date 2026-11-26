#pragma once

#include "runtime/Jit.h"

#include <memory>

namespace angelsea
{
class Jit;
}

namespace runtime
{
/** @brief Compiles script bytecode to native code with the angelsea JIT (C to MIR). */
class AngelseaJit final : public JitProvider
{
public:
    /** @brief Creates a provider that is not attached to an engine yet. */
    AngelseaJit();

    /** @brief Destroys the JIT; it must outlive the engine it is attached to. */
    ~AngelseaJit() override;

    /** @brief Enables the engine's JIT instructions and registers the compiler. Call before loading scripts. */
    bool Attach(asIScriptEngine& engine) override;

    /** @brief Returns the provider name for the CLI version output. */
    const char* Name() override;

    /** @brief Writes `<base>.c` and `<base>.externs` for the module. */
    bool ExportModule(asIScriptModule& module, std::string_view base) override;

    /** @brief Loads `<base>.dll|.so|.dylib` and `<base>.externs`; returns the number of installed functions. */
    std::size_t LoadAot(asIScriptModule& module, std::string_view base) override;

private:
    std::unique_ptr<angelsea::Jit> jit_;
};
}
