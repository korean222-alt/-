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
 -- 6인 테이블은 선미 2층 중앙. 세 번째 값은 TableTop 목표 높이.
 Table_H={0,-132,21},
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
-- Phase 17 : 그룹 가입 보상 드럼은 계단을 내려오자마자 오른쪽 앞 (주 갑판 y 1). 계단(x ±6)과 J 테이블(x 16.6~29.4, z ≤ 92) 사이
-- Phase 22 : 출시 기념 선물(코드 love)은 2층(후갑판) 맨 뒤 왼쪽 구석으로 옮겼다 — 찾아가는 재미 (후갑판 바닥 윗면 y 17.8)
-- Phase 32 : 게임 출시 기념 선물은 스폰에서 내려오는 계단 바로 아래 오른쪽 빈 곳으로 (들어오자마자 보인다)
--   계단(x ±6, 맨 아랫칸 z 101)과 J 테이블(x 16.6~29.4, z ≤ 92) 사이. 받침대 지름 6.6 → x 7.7~14.3, z 92.7~99.3
L.LikeReward = { x = 11, z = 96, y = 1 }
-- Phase 32 : 상점(선미 선실 = 스킨 전시장) 입구 양옆의 순위판 둘. 선실 앞벽 z -103, 입구 x -13 ~ 13
--   오른쪽 = 토너먼트 챔피언판, 왼쪽 = 최고 라운드판. 앞면은 갑판 쪽(face)을 살짝 안쪽으로 비스듬히 본다.
--   예전 자리 : 토너먼트판은 F 테이블 옆, 최고 라운드판은 E 테이블 옆 (갑판 가운데라 잘 안 보였다)
L.ShopBoards = {
 Tournament = { x = 20, z = -94, face = { x = 7, z = -60 } },
 Round = { x = -20, z = -94, face = { x = -7, z = -60 } },
}
function L.halfWidth(z)
 if z>88 then return math.max(3,L.HalfBeam*(1-((z-88)/(L.Bow-88))^1.4)) end
 if z<-135 then return L.HalfBeam-(((-z)-135)/23)*7 end
 return L.HalfBeam
end
return L
