-- Extracts every script in a place file into src/ (Rojo-style names).
-- Usage: lune run extract.luau <place.rbxl> <outDir>
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local placePath = process.args[1] or "CursedBarrel_Phase31.rbxl"
local outDir = process.args[2] or "src"
local place = roblox.deserializePlace(fs.readFile(placePath))

local SUFFIX = { Script = ".server.lua", LocalScript = ".client.lua", ModuleScript = ".lua" }

local function pathOf(instance)
	local parts = {}
	local node = instance
	while node and node ~= place do
		table.insert(parts, 1, node.Name)
		node = node.Parent
	end
	return parts
end

local count = 0
for _, descendant in place:GetDescendants() do
	local suffix = SUFFIX[descendant.ClassName]
	if suffix then
		local parts = pathOf(descendant)
		local name = table.remove(parts)
		local dir = outDir .. "/" .. table.concat(parts, "/")
		fs.writeDir(dir)
		local file = dir .. "/" .. name .. suffix
		if fs.isFile(file) then
			error("duplicate script path: " .. file)
		end
		fs.writeFile(file, descendant.Source)
		count += 1
	end
end
print(("extracted %d scripts into %s"):format(count, outDir))
