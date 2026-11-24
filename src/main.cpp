#include "cli/Commands.h"

#ifdef _WIN32
#include <windows.h>
#endif

#include <cstddef>
#include <iostream>
#include <string>
#include <string_view>
#include <vector>

#ifdef _WIN32
/** @brief Passes the Windows command line to the CLI as UTF-8. */
int wmain(int argc, wchar_t** argv)
{
    std::vector<std::string> utf8Args;
    for (int index = 1; index < argc; ++index)
    {
        const auto* value = argv[index];
        const int size = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value, -1, nullptr, 0, nullptr, nullptr);
        if (size <= 0)
        {
            std::cerr << "Invalid Unicode in a command-line argument\n";
            return 2;
        }
        auto& arg = utf8Args.emplace_back(static_cast<std::size_t>(size), '\0');
        if (WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value, -1, arg.data(), size, nullptr, nullptr) <= 0)
        {
            std::cerr << "Could not convert a command-line argument to UTF-8\n";
            return 2;
        }
        arg.pop_back();
    }
    const std::vector<std::string_view> args(utf8Args.begin(), utf8Args.end());
    return cli::Run(args);
}
#else
/** @brief Passes the process arguments to the CLI. */
int main(int argc, char** argv)
{
    std::vector<std::string_view> args;
    for (int index = 1; index < argc; ++index)
        args.emplace_back(argv[index]);
    return cli::Run(args);
}
#endif
