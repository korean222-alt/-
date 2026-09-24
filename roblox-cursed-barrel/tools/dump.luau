local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local src, outDir = process.args[1] or "place/orig.rbxl", process.args[2] or "place"
local game = roblox.deserializePlace(fs.readFile(src))
local out = {}
local function walk(inst, path, depth)
	local p = path .. "/" .. inst.Name
	local line = string.rep("  ", depth) .. inst.Name .. " [" .. inst.ClassName .. "]"
	if inst:IsA("LuaSourceContainer") then
		local src = inst.Source
		local rel = p:gsub("^/", ""):gsub("[^%w/_%.%-]", "_")
		fs.writeDir(outDir .. "/src/" .. rel:match("(.*)/"))
		fs.writeFile(outDir .. "/src/" .. rel .. ".lua", src)
		line ..= " (" .. #src .. " bytes)"
	end
	table.insert(out, line)
	for _, c in inst:GetChildren() do walk(c, p, depth + 1) end
end
for _, svc in game:GetChildren() do
	if svc.ClassName ~= "Workspace" then walk(svc, "", 0) else
		table.insert(out, "Workspace")
		for _, c in svc:GetChildren() do
			table.insert(out, "  " .. c.Name .. " [" .. c.ClassName .. "] children=" .. #c:GetChildren())
		end
	end
end
fs.writeFile(outDir .. "/tree.txt", table.concat(out, "\n"))
