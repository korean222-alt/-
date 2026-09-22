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
-- Phase 10 : 한 판에 한 번만 잡는다 (0 이면 잡기 자체가 없고, 너무 크면 판이 끝나지 않는다)
check(Config.Catch.PerPlayer==1,"Catch.PerPlayer must be 1 for release")
check(Config.Catch.Grace<=0.15,"Catch grace too generous")
for _,t in ipairs(Tables:GetAllTables()) do
 for _,attr in ipairs({"Pot","BraveOfferUserId","WinForfeit"}) do check(t.model:GetAttribute(attr)~=nil,"Missing table attribute "..attr) end
end
for _,obj in ipairs(workspace:GetDescendants()) do
 if obj.Name=="Plank" or obj.Name=="Gangplank" then check(obj.CanCollide,"Ship walkway must be collidable") end
 if obj.Name=="MainDeck" or obj.Name=="QuarterdeckStep" or obj.Name=="BowStep" then check(obj.CanCollide,"Playable deck/stair collision") end
 if obj.Name=="SupportedLantern" then check(obj:GetAttribute("StructurallySupported"),"Lantern support") end
end
print("[StudioSmoke] "..assertions.." engine assertions passed. This does not replace multiplayer/device QA.")
