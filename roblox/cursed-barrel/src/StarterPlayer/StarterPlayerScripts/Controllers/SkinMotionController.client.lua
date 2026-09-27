--[[
	SkinMotionController  (Phase 17)
	전설 · 신화 스킨의 룬 고리 · 도는 용 · 흩날리는 꽃잎을 내 화면에서 움직인다. (SkinMotion 모듈)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local MeshKit = require(Shared:WaitForChild("MeshKit"))
local SkinMotion = require(Shared:WaitForChild("SkinMotion"))

SkinMotion.start()

-- Blender 스킨 모델이 늦게 도착하면(서버가 옮긴 직후) 한 번 다시 만든다
ReplicatedStorage.ChildAdded:Connect(function(child)
	if child.Name == MeshKit.SkinLibraryName then
		task.delay(0.5, SkinMotion.rebuild)
	end
end)
