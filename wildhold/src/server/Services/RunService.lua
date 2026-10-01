local RS = game:GetService("ReplicatedStorage")
local U = require(RS.Shared.Modules.Utility)
local C = require(RS.Shared.Config.GameConfig)
local EC = require(RS.Shared.Config.EggConfig)
local Eggs = require(RS.Shared.Modules.Eggs)
local L = require(RS.Shared.Modules.Locale)
local S = {}
function S:Init(ctx)
    self.ctx, self.Participants, self.StartAt, self.Result, self.RoundId = ctx, {}, nil, nil, 0
end
function S:IsParticipant(player) return self.Participants[player] == true end
function S:Count() local n = 0; for _ in pairs(self.Participants) do n = n + 1 end; return n end
-- 들어오면 바로 논다: 원정 중간에 들어와도 기본 소지품·펫과 함께 합류한다 (공개 서버에서 튕기지 않게).
-- 혼자 들어온 첫 사람은 StartDelay(몇 초) 뒤 바로 출발한다.
function S:Join(player)
    if self:Count() >= C.MaxPlayers then
        player:Kick(L.t("run.serverFull", nil, L.of(player)))
        return false
    end
    self.Participants[player] = true
    if self.ctx.Clock.Phase == "Waiting" and not self.StartAt then self.StartAt = workspace:GetServerTimeNow() + C.StartDelay end
    if self.ctx.Clock.Phase == "Day" or self.ctx.Clock.Phase == "Night" then
        task.defer(function() if player.Parent then self.ctx.Notify(player, L.M("run.joinedLate")) end end)
    end
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
    self.ctx.Notify(nil, L.M("run.start"))
end
function S:Finish(won, reason)
    if self.ctx.Clock.Phase == "Result" or self.ctx.Clock.Phase == "Waiting" then return end
    self.Result = {Won = won, Reason = reason, Nights = won and C.TargetNights or math.max(0, self.ctx.Clock.Night - 1)}
    -- 보상 알: 클리어 = 희귀한 알, 실패해도 CommonNights 밤 이상 버티면 보통 알
    self.Result.Egg = Eggs.reward(won, self.Result.Nights, EC)
    if self.Result.Egg and self.ctx.Eggs then
        for player in pairs(self.Participants) do
            self.ctx.Eggs:Grant(player, self.Result.Egg, won and L.M("run.clearReason") or L.M("run.nightsReason", {n = self.Result.Nights}))
        end
    end
    self:Change("Result", self.ctx.Clock.Night, C.ResultSeconds * self.ctx.Clock:Scale())
    self.ctx.Enemies:Reset()
    self.ctx.Waves:Reset()
    self.ctx.Notify(nil, L.M(won and "run.won" or "run.lost", {why = reason}))
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
    if self.ctx.Chests then self.ctx.Chests:Reset() end
    if self.ctx.Tutorial then self.ctx.Tutorial:Reset() end
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
            self.Warned = true; self.ctx.Notify(nil, L.M("run.duskWarning"))
        end
        if clock:Expired() then
            self:Change("Night", clock.Night, C.NightSeconds)
            -- 중간에 들어온 사람도 세도록 밤마다 지금 인원으로 웨이브 크기를 정한다
            self.LockedPlayerCount = math.max(1, self:Count())
            if C.ActiveStage >= 4 then self.ctx.Waves:Start(clock.Night, self.LockedPlayerCount) end
            self.ctx.Notify(nil, L.M("run.nightStart", {n = clock.Night}))
        end
    elseif phase == "Night" then
        if clock:Expired() or self.ctx.Waves.BossDefeated then
            if self.ctx.Pets then self.ctx.Pets:NightSurvived(clock.Night, clock.Night >= C.TargetNights) end
            self.ctx.Enemies:Reset()
            self.ctx.Waves:Reset()
            self:Change("Dawn", clock.Night, C.DawnSeconds * clock:Scale())
            self.ctx.Notify(nil, L.M("run.nightSurvived"))
        end
    elseif phase == "Dawn" and clock:Expired() then
        if clock.Night >= C.TargetNights then
            self:Finish(true, L.M(C.ActiveStage >= 4 and "run.clearNights" or "run.stageTest", {n = C.TargetNights}))
        else
            self.Warned = false
            self:Change("Day", clock.Night + 1, C.DaySeconds)
        end
    elseif phase == "Result" and clock:Expired() then
        -- 결과 화면 뒤 로비로 (로비에서 알을 깨우고 다시 출발)
        if self.ctx.ReturnToLobby then self.ctx.ReturnToLobby() end
        self:Reset()
    end
end
return S
