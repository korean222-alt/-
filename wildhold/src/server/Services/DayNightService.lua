local RS = game:GetService("ReplicatedStorage")
local Engine = game:GetService("RunService")
local C = require(RS.Shared.Config.GameConfig)
local D = {Phase = "Waiting", Night = 0, EndsAt = 0}
function D:Scale()
    return Engine:IsStudio() and math.max(1, C.StudioTimeScale) or 1
end
-- 조명 연출(해 지는 전환, 안개, 별)은 클라이언트 EnvironmentController 가 부드럽게 처리한다.
-- 서버는 현재 단계만 알린다. 새로 들어온 클라이언트도 이 속성으로 바로 맞춘다.
function D:Begin(phase, night, seconds)
    self.Phase, self.Night = phase, night
    self.EndsAt = workspace:GetServerTimeNow() + seconds / self:Scale()
    workspace:SetAttribute("Phase", phase)
    workspace:SetAttribute("Night", night)
    workspace:SetAttribute("PhaseEndsAt", self.EndsAt)
end
function D:Remaining()
    return math.max(0, self.EndsAt - workspace:GetServerTimeNow())
end
function D:Expired() return self:Remaining() <= 0 end
return D
