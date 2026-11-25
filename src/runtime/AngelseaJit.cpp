#include "runtime/AngelseaJit.h"

#if defined(_MSC_VER)
#pragma warning(push, 0)
#endif
#include <angelsea.hpp>
#if defined(_MSC_VER)
#pragma warning(pop)
#endif

namespace runtime
{
AngelseaJit::AngelseaJit() = default;

AngelseaJit::~AngelseaJit() = default;

bool AngelseaJit::Attach(asIScriptEngine& engine)
{
    // The JIT only sees functions compiled with its helper instructions, and the engine must speak interface 2.
    if (engine.SetEngineProperty(asEP_INCLUDE_JIT_INSTRUCTIONS, 1) < 0 || engine.SetEngineProperty(asEP_JIT_INTERFACE_VERSION, 2) < 0 ||
        engine.SetEngineProperty(asEP_BUILD_WITHOUT_LINE_CUES, 1) < 0)
        return false;
    jit_ = std::make_unique<angelsea::Jit>(angelsea::JitConfig{}, engine);
    return engine.SetJITCompiler(jit_.get()) >= 0;
}

const char* AngelseaJit::Name()
{
    return "angelsea";
}
}
