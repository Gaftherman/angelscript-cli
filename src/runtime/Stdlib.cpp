#include "runtime/Stdlib.h"
#include "runtime/Net.h"

#include <datetime.h>
#include <scriptarray.h>
#include <scriptdictionary.h>
#include <scriptfile.h>
#include <scriptfilesystem.h>
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

static void GetArgs(asIScriptGeneric* call)
{
    const auto& args = *static_cast<const ScriptArguments*>(call->GetAuxiliary());
    auto* type = call->GetEngine()->GetTypeInfoByDecl("array<string>");
    auto* values = CScriptArray::Create(type, static_cast<asUINT>(args.size()));
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
    RegisterStdStringUtils(&engine);
    RegisterScriptDictionary(&engine);
    RegisterScriptMath(&engine);
    RegisterScriptFile(&engine);
    RegisterScriptDateTime(&engine);
    RegisterScriptFileSystem(&engine);
    RegisterExceptionRoutines(&engine);

    return RegisterNet(engine) &&
           engine.RegisterGlobalFunction("void print(const string &in)", asFUNCTION(Print), asCALL_GENERIC) >= 0 &&
           engine.RegisterGlobalFunction("void println(const string &in)", asFUNCTION(PrintLine), asCALL_GENERIC) >= 0 &&
           engine.RegisterGlobalFunction("array<string>@ getArgs()", asFUNCTION(GetArgs), asCALL_GENERIC, &args) >= 0;
}
}
