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
-- Phase 13 : 출석판 · 룰렛 · 영어
for _,name in ipairs({"RewardRequest","RewardCue"}) do check(RS.CursedBarrel.Remotes:FindFirstChild(name)~=nil,"Missing remote "..name) end
check(require(Services.RewardService)._started,"RewardService started")
check(require(RS.CursedBarrel.Shared.Locale).translate("상점")=="Shop","English dictionary loads")
-- Phase 14 : AI 선원이 실제 엔진에서 앉는다 · 밤 등불은 항상 스트리밍 · 대포 포신 모델
local Bots=require(Services.BotService)
for _,t in ipairs(Tables:GetAllTables()) do
 if not t.config.NoBots and t.state=="Waiting" and t:GetHumanCount()==0 and #t:GetFreeSeats()>0 then
  local bot=Bots:_spawn(t)
  check(bot~=nil and t:HasPlayer(bot),"AI crew sits down")
  check(bot.Character.PrimaryPart.Anchored,"AI body is pinned to the chair")
  Bots:_despawn(bot)
  break
 end
end
local lights=workspace.Lobby.PlayableGalleon:FindFirstChild("ShipLights")
check(lights~=nil and #lights:GetChildren()>=30,"Night lanterns")
for _,lamp in ipairs(lights:GetChildren()) do check(lamp.ModelStreamingMode==Enum.ModelStreamingMode.Persistent,"Lanterns are always streamed") end
for _,c in pairs(require(Services.CannonService).cannons) do check(c.tube.Parent.Name=="Barrel","Cannon barrel model") end
-- Phase 15 : 바다에서 건지기 · 등불 자리 · 최후의 1인 · 라운드 · 블렌더 모델
check(require(Services.RescueService)._started,"RescueService started")
check(workspace.FallenPartsDestroyHeight>=Config.Rescue.FallenPartsDestroyHeight-1,"Fallen parts are removed soon")
local spots=RS.CursedBarrel:FindFirstChild("LanternSpots")
check(spots~=nil and #spots:GetChildren()>=30,"Lantern spots replicate for the client lights")
for _,lamp in ipairs(lights:GetChildren()) do check(lamp:FindFirstChildWhichIsA("PointLight",true)==nil,"Lantern light is made on the client") end
for _,t in ipairs(Tables:GetAllTables()) do
 check(t.model:GetAttribute("Stage")~=nil and t.model:GetAttribute("StageCount")~=nil,"Missing table attribute Stage")
 check((t.config.WinnerTakesAll==true)==(t.typeName~="Duo2"),"Winner-takes-all on multi-seat tables only")
end
local MeshKit=require(RS.CursedBarrel.Shared.MeshKit)
if MeshKit.library() then
 for asset in pairs(MeshKit.Catalog.Assets) do check(MeshKit.has(asset),"Imported Blender model has "..asset) end
else
 print("[StudioSmoke] Blender models not imported yet (assets/models/CursedBarrelModels.fbx) - part-built shapes are used")
end
-- Phase 16 : 명예의 문 랭킹판 셋 · 좋아요 보상 받침대 · 코드
local faces={}
for _,face in ipairs(game:GetService("CollectionService"):GetTagged(Config.Tags.RankingBoard)) do
 if face:IsDescendantOf(workspace) then faces[face:GetAttribute("Board") or "?"]=face end
end
for _,id in ipairs({"streak","coins","wins"}) do check(faces[id]~=nil and faces[id]:FindFirstChild("RankingGui")~=nil,"Hall of fame board "..id) end
check(#game:GetService("CollectionService"):GetTagged(Config.Tags.LikeReward)==1,"Like reward pedestal prompt")
check(require(Services.CodeService).Codes.gnsdl23091~=nil,"Developer test code exists")
check(not Config.isCoinSkin(Config.findSkin("Barrel","blue_drum")),"Blue drum is the like reward")
print("[StudioSmoke] "..assertions.." engine assertions passed. This does not replace multiplayer/device QA.")
