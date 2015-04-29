module d3d_on_dlang;

import core.runtime;
import core.sys.windows.windows;
//pragma(lib, "gdi32.lib");
import std.string;


extern (Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    int result;

    try
    {
        Runtime.initialize();

        result = myWinMain(hInstance, hPrevInstance, lpCmdLine, nCmdShow);

        Runtime.terminate();
    }
    catch (Throwable o)		// catch any uncaught exceptions
    {
        MessageBoxA(null, cast(char *)o.toString(), "Error", MB_OK | MB_ICONEXCLAMATION);
        result = 0;		// failed
    }

    return result;
}

int myWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    wstring appName = "HelloWin";

    WNDCLASSW wndclass;
    wndclass.style         = CS_HREDRAW | CS_VREDRAW;
    wndclass.lpfnWndProc   = &WndProc;
    wndclass.cbClsExtra    = 0;
    wndclass.cbWndExtra    = 0;
    wndclass.hInstance     = hInstance;
    wndclass.hIcon         = LoadIconW(cast(void*)null, cast(wchar*)IDI_APPLICATION);
    wndclass.hCursor       = LoadCursorW(cast(void*)null, cast(wchar*)IDC_ARROW);
    wndclass.hbrBackground = null; //cast(HBRUSH)GetStockObject(WHITE_BRUSH);
    wndclass.lpszMenuName  = null;
    wndclass.lpszClassName = appName.ptr;

    if(!RegisterClassW(&wndclass))
    {
        MessageBoxW(null, "This program requires Windows NT!", appName.ptr, MB_ICONERROR);
        return 0;
    }

    auto hwnd = CreateWindowW(appName.ptr,      // window class name
						"The Hello Program",  // window caption
						WS_OVERLAPPEDWINDOW,  // window style
						CW_USEDEFAULT,        // initial x position
						CW_USEDEFAULT,        // initial y position
						CW_USEDEFAULT,        // initial x size
						CW_USEDEFAULT,        // initial y size
						null,                 // parent window handle
						null,                 // window menu handle
						hInstance,            // program instance handle
						null);                // creation parameters

    ShowWindow(hwnd, nCmdShow);
    UpdateWindow(hwnd);

    MSG  msg;
    while (GetMessageW(&msg, null, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    return cast(int)msg.wParam;
}

extern(Windows)
LRESULT WndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)nothrow
{
    switch (message)
    {
        case WM_CREATE:
            return 0;

        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;

        default:
    }

    return DefWindowProcW(hwnd, message, wParam, lParam);
}

