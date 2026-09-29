local RS = game:GetService("ReplicatedStorage")
local Rules = require(RS.Shared.Modules.Rules)
local W = require(RS.Shared.Config.WaveConfig)
local C = require(RS.Shared.Config.GameConfig)
local S = {}
function S:Init(ctx) self.ctx = ctx; self:Reset() end
function S:Reset() self.Queue, self.Index, self.BossDefeated, self.Spawned = {}, 1, false, 0 end
function S:Start(night, players)
    self:Reset()
    self.Night = night
    self.HealthScale = players <= 1 and W.SoloHealth or 1
    self.Queue = Rules.buildQueue(W.Waves[night], players, W.PerExtraPlayer)
    self.Interval = math.min(W.SpawnInterval, self.ctx.Clock:Remaining() / (#self.Queue + 1))
    self.NextSpawn = os.clock()
end
function S:Tick()
    if C.ActiveStage < 4 or self.ctx.Clock.Phase ~= "Night" then return end
    if os.clock() < (self.NextSpawn or math.huge) then return end
    local entry = self.Queue[self.Index]
    if not entry or self.ctx.Enemies:Count() >= C.EnemyLimit then return end
    local lane = ((self.Index + self.Night - 2) % #self.ctx.Map.Lanes) + 1
    if self.ctx.Enemies:Spawn(entry.Kind, lane, self.Night, entry.Boss) then
        self.Index, self.Spawned = self.Index + 1, self.Spawned + 1
        self.NextSpawn = os.clock() + self.Interval
    end
end
return S
