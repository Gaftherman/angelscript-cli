cmake_minimum_required(VERSION 3.21)
project(angelscript-cli VERSION 1.0.0 LANGUAGES CXX)

option(ANGELSCRIPT_CLI_BUILD_TESTS "Build and register the CLI tests" ON)

set(ANGELSCRIPT_SDK "${CMAKE_CURRENT_SOURCE_DIR}/external/angelscript/sdk")
set(ASDEBUGGER_DIR "${CMAKE_CURRENT_SOURCE_DIR}/external/asdebugger"
    CACHE PATH "Checkout of asdebugger with the host-agnostic core")
if(NOT EXISTS "${ANGELSCRIPT_SDK}/angelscript/projects/cmake/CMakeLists.txt"
   OR NOT EXISTS "${ASDEBUGGER_DIR}/src/core/as_debugger_host.h")
    message(FATAL_ERROR "The AngelScript SDK and asdebugger host core must be present in external/.")
endif()

set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)
set(BUILD_SHARED_LIBS OFF)
set(AS_DISABLE_INSTALL ON)
add_subdirectory("${ANGELSCRIPT_SDK}/angelscript/projects/cmake" angelscript)

set(ASDEBUGGER_BUILD_SVEN_PLUGIN OFF)
set(ASDEBUGGER_BUILD_TESTS OFF)
set(ASDEBUGGER_STD_ADAPTER ON)
set(ASDEBUGGER_STD_ADDON_DIR "${ANGELSCRIPT_SDK}/add_on")
add_subdirectory("${ASDEBUGGER_DIR}" asdebugger)

add_library(as_addons STATIC)
foreach(addon_source IN ITEMS
    scriptstdstring/scriptstdstring.cpp
    scriptstdstring/scriptstdstring_utils.cpp
    scriptarray/scriptarray.cpp
    scriptdictionary/scriptdictionary.cpp
    scriptmath/scriptmath.cpp
    scriptfile/scriptfile.cpp
    scriptfile/scriptfilesystem.cpp
    datetime/datetime.cpp
    scriptbuilder/scriptbuilder.cpp
    scripthelper/scripthelper.cpp
)
    target_sources(as_addons PRIVATE "${ASDEBUGGER_STD_ADDON_DIR}/${addon_source}")
endforeach()
foreach(addon IN ITEMS scriptstdstring scriptarray scriptdictionary scriptmath scriptfile datetime scriptbuilder scripthelper)
    target_include_directories(as_addons SYSTEM PUBLIC "${ASDEBUGGER_STD_ADDON_DIR}/${addon}")
endforeach()
target_link_libraries(as_addons PUBLIC angelscript)

function(configure_cli_target target)
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
    src/debug/DapSession.cpp
)
configure_cli_target(angelscript-cli)
set_target_properties(angelscript-cli PROPERTIES OUTPUT_NAME angelscript RUNTIME_OUTPUT_DIRECTORY "$<1:${CMAKE_BINARY_DIR}/bin>")
target_compile_definitions(angelscript-cli PRIVATE ANGELSCRIPT_CLI_VERSION="${PROJECT_VERSION}")
target_include_directories(angelscript-cli SYSTEM PRIVATE
    "${ANGELSCRIPT_SDK}/angelscript/include"
    "${ASDEBUGGER_DIR}/src/core"
)
target_link_libraries(angelscript-cli PRIVATE asdebugger_core as_addons)
if(MINGW)
    target_link_options(angelscript-cli PRIVATE -municode)
endif()

install(TARGETS angelscript-cli RUNTIME DESTINATION bin)
install(FILES LICENSE DESTINATION .)

if(ANGELSCRIPT_CLI_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
