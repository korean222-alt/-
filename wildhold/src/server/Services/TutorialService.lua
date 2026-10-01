-- 첫 판 안내: 목표 카드 문장 + 지금 가야 할 곳(목표 표시). v2 흐름 (처음 2분 안에 계속 뭔가 터지게):
--  ① 빛기둥 보물상자 열기 → ② 야생 모슬링 포획(잡으면 바로 등록) → ③ 나무 8개 → ④ 제작대 설치 → ⑤ 벽·포탑 설치 → ⑥ 첫 밤 버티기 → 탐험(유적 상자)
-- 단계를 넘을 때마다 "🎯 목표 달성!" + 작은 보상 (Rewards). 문장은 번역 메시지 (Locale "tut.*"), 각 플레이어 화면에서 그 사람 언어로
local RS=game:GetService("ReplicatedStorage")
local U=require(RS.Shared.Modules.Utility)
local G=require(RS.Shared.Config.GameConfig)
local L=require(RS.Shared.Modules.Locale)
local S={}
-- 단계를 마쳤을 때 받는 것: Res = 가방 자원, Items = 소지품
S.Rewards={
    [1]={Items={Snack=1}},                       -- 보물상자를 열었다 (상자 자체가 큰 보상이라 조금만)
    [2]={Items={Trap=2,Snack=1}},                -- 첫 포획
    [3]={Res={Fiber=4,Stone=4}},                 -- 나무 8개
    [4]={Res={Wood=12,Stone=6}},                 -- 제작대 설치 → 바로 벽 하나 만들 만큼
    [5]={Items={Torch=1,RoastMushroom=2}},       -- 첫 방어 시설
}
local WOOD_GOAL=8
function S:Init(ctx) self.ctx=ctx;self.Step={} end
function S:Reset() if self.ctx then self.Step={} end end
function S:NoBench() return self.ctx.Defenses and self.ctx.Defenses:BenchLevel()==0 end
function S:Defended()
    for _,slot in pairs(self.ctx.Defenses and self.ctx.Defenses.Slots or {}) do
        if slot.Kind=="Wall" or slot.Kind=="Gate" or slot.Kind=="ArrowTower" or slot.Kind=="SpikeTrap" then return true end
    end
    return false
end
-- 지금 몇 번째 단계인가 (1~7)
function S:StepOf(player,profile)
    local chests=self.ctx.Chests
    if chests and chests.List and #chests.List>0 and not chests:OpenedStarter(player) then return 1 end
    if not profile.Tutorial.Captured then return 2 end
    if self:NoBench() then
        local items=self.ctx.Crafting.Items[player] or {}
        local bag=self.ctx.Resources.Bags[player] or {}
        if (items.WorkbenchKit or 0)==0 and (bag.Wood or 0)<WOOD_GOAL then return 3 end
        return 4
    end
    if not self:Defended() then return 5 end
    if not profile.Tutorial.Survived then return 6 end
    return 7
end
local TEXT={"tut.chest","tut.capture","tut.wood","tut.bench","tut.walls","tut.survive","tut.explore"}
function S:Objective(player)
    local profile=self.ctx.Data:Get(player);if not profile then return L.M("tut.loading") end
    if self.ctx.Clock.Phase=="Night" then return L.M("tut.night") end
    local step=self:StepOf(player,profile)
    if step==3 then
        local bag=self.ctx.Resources.Bags[player] or {}
        return L.M("tut.wood",{n=bag.Wood or 0,goal=WOOD_GOAL})
    end
    return L.M(TEXT[step])
end
-- 단계가 넘어가는 순간 보상 (판마다 한 번씩, 중간에 합류하면 그때 단계부터)
function S:Tick()
    if not self.ctx or G.ActiveStage<8 then return end
    local phase=self.ctx.Clock.Phase
    if phase~="Day" and phase~="Night" then return end
    for player in pairs(self.ctx.Run.Participants) do
        local profile=self.ctx.Data:Get(player)
        if profile and player.Parent then
            local step=self:StepOf(player,profile)
            local last=self.Step[player]
            if last and step>last then
                for done=last,step-1 do self:Reward(player,done) end
            end
            if not last or step>last then self.Step[player]=step end
        end
    end
end
function S:Reward(player,step)
    local reward=S.Rewards[step];if not reward then return end
    local got={}
    local bag=self.ctx.Resources.Bags[player]
    for kind,n in pairs(reward.Res or {}) do
        if bag then bag[kind]=(bag[kind] or 0)+n;table.insert(got,{kind,n,true}) end
    end
    local items=self.ctx.Crafting.Items[player]
    for id,n in pairs(reward.Items or {}) do
        if items then items[id]=(items[id] or 0)+n;table.insert(got,{id,n}) end
    end
    table.sort(got,function(a,b) return a[1]<b[1] end)
    self.ctx.Crafting:Sync(player)
    self.ctx.FX:FireClient(player,"Goal",step,got)
end
-- 지금 가야 할 곳 (없으면 nil). 반환: 위치, 이름
function S:Target(player)
    local profile=self.ctx.Data:Get(player)
    local root=U.aliveRoot(player)
    if not profile or not root then return nil end
    local clock=self.ctx.Clock
    local home=self.ctx.Map.Core.Position
    local far=(root.Position-home).Magnitude>70
    if clock.Phase=="Night" then return far and home or nil,L.M("goal.base") end
    if clock.Phase~="Day" then return nil end
    if far and clock:Remaining()<=G.WarningSeconds/clock:Scale() then return home,L.M("goal.returnBase") end
    local step=self:StepOf(player,profile)
    if step==1 then
        local chest=self.ctx.Chests:Starter()
        return chest and chest.Pos,L.M("goal.chest")
    elseif step==2 then
        local best,distance=nil,math.huge
        for _,wild in pairs(self.ctx.Capture.Wild) do
            local d=(wild.Part.Position-root.Position).Magnitude
            if wild.SpeciesId=="Mossling" and wild.Stage==1 and d<distance then best,distance=wild,d end
        end
        return best and best.Part.Position,L.M("goal.wildMossling")
    elseif step==3 then
        -- 반짝이는 황금 나무가 가까이 있으면 그쪽으로 (수확 3배)
        local best,distance=nil,math.huge
        for _,node in ipairs(self.ctx.Map.Nodes) do
            local d=(node.Part.Position-root.Position).Magnitude*(node.Golden and 0.5 or 1)
            if node.Kind=="Wood" and node.HP>0 and d<distance then best,distance=node,d end
        end
        return best and best.Part.Position,L.M(best and best.Golden and "goal.goldTree" or "goal.tree")
    elseif step==4 then
        return home+Vector3.new(0,0,-26),L.M("goal.benchSpot")
    elseif step==5 then
        -- 가장 가까운 길목 (괴물 굴에서 기지로 오는 길, Core 에서 40 쯤)
        local best,distance=nil,math.huge
        for _,lane in ipairs(self.ctx.Map.Lanes) do
            local spot=lane.Dir*40
            local d=(spot-root.Position).Magnitude
            if d<distance then best,distance=spot,d end
        end
        return best,L.M("goal.wallSpot")
    elseif step==7 then
        local chest=self.ctx.Chests:NearestClosed(player,root.Position,420)
        return chest and chest.Pos,L.M("goal.ruin")
    end
    return nil
end
return S
