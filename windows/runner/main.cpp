#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <cstdint>
#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Full path of [process]'s executable, lower-cased; empty on failure.
std::wstring ExePath(HANDLE process) {
  wchar_t buf[MAX_PATH * 2];
  DWORD n = MAX_PATH * 2;
  if (!::QueryFullProcessImageNameW(process, 0, buf, &n)) return L"";
  std::wstring path(buf, n);
  ::CharLowerBuffW(path.data(), static_cast<DWORD>(path.size()));
  return path;
}

// FNV-1a: a hash fixed by this file, not by the compiler's std::hash, so
// every build of one install agrees on the name.
uint64_t Fnv1a(const std::wstring& s) {
  uint64_t h = 14695981039346656037ull;
  for (wchar_t c : s) {
    h ^= static_cast<uint64_t>(c);
    h *= 1099511628211ull;
  }
  return h;
}

struct FindArgs {
  const std::wstring* exe;
  HWND found;
};

// The runner window of another process running the same executable.
BOOL CALLBACK FindSameExeWindow(HWND hwnd, LPARAM lparam) {
  auto* args = reinterpret_cast<FindArgs*>(lparam);
  wchar_t cls[64];
  if (!::GetClassNameW(hwnd, cls, 64) ||
      wcscmp(cls, L"FLUTTER_RUNNER_WIN32_WINDOW") != 0) {
    return TRUE;
  }
  DWORD pid = 0;
  ::GetWindowThreadProcessId(hwnd, &pid);
  if (pid == ::GetCurrentProcessId()) return TRUE;
  HANDLE process =
      ::OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (!process) return TRUE;
  const bool same = ExePath(process) == *args->exe;
  ::CloseHandle(process);
  if (!same) return TRUE;
  args->found = hwnd;
  return FALSE;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // One GUI per executable per user session. A second launch (Start menu,
  // taskbar jump list, double-click) brings the existing window forward,
  // including one hidden to the tray, and exits, so two GUIs never drive the
  // same node. Keyed to the exe path, not the app: a build run from a
  // KwaaiNetGUI checkout has its own sandboxed node and may run beside the
  // installed app.
  const std::wstring exe = ExePath(::GetCurrentProcess());
  const std::wstring mutex_name =
      L"Local\\KwaaiNetGUI-" + std::to_wstring(Fnv1a(exe));
  HANDLE instance_mutex = ::CreateMutexW(nullptr, TRUE, mutex_name.c_str());
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    FindArgs args{&exe, nullptr};
    ::EnumWindows(FindSameExeWindow, reinterpret_cast<LPARAM>(&args));
    if (HWND existing = args.found) {
      // SetWindowPlacement, not ShowWindow: this process's first ShowWindow
      // call is swapped for the launcher's STARTUPINFO show state (normal,
      // from a shortcut), which un-maximizes the window.
      WINDOWPLACEMENT placement{sizeof(placement)};
      if (::GetWindowPlacement(existing, &placement)) {
        if (::IsIconic(existing)) {
          placement.showCmd = (placement.flags & WPF_RESTORETOMAXIMIZED)
                                  ? SW_SHOWMAXIMIZED
                                  : SW_RESTORE;
        } else {
          placement.showCmd =
              ::IsZoomed(existing) ? SW_SHOWMAXIMIZED : SW_SHOW;
        }
        ::SetWindowPlacement(existing, &placement);
      }
      ::SetForegroundWindow(existing);
    }
    if (instance_mutex) ::CloseHandle(instance_mutex);
    return EXIT_SUCCESS;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"KwaaiNet", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (instance_mutex) ::CloseHandle(instance_mutex);
  return EXIT_SUCCESS;
}
