#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shellapi.h>
#include <string>
#include <sstream>
#include <winreg.h>

#include "flutter_window.h"
#include "utils.h"

// Register the streamplayer:// protocol in the Windows registry.
// This is done at launch so it works without an installer.
void RegisterProtocol() {
  const wchar_t* protocol = L"streamplayer";
  wchar_t exePath[MAX_PATH];
  GetModuleFileNameW(NULL, exePath, MAX_PATH);

  // Root: HKEY_CURRENT_USER\Software\Classes\streamplayer
  std::wstring root = L"Software\\Classes\\";
  root += protocol;

  HKEY hKey;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, root.c_str(), 0, NULL,
                      REG_OPTION_NON_VOLATILE, KEY_WRITE, NULL,
                      &hKey, NULL) == ERROR_SUCCESS) {
    std::wstring desc = L"URL:Sphere Player Protocol";
    RegSetValueExW(hKey, NULL, 0, REG_SZ,
                   (BYTE*)desc.c_str(),
                   (DWORD)((desc.size() + 1) * sizeof(wchar_t)));
    RegSetValueExW(hKey, L"URL Protocol", 0, REG_SZ,
                   (BYTE*)L"", sizeof(wchar_t));
    RegCloseKey(hKey);
  }

  std::wstring cmdKey = root + L"\\shell\\open\\command";
  HKEY hCmdKey;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, cmdKey.c_str(), 0, NULL,
                      REG_OPTION_NON_VOLATILE, KEY_WRITE, NULL,
                      &hCmdKey, NULL) == ERROR_SUCCESS) {
    std::wstring cmd = L"\"";
    cmd += exePath;
    cmd += L"\" \"%1\"";
    RegSetValueExW(hCmdKey, NULL, 0, REG_SZ,
                   (BYTE*)cmd.c_str(),
                   (DWORD)((cmd.size() + 1) * sizeof(wchar_t)));
    RegCloseKey(hCmdKey);
  }
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t* command_line, _In_ int show_command) {
  // Attach to console when present (e.g. IDE run)
  if (!::AttachConsole(ATTACH_PARENT_PROCESS)) {
    ::AllocConsole();
  }

  RegisterProtocol();

  // Initialize COM
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments = GetCommandLineArguments();
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 800);
  if (!window.Create(L"Sphere Player", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
