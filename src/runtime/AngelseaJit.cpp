#include "runtime/AngelseaJit.h"

#include <string>

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
    // The JIT only sees functions compiled with its helper instructions, and from 2.37 the engine must speak interface 2.
    if (engine.SetEngineProperty(asEP_INCLUDE_JIT_INSTRUCTIONS, 1) < 0 || engine.SetEngineProperty(asEP_BUILD_WITHOUT_LINE_CUES, 1) < 0)
        return false;
#if ANGELSCRIPT_VERSION >= 23700
    // Releases before 2.37 only have the version 1 interface, which is the default there.
    if (engine.SetEngineProperty(asEP_JIT_INTERFACE_VERSION, 2) < 0)
        return false;
#endif
    jit_ = std::make_unique<angelsea::Jit>(angelsea::JitConfig{}, engine);
    return engine.SetJITCompiler(jit_.get()) >= 0;
}

const char* AngelseaJit::Name()
{
    return "angelsea";
}

bool AngelseaJit::ExportModule(asIScriptModule& module, std::string_view base)
{
    return jit_ && jit_->ExportModuleC(module, std::string(base).c_str());
}

std::size_t AngelseaJit::LoadAot(asIScriptModule& module, std::string_view base)
{
    if (!jit_)
        return 0;
#if defined(_WIN32)
    const char* extension = ".dll";
#elif defined(__APPLE__)
    const char* extension = ".dylib";
#else
    const char* extension = ".so";
#endif
    const std::string library = std::string(base) + extension;
    const std::string manifest = std::string(base) + ".externs";
    return jit_->LoadAot(module, library.c_str(), manifest.c_str());
}
}
