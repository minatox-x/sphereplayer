#ifndef RUNNER_UTILS_H_
#define RUNNER_UTILS_H_

#include <string>
#include <vector>

// Returns command-line arguments as a UTF-8 vector.
std::vector<std::string> GetCommandLineArguments();

// Converts a UTF-16 wstring to UTF-8 string.
std::string Utf8FromUtf16(const std::wstring& utf16_string);

#endif  // RUNNER_UTILS_H_
