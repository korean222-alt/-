-- 기본 아바타/리그는 유지하고, 중력 조종기의 이동 상태로 기존 애니메이션을 재생합니다.
local Animation={}
Animation.__index=Animation
function Animation.new(character)
    local humanoid=character:WaitForChild("Humanoid")
    local animator=humanoid:WaitForChild("Animator")
    local animate=character:WaitForChild("Animate",5)
    if animate then animate.Enabled=false end
    for _,track in ipairs(animator:GetPlayingAnimationTracks()) do track:Stop(0.1) end
    local ids=if humanoid.RigType==Enum.HumanoidRigType.R15 then
        {idle=507766666,walk=507777826,jump=507765000,fall=507767968} else
        {idle=180435571,walk=180426354,jump=125750702,fall=180436148}
    local self=setmetatable({Tracks={},State=nil},Animation)
    for name,id in pairs(ids) do
        local folder=animate and animate:FindFirstChild(name)
        local original=folder and folder:FindFirstChildWhichIsA("Animation",true)
        local asset=Instance.new("Animation")
        asset.AnimationId=if original then original.AnimationId else "rbxassetid://"..id
        local ok,track=pcall(function() return animator:LoadAnimation(asset) end)
        asset:Destroy()
        if ok then
            track.Looped=name~="jump"
            track.Priority=Enum.AnimationPriority.Movement
            self.Tracks[name]=track
        else warn("PlanetTest animation",name,track) end
    end
    return self
end
function Animation:Update(grounded,speed,radialSpeed)
    local state=if grounded then (if speed>0.5 then "walk" else "idle") else (if radialSpeed>1 then "jump" else "fall")
    if state~=self.State then
        if self.Tracks[self.State] then self.Tracks[self.State]:Stop(0.15) end
        self.State=state
        if self.Tracks[state] then self.Tracks[state]:Play(0.15) end
    end
    if state=="walk" and self.Tracks.walk then self.Tracks.walk:AdjustSpeed(math.max(0.1,speed/14)) end
end
function Animation:Destroy()
    for _,track in pairs(self.Tracks) do track:Stop(); track:Destroy() end
end
return Animation
