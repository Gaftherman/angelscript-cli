cmake_minimum_required(VERSION 3.21)
project(angelscript-cli VERSION 1.2.1 LANGUAGES CXX)

option(ANGELSCRIPT_CLI_BUILD_TESTS "Build and register the CLI tests" ON)

set(ANGELSCRIPT_SDK "${CMAKE_CURRENT_SOURCE_DIR}/external/angelscript/sdk"
    CACHE PATH "AngelScript SDK to build against (an official release or the bundled submodule)")
set(ANGELSCRIPT_ENGINE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/external/angelscript-engine"
    CACHE PATH "Checkout of angelscript-engine (builds any official AngelScript release and patches its sources)")
set(ASDEBUGGER_DIR "${CMAKE_CURRENT_SOURCE_DIR}/external/angelscript-dap"
    CACHE PATH "Checkout of angelscript-dap (the host-agnostic DAP core)")
if(NOT EXISTS "${ANGELSCRIPT_SDK}/angelscript/include/angelscript.h"
   OR NOT EXISTS "${ASDEBUGGER_DIR}/src/as_debugger_host.h")
    message(FATAL_ERROR "The AngelScript SDK and the debugger core (angelscript-dap) must be present in external/.")
endif()

# The bundled SDK is the current official release and builds as it is. Any other SDK is an older release that
# angelscript-engine prepares (download, hash check, patches) and builds.
get_filename_component(bundled_sdk "${CMAKE_CURRENT_SOURCE_DIR}/external/angelscript/sdk" REALPATH)
get_filename_component(requested_sdk "${ANGELSCRIPT_SDK}" REALPATH)
if(requested_sdk STREQUAL bundled_sdk)
    include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/BundledAngelScript.cmake")
else()
    if(NOT EXISTS "${ANGELSCRIPT_ENGINE_DIR}/cmake/AngelScriptEngine.cmake")
        message(FATAL_ERROR "Building another AngelScript release needs angelscript-engine: "
                            "git submodule update --init external/angelscript-engine")
    endif()
    include("${ANGELSCRIPT_ENGINE_DIR}/cmake/AngelScriptEngine.cmake")
endif()

# The debugger core needs the context and function introspection API of 2.36 and later.
set(ANGELSCRIPT_CLI_HAS_DAP OFF)
if(ANGELSCRIPT_ENGINE_NUMBER GREATER_EQUAL 23600)
    set(ANGELSCRIPT_CLI_HAS_DAP ON)
endif()

set(ASDEBUGGER_BUILD_TESTS OFF)
set(ASDEBUGGER_STD_ADAPTER ON)
set(ASDEBUGGER_STD_ADDON_DIR "${ANGELSCRIPT_SDK}/add_on")
if(ANGELSCRIPT_CLI_HAS_DAP)
    add_subdirectory("${ASDEBUGGER_DIR}" asdebugger)
    if(TARGET asdebugger_core)
        angelscript_engine_force_legacy_std(asdebugger_core)
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
set(cli_skipped_addons "")
foreach(optional IN ITEMS
    "DATETIME:datetime/datetime.cpp"
    "FILESYSTEM:scriptfile/scriptfilesystem.cpp"
    "STDSTRING_UTILS:scriptstdstring/scriptstdstring_utils.cpp")
    string(REPLACE ":" ";" optional_parts "${optional}")
    list(GET optional_parts 0 optional_name)
    list(GET optional_parts 1 optional_source)
    set(optional_usable "${ASDEBUGGER_STD_ADDON_DIR}/${optional_source}")
    if(EXISTS "${optional_usable}" AND ANGELSCRIPT_ENGINE_PORTABLE)
        # Some older add-ons register native calls only. In portable mode the engine rejects those.
        file(READ "${optional_usable}" optional_text)
        if(NOT optional_text MATCHES "\n[ \t]*if[ \t]*\\([ \t]*strstr\\(asGetLibraryOptions")
            list(APPEND cli_skipped_addons ${optional_name})
            set(optional_usable "")
        endif()
    endif()
    if(optional_usable AND EXISTS "${optional_usable}")
        target_sources(as_addons PRIVATE "${optional_usable}")
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
    set(helper_portable_ok ON)
    if(ANGELSCRIPT_ENGINE_PORTABLE)
        file(READ "${ASDEBUGGER_STD_ADDON_DIR}/scripthelper/scripthelper.cpp" helper_source)
        if(NOT helper_source MATCHES "\n[ \t]*if[ \t]*\\([ \t]*strstr\\(asGetLibraryOptions")
            set(helper_portable_ok OFF)
        endif()
    endif()
    if(helper_portable_ok AND helper_text MATCHES "RegisterExceptionRoutines")
        list(APPEND cli_optional_addons ANGELSCRIPT_CLI_HAS_EXCEPTION_ROUTINES=1)
    endif()
endif()
if(ANGELSCRIPT_ENGINE_NUMBER GREATER_EQUAL 23900)
    list(APPEND cli_optional_addons ANGELSCRIPT_CLI_HAS_DUMP_PREDEFINED=1)
endif()
angelscript_engine_force_legacy_std(as_addons)
angelscript_engine_relax_old_sources(as_addons)
target_include_directories(as_addons SYSTEM PUBLIC "${ANGELSCRIPT_SDK}/angelscript/include")
foreach(addon IN ITEMS scriptstdstring scriptarray scriptdictionary scriptmath scriptfile datetime scriptbuilder scripthelper)
    if(EXISTS "${ASDEBUGGER_STD_ADDON_DIR}/${addon}")
        target_include_directories(as_addons SYSTEM PUBLIC "${ASDEBUGGER_STD_ADDON_DIR}/${addon}")
    endif()
endforeach()
target_compile_definitions(as_addons PUBLIC ${cli_optional_addons})
target_link_libraries(as_addons PUBLIC angelscript)

function(configure_cli_target target)
    angelscript_engine_force_legacy_std(${target})
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
angelscript_engine_force_legacy_std(angelscript-cli)
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
# NetSocket.cpp uses Winsock directly. The debugger core only links it for engines that have a debugger.
if(WIN32)
    target_link_libraries(angelscript-cli PRIVATE ws2_32)
endif()

# Optional JIT compiler: angelscript-jit, a fork of angelsea (BSD-2). It turns script bytecode into native code through
# MIR and uses the asIJITCompilerV2 interface of AngelScript 2.37 and later, on 64-bit x86 (Windows, Linux) and arm64.
set(ANGELSCRIPT_JIT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/external/angelscript-jit"
    CACHE PATH "Checkout of angelscript-jit (the JIT compiler)")
set(ANGELSCRIPT_CLI_JIT "none" CACHE STRING "JIT compiler to build in: none or angelsea")
set_property(CACHE ANGELSCRIPT_CLI_JIT PROPERTY STRINGS none angelsea)
if(ANGELSCRIPT_CLI_JIT STREQUAL "angelsea")
    if(ANGELSCRIPT_ENGINE_NUMBER LESS 23700)
        message(FATAL_ERROR "ANGELSCRIPT_CLI_JIT=angelsea needs AngelScript 2.37 or later (found ${ANGELSCRIPT_ENGINE_VERSION}).")
    endif()
    if(ANGELSCRIPT_ENGINE_PORTABLE OR NOT CMAKE_SIZEOF_VOID_P EQUAL 8
       OR NOT CMAKE_SYSTEM_PROCESSOR MATCHES "^(AMD64|amd64|x86_64|arm64|aarch64|ARM64)$"
       OR (APPLE AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64)$"))
        message(FATAL_ERROR "ANGELSCRIPT_CLI_JIT=angelsea supports 64-bit Windows and Linux on x86-64, and arm64 on Linux and macOS (not 32-bit x86, not macOS x64).")
    endif()
    if(NOT EXISTS "${ANGELSCRIPT_JIT_DIR}/vendor/mir/mir.h"
       OR NOT EXISTS "${ANGELSCRIPT_JIT_DIR}/vendor/fmt/CMakeLists.txt")
        message(FATAL_ERROR "Run: git submodule update --init external/angelscript-jit && git -C external/angelscript-jit submodule update --init vendor/mir vendor/fmt")
    endif()
    enable_language(C)
    set(ASEA_ANGELSCRIPT_SYSTEM ON CACHE BOOL "" FORCE)
    set(ASEA_ANGELSCRIPT_ROOT "${ANGELSCRIPT_SDK}" CACHE STRING "" FORCE)
    add_subdirectory("${ANGELSCRIPT_JIT_DIR}" angelscript-jit EXCLUDE_FROM_ALL)
    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        target_compile_options(angelscript PRIVATE -fno-strict-aliasing)
    endif()
    target_sources(angelscript-cli PRIVATE src/runtime/AngelseaJit.cpp)
    target_link_libraries(angelscript-cli PRIVATE angelsea)
    target_compile_definitions(angelscript-cli PRIVATE ANGELSCRIPT_CLI_HAS_ANGELSEA=1)
elseif(NOT ANGELSCRIPT_CLI_JIT STREQUAL "none")
    message(FATAL_ERROR "ANGELSCRIPT_CLI_JIT must be none or angelsea.")
endif()

# What this build supports, for the installer and the release notes (scripts/package.cmake copies it).
set(engine_info_addons string array dictionary math file builder helper)
foreach(define IN LISTS cli_optional_addons)
    if(define MATCHES "^ANGELSCRIPT_CLI_HAS_(DATETIME|FILESYSTEM)=1$")
        string(TOLOWER "${CMAKE_MATCH_1}" addon_name)
        list(APPEND engine_info_addons ${addon_name})
    endif()
endforeach()
list(JOIN engine_info_addons "\", \"" engine_info_addon_list)
set(engine_info_jit false)
if(ANGELSCRIPT_CLI_JIT STREQUAL "angelsea")
    set(engine_info_jit true)
endif()
# Whether a JIT build exists for this release and target, even when this build has none.
set(engine_info_jit_supported false)
if(ANGELSCRIPT_ENGINE_NUMBER GREATER_EQUAL 23700 AND NOT ANGELSCRIPT_ENGINE_PORTABLE AND CMAKE_SIZEOF_VOID_P EQUAL 8
   AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(AMD64|amd64|x86_64|arm64|aarch64|ARM64)$"
   AND NOT (APPLE AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64)$"))
    set(engine_info_jit_supported true)
endif()
set(engine_info_debugger false)
if(ANGELSCRIPT_CLI_HAS_DAP)
    set(engine_info_debugger true)
endif()
file(WRITE "${CMAKE_BINARY_DIR}/engine-info.json"
"{\"version\": \"${ANGELSCRIPT_ENGINE_VERSION}\", \"jit\": ${engine_info_jit}, \"jitSupported\": ${engine_info_jit_supported}, \"debugger\": ${engine_info_debugger}, \"addons\": [\"${engine_info_addon_list}\"]}
")

install(TARGETS angelscript-cli RUNTIME DESTINATION bin)
install(FILES LICENSE DESTINATION .)

if(ANGELSCRIPT_CLI_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
