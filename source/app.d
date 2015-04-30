module d3d_on_dlang;

import core.runtime;
import core.sys.windows.windows;
import std.string;
import d3d11manager;


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

    D3D11Manager d3d11;

    auto hWnd = CreateWindowW(appName.ptr,      // window class name
						"The Hello Program",  // window caption
						WS_OVERLAPPEDWINDOW,  // window style
						CW_USEDEFAULT,        // initial x position
						CW_USEDEFAULT,        // initial y position
						CW_USEDEFAULT,        // initial x size
						CW_USEDEFAULT,        // initial y size
						null,                 // parent window handle
						null,                 // window menu handle
						hInstance,            // program instance handle
						&d3d11);                // creation parameters
    ShowWindow(hWnd, nCmdShow);
    UpdateWindow(hWnd);

	// d3d
	string shaderFile="source/MinTriangle.fx";
    if (!d3d11.Initialize(hWnd, shaderFile)){
        return 2;
    }

    // main loop
    MSG msg;
    while (true)
    {
        if (PeekMessageW(&msg, null, 0, 0, PM_NOREMOVE))
        {
            if (!GetMessageW(&msg, null, 0, 0))break;
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
        else {
            d3d11.Render();
        }
    }

    return cast(int)msg.wParam;
}


struct CREATESTRUCT 
{
	LPVOID lpCreateParams;
	HANDLE hInstance;
	HMENU hMenu;
	HWND hwndParent;
	int cy;
	int cx;
	int y;
	int x;
	LONG style;
	LPCSTR lpszName;
	LPCSTR lpszClass;
	DWORD dwExStyle;
};


@nogc
extern(Windows)
{
	export LONG SetWindowLongW(
					   HWND hWnd,       // ウィンドウのハンドル
					   int nIndex,      // 設定する値のオフセット
					   LONG dwNewLong   // 新しい値
						   )nothrow;

	export LONG GetWindowLongW(
					   HWND hWnd,  // ウィンドウのハンドル
					   int nIndex  // 取得する値のオフセット
						   )nothrow;

	/*
	export LONG_PTR SetWindowLongPtrW(
						  HWND hWnd,           // ウィンドウのハンドル
						  int nIndex,          // 変更する値のオフセット
						  LONG_PTR dwNewLong   // 新しい値
							  )nothrow;
	*/
}

enum
{
	GWL_USERDATA=(-21),
}

D3D11Manager* g_d3d;

extern(Windows)
LRESULT WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)nothrow
{
    switch (message)
    {
        case WM_CREATE:
            {
                // initialize
                auto d3d = cast(D3D11Manager*)(cast(CREATESTRUCT*)lParam).lpCreateParams;
                SetWindowLongW(hWnd, GWL_USERDATA, cast(LONG)d3d);

				auto tmp=GetWindowLongW(hWnd, GWL_USERDATA);
				auto t2=cast(D3D11Manager*)tmp;

				g_d3d=d3d;
                break;
            }

        case WM_ERASEBKGND:
            return 0;

        case WM_SIZE:
            {
				auto tmp=GetWindowLongW(hWnd, GWL_USERDATA);
				auto d3d = cast(D3D11Manager*)tmp;
				try{
					//d3d.Resize(LOWORD(wParam), HIWORD(wParam));
					g_d3d.Resize(LOWORD(wParam), HIWORD(wParam));
				}
				catch(Throwable o)
				{
					//MessageBoxA(null, cast(char *)o.toString(), "Error", MB_OK | MB_ICONEXCLAMATION);
				}
			}
			return 0;

        case WM_PAINT:
			{
				PAINTSTRUCT ps;
				HDC hdc = BeginPaint(hWnd, &ps);
				scope(exit)EndPaint(hWnd, &ps);
			}
			return 0;

        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;

		default:
			break;
    }

    return DefWindowProcW(hWnd, message, wParam, lParam);
}
