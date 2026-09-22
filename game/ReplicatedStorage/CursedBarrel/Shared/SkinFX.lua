--[[
	SkinFX  (Phase 6)
	스킨의 fx 항목을 읽어 실제 파티클 · 빛 · 꼬리를 붙인다.

	Phase 5 까지 스킨은 "색과 재질만" 바뀌었다. 그래서 전설 스킨도 색 다른 나무통처럼 보였다.
	여기서 붙이는 것은 전부 눈에 띄는 것들이다.

	  emit    피어오르는 입자
	  spark   반짝임
	  trail   움직일 때 남는 꼬리 (칼 전용)
	  halo    바닥에 깔리는 고리
	  pulse   밝기가 숨 쉬는 속도
	  smoke   느리고 큰 연기
	  bubbles 위로 올라가는 물방울
	  coins   튀어 오르는 금화

	규칙
	  · 이 모듈이 만든 것은 전부 이름이 "SkinFX_" 로 시작한다.
	    다시 칠할 때 그것만 지우면 원래 모델은 건드리지 않는다.
	  · 파티클 수는 일부러 인색하게 잡았다. 테이블 10개에서 동시에 터져도 버텨야 한다.
	  · 숨 쉬는 애니메이션은 매 프레임 도는 코드 대신 TweenService 의 무한 반복을 쓴다.
]]

local TweenService = game:GetService("TweenService")

local SkinFX = {}

local PREFIX = "SkinFX_"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

--------------------------------------------------
-- 정리
--------------------------------------------------

function SkinFX.clear(instance)
	if not instance then
		return
	end
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant.Name:sub(1, #PREFIX) == PREFIX then
			descendant:Destroy()
		end
	end
end

--------------------------------------------------
-- 작은 도구
--------------------------------------------------

local function named(class, suffix, parent)
	local instance = Instance.new(class)
	instance.Name = PREFIX .. suffix
	instance.Parent = parent
	return instance
end

local function sequence(color)
	return ColorSequence.new(color)
end

-- 밝기가 천천히 숨 쉬게 한다. 매 프레임 도는 코드를 만들지 않으려고 Tween 을 쓴다.
local function breathe(object, property, low, high, speed)
	if not speed or speed <= 0 then
		return
	end
	object[property] = low
	local info = TweenInfo.new(math.max(0.25, 1.6 / speed), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(object, info, { [property] = high }):Play()
end

--------------------------------------------------
-- 조각별 효과
--------------------------------------------------

local function addEmit(part, color, rate, size, speed)
	local emitter = named("ParticleEmitter", "Emit", part)
	emitter.Texture = SPARKLE
	emitter.Color = sequence(color)
	emitter.LightEmission = 0.85
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.35, size or 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.7, 1.4)
	emitter.Rate = rate or 7
	emitter.Speed = NumberRange.new(0.3, speed or 1.1)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Acceleration = Vector3.new(0, 1.6, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-45, 45)
	return emitter
end

local function addSpark(part, color)
	local emitter = named("ParticleEmitter", "Spark", part)
	emitter.Texture = SPARKLE
	emitter.Color = sequence(color)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.25, 0.6)
	emitter.Rate = 10
	emitter.Speed = NumberRange.new(1.5, 3.4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	return emitter
end

local function addSmoke(part, color)
	local emitter = named("ParticleEmitter", "Smoke", part)
	emitter.Texture = SMOKE
	emitter.Color = sequence(color)
	emitter.LightEmission = 0.2
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1.9),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.72),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(1.4, 2.4)
	emitter.Rate = 4
	emitter.Speed = NumberRange.new(0.4, 1)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.Acceleration = Vector3.new(0, 2.2, 0)
	return emitter
end

local function addBubbles(part, color)
	local emitter = named("ParticleEmitter", "Bubbles", part)
	emitter.Texture = SPARKLE
	emitter.Color = sequence(color)
	emitter.LightEmission = 0.6
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.26),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(1.6, 2.6)
	emitter.Rate = 6
	emitter.Speed = NumberRange.new(1, 2)
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.Acceleration = Vector3.new(0, 3.4, 0)
	return emitter
end

local function addCoins(part, color)
	local emitter = named("ParticleEmitter", "Coins", part)
	emitter.Texture = FIRE
	emitter.Color = sequence(color)
	emitter.LightEmission = 0.9
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(1, 0.02),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Rate = 5
	emitter.Speed = NumberRange.new(2.4, 4.2)
	emitter.SpreadAngle = Vector2.new(50, 50)
	emitter.Acceleration = Vector3.new(0, -14, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-260, 260)
	return emitter
end

local function addLight(part, color, brightness, range, pulse)
	local light = named("PointLight", "Light", part)
	light.Color = color
	light.Range = range or 12
	light.Shadows = false
	if pulse and pulse > 0 then
		breathe(light, "Brightness", brightness * 0.45, brightness, pulse)
	else
		light.Brightness = brightness
	end
	return light
end

-- 바닥 고리. 가만히 있는 얇은 네온 원판이라 비용이 거의 없다.
local function addHalo(part, color, diameter, pulse)
	local halo = named("Part", "Halo", part.Parent or part)
	halo.Shape = Enum.PartType.Cylinder
	halo.Size = Vector3.new(0.08, diameter, diameter)
	halo.CFrame = part.CFrame * CFrame.new(0, -(part.Size.Y * 0.5) - 0.2, 0) * CFrame.Angles(0, 0, math.rad(90))
	halo.Color = color
	halo.Material = Enum.Material.Neon
	halo.Anchored = true
	halo.CanCollide = false
	halo.CanTouch = false
	halo.CanQuery = false
	halo.CastShadow = false
	breathe(halo, "Transparency", 0.55, 0.9, pulse or 1)
	if not pulse or pulse <= 0 then
		halo.Transparency = 0.7
	end
	return halo
end

--------------------------------------------------
-- 종류별 적용
--------------------------------------------------

-- 어떤 파트에 붙일지 고른다. 없으면 가장 큰 파트.
local function anchorPart(model, preferred)
	if not model then
		return nil
	end
	if model:IsA("BasePart") then
		return model
	end
	for _, name in ipairs(preferred or {}) do
		local found = model:FindFirstChild(name, true)
		if found and found:IsA("BasePart") then
			return found
		end
	end
	local best, bestVolume = nil, -1
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
			if volume > bestVolume then
				best, bestVolume = descendant, volume
			end
		end
	end
	return best
end

local function applyCommon(anchor, fx, scale)
	if not anchor or not fx then
		return
	end
	scale = scale or 1

	if fx.emit then
		addEmit(anchor, fx.emit, 7 * scale, 0.35 * scale)
	end
	if fx.spark then
		addSpark(anchor, fx.spark == true and (fx.emit or Color3.new(1, 1, 1)) or fx.spark)
	end
	if fx.smoke then
		addSmoke(anchor, fx.smoke == true and (fx.emit or Color3.fromRGB(120, 120, 120)) or fx.smoke)
	end
	if fx.bubbles then
		addBubbles(anchor, fx.bubbles == true and (fx.emit or Color3.fromRGB(180, 226, 255)) or fx.bubbles)
	end
	if fx.coins then
		addCoins(anchor, fx.coins == true and Color3.fromRGB(255, 206, 110) or fx.coins)
	end
	if fx.halo then
		addHalo(anchor, fx.halo, math.max(anchor.Size.X, anchor.Size.Z) * 1.9, fx.pulse)
	end
	if fx.emit or fx.halo then
		addLight(anchor, fx.halo or fx.emit, 2.2, 13 * scale, fx.pulse)
	end
end

-- 통에 꽂힌 칼 하나. (서버가 부른다 → 같은 테이블 모두에게 보인다)
function SkinFX.applyKnife(knifeModel, skin, visible)
	SkinFX.clear(knifeModel)
	if not knifeModel or not skin then
		return
	end
	-- 칼이 아직 숨어 있으면(아무도 안 꽂은 자리) 이펙트도 붙이지 않는다.
	if visible == false then
		return
	end
	local fx = skin.fx
	if not fx then
		return
	end

	local blade = anchorPart(knifeModel, { "Blade" })
	applyCommon(blade, fx, 0.6)

	if fx.trail and blade then
		local attach0 = named("Attachment", "TrailA", blade)
		attach0.Position = Vector3.new(0, blade.Size.Y * 0.4, 0)
		local attach1 = named("Attachment", "TrailB", blade)
		attach1.Position = Vector3.new(0, -blade.Size.Y * 0.4, 0)
		local trail = named("Trail", "Trail", blade)
		trail.Attachment0 = attach0
		trail.Attachment1 = attach1
		trail.Color = sequence(fx.trail)
		trail.Lifetime = 0.35
		trail.LightEmission = 1
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
end

-- 게임 안의 통. (각자 화면에서 부른다)
function SkinFX.applyBarrel(barrelModel, skin)
	SkinFX.clear(barrelModel)
	if not barrelModel or not skin or not skin.fx then
		return
	end
	local body = anchorPart(barrelModel, { "Body" })
	applyCommon(body, skin.fx, 1.15)
end

-- 통에서 튀어나오는 해적. (각자 화면에서 부른다)
function SkinFX.applyGhost(ghostModel, skin)
	SkinFX.clear(ghostModel)
	if not ghostModel or not skin or not skin.fx then
		return
	end
	local anchor = anchorPart(ghostModel, { "Coat", "SpectralHead" })
	applyCommon(anchor, skin.fx, 1)
end

-- 전시대 위에서 도는 모형. 로비는 여유가 있으니 조금 더 화려하게.
function SkinFX.applyPreview(model, skin, kind)
	SkinFX.clear(model)
	if not model or not skin or not skin.fx then
		return
	end
	local preferred = (kind == "Knife" and { "Blade" })
		or (kind == "Barrel" and { "Body" })
		or { "Coat", "SpectralHead" }
	local anchor = anchorPart(model, preferred)
	applyCommon(anchor, skin.fx, 1.35)
end

return SkinFX
