local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local U = require(RS.Shared.Modules.Utility)
local C = require(RS.Shared.Config.GameConfig)
local S = {}
function S:Init(ctx)
    self.ctx, self.Participants, self.StartAt, self.Result, self.RoundId = ctx, {}, nil, nil, 0
end
function S:IsParticipant(player) return self.Participants[player] == true end
function S:Count() local n = 0; for _ in pairs(self.Participants) do n = n + 1 end; return n end
function S:Join(player)
    if self.ctx.Clock.Phase ~= "Waiting" or self:Count() >= C.MaxPlayers then
        player:Kick("이 원정은 이미 시작했거나 인원이 찼습니다. 새 서버에서 시작해 주세요.")
        return false
    end
    self.Participants[player] = true
    if not self.StartAt then self.StartAt = workspace:GetServerTimeNow() + C.StartDelay end
    return true
end
function S:Leave(player)
    self.Participants[player] = nil
    if self:Count() == 0 then
        if self.ctx.Clock.Phase ~= "Waiting" then self:Reset() else self.StartAt = nil end
    end
end
function S:Change(phase, night, seconds)
    self.ctx.Clock:Begin(phase, night, seconds)
    self.ctx.Defenses:RefreshAll()
end
function S:Start()
    if self:Count() == 0 then return end
    self.RoundId = self.RoundId + 1
    self.LockedPlayerCount, self.Result, self.Warned = self:Count(), nil, false
    self:Change("Day", 1, C.FirstDaySeconds)
    self.ctx.Notify(nil, "원정 시작! 펫 포획 · 재료 모으기 · 제작대에서 더 좋은 도구 · 밤에는 기지 방어")
end
function S:Finish(won, reason)
    if self.ctx.Clock.Phase == "Result" or self.ctx.Clock.Phase == "Waiting" then return end
    self.Result = {Won = won, Reason = reason, Nights = won and C.TargetNights or math.max(0, self.ctx.Clock.Night - 1)}
    self:Change("Result", self.ctx.Clock.Night, C.ResultSeconds * self.ctx.Clock:Scale())
    self.ctx.Enemies:Reset()
    self.ctx.Waves:Reset()
    self.ctx.Notify(nil, (won and "방어 성공! " or "원정 실패: ") .. reason)
end
function S:Reset()
    self:Change("Waiting", 0, 0)
    self.ctx.Enemies:Reset()
    self.ctx.Waves:Reset()
    self.ctx.Resources:Reset()
    self.ctx.Defenses:Reset()
    self.ctx.Core:Reset()
    if self.ctx.Pets then self.ctx.Pets:Reset() end
    if self.ctx.Capture then self.ctx.Capture:Reset() end
    if self.ctx.Crafting then self.ctx.Crafting:Reset() end
    if self.ctx.Survival then self.ctx.Survival:Reset() end
    self.Result, self.Warned = nil, false
    self.StartAt = self:Count() > 0 and workspace:GetServerTimeNow() + C.StartDelay or nil
    for player in pairs(self.Participants) do
        local root, human = U.aliveRoot(player)
        if root then
            human.Health = human.MaxHealth
            player.Character:PivotTo(self.ctx.Map.Spawn.CFrame + Vector3.new(0, 4, 0))
        end
    end
end
function S:Tick()
    local clock, phase = self.ctx.Clock, self.ctx.Clock.Phase
    if phase == "Waiting" then
        if self.StartAt and workspace:GetServerTimeNow() >= self.StartAt then self:Start() end
    elseif phase == "Day" then
        if not self.Warned and clock:Remaining() <= C.WarningSeconds / clock:Scale() then
            self.Warned = true; self.ctx.Notify(nil, "곧 밤입니다! 기지로 돌아오세요")
        end
        if clock:Expired() then
            self:Change("Night", clock.Night, C.NightSeconds)
            if C.ActiveStage >= 4 then self.ctx.Waves:Start(clock.Night, self.LockedPlayerCount) end
            self.ctx.Notify(nil, "밤 " .. clock.Night .. " 시작 · 밤에는 수리만 가능합니다")
        end
    elseif phase == "Night" then
        if clock:Expired() or self.ctx.Waves.BossDefeated then
            if self.ctx.Pets then self.ctx.Pets:NightSurvived(clock.Night, clock.Night >= C.TargetNights) end
            self.ctx.Enemies:Reset()
            self.ctx.Waves:Reset()
            self:Change("Dawn", clock.Night, C.DawnSeconds * clock:Scale())
            self.ctx.Notify(nil, "밤 생존! 다음 방어를 준비하세요")
        end
    elseif phase == "Dawn" and clock:Expired() then
        if clock.Night >= C.TargetNights then
            self:Finish(true, C.ActiveStage >= 4 and "초원 3밤 생존" or "단계 테스트 완료 (적 없음)")
        else
            self.Warned = false
            self:Change("Day", clock.Night + 1, C.DaySeconds)
        end
    elseif phase == "Result" and clock:Expired() then self:Reset() end
end
return S
