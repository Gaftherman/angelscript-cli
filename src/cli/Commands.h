#pragma once

#include <span>
#include <string_view>

namespace cli
{
/** @brief Parses the arguments after the executable name and dispatches the CLI command. */
int Run(std::span<const std::string_view> args);
}
