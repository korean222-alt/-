local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Engine=game:GetService("RunService")
local C=require(RS.Shared.Config.GameConfig)
local U=require(RS.Shared.Modules.Utility)
assert(C.ActiveStage>=1 and C.ActiveStage<=8,"ActiveStage must be 1..8")
local folder=Instance.new("Folder");folder.Name,folder.Parent="Remotes",RS
local remotes={}
for _,name in ipairs({"State","AttackRequest","Notice","FX","PetAction","CraftAction","CaptureAction","PetFX"}) do
    local event=Instance.new("RemoteEvent");event.Name,event.Parent=name,folder;remotes[name]=event
end
local ctx={State=remotes.State,Attack=remotes.AttackRequest,FX=remotes.FX,PetFX=remotes.PetFX,SessionId=game:GetService("HttpService"):GenerateGUID(false)}
ctx.Notify=function(player,message) if player then remotes.Notice:FireClient(player,message) else remotes.Notice:FireAllClients(message) end end
local names={Map="MapService",Clock="DayNightService",Core="CoreService",Resources="ResourceService",Defenses="DefenseService",
    Enemies="EnemyService",Waves="WaveService",Run="RunService",Combat="CombatService",Data="DataService",Pets="PetService",
    Crafting="CraftingService",Capture="CaptureService",Tutorial="TutorialService"}
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
ctx.Map:Build()
for _,name in ipairs({"Run","Core","Resources","Enemies","Waves","Defenses","Data","Pets","Crafting","Capture","Tutorial","Combat"}) do ctx[name]:Init(ctx) end
ctx.Clock:Begin("Waiting",0,0)
remotes.PetAction.OnServerEvent:Connect(function(player,action,value) ctx.Pets:Action(player,action,value) end)
remotes.CraftAction.OnServerEvent:Connect(function(player,item) ctx.Crafting:Craft(player,item) end)
remotes.CaptureAction.OnServerEvent:Connect(function(player,uid,trap,bait) ctx.Capture:Attempt(player,uid,trap,bait) end)
ctx.Map.CagePrompt.Triggered:Connect(function(player) ctx.Pets:Action(player,"Register") end)
ctx.Map.CraftPrompt.Triggered:Connect(function(player)
    if C.ActiveStage>=6 and ctx.Data:Ready(player) and U.near(player,ctx.Map.Workbench.Position,C.InteractionRange) then ctx.PetFX:FireClient(player,"OpenCraft") end
end)
for _,slot in ipairs(ctx.Map.Slots) do
    if slot.Kind=="PetStand" then
        local prompt=U.prompt(slot.Pad,"PlacePet","펫 올려두기 (공격·사거리 강화)",Enum.KeyCode.E,Vector3.new(0,3,0))
        prompt.ObjectText="펫 배치대"
        prompt.Triggered:Connect(function(player)
            if C.ActiveStage>=5 then ctx.Pets:AssignStand(player,slot) end
        end)
    end
end
Players.RespawnTime=C.RespawnSeconds
local loading={}
local function playerAdded(player)
    if loading[player] then return end;loading[player]=true
    if not ctx.Data:Load(player) then loading[player]=nil;return end
    if not player.Parent or not ctx.Run:Join(player) then ctx.Data:Save(player,true);loading[player]=nil;return end
    ctx.Resources:AddPlayer(player);ctx.Crafting:AddPlayer(player);ctx.Pets:AddPlayer(player)
    player.RespawnLocation=ctx.Map.Spawn
    player.CharacterAdded:Connect(function(character) if ctx.Run:IsParticipant(player) then ctx.Combat:Equip(player,character) end end)
    if player.Character then task.spawn(function() ctx.Combat:Equip(player,player.Character) end) end
end
Players.PlayerAdded:Connect(playerAdded)
Players.PlayerRemoving:Connect(function(player)
    ctx.Data:Save(player,true);ctx.Pets:RemovePlayer(player);ctx.Capture:RemovePlayer(player)
    ctx.Crafting:RemovePlayer(player);ctx.Resources:RemovePlayer(player)
    ctx.Combat.LastAttack[player],ctx.Defenses.LastAction[player],loading[player]=nil,nil,nil
    ctx.Run:Leave(player)
end)
for _,player in ipairs(Players:GetPlayers()) do task.spawn(playerAdded,player) end
game:BindToClose(function() ctx.Data:Close() end)
local elapsed,broadcast=0,0
Engine.Heartbeat:Connect(function(dt)
    elapsed,broadcast=elapsed+dt,broadcast+dt
    if elapsed>=C.TickSeconds then
        local step=math.min(elapsed,C.TickSeconds*2);elapsed=0
        ctx.Data:Tick();ctx.Run:Tick();ctx.Resources:Tick();ctx.Waves:Tick()
        ctx.Pets:Tick(step);ctx.Capture:Tick(step);ctx.Defenses:Tick();ctx.Enemies:Tick(step)
    end
    if broadcast>=C.StateInterval then
        broadcast=0
        local clock=ctx.Clock
        for player in pairs(ctx.Run.Participants) do
            local session=ctx.Data.Sessions[player]
            if session and player.Parent then
                remotes.State:FireClient(player,{
                    Phase=clock.Phase,Night=clock.Night,Target=C.TargetNights,EndsAt=clock.Phase=="Waiting" and (ctx.Run.StartAt or 0) or clock.EndsAt,
                    CoreHP=ctx.Core.HP,CoreMaxHP=C.CoreHP,Bag=ctx.Resources.Bags[player],Bank=ctx.Resources.Bank,
                    Enemies=ctx.Enemies:Count(),Spawned=ctx.Waves.Spawned,Total=#ctx.Waves.Queue,
                    Result=ctx.Run.Result,Stage=C.ActiveStage,Players=ctx.Run:Count(),TimeScale=clock:Scale(),
                    Pets=ctx.Pets:Snapshot(player),Wild=ctx.Capture:Snapshot(player),Items=ctx.Crafting.Items[player],
                    Coins=session.Profile.Coins,Dex=session.Profile.Dex,SaveStatus=session.Status,Practice=ctx.Data.Memory,
                    Objective=C.ActiveStage>=8 and ctx.Tutorial:Objective(player) or nil,
                })
            end
        end
    end
end)
print("WILDHOLD stages 1–8 prototype ready. Studio uses practice data by default.")
