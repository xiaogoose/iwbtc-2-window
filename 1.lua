local Camera = UnityEngine.Camera
local GameObject = UnityEngine.GameObject
local RenderTexture = UnityEngine.RenderTexture
local CameraClearFlags =UnityEngine.CameraClearFlags 
local Color = UnityEngine.Color

local ffi = require("ffi")

-- 更推荐的方案：复制主摄像机的设置，但改targetTexture
function _G.createSlaveCamera()
    local mainCam = Camera.main
    if not mainCam then
        print("找不到主摄像机")
        return nil
    end
    
    -- 创建新物体
    local slaveObj = GameObject("SlaveCamera")
    local slaveCam = slaveObj:AddComponent(typeof(Camera))

    -- 复制主摄像机的所有设置（位置、旋转、视野等）
    slaveCam.transform.position = mainCam.transform.position
    slaveCam.transform.rotation = Vector3(0, 0, 0)
    slaveCam.transform.localScale = Vector3(1, -1, 1)
    slaveCam.fieldOfView = 6
    slaveCam.nearClipPlane = mainCam.nearClipPlane
    slaveCam.farClipPlane = mainCam.farClipPlane
    slaveCam.cullingMask = mainCam.cullingMask
    slaveCam.clearFlags = UnityEngine.CameraClearFlags.SolidColor
    slaveCam.backgroundColor = UnityEngine.Color(0,0,0,1)
    slaveCam.depth = mainCam.depth - 1
    -- 翻转投影矩阵
    local mat = slaveCam.projectionMatrix
    mat.m11 = -mat.m11
    slaveCam.projectionMatrix = mat


    -- 创建RenderTexture
    local rt = RenderTexture(1920,1080,24)
    rt:Create()



    slaveCam.targetTexture = rt
    mainCam.targetTexture = nil
    
    -- 这个摄像机会自动每帧渲染到rt
    -- 完全不影响主摄像机的渲染
    
    return slaveCam, rt
end

-- 使用

local slaveCam, oldRt = _G.createSlaveCamera()
_G.Ptr = oldRt:GetNativeTexturePtr()
_G.oldrt=oldRt
print("相机的指针：" .. tostring(_G.Ptr))



