--[[
	loader.lua
	game/ 아래의 Luau 모듈을 흉내 환경에서 불러온다.

	Luau CLI 는 _G 가 읽기 전용이라 전역을 갈아끼울 수 없다.
	그래서 파일 앞에 "전역을 지역 변수로 가리는 줄"을 붙여 loadstring 으로 불러온다.
	모듈 코드는 한 글자도 고치지 않는다. 진짜 게임에서 도는 그 코드를 그대로 돌린다.
]]

local stub = require("./roblox_stub")
local bundle = require("./bundle")

local SHADOWED = {
	"game", "workspace", "Instance", "Vector3", "Vector2", "Color3", "CFrame",
	"UDim", "UDim2", "Enum", "Random", "task", "typeof", "require", "script",
	"NumberSequence", "NumberSequenceKeypoint", "ColorSequence", "NumberRange",
	"TweenInfo", "warn",
}

local Loader = {}
Loader.__index = Loader

function Loader.new()
	local env = stub.build()
	local self = setmetatable({
		env = env,
		cache = {},
		stub = stub,
	}, Loader)

	-- 모듈 인스턴스를 require 로 넘기면 그 모듈의 반환값을 돌려준다.
	env.require = function(moduleInstance)
		assert(moduleInstance, "require 에 nil 이 들어왔습니다")
		return self:load(moduleInstance.Name, moduleInstance)
	end

	return self
end

function Loader:load(name, moduleInstance)
	if self.cache[name] ~= nil then
		return self.cache[name]
	end

	local chunk = bundle[name]
	assert(chunk, ("묶음에 '%s' 모듈이 없습니다. tests/build_bundle.py 를 다시 돌려 주세요."):format(tostring(name)))

	-- script 는 모듈마다 다르다. 나머지 전역은 모두가 같은 것을 본다.
	local flat = { script = moduleInstance }
	for _, key in ipairs(SHADOWED) do
		if flat[key] == nil then
			flat[key] = self.env[key]
		end
	end

	self.cache[name] = true -- 순환 require 를 막는다
	local result = chunk(flat)
	self.cache[name] = result
	return result
end

return Loader
