local RS = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Engine = game:GetService("RunService")
local C = require(RS.Shared.Config.GameConfig)
local D = {Phase = "Waiting", Night = 0, EndsAt = 0}
function D:Scale()
    return Engine:IsStudio() and math.max(1, C.StudioTimeScale) or 1
end
function D:Begin(phase, night, seconds)
    self.Phase, self.Night = phase, night
    self.EndsAt = workspace:GetServerTimeNow() + seconds / self:Scale()
    local dark = phase == "Night"
    Lighting.ClockTime = dark and C.NightClock or C.DayClock
    Lighting.Brightness = dark and 2 or 3
    Lighting.Ambient = dark and Color3.fromRGB(106, 115, 147) or Color3.fromRGB(145, 145, 145)
    Lighting.OutdoorAmbient = dark and Color3.fromRGB(100, 110, 140) or Color3.fromRGB(155, 155, 155)
end
function D:Remaining()
    return math.max(0, self.EndsAt - workspace:GetServerTimeNow())
end
function D:Expired() return self:Remaining() <= 0 end
return D
