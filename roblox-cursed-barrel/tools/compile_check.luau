local fs = require("@lune/fs")
local luau = require("@lune/luau")
local bad = 0
local count = 0
local function walk(dir)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif name:sub(-4) == ".lua" then
			count += 1
			local ok, err = pcall(luau.compile, fs.readFile(path))
			if not ok then
				bad += 1
				print("FAIL", path, err)
			end
		end
	end
end
walk(require("@lune/process").args[1] or "place/new")
print(("compiled %d files, %d failed"):format(count, bad))
