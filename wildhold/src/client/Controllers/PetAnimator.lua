local RS=game:GetService("ReplicatedStorage")
local Engine=game:GetService("RunService")
local P=require(RS.Shared.Config.PetConfig)
local S={}
local function part(parent,name,size,color)
    local p=Instance.new("Part");p.Name,p.Size,p.Color=name,size,color
    p.Anchored,p.CanCollide,p.CanTouch,p.CanQuery=true,false,false,false
    p.Material=Enum.Material.SmoothPlastic;p.Parent=parent;return p
end
function S:Init()
    self.Visuals={}
    local root=workspace:WaitForChild("WILDHOLD")
    local function add(anchor)
        if not anchor:IsA("BasePart") or self.Visuals[anchor] then return end
        local species=anchor:GetAttribute("SpeciesId")
        if not species or not P.Species[species] then return end
        local spec=P.Species[species];local model=Instance.new("Model");model.Name="PetVisual";model.Parent=anchor
        local scale=species=="Briarhorn" and 1.55 or 1
        local body=part(model,"Body",Vector3.new(2.7,2.5,3)*scale,Color3.fromRGB(table.unpack(spec.Color)))
        body.Shape=Enum.PartType.Ball
        local pieces={{body,CFrame.new()}}
        for _,side in ipairs({-1,1}) do
            local eye=part(model,"Eye",Vector3.new(0.5,0.6,0.2)*scale,Color3.fromRGB(248,250,243))
            local pupil=part(model,"Pupil",Vector3.new(0.23,0.33,0.15)*scale,Color3.fromRGB(25,44,43))
            pieces[#pieces+1]={eye,CFrame.new(side*0.64*scale,0.3*scale,-1.28*scale)}
            pieces[#pieces+1]={pupil,CFrame.new(side*0.64*scale,0.3*scale,-1.4*scale)}
            local ear=part(model,"Ear",Vector3.new(0.65,1.1,0.7)*scale,body.Color)
            pieces[#pieces+1]={ear,CFrame.new(side*0.85*scale,1.3*scale,0)*CFrame.Angles(0,0,side*0.3)}
        end
        if species=="Shellbub" then
            local shell=part(model,"Shell",Vector3.new(2.6,1.3,2.5),Color3.fromRGB(75,132,152));shell.Shape=Enum.PartType.Ball
            pieces[#pieces+1]={shell,CFrame.new(0,0.7,0.65)}
        elseif species=="Briarhorn" then
            local horn=part(model,"Horn",Vector3.new(0.6,1.8,0.6),Color3.fromRGB(244,226,163));pieces[#pieces+1]={horn,CFrame.new(0,1.9,-0.7)}
        end
        self.Visuals[anchor]={Model=model,Pieces=pieces,Pose=anchor.CFrame,Phase=math.random()*6.28}
    end
    for _,name in ipairs({"Pets","WildPets"}) do
        local folder=root:WaitForChild(name)
        folder.ChildAdded:Connect(function(anchor)
            add(anchor)
            if not self.Visuals[anchor] then
                local connection;connection=anchor:GetAttributeChangedSignal("SpeciesId"):Connect(function() add(anchor);if self.Visuals[anchor] then connection:Disconnect() end end)
            end
        end)
        for _,anchor in ipairs(folder:GetChildren()) do add(anchor) end
    end
    Engine.RenderStepped:Connect(function(dt)
        for anchor,visual in pairs(self.Visuals) do
            if not anchor.Parent then visual.Model:Destroy();self.Visuals[anchor]=nil
            else
                visual.Pose=visual.Pose:Lerp(anchor.CFrame,1-math.exp(-16*dt))
                local t=workspace:GetServerTimeNow()
                local faint=anchor:GetAttribute("Fainted")
                local age=t-(anchor:GetAttribute("AttackAt") or -100)
                local bounce=math.sin(t*5+visual.Phase)*0.12
                local pose=visual.Pose*CFrame.new(0,bounce,-(age>=0 and age<0.2 and math.sin(age/0.2*math.pi)*0.7 or 0))
                if faint then pose=pose*CFrame.Angles(0,0,math.pi/2) end
                for _,piece in ipairs(visual.Pieces) do piece[1].CFrame=pose*piece[2];piece[1].Transparency=faint and 0.35 or 0 end
            end
        end
    end)
end
return S
