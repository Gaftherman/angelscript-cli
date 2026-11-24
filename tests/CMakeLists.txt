add_executable(angelscript-cli-unit
    unit/main.cpp
    ../src/cli/CommandLine.cpp
    ../src/runtime/Jit.cpp
)
configure_cli_target(angelscript-cli-unit)
target_include_directories(angelscript-cli-unit SYSTEM PRIVATE "${ANGELSCRIPT_SDK}/angelscript/include")
add_test(NAME cli-unit COMMAND angelscript-cli-unit)

foreach(integration_case IN ITEMS hello args stdlib filesystem datetime int-main void-main
    compile-error exception check-ok check-fail include no-entry usage install init version help
    net-echo net-refused net-closed examples)
    add_test(NAME "cli-${integration_case}"
        COMMAND "${CMAKE_COMMAND}" "-DCLI=$<TARGET_FILE:angelscript-cli>" "-DCASE=${integration_case}"
                -P "${CMAKE_CURRENT_SOURCE_DIR}/integration.cmake")
endforeach()

find_program(ANGELSCRIPT_CLI_NODE NAMES node nodejs)
if(ANGELSCRIPT_CLI_NODE)
    add_test(NAME cli-dap
        COMMAND "${ANGELSCRIPT_CLI_NODE}" "${CMAKE_CURRENT_SOURCE_DIR}/dap/handshake.mjs"
                "$<TARGET_FILE:angelscript-cli>")
    set_tests_properties(cli-dap PROPERTIES TIMEOUT 40)
endif()
