-- 칼 꽂기 모션이 마지막으로 꽂히기 전에 통 속을 지나가는지 검사한다.
-- 통 : 원기둥 반지름 1.75 · 높이 4 (place 의 Barrel.Body) · 슬롯 16개 (두 줄)
-- 사용 : lune run tests/stab_motion.luau src/ReplicatedStorage/CursedBarrel/Shared/StabMotion.lua
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local file = process.args[1]
local env = setmetatable({
	game = { GetService = function() return {} end },
	CFrame = roblox.CFrame, Vector3 = roblox.Vector3, TweenInfo = {}, Enum = {},
}, { __index = _G })
local StabMotion = luau.load(fs.readFile(file), { environment = env, debugName = "StabMotion" })()
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local R, H = 1.75, 4
local failed = false
for _, style in { "classic", "overhead", "triple", "spin", "flourish", "slam", "dive", "bolt" } do
	local hits = 0
	for _, ringY in { -0.62, 0.62 } do
		for slot = 0, 7 do
			local angle = slot / 8 * math.pi * 2
			local outward = Vector3.new(math.sin(angle), 0, math.cos(angle))
			local pos = outward * (R + 0.06) + Vector3.new(0, ringY, 0)
			local spot = CFrame.new(pos) * CFrame.Angles(0, angle, 0)
			local target = spot * CFrame.Angles(math.rad(-14), 0, 0) * CFrame.new(0, 0, 0.2)
			local ctx = { target = target, look = spot.LookVector, center = Vector3.new(0, 0, 0) }
			for _, windup in { 0.2, 0.42 } do
				local plan = StabMotion.plan(style, windup)
				local strike = plan.strike or 0.08
				local stopAt = plan.total - strike -- 마지막으로 꽂히는 순간 전까지
				local t = 0
				while t <= stopAt do
					local cf = StabMotion.knifeAt(plan, t, ctx)
					for z = -0.8, 0.8, 0.2 do
						local p = (cf * CFrame.new(0, 0, z)).Position
						local r = math.sqrt(p.X * p.X + p.Z * p.Z)
						if r < R - 0.05 and math.abs(p.Y) < H / 2 then
							hits += 1
						end
					end
					t += 0.01
				end
			end
		end
	end
	print(("%-9s 통 속에 들어간 칼 표본: %d"):format(style, hits))
	if hits > 0 then failed = true end
end
if failed then error("칼이 통 속을 지나간다") end
