local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local SoundService=game:GetService("SoundService")
local Debris=game:GetService("Debris")
local C=require(RS.Shared.Config.AudioConfig)
local S={}
function S:Play(key)
    if Players.LocalPlayer:GetAttribute("MutePets") then return end
    local id=C[key];if type(id)~="string" or id=="" then return end
    local sound=Instance.new("Sound");sound.SoundId=id;sound.Volume=C.Volume;sound.Parent=SoundService
    sound:Play();Debris:AddItem(sound,10)
end
function S:Init(remotes)
    remotes.PetFX.OnClientEvent:Connect(function(kind) self:Play(kind) end)
    remotes.State.OnClientEvent:Connect(function(data)
        if data.Phase=="Night" and self.LastPhase~="Night" then self:Play("Night") end
        self.LastPhase=data.Phase
    end)
end
return S
