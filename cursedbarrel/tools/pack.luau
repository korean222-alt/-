--[[
	pack.luau — cursedbarrel/src 의 스크립트를 .rbxl 에 다시 넣는다. (Lune 0.10+)

	  lune run tools/pack.luau <원본.rbxl> <src 폴더> <결과.rbxl>

	src 안의 경로가 곧 게임 안의 경로다.
	  src/ServerScriptService/CursedBarrel/Services/RoundService.lua  → ModuleScript
	  src/.../Main.server.lua                                           → Script
	  src/.../TableController.client.lua                                → LocalScript
	원본에 있는 스크립트의 Source 만 바꾼다. 없는 경로를 만나면 멈춘다 (새 스크립트를 몰래 만들지 않는다).
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local input, srcRoot, output = process.args[1], process.args[2], process.args[3]
assert(input and srcRoot and output, "usage: lune run tools/pack.luau <in.rbxl> <src> <out.rbxl>")

local game = roblox.deserializePlace(fs.readFile(input))

local CLASS = { [".server.lua"] = "Script", [".client.lua"] = "LocalScript", [".lua"] = "ModuleScript" }

local function split(path)
	local parts = {}
	for piece in string.gmatch(path, "[^/]+") do
		table.insert(parts, piece)
	end
	return parts
end

local changed, same, total = 0, 0, 0
local function walk(dir, rel)
	for _, name in fs.readDir(dir) do
		local full = dir .. "/" .. name
		local relPath = rel == "" and name or (rel .. "/" .. name)
		if fs.isDir(full) then
			walk(full, relPath)
		else
			local className, base
			for suffix, cls in { [".server.lua"] = "Script", [".client.lua"] = "LocalScript" } do
				if string.sub(name, -#suffix) == suffix then
					className, base = cls, string.sub(name, 1, -#suffix - 1)
				end
			end
			if not className and string.sub(name, -4) == ".lua" then
				className, base = "ModuleScript", string.sub(name, 1, -5)
			end
			if className then
				total += 1
				local parts = split(rel)
				local node = game:GetService(parts[1])
				for i = 2, #parts do
					node = node and node:FindFirstChild(parts[i])
				end
				local target = node and node:FindFirstChild(base)
				assert(target, "원본에 없는 스크립트: " .. relPath)
				assert(target.ClassName == className, ("종류가 다름: %s (%s ≠ %s)"):format(relPath, target.ClassName, className))
				local source = fs.readFile(full)
				if target.Source ~= source then
					target.Source = source
					changed += 1
					print("  바뀜  " .. relPath)
				else
					same += 1
				end
			end
		end
	end
end
walk(srcRoot, "")
fs.writeFile(output, roblox.serializePlace(game))
print(("스크립트 %d개 중 %d개 바뀜 · %d개 그대로 → %s"):format(total, changed, same, output))
