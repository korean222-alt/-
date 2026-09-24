-- tools/blender/build_models.py 가 부른다. 누운 다리 곡선을 JSON 으로 내보낸다.
local K = require({ __name = "KrakenLayout" })
local count = 200
local out = {}
local function vec(v) return string.format("[%.4f,%.4f,%.4f]", v.X, v.Y, v.Z) end
for _, arm in ipairs(K.Resting) do
	local samples = K.restingSample(arm, count)
	local rows = {}
	for _, s in ipairs(samples) do
		table.insert(rows, string.format('{"p":%s,"r":%.4f,"u":%.4f,"inner":%s}', vec(s.p), s.r, s.u, vec(s.inner)))
	end
	table.insert(out, string.format('{"name":"%s","samples":[%s]}', arm.name, table.concat(rows, ",")))
end
local head = K.Head
print(string.format('{"resting":[%s],"head":{"mantle":%.3f,"eyeSpread":%.3f,"eyeRise":%.3f,"eyeForward":%.3f,"eye":%.3f}}',
	table.concat(out, ","), head.mantle, head.eyeSpread, head.eyeRise, head.eyeForward, head.eye))
