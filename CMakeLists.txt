cmake_minimum_required(VERSION 3.21)
project(angelscript-cli VERSION 1.0.0 LANGUAGES CXX)

option(ANGELSCRIPT_CLI_BUILD_TESTS "Build and register the CLI tests" ON)

set(ANGELSCRIPT_SDK "${CMAKE_CURRENT_SOURCE_DIR}/external/angelscript/sdk"
    CACHE PATH "AngelScript SDK to build against (an official release or the bundled submodule)")
set(ASDEBUGGER_DIR "${CMAKE_CURRENT_SOURCE_DIR}/external/angelscript-dap"
    CACHE PATH "Checkout of angelscript-dap (the host-agnostic DAP core)")
if(NOT EXISTS "${ANGELSCRIPT_SDK}/angelscript/include/angelscript.h"
   OR NOT EXISTS "${ASDEBUGGER_DIR}/src/as_debugger_host.h")
    message(FATAL_ERROR "The AngelScript SDK and the debugger core (angelscript-dap) must be present in external/.")
endif()

set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)
set(BUILD_SHARED_LIBS OFF)
set(AS_DISABLE_INSTALL ON)
file(STRINGS "${ANGELSCRIPT_SDK}/angelscript/include/angelscript.h" angelscript_version_line
     REGEX "^#define ANGELSCRIPT_VERSION[ \t]+[0-9]+")
string(REGEX MATCH "[0-9]+$" ANGELSCRIPT_CLI_ENGINE_NUMBER "${angelscript_version_line}")
file(STRINGS "${ANGELSCRIPT_SDK}/angelscript/include/angelscript.h" angelscript_version_string_line
     REGEX "^#define ANGELSCRIPT_VERSION_STRING")
string(REGEX MATCH "\"[^\"]+\"" ANGELSCRIPT_CLI_ENGINE_STRING "${angelscript_version_string_line}")
string(REPLACE "\"" "" ANGELSCRIPT_CLI_ENGINE_VERSION "${ANGELSCRIPT_CLI_ENGINE_STRING}")
message(STATUS "Building against AngelScript ${ANGELSCRIPT_CLI_ENGINE_VERSION} (${ANGELSCRIPT_CLI_ENGINE_NUMBER})")

# The SDK's own CMake project is only dependable from 2.31 on. Earlier releases miss the target or add
# test projects that do not exist in the archive, so the engine sources are built directly.
if(ANGELSCRIPT_CLI_ENGINE_NUMBER GREATER_EQUAL 23100
   AND EXISTS "${ANGELSCRIPT_SDK}/angelscript/projects/cmake/CMakeLists.txt")
    add_subdirectory("${ANGELSCRIPT_SDK}/angelscript/projects/cmake" angelscript)
else()
    file(GLOB angelscript_sources CONFIGURE_DEPENDS "${ANGELSCRIPT_SDK}/angelscript/source/*.cpp")
    add_library(angelscript STATIC ${angelscript_sources})
    find_package(Threads REQUIRED)
    target_link_libraries(angelscript PUBLIC Threads::Threads)
endif()

# Releases before 2.31 use std::has_trivial_* traits that no standard library ships any more.
set(cli_legacy_std_header "${CMAKE_CURRENT_SOURCE_DIR}/src/compat/LegacyStd.h")
function(cli_force_legacy_std target)
    if(ANGELSCRIPT_CLI_ENGINE_NUMBER LESS 23100)
        if(MSVC)
            target_compile_options(${target} PRIVATE "/FI${cli_legacy_std_header}")
        else()
            target_compile_options(${target} PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:SHELL:-include ${cli_legacy_std_header}>")
        endif()
    endif()
endfunction()
cli_force_legacy_std(angelscript)
# Official sources before 2.31 and some add-ons predate stricter GCC and Clang checks. The flags only downgrade
# those diagnostics and add <cstring>; no SDK file is patched.
function(cli_relax_old_sources target)
    if(NOT MSVC)
        # C++ only: the arm64 call-convention sources are assembly and have no <cstring>.
        target_compile_options(${target} PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:SHELL:-include cstring>")
        if(ANGELSCRIPT_CLI_ENGINE_NUMBER LESS 23100)
            target_compile_options(${target} PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:-fpermissive>")
        endif()
    endif()
endfunction()
cli_relax_old_sources(angelscript)
# Older SDK projects do not export their headers to the targets that link them.
include_directories(SYSTEM "${ANGELSCRIPT_SDK}/angelscript/include")

# The debugger core needs the context and function introspection API of 2.36 and later.
set(ANGELSCRIPT_CLI_HAS_DAP OFF)
if(ANGELSCRIPT_CLI_ENGINE_NUMBER GREATER_EQUAL 23600)
    set(ANGELSCRIPT_CLI_HAS_DAP ON)
endif()

set(ASDEBUGGER_BUILD_TESTS OFF)
set(ASDEBUGGER_STD_ADAPTER ON)
set(ASDEBUGGER_STD_ADDON_DIR "${ANGELSCRIPT_SDK}/add_on")
if(ANGELSCRIPT_CLI_HAS_DAP)
    add_subdirectory("${ASDEBUGGER_DIR}" asdebugger)
    if(TARGET asdebugger_core)
        cli_force_legacy_std(asdebugger_core)
    endif()
endif()

add_library(as_addons STATIC)
# Add-ons that older releases do not ship are skipped, and ANGELSCRIPT_CLI_HAS_<NAME> tells the sources.
foreach(addon_source IN ITEMS
    scriptstdstring/scriptstdstring.cpp
    scriptarray/scriptarray.cpp
    scriptdictionary/scriptdictionary.cpp
    scriptmath/scriptmath.cpp
    scriptfile/scriptfile.cpp
    scriptbuilder/scriptbuilder.cpp
    scripthelper/scripthelper.cpp
)
    target_sources(as_addons PRIVATE "${ASDEBUGGER_STD_ADDON_DIR}/${addon_source}")
endforeach()
set(cli_optional_addons "")
foreach(optional IN ITEMS
    "DATETIME:datetime/datetime.cpp"
    "FILESYSTEM:scriptfile/scriptfilesystem.cpp"
    "STDSTRING_UTILS:scriptstdstring/scriptstdstring_utils.cpp")
    string(REPLACE ":" ";" optional_parts "${optional}")
    list(GET optional_parts 0 optional_name)
    list(GET optional_parts 1 optional_source)
    if(EXISTS "${ASDEBUGGER_STD_ADDON_DIR}/${optional_source}")
        target_sources(as_addons PRIVATE "${ASDEBUGGER_STD_ADDON_DIR}/${optional_source}")
        list(APPEND cli_optional_addons ANGELSCRIPT_CLI_HAS_${optional_name}=1)
    endif()
endforeach()
set(array_header "${ASDEBUGGER_STD_ADDON_DIR}/scriptarray/scriptarray.h")
if(EXISTS "${array_header}")
    file(READ "${array_header}" array_text)
    if(array_text MATCHES "static CScriptArray \\*Create\\(")
        list(APPEND cli_optional_addons ANGELSCRIPT_CLI_HAS_ARRAY_CREATE=1)
    endif()
endif()
if(NOT ANGELSCRIPT_CLI_HAS_DAP)
    list(APPEND cli_optional_addons ANGELSCRIPT_CLI_NO_DAP=1)
endif()
set(helper_header "${ASDEBUGGER_STD_ADDON_DIR}/scripthelper/scripthelper.h")
if(EXISTS "${helper_header}")
    file(READ "${helper_header}" helper_text)
    if(helper_text MATCHES "RegisterExceptionRoutines")
        list(APPEND cli_optional_addons ANGELSCRIPT_CLI_HAS_EXCEPTION_ROUTINES=1)
    endif()
endif()
if(ANGELSCRIPT_CLI_ENGINE_NUMBER GREATER_EQUAL 23900)
    list(APPEND cli_optional_addons ANGELSCRIPT_CLI_HAS_DUMP_PREDEFINED=1)
endif()
cli_force_legacy_std(as_addons)
cli_relax_old_sources(as_addons)
target_include_directories(as_addons SYSTEM PUBLIC "${ANGELSCRIPT_SDK}/angelscript/include")
foreach(addon IN ITEMS scriptstdstring scriptarray scriptdictionary scriptmath scriptfile datetime scriptbuilder scripthelper)
    if(EXISTS "${ASDEBUGGER_STD_ADDON_DIR}/${addon}")
        target_include_directories(as_addons SYSTEM PUBLIC "${ASDEBUGGER_STD_ADDON_DIR}/${addon}")
    endif()
endforeach()
target_compile_definitions(as_addons PUBLIC ${cli_optional_addons})
target_link_libraries(as_addons PUBLIC angelscript)

function(configure_cli_target target)
    cli_force_legacy_std(${target})
    target_compile_features(${target} PRIVATE cxx_std_20)
    set_target_properties(${target} PROPERTIES CXX_EXTENSIONS OFF)
    target_include_directories(${target} PRIVATE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/src")
    if(MSVC)
        target_compile_options(${target} PRIVATE /W4 /WX)
    elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        target_compile_options(${target} PRIVATE -Wall -Wextra -Wpedantic -Werror)
    endif()
endfunction()

add_executable(angelscript-cli
    src/main.cpp
    src/cli/CommandLine.cpp
    src/cli/Commands.cpp
    src/runtime/Engine.cpp
    src/runtime/Stdlib.cpp
    src/runtime/Net.cpp
    src/runtime/NetSocket.cpp
    src/runtime/ScriptLoader.cpp
    src/runtime/Executor.cpp
    src/runtime/Jit.cpp
)
if(ANGELSCRIPT_CLI_HAS_DAP)
    target_sources(angelscript-cli PRIVATE src/debug/DapSession.cpp)
endif()
configure_cli_target(angelscript-cli)
cli_force_legacy_std(angelscript-cli)
set_target_properties(angelscript-cli PROPERTIES OUTPUT_NAME angelscript RUNTIME_OUTPUT_DIRECTORY "$<1:${CMAKE_BINARY_DIR}/bin>")
target_compile_definitions(angelscript-cli PRIVATE ANGELSCRIPT_CLI_VERSION="${PROJECT_VERSION}")
target_include_directories(angelscript-cli SYSTEM PRIVATE "${ANGELSCRIPT_SDK}/angelscript/include")
target_link_libraries(angelscript-cli PRIVATE as_addons)
if(ANGELSCRIPT_CLI_HAS_DAP)
    target_include_directories(angelscript-cli SYSTEM PRIVATE "${ASDEBUGGER_DIR}/src")
    target_link_libraries(angelscript-cli PRIVATE asdebugger_core)
endif()
if(MINGW)
    target_link_options(angelscript-cli PRIVATE -municode)
endif()

install(TARGETS angelscript-cli RUNTIME DESTINATION bin)
install(FILES LICENSE DESTINATION .)

if(ANGELSCRIPT_CLI_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
