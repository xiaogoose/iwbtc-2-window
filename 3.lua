-- 子窗口
local ffi = require("ffi")
local bridge = ffi.load(Data.GetCurrentGameFileFullPath_Dir( "Sprite" ) .. "/d3d11_bridge.dll")

ffi.cdef[[
    typedef void* HWND;
    typedef void* HINSTANCE;
    typedef void* HDC;
    typedef void* HBRUSH;
    typedef void* HGDIOBJ;
    
    HWND CreateWindowExA(unsigned int dwExStyle, const char* lpClassName, 
                         const char* lpWindowName, unsigned int dwStyle, 
                         int X, int Y, int nWidth, int nHeight,
                         HWND hWndParent, void* hMenu, HINSTANCE hInstance, void* lpParam);
    HINSTANCE GetModuleHandleA(const char* lpModuleName);
    int ShowWindow(HWND hWnd, int nCmdShow);
    int UpdateWindow(HWND hWnd);
    int DeleteObject(HGDIOBJ hgdiobj);
    int DestroyWindow(HWND hWnd);
    int GetAsyncKeyState(int vKey);

    // dll内容

    typedef struct IDXGISwapChain IDXGISwapChain;
    typedef struct ID3D11Device ID3D11Device;
    typedef struct ID3D11DeviceContext ID3D11DeviceContext;
    typedef struct IUnknown IUnknown;


    void CopyTexture(ID3D11DeviceContext* ctx, ID3D11Texture2D* dst, ID3D11Texture2D* src);
    void Present(IDXGISwapChain* swapChain, int syncInterval);
    void ReleaseComObject(IUnknown* obj);
    ID3D11Texture2D* GetBackBuffer(IDXGISwapChain* swapChain);
    void PumpMessages();
]]

local WS_OVERLAPPEDWINDOW = 0x00CF0000
local WS_VISIBLE = 0x10000000
local SW_SHOW = 5
local VK_ESCAPE = 0x1B
local SRCCOPY = 0x00CC0020
local LR_LOADFROMFILE = 0x0010
local IMAGE_BITMAP = 0
local LR_CREATEDIBSECTION = 0x2000

-- 创建窗口
local hInstance = ffi.C.GetModuleHandleA(nil)
local hwnd = ffi.C.CreateWindowExA(
    0, "#32770", "Second Camera View",
    bit.bor(WS_OVERLAPPEDWINDOW, WS_VISIBLE),
    200, 200, 960, 540,
    nil, nil, hInstance, nil
)

if hwnd == nil or tonumber(ffi.cast("int", hwnd)) == 0 then
    print("窗口创建失败")
    return
end

ffi.C.ShowWindow(hwnd, SW_SHOW)
ffi.C.UpdateWindow(hwnd)
print("窗口创建成功")

_G.second_window_hwnd = hwnd
_G.cachedBitmap = nil

print("hwnd: " .. tostring(hwnd))
print("hwnd 数值: " .. tonumber(ffi.cast("intptr_t", hwnd)))

_G.load_d3d(_G.second_window_hwnd)

function _G.UpdateSecondWindow()
    if not _G.second_window_hwnd then
        return
    end
    
    -- 按ESC关闭
    if ffi.C.GetAsyncKeyState(VK_ESCAPE) ~= 0 then
        if _G.cachedBitmap then
            ffi.C.DeleteObject(ffi.cast("HGDIOBJ", _G.cachedBitmap))
            _G.cachedBitmap = nil
        end
        ffi.C.DestroyWindow(_G.second_window_hwnd)
        _G.second_window_hwnd = nil
        print("窗口已关闭")
        return
    end

    local backBuffer = bridge.GetBackBuffer(_G.d3dSwapChain)
    -- Unity RT -> 共享纹理
    bridge.CopyTexture(_G.d3dContext, _G.d3dSharedTex, _G.unityTex)
    -- 共享纹理 -> 后台缓冲
    bridge.CopyTexture(_G.d3dContext, backBuffer, _G.d3dSharedTex)
    bridge.Present(_G.d3dSwapChain, 1)
    bridge.ReleaseComObject(ffi.cast("IUnknown*", backBuffer))

end
print("窗口已创建")
