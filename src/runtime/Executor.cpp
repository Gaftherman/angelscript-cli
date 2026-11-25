#include "runtime/Executor.h"
#ifndef ANGELSCRIPT_CLI_NO_DAP
#include "debug/DapSession.h"
#endif
#include "runtime/Engine.h"
#include "runtime/Jit.h"
#include "runtime/ScriptLoader.h"
#include "runtime/Stdlib.h"

#include <cstdint>
#include <iostream>

namespace runtime
{
static asIScriptFunction* FindEntryPoint(asIScriptModule& module)
{
#if ANGELSCRIPT_VERSION >= 22200
    auto* intMain = module.GetFunctionByDecl("int main()");
    auto* voidMain = module.GetFunctionByDecl("void main()");
#else
    // Releases before 2.22 look functions up by id.
    auto* engine = module.GetEngine();
    const int intId = module.GetFunctionIdByDecl("int main()");
    const int voidId = module.GetFunctionIdByDecl("void main()");
    auto* intMain = intId >= 0 ? engine->GetFunctionDescriptorById(intId) : nullptr;
    auto* voidMain = voidId >= 0 ? engine->GetFunctionDescriptorById(voidId) : nullptr;
#endif
    if ((intMain == nullptr) == (voidMain == nullptr))
    {
        std::cerr << "no entry point `int main()` or `void main()`\n";
        return nullptr;
    }
    return intMain ? intMain : voidMain;
}

static void ReportException(asIScriptContext& context)
{
    std::cerr << "Unhandled exception: " << context.GetExceptionString() << '\n';
    for (asUINT level = 0; level < context.GetCallstackSize(); ++level)
    {
        const auto* function = context.GetFunction(level);
        if (!function || function->GetFuncType() != asFUNC_SCRIPT)
            continue;

        const char* section = nullptr;
        const int line = context.GetLineNumber(level, nullptr, &section);
        if (section && *section)
            std::cerr << "  at " << function->GetDeclaration() << " (" << section << ':' << line << ")\n";
    }
}

static int RunEntryPoint(asIScriptContext& context, asIScriptFunction& entry)
{
#if ANGELSCRIPT_VERSION >= 22200
    const int prepareResult = context.Prepare(&entry);
#else
    const int prepareResult = context.Prepare(entry.GetId());
#endif
    if (prepareResult < 0)
    {
        std::cerr << "Could not prepare " << entry.GetDeclaration() << " (" << prepareResult << ")\n";
        return 1;
    }

    const int result = context.Execute();
    if (result == asEXECUTION_EXCEPTION)
    {
        ReportException(context);
        return 1;
    }
    if (result != asEXECUTION_FINISHED)
    {
        std::cerr << "Could not execute " << entry.GetDeclaration() << " (" << result << ")\n";
        return 1;
    }
    return entry.GetReturnTypeId() == asTYPEID_VOID ? 0 : static_cast<std::int32_t>(context.GetReturnDWord());
}

int Execute(const ExecutionRequest& request)
{
    auto args = request.scriptArgs;
    NullJit provider;
    auto engine = CreateEngine();
    if (!engine)
        return 1;

    const auto policy = Decide({false, HostArchitecture(), request.noJit, request.dapPort.has_value()});
    if (policy.enabled && !provider.Attach(*engine))
    {
        std::cerr << "Could not attach the JIT provider\n";
        return 1;
    }
    if (!RegisterStdlib(*engine, args))
    {
        std::cerr << "Could not register the standard library\n";
        return 1;
    }

    RelativeIncludeResolver resolver;
    const auto script = LoadScript(*engine, request.scriptPath, resolver);
    if (!script.module || request.checkOnly)
        return script.module ? 0 : 1;

    auto* entry = FindEntryPoint(*script.module);
    if (!entry)
        return 1;

    ContextPtr context(engine->CreateContext());
    if (!context)
    {
        std::cerr << "Could not create the script context\n";
        return 1;
    }

#ifndef ANGELSCRIPT_CLI_NO_DAP
    std::optional<DapSession> session;
    if (request.dapPort)
    {
        session.emplace(*engine, *context, script.rootDir);
        if (!session->Start(request.dapHost, *request.dapPort))
            return 1;
    }
#else
    if (request.dapPort)
    {
        std::cerr << "Debugging needs a build against AngelScript 2.33.0 or later\n";
        return 2;
    }
#endif

    // Global initializers can execute script and hit breakpoints.
#if ANGELSCRIPT_VERSION >= 22200
    if (script.module->ResetGlobalVars(context.get()) < 0)
#else
    if (script.module->ResetGlobalVars() < 0)
#endif
    {
        if (context->GetState() == asEXECUTION_EXCEPTION)
            ReportException(*context);
        else
            std::cerr << "Could not initialize script globals\n";
        return 1;
    }

#ifndef ANGELSCRIPT_CLI_NO_DAP
    if (session)
        session->Poll();
#endif
    return RunEntryPoint(*context, *entry);
}
}
