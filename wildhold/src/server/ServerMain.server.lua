-- 서버 시작. Place 하나가 세 가지로 동작한다 (workspace 속성 ServerMode):
--  Lobby      : 공개 서버. 로비 캠프만 만든다. 원정 수레(방)에서 출발하면 예약 서버로 텔레포트
--  Expedition : 예약 서버 (로비가 만든 방). 원정 맵만 만들고 도착한 대원으로 바로 출발, 끝나면 로비로 텔레포트
--  Both       : Studio. 텔레포트가 안 되므로 로비와 원정 맵을 한 서버에 만들고 그 사이를 옮겨 다닌다
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Engine=game:GetService("RunService")
local TeleportService=game:GetService("TeleportService")
local C=require(RS.Shared.Config.GameConfig)
local LC=require(RS.Shared.Config.LobbyConfig)
local U=require(RS.Shared.Modules.Utility)
assert(C.ActiveStage>=1 and C.ActiveStage<=8,"ActiveStage must be 1..8")

local mode
if (game.PrivateServerId or "")~="" and (game.PrivateServerOwnerId or 0)==0 then mode="Expedition"
elseif Engine:IsStudio() then mode=C.StudioMode or "Both"
else mode="Lobby" end
workspace:SetAttribute("ServerMode",mode)
local hasMap,hasLobby=mode~="Lobby",mode~="Expedition"

local folder=Instance.new("Folder");folder.Name,folder.Parent="Remotes",RS
local remotes={}
for _,name in ipairs({"State","AttackRequest","Notice","FX","PetAction","CraftAction","CaptureAction","PetFX","Lobby","LobbyAction","BuildRequest"}) do
    local event=Instance.new("RemoteEvent");event.Name,event.Parent=name,folder;remotes[name]=event
end
local ctx={State=remotes.State,Attack=remotes.AttackRequest,FX=remotes.FX,PetFX=remotes.PetFX,LobbyEvent=remotes.Lobby,LobbyAction=remotes.LobbyAction,
    SessionId=game:GetService("HttpService"):GenerateGUID(false),Mode=mode}
ctx.Notify=function(player,message) if player then remotes.Notice:FireClient(player,message) else remotes.Notice:FireAllClients(message) end end
local names={Map="MapService",Clock="DayNightService",Core="CoreService",Resources="ResourceService",Defenses="DefenseService",
    Enemies="EnemyService",Waves="WaveService",Run="RunService",Combat="CombatService",Data="DataService",Pets="PetService",
    Crafting="CraftingService",Capture="CaptureService",Tutorial="TutorialService",Survival="SurvivalService",Eggs="EggService",Lobby="LobbyService"}
for key,name in pairs(names) do ctx[key]=require(script.Parent.Services[name]) end
-- Studio 에서 가져온 펫 모델(FBX)을 작업 공간에 그대로 두었으면 PetModels 로 옮긴다 (같은 이름이 있으면 새로 가져온 쪽으로 교체)
local petModels=RS:FindFirstChild("PetModels") or Instance.new("Folder");petModels.Name,petModels.Parent="PetModels",RS
for _,id in ipairs(require(RS.Shared.Config.PetConfig).Order) do
    local model=workspace:FindFirstChild(id)
    if model and model:IsA("Model") and model:FindFirstChildWhichIsA("Bone",true) then
        local old=petModels:FindFirstChild(id);if old then old:Destroy() end
        model.Parent=petModels
    end
end

-- ===================================================================== 만들기
if hasMap then ctx.Map:Build() else ctx.Map:BuildShell() end
ctx.Data:Init(ctx);ctx.Eggs:Init(ctx)
local EXPEDITION={"Run","Core","Resources","Enemies","Waves","Defenses","Pets","Crafting","Capture","Tutorial","Survival","Combat"}
if hasMap then
    for _,name in ipairs(EXPEDITION) do ctx[name]:Init(ctx) end
    ctx.Clock:Begin("Waiting",0,0)
    remotes.PetAction.OnServerEvent:Connect(function(player,action,value) ctx.Pets:Action(player,action,value) end)
    remotes.CraftAction.OnServerEvent:Connect(function(player,item) ctx.Crafting:Craft(player,item) end)
    remotes.CaptureAction.OnServerEvent:Connect(function(player,uid,trap,bait) ctx.Capture:Attempt(player,uid,trap,bait) end)
    ctx.Map.CagePrompt.Triggered:Connect(function(player) ctx.Pets:Action(player,"Register") end)
    ctx.Map.CookPrompt.Triggered:Connect(function(player)
        if C.ActiveStage>=6 and ctx.Data:Ready(player) and U.near(player,ctx.Map.Campfire.Position,C.InteractionRange) then ctx.PetFX:FireClient(player,"OpenCraft","Campfire") end
    end)
    remotes.BuildRequest.OnServerEvent:Connect(function(player,kit,frame) ctx.Defenses:Request(player,kit,frame) end)
end
if hasLobby then
    local origin=mode=="Both" and Vector3.new(table.unpack(LC.StudioOrigin)) or Vector3.zero
    ctx.Lobby:Init(ctx,origin)
end
Players.RespawnTime=C.RespawnSeconds

-- ===================================================================== 원정 들어가기 / 나오기
-- 원정 대원이 된다: 기본 소지품·펫과 함께 원정 맵 스폰으로
function ctx.EnterExpedition(player)
    if not player.Parent or ctx.Run:IsParticipant(player) or not ctx.Run:Join(player) then return false end
    ctx.Resources:AddPlayer(player);ctx.Crafting:AddPlayer(player);ctx.Survival:AddPlayer(player);ctx.Pets:AddPlayer(player)
    player:SetAttribute("Place","Expedition")
    player.RespawnLocation=ctx.Map.Spawn
    if player.Character then task.spawn(function() ctx.Combat:Equip(player,player.Character) end) end
    return true
end
local function leaveExpedition(player)
    if not ctx.Run:IsParticipant(player) then return end
    ctx.Pets:RemovePlayer(player);ctx.Capture:RemovePlayer(player)
    ctx.Crafting:RemovePlayer(player);ctx.Survival:RemovePlayer(player);ctx.Resources:RemovePlayer(player)
    ctx.Combat.LastAttack[player],ctx.Defenses.LastAction[player]=nil,nil
    ctx.Run:Leave(player)
end
-- 결과 화면이 끝나면 로비로: Studio 는 같은 서버의 로비 캠프로, 실제 서버는 공개 서버(로비)로 텔레포트
function ctx.ReturnToLobby()
    local list={};for player in pairs(ctx.Run.Participants) do if player.Parent then table.insert(list,player) end end
    if mode=="Both" then
        for _,player in ipairs(list) do leaveExpedition(player);ctx.Lobby:Add(player) end
    elseif #list>0 then
        task.spawn(function()
            for _,player in ipairs(list) do ctx.Data:Save(player,true) end
            local deadline=os.clock()+8
            repeat
                local busy=false;for _,player in ipairs(list) do if ctx.Data.Sessions[player] then busy=true end end
                if busy then task.wait(0.2) end
            until not busy or os.clock()>deadline
            local ok=pcall(function() TeleportService:TeleportAsync(game.PlaceId,list) end)
            if not ok then for _,player in ipairs(list) do if player.Parent then player:Kick("로비로 돌아가지 못했습니다. 다시 접속해 주세요.") end end end
        end)
    end
end

-- ===================================================================== 플레이어
local loading={}
local function playerAdded(player)
    if loading[player] then return end;loading[player]=true
    if not ctx.Data:Load(player) or not player.Parent then loading[player]=nil;return end
    if mode=="Expedition" then
        if not ctx.EnterExpedition(player) then ctx.Data:Save(player,true);loading[player]=nil;return end
    else
        ctx.Lobby:Add(player)
    end
    player.CharacterAdded:Connect(function(character)
        if hasMap and ctx.Run:IsParticipant(player) then ctx.Combat:Equip(player,character)
        elseif hasLobby and ctx.Lobby.Players[player] then ctx.Lobby:OnSpawn(player,character) end
    end)
end
Players.PlayerAdded:Connect(playerAdded)
Players.PlayerRemoving:Connect(function(player)
    ctx.Data:Save(player,true);ctx.Eggs:RemovePlayer(player)
    if hasLobby then ctx.Lobby:Remove(player) end
    if hasMap then leaveExpedition(player) end
    loading[player]=nil
end)
for _,player in ipairs(Players:GetPlayers()) do task.spawn(playerAdded,player) end
game:BindToClose(function() ctx.Data:Close() end)

-- ===================================================================== 매 틱
local elapsed,broadcast=0,0
Engine.Heartbeat:Connect(function(dt)
    elapsed,broadcast=elapsed+dt,broadcast+dt
    if elapsed>=C.TickSeconds then
        local step=math.min(elapsed,C.TickSeconds*2);elapsed=0
        ctx.Data:Tick()
        if hasMap then
            ctx.Run:Tick();ctx.Resources:Tick();ctx.Waves:Tick()
            ctx.Pets:Tick(step);ctx.Capture:Tick(step);ctx.Defenses:Tick();ctx.Enemies:Tick(step)
            ctx.Crafting:Tick();ctx.Survival:Tick(step)
            for player in pairs(ctx.Run.Participants) do ctx.Map:Contain(player) end
        end
        if hasLobby then ctx.Lobby:Tick(step) end
    end
    if hasMap and broadcast>=C.StateInterval then
        broadcast=0
        local clock=ctx.Clock
        for player in pairs(ctx.Run.Participants) do
            local session=ctx.Data.Sessions[player]
            if session and player.Parent then
                local goalAt,goalName
                if C.ActiveStage>=8 then goalAt,goalName=ctx.Tutorial:Target(player) end
                remotes.State:FireClient(player,{
                    Phase=clock.Phase,Night=clock.Night,Target=C.TargetNights,EndsAt=clock.Phase=="Waiting" and (ctx.Run.StartAt or 0) or clock.EndsAt,
                    CoreHP=ctx.Core.HP,CoreMaxHP=C.CoreHP,Bag=ctx.Resources.Bags[player],Bank=ctx.Resources.Bank,
                    Enemies=ctx.Enemies:Count(),Spawned=ctx.Waves.Spawned,Total=#ctx.Waves.Queue,
                    Result=ctx.Run.Result,Stage=C.ActiveStage,Players=ctx.Run:Count(),TimeScale=clock:Scale(),
                    Pets=ctx.Pets:Snapshot(player),Wild=ctx.Capture:Snapshot(player),Items=ctx.Crafting.Items[player],
                    Hunger=ctx.Survival:Get(player),Capacity=ctx.Crafting:Capacity(player),Bench=ctx.Crafting.BenchLevel,
                    Coins=session.Profile.Coins,Dex=session.Profile.Dex,Perks=session.Profile.Perks,SaveStatus=session.Status,Practice=ctx.Data.Memory,
                    Objective=C.ActiveStage>=8 and ctx.Tutorial:Objective(player) or nil,GoalAt=goalAt,GoalName=goalName,
                })
            end
        end
    end
end)
print("WILDHOLD ready · mode "..mode..(ctx.Data.Memory and " · practice data" or ""))
