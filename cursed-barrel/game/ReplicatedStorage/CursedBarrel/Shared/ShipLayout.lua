-- Shared, deterministic layout: playable ship, not a square dock with a ship beside it.
local L = {}
L.DeckY = 1
L.HalfBeam = 57
L.Stern = -158
L.Bow = 145
L.CabinFront = -103
L.CabinBack = -155
L.Tables = {
 Table_A={-27,50}, Table_B={27,50},
 Table_C={-27,12}, Table_D={27,12},
 Table_E={-27,-26}, Table_F={27,-26},
 Table_G={-27,-64}, Table_H={27,-64},
 Table_I={-23,85}, Table_J={23,85},
}
L.Masts = {35,-42}
L.LanternFrames = {70,16,-38,-90}
L.CannonZ = {61,6,-49,-85}
L.Showcase = { Z=-143, SignZ=-151, Columns=3, RowSpacing=10, Centers={Ghost=-34,Barrel=0,Knife=34} }
-- Phase 16 : 스폰 바로 앞 "명예의 문" (나무판자 랭킹판 셋) · 좋아요 보상 드럼 받침대
--   뱃머리 높은 갑판(스폰, z 118)에서 계단(가운데 x ±6)으로 내려가는 입구에 선다. 판은 스폰 쪽(+Z)을 본다.
--   양옆 판은 계단 입구를 비켜 서고, 가운데 판은 계단 위에 높이 걸려 있어서 지나다닐 수 있다.
L.HallOfFame = {
 Z = 113.1, -- 판 앞면이 이 z 에 선다
 Base = 5.5, -- 뱃머리 갑판 윗면
 Boards = {
  { id = "streak", x = -12.2, bottom = 6.6, w = 10, h = 9.2 },
  { id = "coins", x = 0, bottom = 13.2, w = 13.6, h = 8.4 },
  { id = "wins", x = 12.2, bottom = 6.6, w = 10, h = 9.2 },
 },
}
L.LikeReward = { x = 13.4, z = 121.6 }
function L.halfWidth(z)
 if z>88 then return math.max(3,L.HalfBeam*(1-((z-88)/(L.Bow-88))^1.4)) end
 if z<-135 then return L.HalfBeam-(((-z)-135)/23)*7 end
 return L.HalfBeam
end
return L
