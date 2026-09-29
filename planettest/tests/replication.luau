-- 실제 ClientMain/모듈을 실행하되 복제 도착 순서를 일부러 뒤섞습니다.
local API=source("mock/api.lua")()
local D=source("mock/mock/datatypes.luau")()
local R=source("mock/mock/roblox.luau")(API,D)
local E=source("mock/mock/env.luau")(R,D,API)
local game=E.build()
local RS=game:GetService("ReplicatedStorage")
local player=R.newInstance("Player"); player.Parent=E.players
rawget(E.players,"_props").LocalPlayer=player
local ps=R.newInstance("PlayerScripts"); ps.Name="PlayerScripts"; ps.Parent=player
local gui=R.newInstance("PlayerGui"); gui.Name="PlayerGui"; gui.Parent=player
local main=E.Instance.new("LocalScript",ps); main.Name="ClientMain"
local globals={game=game,workspace=E.workspace,Instance=E.Instance,Enum=R.Enum,task=R.task,
    Vector3=D.Vector3,Vector2=D.Vector2,CFrame=D.CFrame,Color3=D.Color3,UDim2=D.UDim2,
    RaycastParams=D.RaycastParams,typeof=R.typeof}
setmetatable(globals,{__index=getfenv()})
local cache={}
local function req(inst)
    if cache[inst] then return cache[inst] end
    local fn=assert(loadstring(rawget(inst,"_source"),inst.Name))
    setfenv(fn,setmetatable({script=inst,require=req},{__index=globals}))
    local value=fn(); cache[inst]=value; return value
end
local function add(parent,name,filename)
    local inst=E.Instance.new(if filename then "ModuleScript" else "Folder")
    inst.Name=name
    if filename then rawset(inst,"_source",FILES[filename]) end
    inst.Parent=parent
    return inst
end
local fn=source("client/ClientMain.client.lua")
setfenv(fn,setmetatable({script=main,require=req},{__index=globals}))
local finished=false
R.task.spawn(function() fn(); finished=true end)
local function step(t) R.runUntil(t); assert(#R.Errors==0,table.concat(R.Errors,"\n")) end
step(0.2); assert(not finished)
local modules=add(ps,"Modules")
step(0.4); assert(not finished)
add(modules,"GravityController","client/Modules/GravityController.lua")
step(0.6); assert(not finished)
local shared=add(RS,"Shared")
step(0.8); assert(not finished)
add(shared,"PlanetMath","shared/PlanetMath.lua") -- Config보다 먼저 도착
step(1); assert(not finished)
add(shared,"Config","shared/Config.lua")
step(1.2); assert(not finished)
add(modules,"PlanetCamera","client/Modules/PlanetCamera.lua")
step(1.4); assert(not finished)
add(modules,"AvatarAnimation","client/Modules/AvatarAnimation.lua")
step(2); assert(finished)
assert(gui:FindFirstChild("PlanetDayNight"))
print("PASS: delayed/reordered PlayerScripts and ReplicatedStorage startup; actual ClientMain reaches UI and character hooks")
