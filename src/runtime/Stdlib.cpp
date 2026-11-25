#include "runtime/Stdlib.h"
#include "runtime/Net.h"

#ifdef ANGELSCRIPT_CLI_HAS_DATETIME
#include <datetime.h>
#endif
#include <scriptarray.h>
#include <scriptdictionary.h>
#include <scriptfile.h>
#ifdef ANGELSCRIPT_CLI_HAS_FILESYSTEM
#include <scriptfilesystem.h>
#endif
#include <scripthelper.h>
#include <scriptmath.h>
#include <scriptstdstring.h>

#include <iostream>
#include <string>

namespace runtime
{
static void Print(asIScriptGeneric* call)
{
    const auto& text = *static_cast<const std::string*>(call->GetArgObject(0));
    std::cout << text << std::flush;
}

static void PrintLine(asIScriptGeneric* call)
{
    const auto& text = *static_cast<const std::string*>(call->GetArgObject(0));
    std::cout << text << std::endl;
}

/** @brief Script arguments of the process. One engine runs per process, and older engines cannot attach data to a function. */
static const ScriptArguments* g_arguments = nullptr;

static void GetArgs(asIScriptGeneric* call)
{
    const auto& args = *g_arguments;
#if ANGELSCRIPT_VERSION >= 23300
    auto* type = call->GetEngine()->GetTypeInfoByDecl("array<string>");
#elif ANGELSCRIPT_VERSION >= 23100
    auto* type = call->GetEngine()->GetTypeInfoById(call->GetEngine()->GetTypeIdByDecl("array<string>"));
#else
    auto* type = call->GetEngine()->GetObjectTypeById(call->GetEngine()->GetTypeIdByDecl("array<string>"));
#endif
#ifdef ANGELSCRIPT_CLI_HAS_ARRAY_CREATE
    auto* values = CScriptArray::Create(type, static_cast<asUINT>(args.size()));
#else
    auto* values = new CScriptArray(static_cast<asUINT>(args.size()), type);
#endif
    if (values)
    {
        asUINT index = 0;
        for (const auto arg : args)
            *static_cast<std::string*>(values->At(index++)) = arg;
    }
    call->SetReturnAddress(values);
}

bool RegisterStdlib(asIScriptEngine& engine, ScriptArguments& args)
{
    RegisterStdString(&engine);
    RegisterScriptArray(&engine, true);
#ifdef ANGELSCRIPT_CLI_HAS_STDSTRING_UTILS
    RegisterStdStringUtils(&engine);
#endif
    RegisterScriptDictionary(&engine);
    RegisterScriptMath(&engine);
    RegisterScriptFile(&engine);
#ifdef ANGELSCRIPT_CLI_HAS_DATETIME
    RegisterScriptDateTime(&engine);
#endif
#ifdef ANGELSCRIPT_CLI_HAS_FILESYSTEM
    RegisterScriptFileSystem(&engine);
#endif
#ifdef ANGELSCRIPT_CLI_HAS_EXCEPTION_ROUTINES
    RegisterExceptionRoutines(&engine);
#endif

    g_arguments = &args;
    return RegisterNet(engine) &&
           engine.RegisterGlobalFunction("void print(const string &in)", asFUNCTION(Print), asCALL_GENERIC) >= 0 &&
           engine.RegisterGlobalFunction("void println(const string &in)", asFUNCTION(PrintLine), asCALL_GENERIC) >= 0 &&
           engine.RegisterGlobalFunction("array<string>@ getArgs()", asFUNCTION(GetArgs), asCALL_GENERIC) >= 0;
}
}
