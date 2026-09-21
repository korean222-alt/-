--[[
	SetupLighting.lua  (Studio 명령줄 전용 · 1회 실행)

	해적 선술집 분위기의 기본 라이팅을 한 번에 잡아준다.
	"따뜻한 랜턴 + 어두운 실내 + 창밖의 푸른 밤" 톤.

	주의: Lighting.Technology 는 스크립트로 바꿀 수 없다.
	      Explorer 에서 Lighting 을 선택하고 Properties 의 Technology 를
	      Future 로 직접 바꿔주면 조명 품질이 크게 좋아진다.
]]

local Lighting = game:GetService("Lighting")

-- 기본 톤
Lighting.Ambient = Color3.fromRGB(58, 48, 42) -- 실내 기본 밝기 (너무 어두우면 플레이가 답답해진다)
Lighting.OutdoorAmbient = Color3.fromRGB(46, 60, 74) -- 창밖에서 들어오는 푸른 밤빛
Lighting.Brightness = 1.6
Lighting.ClockTime = 20.6 -- 해가 막 진 시간대
Lighting.GeographicLatitude = 12
Lighting.ExposureCompensation = 0.15
Lighting.EnvironmentDiffuseScale = 0.35
Lighting.EnvironmentSpecularScale = 0.25
Lighting.GlobalShadows = true
Lighting.FogEnd = 100000 -- Atmosphere 를 쓰므로 구형 Fog 는 끈다

local function ensure(className, name)
	local instance = Lighting:FindFirstChild(name)
	if instance and not instance:IsA(className) then
		instance:Destroy()
		instance = nil
	end
	if not instance then
		instance = Instance.new(className)
		instance.Name = name
		instance.Parent = Lighting
	end
	return instance
end

-- 공기 중의 먼지 느낌
local atmosphere = ensure("Atmosphere", "Atmosphere")
atmosphere.Density = 0.32
atmosphere.Offset = 0.1
atmosphere.Color = Color3.fromRGB(202, 188, 166)
atmosphere.Decay = Color3.fromRGB(70, 82, 96)
atmosphere.Glare = 0.25
atmosphere.Haze = 1.6

-- 랜턴 불빛이 은은하게 번지게
local bloom = ensure("BloomEffect", "Bloom")
bloom.Intensity = 0.55
bloom.Size = 26
bloom.Threshold = 1.05

-- 전체 색감 보정 (따뜻하게, 대비 약간 up)
local colorCorrection = ensure("ColorCorrectionEffect", "ColorCorrection")
colorCorrection.Brightness = 0.02
colorCorrection.Contrast = 0.12
colorCorrection.Saturation = 0.08
colorCorrection.TintColor = Color3.fromRGB(255, 245, 231)

print("[CursedBarrel] 라이팅 기본 설정 완료 · Lighting.Technology 는 직접 Future 로 바꿔주세요")
