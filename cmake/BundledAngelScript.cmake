# Builds the bundled official AngelScript release (external/angelscript, the current version) as the static target
# `angelscript`, straight from its own CMake project. Older releases go through angelscript-engine, which patches
# their sources; the current one needs no patches, so the default build does not depend on that repository.
#
# Sets the same variables and helpers as angelscript-engine's AngelScriptEngine.cmake:
#   ANGELSCRIPT_ENGINE_NUMBER, ANGELSCRIPT_ENGINE_VERSION, ANGELSCRIPT_ENGINE_PORTABLE
#   angelscript_engine_force_legacy_std(<target>), angelscript_engine_relax_old_sources(<target>)

file(TO_CMAKE_PATH "${ANGELSCRIPT_SDK}" ANGELSCRIPT_SDK)
set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)
set(BUILD_SHARED_LIBS OFF)
set(AS_DISABLE_INSTALL ON)

file(STRINGS "${ANGELSCRIPT_SDK}/angelscript/include/angelscript.h" angelscript_version_line
     REGEX "^#define ANGELSCRIPT_VERSION[ \t]+[0-9]+")
string(REGEX MATCH "[0-9]+$" ANGELSCRIPT_ENGINE_NUMBER "${angelscript_version_line}")
file(STRINGS "${ANGELSCRIPT_SDK}/angelscript/include/angelscript.h" angelscript_version_string_line
     REGEX "^#define ANGELSCRIPT_VERSION_STRING")
string(REGEX MATCH "\"[^\"]+\"" angelscript_version_string "${angelscript_version_string_line}")
string(REPLACE "\"" "" ANGELSCRIPT_ENGINE_VERSION "${angelscript_version_string}")
message(STATUS "Building against the bundled AngelScript ${ANGELSCRIPT_ENGINE_VERSION} (${ANGELSCRIPT_ENGINE_NUMBER})")

if(ANGELSCRIPT_ENGINE_NUMBER LESS 23700)
    message(FATAL_ERROR "The bundled AngelScript is ${ANGELSCRIPT_ENGINE_VERSION}. Releases before 2.37 need angelscript-engine: "
                        "git submodule update --init external/angelscript-engine, then pass -DANGELSCRIPT_SDK=<prepared SDK>.")
endif()

# The releases from 2.37 have native calls on every target, so portable mode is never needed here.
set(ANGELSCRIPT_ENGINE_PORTABLE OFF)
add_subdirectory("${ANGELSCRIPT_SDK}/angelscript/projects/cmake" angelscript)

function(angelscript_engine_force_legacy_std target)
endfunction()

function(angelscript_engine_relax_old_sources target)
    if(NOT MSVC)
        target_compile_options(${target} PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:SHELL:-include cstring>")
    endif()
endfunction()

angelscript_engine_relax_old_sources(angelscript)
include_directories(SYSTEM "${ANGELSCRIPT_SDK}/angelscript/include")
