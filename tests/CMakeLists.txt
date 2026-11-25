add_executable(angelscript-cli-unit
    unit/main.cpp
    ../src/cli/CommandLine.cpp
    ../src/runtime/Jit.cpp
)
configure_cli_target(angelscript-cli-unit)
target_include_directories(angelscript-cli-unit SYSTEM PRIVATE "${ANGELSCRIPT_SDK}/angelscript/include")
add_test(NAME cli-unit COMMAND angelscript-cli-unit)

set(cli_core_cases hello args stdlib int-main void-main compile-error exception check-ok check-fail include
    no-entry usage install init version help net-echo net-refused net-closed dump-predefined)
# These cases use add-ons whose API changed after 2.32 (filesystem, datetime), so older engines skip them.
set(cli_addon_cases filesystem datetime examples)
set(cli_cases ${cli_core_cases})
if(ANGELSCRIPT_CLI_ENGINE_NUMBER GREATER_EQUAL 23300)
    list(APPEND cli_cases ${cli_addon_cases})
endif()
foreach(integration_case IN LISTS cli_cases)
    add_test(NAME "cli-${integration_case}"
        COMMAND "${CMAKE_COMMAND}" "-DCLI=$<TARGET_FILE:angelscript-cli>" "-DCASE=${integration_case}"
                "-DVERSION=${PROJECT_VERSION}"
                "-DENGINE_VERSION=${ANGELSCRIPT_CLI_ENGINE_VERSION}"
                "-DENGINE_NUMBER=${ANGELSCRIPT_CLI_ENGINE_NUMBER}"
                -P "${CMAKE_CURRENT_SOURCE_DIR}/integration.cmake")
endforeach()

find_program(ANGELSCRIPT_CLI_NODE NAMES node nodejs)
if(ANGELSCRIPT_CLI_NODE AND ANGELSCRIPT_CLI_HAS_DAP)
    add_test(NAME cli-dap
        COMMAND "${ANGELSCRIPT_CLI_NODE}" "${CMAKE_CURRENT_SOURCE_DIR}/dap/handshake.mjs"
                "$<TARGET_FILE:angelscript-cli>")
    set_tests_properties(cli-dap PROPERTIES TIMEOUT 40)
endif()
