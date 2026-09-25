local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local Instance = roblox.Instance

local src, out, scripts = process.args[1], process.args[2], process.args[3] or "place/new"
local game = roblox.deserializePlace(fs.readFile(src))

local changed, created = {}, {}
local function classFor(path)
	if path:find("^StarterPlayer/StarterPlayerScripts/") then
		return "LocalScript"
	end
	if path:find("/Main%.lua$") then
		return "Script"
	end
	return "ModuleScript"
end

local function walk(dir, rel)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		local r = rel == "" and name or (rel .. "/" .. name)
		if fs.isDir(path) then
			walk(path, r)
		elseif name:sub(-4) == ".lua" then
			local source = fs.readFile(path)
			local parts = string.split(r:sub(1, -5), "/")
			local node = game:GetService(parts[1])
			for i = 2, #parts - 1 do
				local child = node:FindFirstChild(parts[i])
				assert(child, "missing folder " .. parts[i] .. " in " .. r)
				node = child
			end
			local leaf = parts[#parts]
			local inst = node:FindFirstChild(leaf)
			if inst then
				if inst.Source ~= source then
					inst.Source = source
					table.insert(changed, r)
				end
			else
				inst = Instance.new(classFor(r))
				inst.Name = leaf
				inst.Source = source
				inst.Parent = node
				table.insert(created, r .. " (" .. inst.ClassName .. ")")
			end
		end
	end
end
walk(scripts, "")

-- Phase 17 : 예전 해적 모델은 파일에서도 치운다 (Phase 21 : 네 번째 인자로 --drop-custom-pirate 를 줄 때만.
--   지금 파일의 CustomPirate 는 직접 넣은 해적 모델일 수 있다)
local visuals = game.ReplicatedStorage.CursedBarrel:FindFirstChild("Visuals")
local custom = visuals and visuals:FindFirstChild("CustomPirate")
if custom and process.args[4] == "--drop-custom-pirate" then
	custom.Parent = nil
	print("removed Visuals.CustomPirate")
end

fs.writeFile(out, roblox.serializePlace(game))
print("changed:", #changed)
for _, c in changed do print("  ~ " .. c) end
print("created:", #created)
for _, c in created do print("  + " .. c) end
