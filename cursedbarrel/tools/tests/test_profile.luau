local task = require("@lune/task")
local H = require("./harness")
local RS = H.services.ReplicatedStorage
local SSS = H.services.ServerScriptService
local Profiles = H.load(SSS.CursedBarrel.Services.ProfileService)
local Purchase = H.load(SSS.CursedBarrel.Services.PurchaseService)
Profiles:Start()
Purchase:Start()
local function check(name, cond)
	print((cond and "PASS " or "FAIL ") .. name)
	if not cond then
		H.failed = true
	end
end
local function key(p)
	return "u_" .. tostring(p.UserId)
end

-- 1) 로딩
local a = H.newPlayer("Alice")
check("load", H.waitFor(function() return Profiles:Get(a) ~= nil end, 5))

-- 2) 영수증 : 후속 처리는 한 번만 · 첫 구매 지급량 전달
local afterRuns, lastDetail = 0, nil
Purchase:Register(777, function(profile)
	profile.coins += 1000
	return true, { coins = 1000 }
end, function(_, _, detail)
	afterRuns += 1
	lastDetail = detail
end)
local receipt = { PlayerId = a.UserId, ProductId = 777, PurchaseId = "R1" }
local d1 = H.marketplace.ProcessReceipt(receipt)
local d2 = H.marketplace.ProcessReceipt(receipt)
task.wait(0.2)
check("receipt granted once", Profiles:Get(a).coins == 3000 + 1000)
check("after callback ran exactly once (" .. afterRuns .. ")", afterRuns == 1)
check("after got grant detail", lastDetail and lastDetail.coins == 1000)
check("both decisions granted", tostring(d1) == tostring(d2) and tostring(d1):find("PurchaseGranted") ~= nil)

-- 3) 저장 실패 후 영수증 재전송 : 지급은 한 번, 후속 처리는 저장이 성공한 그때 한 번
H.store.failAll = true
local receipt2 = { PlayerId = a.UserId, ProductId = 777, PurchaseId = "R2" }
task.spawn(function()
	task.wait(3)
	H.store.failAll = false
end)
local r2a = H.marketplace.ProcessReceipt(receipt2) -- 첫 시도 : 저장 실패(재시도 중 복구될 수도)
local r2b = H.marketplace.ProcessReceipt(receipt2)
task.wait(0.2)
check("R2 coins granted once", Profiles:Get(a).coins == 5000)
check("R2 after ran once (" .. afterRuns .. ")", afterRuns == 2)

-- 4) 퇴장 저장 실패 → 자료 보존 → 재시도로 저장
Profiles:Award(a, 250)
local coinsBefore = Profiles:Get(a).coins
H.store.failAll = true
H.leave(a)
check("release failed and kept pending", H.waitFor(function() return Profiles._pendingRelease[a.UserId] == a end, 25))
check("profile kept in memory", Profiles:Get(a) ~= nil and Profiles:Get(a).coins == coinsBefore)
H.store.failAll = false
check("retry saved and forgot", H.waitFor(function() return Profiles:Get(a) == nil end, 20))
local saved = H.store.data[key(a)]
check("store has latest coins (" .. tostring(saved and saved.coins) .. ")", saved and saved.coins == coinsBefore)
check("store session released", saved and saved.session == nil)

-- 5) 재접속 이어받기 : 저장 실패로 밀린 자료를 같은 서버에서 다시 들어온 사람이 이어받는다
local b = H.newPlayer("Bob")
H.waitFor(function() return Profiles:Get(b) ~= nil end, 5)
Profiles:Award(b, 777)
local bobCoins = Profiles:Get(b).coins
H.store.failAll = true
H.leave(b)
H.waitFor(function() return Profiles._pendingRelease[b.UserId] == b end, 25)
H.store.failAll = false
local b2 = H.fakeInstance("Player", "Bob")
b2.UserId = b.UserId
b2.DisplayName = "Bob"
b2.LocaleId = "en-us"
b2.Kick = function(self, msg) rawget(self, "_props").kicked = msg end
b2.Parent = H.Players
H.Players.PlayerAdded:Fire(b2)
check("rejoin loaded", H.waitFor(function() return Profiles:Get(b2) ~= nil end, 10))
check("rejoin took over pending coins (" .. tostring(Profiles:Get(b2) and Profiles:Get(b2).coins) .. ")", Profiles:Get(b2) and Profiles:Get(b2).coins == bobCoins)
check("old player object forgotten", Profiles:Get(b) == nil and Profiles._pendingRelease[b.UserId] == nil)
task.wait(6)
check("old retry loop did not release new session", H.store.data[key(b2)].session ~= nil)

-- 6) 종료 : 저장소가 계속 실패해도 BindToClose 가 30초 안에 끝난다
local c = H.newPlayer("Cara")
H.waitFor(function() return Profiles:Get(c) ~= nil end, 5)
H.store.failAll = true
local t0 = os.clock()
for _, fn in ipairs(H.closeHandlers) do
	fn()
end
local took = os.clock() - t0
check(("shutdown within budget (%.1fs)"):format(took), took < 29.5)
print(H.failed and "SOME TESTS FAILED" or "ALL PASSED")
require("@lune/process").exit(H.failed and 1 or 0)
