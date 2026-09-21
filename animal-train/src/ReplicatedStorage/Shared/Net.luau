-- 서버 ↔ 클라이언트 통신 통로.
-- 모든 RemoteEvent 는 ReplicatedStorage/Remotes 안에만 있습니다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}
local cache = {}

local function getFolder()
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		if existing then
			return existing
		end
		local folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
		return folder
	end
	return ReplicatedStorage:WaitForChild("Remotes", 30)
end

function Net.event(name)
	local cached = cache[name]
	if cached then
		return cached
	end

	local folder = getFolder()
	local event
	if RunService:IsServer() then
		event = folder:FindFirstChild(name)
		if not event then
			event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
	else
		event = folder:WaitForChild(name, 30)
	end

	cache[name] = event
	return event
end

return Net
