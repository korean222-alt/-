local C = require(script.Parent:WaitForChild("Config"))
local P = {}
P.Center = Vector3.new(C.CenterX,C.CenterY,C.CenterZ)
local Y, X, Z = Vector3.new(0,1,0),Vector3.new(1,0,0),Vector3.new(0,0,1)
function P.up(position)
    local delta = position-P.Center
    return if delta.Magnitude > 0.001 then delta.Unit else Y
end
function P.tangent(vector, up)
    local projected = vector-up*vector:Dot(up)
    if projected.Magnitude < 0.0001 then
        local axis = if math.abs(up:Dot(Z))<0.9 then Z else X
        projected = axis-up*axis:Dot(up)
    end
    return projected.Unit
end
-- 최단 회전: EgoMoose getRotationBetween 기반. 대척점에서도 유효한 축 사용.
function P.rotationBetween(a,b,axis)
    local dot = math.clamp(a:Dot(b),-1,1)
    if dot < -0.99999 then return CFrame.fromAxisAngle(P.tangent(axis,a),math.pi) end
    local cross = a:Cross(b)
    if cross.Magnitude<1e-8 then return CFrame.new() end
    return CFrame.fromAxisAngle(cross.Unit,math.atan2(cross.Magnitude,dot))
end
function P.transport(forward,oldUp,newUp)
    return P.tangent(P.rotationBetween(oldUp,newUp,forward)*forward,newUp)
end
function P.frame(up,height,forward)
    up = up.Unit
    local f = P.tangent(forward or Z,up)
    return CFrame.fromMatrix(P.Center+up*(C.Radius+(height or 0)),f:Cross(up),up,-f)
end
function P.arc(start,tangent,angle)
    local t = P.tangent(tangent,start)
    return (start*math.cos(angle)+t*math.sin(angle)).Unit,
        (-start*math.sin(angle)+t*math.cos(angle)).Unit
end
function P.monster(t)
    local far = math.pi*C.Radius*C.MonsterFarFraction
    local span = far-C.MonsterNear
    local distance = (t*C.MonsterSpeed)%(2*span)
    local inbound = distance<span
    local radius = if inbound then far-distance else C.MonsterNear+distance-span
    local up,tangent = P.arc(Y,Z,radius/C.Radius)
    return P.frame(up,0,if inbound then -tangent else tangent)
end
function P.gravityForce(position,mass,worldGravity)
    return mass*(Y*worldGravity-P.up(position)*C.Gravity)
end
assert(C.Radius>=40 and C.Radius<=900, "Radius는 40~900으로 설정하세요")
assert(C.Gravity>0 and C.WalkSpeed>0 and C.MonsterSpeed>0)
assert(C.MonsterFarFraction>0 and C.MonsterFarFraction<1)
assert(C.MonsterNear<math.pi*C.Radius*C.MonsterFarFraction)
return P
