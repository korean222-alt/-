-- Writes every script in src/ back into the place file and saves a new place.
-- Usage: lune run build.luau <in.rbxl> <out.rbxl>
--   · src/<Service>/<...>/<Name>.server.lua  → Script
--   · src/<Service>/<...>/<Name>.client.lua  → LocalScript
--   · src/<Service>/<...>/<Name>.lua         → ModuleScript
-- Scripts that exist in src/ but not in the place are created (missing folders become Folders).
-- Every source is compiled first; a syntax error stops the build.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Instance = roblox.Instance

local inPath = process.args[1] or "CursedBarrel_Phase31.rbxl"
local outPath = process.args[2] or "CursedBarrel_Phase32.rbxl"
local srcDir = "src"

local place = roblox.deserializePlace(fs.readFile(inPath))

local function classOf(file)
	if file:sub(-11) == ".server.lua" then
		return "Script", file:sub(1, -12)
	elseif file:sub(-11) == ".client.lua" then
		return "LocalScript", file:sub(1, -12)
	elseif file:sub(-4) == ".lua" then
		return "ModuleScript", file:sub(1, -5)
	end
	return nil
end

local function walk(dir, parts, out)
	for _, name in fs.readDir(dir) do
		local full = dir .. "/" .. name
		if fs.isDir(full) then
			local next = table.clone(parts)
			table.insert(next, name)
			walk(full, next, out)
		else
			local className, base = classOf(name)
			if className then
				table.insert(out, { file = full, parts = parts, name = base, className = className })
			end
		end
	end
end

local entries = {}
walk(srcDir, {}, entries)
table.sort(entries, function(a, b)
	return a.file < b.file
end)

local failures = 0
for _, entry in entries do
	local source = fs.readFile(entry.file)
	local ok, err = pcall(luau.compile, source)
	if not ok then
		failures += 1
		print("SYNTAX ERROR in " .. entry.file .. ": " .. tostring(err))
	end
end
if failures > 0 then
	error(("%d file(s) failed to compile"):format(failures))
end

local created, updated, unchanged = 0, 0, 0
for _, entry in entries do
	local node = place:GetService(entry.parts[1])
	for index = 2, #entry.parts do
		local child = node:FindFirstChild(entry.parts[index])
		if not child then
			child = Instance.new("Folder")
			child.Name = entry.parts[index]
			child.Parent = node
		end
		node = child
	end
	local script = node:FindFirstChild(entry.name)
	if script and script.ClassName ~= entry.className then
		error(("%s exists as %s, expected %s"):format(entry.file, script.ClassName, entry.className))
	end
	local source = fs.readFile(entry.file)
	if not script then
		script = Instance.new(entry.className)
		script.Name = entry.name
		script.Source = source
		script.Parent = node
		created += 1
		print("created " .. entry.file)
	elseif script.Source ~= source then
		script.Source = source
		updated += 1
		print("updated " .. entry.file)
	else
		unchanged += 1
	end
end

fs.writeFile(outPath, roblox.serializePlace(place))
print(("built %s · %d updated · %d created · %d unchanged"):format(outPath, updated, created, unchanged))
