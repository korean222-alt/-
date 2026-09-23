-- Optional: copy into ServerScriptService of a PRIVATE test place and press Play.
-- Does not grant purchases or mutate saved balances. Remove before publishing.
local Run=game:GetService("RunService")
if not Run:IsStudio() then return end
task.wait(5)
local RS=game:GetService("ReplicatedStorage")
local Tags=game:GetService("CollectionService")
local Config=require(RS.CursedBarrel.Shared.GameConfig)
local Tables=require(game.ServerScriptService.CursedBarrel.Services.TableService)
local assertions=0
local function check(value,message) assertions+=1;assert(value,"[StudioSmoke] "..message) end
check(workspace.StreamingEnabled,"StreamingEnabled")
check(workspace:GetAttribute("ShipLobbyReady"),"Playable ship was built before game registration")
check(#Tables:GetAllTables()==10,"Expected 10 registered tables")
for _,t in ipairs(Tables:GetAllTables()) do
 check(t:GetMinPlayers()>=2,"Release MinPlayers: "..t.tableId)
 check(#t:GetSeats()==t.config.SeatCount,"Seat count: "..t.tableId)
 check(t:GetSlotCount()==t.config.KnifeSlots,"Knife count: "..t.tableId)
 check(t.model.ModelStreamingMode==Enum.ModelStreamingMode.Atomic,"Atomic table")
 for _,slot in ipairs(t:GetSlots()) do
  for key in pairs(slot:GetAttributes()) do check(not key:lower():find("danger"),"Hidden danger leaked") end
 end
end
for _,name in ipairs({"VoyageRequest","VoyageState","SelectSlot","ShopRequest","ShopResult","CatchInput","CatchResult","PresentationCue","BraveRequest"}) do check(RS.CursedBarrel.Remotes:FindFirstChild(name)~=nil,"Missing remote "..name) end
-- Phase 11 : 잡을수록 빨라지고, MaxPerPlayer 번 뒤에는 분노한 해적이 나온다 (너무 크면 판이 길어진다)
check(Config.Catch.MaxPerPlayer>=2 and Config.Catch.MaxPerPlayer<=10,"Catch.MaxPerPlayer out of range")
check(Config.Catch.PersonalDecay<1,"Catches must get faster")
check(Config.Catch.MinLead>=0.8,"Stab motion must land before the pirate")
check(not Config.Bots.Enabled or require(game.ServerScriptService.CursedBarrel.Services.BotService)._started,"BotService started")
check(Config.Catch.Grace<=0.15,"Catch grace too generous")
for _,t in ipairs(Tables:GetAllTables()) do
 for _,attr in ipairs({"Pot","BraveOfferUserId","WinForfeit","PotCarry","Practice"}) do check(t.model:GetAttribute(attr)~=nil,"Missing table attribute "..attr) end
end
for _,obj in ipairs(workspace:GetDescendants()) do
 if obj.Name=="Plank" or obj.Name=="Gangplank" then check(obj.CanCollide,"Ship walkway must be collidable") end
 if obj.Name=="MainDeck" or obj.Name=="QuarterdeckStep" or obj.Name=="BowStep" then check(obj.CanCollide,"Playable deck/stair collision") end
 if obj.Name=="SupportedLantern" then check(obj:GetAttribute("StructurallySupported"),"Lantern support") end
end
-- Phase 12 : 항해 시계 · 크라켄 습격 · 대포 · 관전 예측 · 토너먼트
local Services=game.ServerScriptService.CursedBarrel.Services
for _,name in ipairs({"WorldCue","CannonRequest","CannonCue","PredictRequest"}) do check(RS.CursedBarrel.Remotes:FindFirstChild(name)~=nil,"Missing remote "..name) end
for _,name in ipairs({"WorldService","CannonService","PredictionService","TournamentService"}) do check(require(Services[name])._started,name.." started") end
check(not Config.World.Enabled or type(workspace:GetAttribute("WorldPhase"))=="string","WorldPhase attribute")
check(Config.worldCycleLength()>=300,"World cycle too short")
local cannons=0;for _ in pairs(require(Services.CannonService).cannons) do cannons+=1 end
check(not Config.Cannon.Enabled or cannons>=4,"Deck cannons registered")
local Stab=require(RS.CursedBarrel.Shared.StabMotion)
check(Config.Catch.MinLead>=(Stab.MaxDuration or 0),"Stab motion (incl. storm_strike) must land before the pirate")
check(Config.TableTypeByName.Table_J=="Tournament4","Tournament table assignment")
for _,t in ipairs(Tables:GetAllTables()) do check(t.model:GetAttribute("PredictOpen")~=nil,"Missing table attribute PredictOpen") end
print("[StudioSmoke] "..assertions.." engine assertions passed. This does not replace multiplayer/device QA.")
