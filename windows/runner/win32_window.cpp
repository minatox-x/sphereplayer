#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>

namespace {
constexpr const wchar_t kWindowClassName[] = L"SPHERE_PLAYER_WIN32";

LRESULT GetDefaultReturnValue(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) {
  return DefWindowProc(hwnd, message, wParam, lParam);
}
}  // namespace

Win32Window::Win32Window() {
  WNDCLASS window_class{};
  window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
  window_class.lpszClassName = kWindowClassName;
  window_class.style = CS_HREDRAW | CS_VREDRAW;
  window_class.cbClsExtra = 0;
  window_class.cbWndExtra = 0;
  window_class.hInstance = GetModuleHandle(nullptr);
  window_class.hIcon = LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
  window_class.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
  window_class.lpszMenuName = nullptr;
  window_class.lpfnWndProc = WndProc;
  RegisterClass(&window_class);
}

Win32Window::~Win32Window() {
  Destroy();
}

bool Win32Window::Create(const std::wstring& title, const Point& origin,
                          const Size& size) {
  Destroy();
  title_ = title;

  const HWND hwnd = CreateWindow(
      kWindowClassName, title.c_str(),
      WS_OVERLAPPEDWINDOW | WS_VISIBLE,
      origin.x, origin.y, size.width, size.height,
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!hwnd) return false;

  window_handle_ = hwnd;
  UpdateWindow(hwnd);
  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOW);
}

void Win32Window::Destroy() {
  OnDestroy();
  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();
  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() { return true; }
void Win32Window::OnDestroy() {}

LRESULT Win32Window::MessageHandler(HWND hwnd, UINT const message,
                                     WPARAM const wparam,
                                     LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      window_handle_ = nullptr;
      if (quit_on_close_) PostQuitMessage(0);
      return 0;
    case WM_SIZE:
      RECT rect;
      GetClientRect(hwnd, &rect);
      if (child_content_ != nullptr) {
        MoveWindow(child_content_, rect.left, rect.top,
                   rect.right - rect.left, rect.bottom - rect.top, TRUE);
      }
      return 0;
    case WM_ACTIVATE:
      if (child_content_ != nullptr) SetFocus(child_content_);
      return 0;
  }
  return DefWindowProc(hwnd, message, wparam, lparam);
}

LRESULT CALLBACK Win32Window::WndProc(HWND const window, UINT const message,
                                       WPARAM const wparam,
                                       LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto* cs = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(cs->lpCreateParams));
    auto* that = static_cast<Win32Window*>(cs->lpCreateParams);
    EnableNonClientDpiScaling(window);
    return DefWindowProc(window, message, wparam, lparam);
  }

  if (auto* that = reinterpret_cast<Win32Window*>(
          GetWindowLongPtr(window, GWLP_USERDATA))) {
    return that->MessageHandler(window, message, wparam, lparam);
  }
  return DefWindowProc(window, message, wparam, lparam);
}
