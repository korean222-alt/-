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
function L.halfWidth(z)
 if z>88 then return math.max(3,L.HalfBeam*(1-((z-88)/(L.Bow-88))^1.4)) end
 if z<-135 then return L.HalfBeam-(((-z)-135)/23)*7 end
 return L.HalfBeam
end
return L
