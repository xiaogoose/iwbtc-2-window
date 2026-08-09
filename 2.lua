-- 加载d3d
local ffi = require("ffi")
local bridge = ffi.load(Data.GetCurrentGameFileFullPath_Dir( "Sprite" ) .. "/d3d11_bridge.dll")

ffi.cdef[[
    typedef struct IDXGISwapChain IDXGISwapChain;
    typedef struct ID3D11Device ID3D11Device;
    typedef struct ID3D11DeviceContext ID3D11DeviceContext;
    typedef struct ID3D11Texture2D ID3D11Texture2D;

    ID3D11Device* InitD3D11(ID3D11DeviceContext** outContext);
    IDXGISwapChain* CreateSwapChainForWindow(void* hwnd, int width, int height);
    ID3D11Texture2D* CreateSharedTex(int width, int height);
    void* VoidToTexture(void* tex);
    void* GetDevice(void* texPtr);
]]

function _G.load_d3d(hwnd)
    local outContext = ffi.new("ID3D11DeviceContext*[1]")

    _G.d3dDevice = bridge.InitD3D11(outContext)
    _G.d3dContext = outContext[0]
    _G.d3dSwapChain = bridge.CreateSwapChainForWindow(hwnd, 1920, 1080)
    _G.d3dSharedTex = bridge.CreateSharedTex(1920, 1080)
    
    print("InitD3D11 Device: " .. tostring(_G.d3dDevice))
    print("InitD3D11 Context: " .. tostring(_G.d3dContext))
    print("SwapChain: " .. tostring(_G.d3dSwapChain))
    print("SharedTex: " .. tostring(_G.d3dSharedTex))

    _G.unityTex  = bridge.VoidToTexture(_G.Ptr)
    print("纹理指针: " .. tostring(_G.unityTex))

    local drfff=bridge.GetDevice(_G.Ptr)
    print(tostring(drfff))
end