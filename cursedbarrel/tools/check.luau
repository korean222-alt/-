local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local root = process.args[1]
local bad = 0
local count = 0
local function walk(dir)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif name:match("%.lua$") then
			count += 1
			local ok, err = pcall(luau.compile, fs.readFile(path))
			if not ok then
				bad += 1
				print("SYNTAX ERROR", path, err)
			end
		end
	end
end
walk(root)
print(("checked %d files, %d errors"):format(count, bad))
