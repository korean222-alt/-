local C = require(script.Parent.Config)
local P = require(script.Parent.PlanetMath)
local L = {}
function L.props()
    local result = {}
    -- Fibonacci 구면 분포. 대원 보행 코스와 기지 주변은 비웁니다.
    for _, kind in ipairs({"Tree","Rock"}) do
        local count = if kind=="Tree" then C.TreeCount else C.RockCount
        for i=1,count do
            local y = 1-2*(i-0.5)/count
            local a = i*math.pi*(3-math.sqrt(5))+C.Seed*0.01
            local r = math.sqrt(1-y*y)
            local up = Vector3.new(math.cos(a)*r,y,math.sin(a)*r)
            if math.abs(up.X)*C.Radius>10 and y<0.99 then
                table.insert(result,{kind=kind,frame=P.frame(up,-C.Embed)})
            end
        end
    end
    return result
end
function L.flags()
    local result = {}
    local Y,Z = Vector3.new(0,1,0),Vector3.new(0,0,1)
    for _,distance in ipairs(C.FlagDistances) do
        local up,f = P.arc(Y,Z,distance/C.Radius)
        -- 코스 옆 5 stud에 두되 밑바닥은 정확히 구면으로 투영
        up = (up+Vector3.new(5/C.Radius,0,0)).Unit
        table.insert(result,{name=distance.." stud",frame=P.frame(up,-C.Embed,f)})
    end
    for i=1,C.RouteFlagCount do
        local up,f = P.arc(Y,Z,i*2*math.pi/C.RouteFlagCount)
        up = (up+Vector3.new(-5/C.Radius,0,0)).Unit
        table.insert(result,{name=math.floor(i*360/C.RouteFlagCount).."°",frame=P.frame(up,-C.Embed,f)})
    end
    return result
end
return L
