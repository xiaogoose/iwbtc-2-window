#include <windows.h>
#include <d3d11.h>
#include <dxgi.h>
#include <stdint.h>
#include <stdio.h>

#define WIN32_LEAN_AND_MEAN

#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")

// COM 接口指针在 C 中是 struct 指针
typedef struct IDXGISwapChain IDXGISwapChain;
typedef struct ID3D11Device ID3D11Device;
typedef struct ID3D11DeviceContext ID3D11DeviceContext;
typedef struct ID3D11Texture2D ID3D11Texture2D;
typedef struct IDXGIResource IDXGIResource;
typedef struct IUnknown IUnknown;

static ID3D11Device* g_Device = NULL;
static ID3D11DeviceContext* g_Context = NULL;
static ID3D11Texture2D* g_SharedTex = NULL;
static IDXGISwapChain* g_SwapChain = NULL;

__declspec(dllexport) ID3D11Texture2D* GetBackBuffer(IDXGISwapChain* swapChain)
{
    if (!swapChain) return NULL;

    ID3D11Texture2D* backBuffer = NULL;
    swapChain->lpVtbl->GetBuffer(swapChain, 0, &IID_ID3D11Texture2D, (void**)&backBuffer);
    return backBuffer;
}

__declspec(dllexport) void CopyTexture(ID3D11DeviceContext* ctx, ID3D11Texture2D* dst, ID3D11Texture2D* src)
{
    if (!ctx || !dst || !src) return;

    D3D11_TEXTURE2D_DESC srcDesc, dstDesc;
    src->lpVtbl->GetDesc(src, &srcDesc);
    dst->lpVtbl->GetDesc(dst, &dstDesc);

    D3D11_BOX box;
    box.left = 0;
    box.top = 0;
    box.front = 0;
    box.right = srcDesc.Width < dstDesc.Width ? srcDesc.Width : dstDesc.Width;
    box.bottom = srcDesc.Height < dstDesc.Height ? srcDesc.Height : dstDesc.Height;
    box.back = 1;


    ctx->lpVtbl->CopySubresourceRegion(
        ctx,
        (ID3D11Resource*)dst, 0, 0, 0, 0,
        (ID3D11Resource*)src, 0, &box
    );
}

// ============================================
// 6. 呈现交换链
// ============================================
__declspec(dllexport) void Present(IDXGISwapChain* swapChain, int syncInterval)
{
    if (swapChain) {
        swapChain->lpVtbl->Present(swapChain, syncInterval, 0);
    }
}

// ============================================
// 辅助：释放对象
// ============================================
__declspec(dllexport) void ReleaseComObject(IUnknown* obj)
{
    if (obj) {
        obj->lpVtbl->Release(obj);
    }
}
// 指针转换
__declspec(dllexport) HANDLE VoidToTexture(void* tex)
{
    if (!tex) return NULL;
    ID3D11Texture2D* tex2D = (ID3D11Texture2D*)tex;
    return tex2D;
}

__declspec(dllexport) ID3D11Device* InitD3D11(ID3D11DeviceContext** outContext)
{
    D3D_FEATURE_LEVEL featureLevel;
    HRESULT hr = D3D11CreateDevice(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, 0,
                                     NULL, 0, D3D11_SDK_VERSION,
                                     &g_Device, &featureLevel, &g_Context);
    if (FAILED(hr)) return NULL;

    if (outContext) *outContext = g_Context;
    return g_Device;
}

__declspec(dllexport) ID3D11Texture2D* CreateSharedTex(int width, int height)
{
    D3D11_TEXTURE2D_DESC desc = {0};
    desc.Width = width;
    desc.Height = height;
    desc.MipLevels = 1;
    desc.ArraySize = 1;
    desc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    desc.SampleDesc.Count = 1;
    desc.Usage = D3D11_USAGE_DEFAULT;
    desc.BindFlags = D3D11_BIND_SHADER_RESOURCE | D3D11_BIND_RENDER_TARGET;
    desc.MiscFlags = D3D11_RESOURCE_MISC_SHARED;
    //desc.MiscFlags = 0;

    HRESULT hr = g_Device->lpVtbl->CreateTexture2D(g_Device, &desc, NULL, &g_SharedTex);
    if (FAILED(hr)) return NULL;

    char buf[256];
    sprintf(buf, "[DLL] CreateSharedTex: MiscFlags = 0x%08X", desc.MiscFlags);
    OutputDebugStringA(buf);

    return g_SharedTex;
}

// 用已有 g_Device 创建 SwapChain
__declspec(dllexport) IDXGISwapChain* CreateSwapChainForWindow(HWND hwnd, int width, int height)
{
    // 1. QueryInterface 拿 IDXGIDevice
    IDXGIDevice* dxgiDevice = NULL;
    HRESULT hr = g_Device->lpVtbl->QueryInterface(g_Device, &IID_IDXGIDevice, (void**)&dxgiDevice);
    if (FAILED(hr) || !dxgiDevice) return (IDXGISwapChain*)(size_t)hr;

    // 2. GetAdapter
    IDXGIAdapter* adapter = NULL;
    hr = dxgiDevice->lpVtbl->GetAdapter(dxgiDevice, &adapter);
    dxgiDevice->lpVtbl->Release(dxgiDevice);
    if (FAILED(hr) || !adapter) return (IDXGISwapChain*)(size_t)hr;

    // 3. GetParent 拿 Factory
    IDXGIFactory* factory = NULL;
    hr = adapter->lpVtbl->GetParent(adapter, &IID_IDXGIFactory, (void**)&factory);
    adapter->lpVtbl->Release(adapter);
    if (FAILED(hr) || !factory) return (IDXGISwapChain*)(size_t)hr;

    // 4. CreateSwapChain
    DXGI_SWAP_CHAIN_DESC sd = {0};
    sd.BufferDesc.Width = width;
    sd.BufferDesc.Height = height;
    sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    sd.BufferDesc.RefreshRate.Numerator = 60;
    sd.BufferDesc.RefreshRate.Denominator = 1;
    sd.SampleDesc.Count = 1;
    sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    sd.BufferCount = 2;
    sd.OutputWindow = hwnd;
    sd.Windowed = TRUE;
    sd.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;

    hr = factory->lpVtbl->CreateSwapChain(factory, (IUnknown*)g_Device, &sd, &g_SwapChain);
    factory->lpVtbl->Release(factory);
    if (FAILED(hr)) return (IDXGISwapChain*)(size_t)hr;

    return g_SwapChain;
}

__declspec(dllexport) void* GetDevice(void* ptr) {
    ID3D11Resource* res = (ID3D11Resource*)ptr;
    ID3D11Texture2D* tex = NULL;
    ID3D11Device* device = NULL;

    res->lpVtbl->QueryInterface(res, &IID_ID3D11Texture2D, (void**)&tex);
    if (!tex) return NULL;

    tex->lpVtbl->GetDevice(tex, &device);
    tex->lpVtbl->Release(tex);

    return device;
}