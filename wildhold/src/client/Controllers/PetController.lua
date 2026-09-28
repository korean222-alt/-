local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local P=require(RS.Shared.Config.PetConfig)
local Recipes=require(RS.Shared.Config.RecipeConfig)
local Controller={}
local colors={Back=Color3.fromRGB(18,32,32),Card=Color3.fromRGB(38,57,53),Text=Color3.fromRGB(237,245,233),Accent=Color3.fromRGB(151,218,174)}
local function create(kind,parent,props)
    local node=Instance.new(kind);for key,value in pairs(props) do node[key]=value end;node.Parent=parent;return node
end
local function label(parent,text,pos,size)
    return create("TextLabel",parent,{Text=text,Position=pos,Size=size,Font=Enum.Font.GothamMedium,TextSize=14,TextColor3=colors.Text,TextWrapped=true,BackgroundTransparency=1})
end
local function button(parent,text,pos,size,fn)
    local node=create("TextButton",parent,{Text=text,Position=pos,Size=size,TextSize=14,Font=Enum.Font.GothamBold,TextColor3=colors.Text,BackgroundColor3=colors.Card,BorderSizePixel=0,AutoButtonColor=true})
    create("UICorner",node,{CornerRadius=UDim.new(0,9)});node.Activated:Connect(fn);return node
end
function Controller:Init(remotes)
    self.Remotes,self.Tab,self.Filter,self.Rows=remotes,"Pets","",{}
    local player=Players.LocalPlayer
    self.Gui=create("ScreenGui",player:WaitForChild("PlayerGui"),{Name="PetBook",ResetOnSpawn=false,DisplayOrder=25})
    self.OpenButton=button(self.Gui,"펫 / 포획",UDim2.new(0.5,-70,1,-68),UDim2.fromOffset(140,50),function() self:Open("Pets") end)
    self.Panel=create("Frame",self.Gui,{Name="Panel",Visible=false,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromScale(0.96,0.92),BackgroundColor3=colors.Back,BorderSizePixel=0})
    create("UISizeConstraint",self.Panel,{MaxSize=Vector2.new(700,700)})
    create("UICorner",self.Panel,{CornerRadius=UDim.new(0,16)})
    self.Status=label(self.Panel,"내 펫",UDim2.fromOffset(12,6),UDim2.new(1,-78,0,48))
    button(self.Panel,"닫기",UDim2.new(1,-62,0,8),UDim2.fromOffset(54,44),function() self:Close() end)
    for index,tab in ipairs({{"Pets","내 펫"},{"Wild","야생"},{"Orders","명령"},{"Craft","제작"},{"Dex","도감"}}) do
        button(self.Panel,tab[2],UDim2.new((index-1)*0.2,4,0,60),UDim2.new(0.2,-8,0,44),function() self.Tab=tab[1];self:Render() end)
    end
    self.Search=create("TextBox",self.Panel,{PlaceholderText="이름 / 역할 / 속성 검색",Text="",ClearTextOnFocus=false,Position=UDim2.new(0,8,0,112),Size=UDim2.new(1,-100,0,44),BackgroundColor3=colors.Card,TextColor3=colors.Text,TextSize=14,Font=Enum.Font.GothamMedium})
    self.Search:GetPropertyChangedSignal("Text"):Connect(function() self.Filter=string.lower(self.Search.Text);self:Render() end)
    self.FavButton=button(self.Panel,"즐겨찾기",UDim2.new(1,-86,0,112),UDim2.fromOffset(78,44),function() self.Favorites=not self.Favorites;self:Render() end)
    self.Scroll=create("ScrollingFrame",self.Panel,{Position=UDim2.fromOffset(8,164),Size=UDim2.new(1,-16,1,-220),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=5,CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y})
    create("UIListLayout",self.Scroll,{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})
    self.Footer=label(self.Panel,"",UDim2.new(0,8,1,-50),UDim2.new(1,-16,0,44))
    remotes.State.OnClientEvent:Connect(function(data)
        self.Data=data;self.OpenButton.Visible=data.Stage>=5
        if not self.Capturing then
            local short={Practice="연습 모드",Saved="저장 완료",Unsaved="저장 대기",Saving="저장 중",Retrying="저장 재시도"}
            self.OpenButton.Text="펫 / 포획\n"..(short[data.SaveStatus] or "연결 중")
        end
        if self.Panel.Visible then self:Refresh() end
    end)
    remotes.PetFX.OnClientEvent:Connect(function(kind,name,seconds)
        if kind=="OpenCraft" then self:Open("Craft")
        elseif kind=="Shake" then
            self:Close();self.Capturing=true;self.OpenButton.Text="포획 중…"
            self:CaptureCard(name,seconds)
            task.delay((seconds or 2.4)+0.5,function() self.Capturing=false;self.OpenButton.Text="펫 / 포획" end)
        elseif kind=="Capture" then self:Open("Pets");self.Footer.Text="포획 성공! "..(name or "").." · 우리에 등록하세요" end
    end)
end
function Controller:CaptureCard(name,seconds)
    if self.CaptureOverlay then self.CaptureOverlay:Destroy() end
    local overlay=create("Frame",self.Gui,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.45),Size=UDim2.new(0.72,0,0,170),BackgroundColor3=colors.Back,BorderSizePixel=0})
    create("UISizeConstraint",overlay,{MaxSize=Vector2.new(360,170)})
    create("UICorner",overlay,{CornerRadius=UDim.new(0,18)})
    label(overlay,name or "야생 펫",UDim2.fromOffset(8,8),UDim2.new(1,-16,0,35))
    local icon=label(overlay,"◇",UDim2.new(0.5,-28,0,48),UDim2.fromOffset(56,56));icon.TextSize=46;icon.TextColor3=colors.Accent
    local progress=label(overlay,"포획 중 ·",UDim2.new(0,8,1,-50),UDim2.new(1,-16,0,40))
    self.CaptureOverlay=overlay
    task.spawn(function()
        local duration=seconds or 2.4
        for i=1,3 do
            if not overlay.Parent then return end
            progress.Text="포획 중 "..string.rep("●",i)..string.rep("○",3-i)
            local tween=game:GetService("TweenService"):Create(icon,TweenInfo.new(0.12,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,2,true),{Rotation=i%2==0 and -18 or 18})
            tween:Play();task.wait(duration/3)
        end
        if overlay.Parent then overlay:Destroy() end
    end)
end
function Controller:Open(tab)
    self.Tab=tab or self.Tab;self.Panel.Visible=true
    Players.LocalPlayer:SetAttribute("PetMenuOpen",true);self:Render()
end
function Controller:Close() self.Panel.Visible=false;Players.LocalPlayer:SetAttribute("PetMenuOpen",false) end
function Controller:Send(action,value) self.Remotes.PetAction:FireServer(action,value) end
function Controller:Row(height)
    return create("Frame",self.Scroll,{Size=UDim2.new(1,-5,0,height or 120),BackgroundColor3=colors.Card,BorderSizePixel=0,LayoutOrder=#self.Rows+1})
end
function Controller:Render()
    if not self.Scroll or not self.Data then return end
    for _,child in ipairs(self.Scroll:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    self.Rows={}
    local searching=self.Tab=="Pets"
    self.Search.Visible,self.FavButton.Visible=searching,searching
    self.Scroll.Position=UDim2.fromOffset(8,searching and 164 or 112)
    self.Scroll.Size=UDim2.new(1,-16,1,searching and -220 or -168)
    local d=self.Data
    if self.Tab=="Pets" then
        for _,pet in ipairs(d.Pets or {}) do
            local spec=P.Species[pet.SpeciesId]
            if (not self.Favorites or pet.Favorite) and string.find(string.lower(spec.Name..spec.Role..spec.Element),self.Filter,1,true) then
                local row=self:Row(146)
                local info=label(row,"",UDim2.fromOffset(8,4),UDim2.new(1,-16,0,86))
                local toggle=button(row,pet.Active and "편성 해제" or "편성",UDim2.new(0,6,1,-50),UDim2.new(0.36,-8,0,44),function() self:Send("Toggle",pet.Uid) end)
                button(row,pet.Favorite and "★ 해제" or "☆ 즐겨찾기",UDim2.new(0.36,2,1,-50),UDim2.new(0.34,-6,0,44),function() self:Send("Favorite",pet.Uid) end)
                button(row,"간식 회복",UDim2.new(0.70,2,1,-50),UDim2.new(0.30,-8,0,44),function() self:Send("Heal",pet.Uid) end)
                self.Rows[#self.Rows+1]={Key=pet.Uid,Info=info,Toggle=toggle}
            end
        end
    elseif self.Tab=="Wild" then
        for _,wild in ipairs(d.Wild or {}) do
            local spec=P.Species[wild.SpeciesId]
            local row=self:Row(146)
            local info=label(row,"",UDim2.fromOffset(6,3),UDim2.new(1,-12,0,88))
            button(row,"팀으로 약화",UDim2.new(0,6,1,-50),UDim2.new(0.34,-8,0,44),function() self:Send("Focus",wild.Id);self:Close() end)
            button(row,"일반 덫",UDim2.new(0.34,2,1,-50),UDim2.new(0.30,-6,0,44),function() self.Remotes.CaptureAction:FireServer(wild.Id,"Trap",false) end)
            button(row,"강화+먹이",UDim2.new(0.64,2,1,-50),UDim2.new(0.36,-8,0,44),function() self.Remotes.CaptureAction:FireServer(wild.Id,"BetterTrap",true) end)
            self.Rows[#self.Rows+1]={Key=wild.Id,Info=info}
        end
    elseif self.Tab=="Orders" then
        local actions={{"Follow","전원 따라와"},{"Stay","전원 대기"},{"Guard","현재 자리 방어"},{"Best","공격력 순 자동 편성"},{"Register","우리에서 일괄 등록"}}
        for _,a in ipairs(actions) do
            local row=self:Row(52);button(row,a[2],UDim2.fromOffset(4,4),UDim2.new(1,-8,0,44),function() self:Send(a[1]) end)
            self.Rows[#self.Rows+1]={}
        end
        for i=1,3 do
            local row=self:Row(52)
            button(row,"팀 "..i.." 저장",UDim2.fromOffset(4,4),UDim2.new(0.5,-8,0,44),function() self:Send("SaveTeam",i) end)
            button(row,"팀 "..i.." 불러오기",UDim2.new(0.5,4,0,4),UDim2.new(0.5,-8,0,44),function() self:Send("LoadTeam",i) end)
            self.Rows[#self.Rows+1]={}
        end
        local row=self:Row(52);button(row,"효과음 켜기 / 끄기",UDim2.fromOffset(4,4),UDim2.new(1,-8,0,44),function() Players.LocalPlayer:SetAttribute("MutePets",not Players.LocalPlayer:GetAttribute("MutePets")) end)
        self.Rows[#self.Rows+1]={}
    elseif self.Tab=="Craft" then
        for _,id in ipairs(Recipes.Order) do
            local spec=Recipes.Recipes[id];local cost={}
            for material,amount in pairs(spec.Cost) do cost[#cost+1]=material.." "..amount end
            local row=self:Row(104);local info=label(row,"",UDim2.fromOffset(6,2),UDim2.new(1,-12,0,48))
            button(row,"제작",UDim2.new(0,6,1,-50),UDim2.new(1,-12,0,44),function() self.Remotes.CraftAction:FireServer(id) end)
            self.Rows[#self.Rows+1]={Key=id,Info=info,Cost=table.concat(cost," + ")}
        end
    elseif self.Tab=="Dex" then
        for _,id in ipairs(P.Order) do
            local spec=P.Species[id];local row=self:Row(100)
            local entry=d.Dex[id];local state=entry and entry.Caught and "수집 완료" or (entry and entry.Seen and "발견 · 미확정" or "미수집")
            label(row,spec.Name.." · "..spec.Element.." · "..spec.Role.."\n"..state.."\n기본 HP "..spec.HP.." / 공격 "..spec.Damage,UDim2.fromOffset(6,4),UDim2.new(1,-12,1,-8))
            self.Rows[#self.Rows+1]={}
        end
    end
    if #self.Rows==0 then local row=self:Row(90);label(row,"표시할 펫이 없습니다.\n야생 펫은 가까이 이동하면 보입니다.",UDim2.fromOffset(4,4),UDim2.new(1,-8,1,-8)) end
    self.Structure=self:Signature();self:Refresh(true)
end
function Controller:Signature()
    local pieces={self.Tab}
    if self.Tab=="Pets" then
        for _,pet in ipairs(self.Data.Pets or {}) do pieces[#pieces+1]=pet.Uid..tostring(pet.Active)..tostring(pet.Favorite)..pet.Status end
    elseif self.Tab=="Wild" then
        local ids={};for _,wild in ipairs(self.Data.Wild or {}) do ids[#ids+1]=wild.Id end;table.sort(ids)
        for _,id in ipairs(ids) do pieces[#pieces+1]=id end
    elseif self.Tab=="Dex" then for _,id in ipairs(P.Order) do local e=self.Data.Dex[id];pieces[#pieces+1]=id..tostring(e and e.Caught)..tostring(e and e.Seen) end end
    return table.concat(pieces,"|")
end
function Controller:Refresh(skip)
    if not skip and self.Structure~=self:Signature() then self:Render();return end
    local d=self.Data;local equipped=0
    for _,pet in ipairs(d.Pets or {}) do if pet.Active then equipped=equipped+1 end end
    local status={Practice="연습 · 영구 저장 안 됨",Saved="저장 완료",Unsaved="저장 대기",Saving="저장 중",Retrying="저장 재시도",LockLost="연결 종료"}
    self.Status.Text=string.format("펫 %d/3 · 코인 %d\n%s",equipped,d.Coins or 0,status[d.SaveStatus] or "연결 중")
    for _,row in ipairs(self.Rows) do
        if row.Info and self.Tab=="Pets" then
            for _,pet in ipairs(d.Pets) do if pet.Uid==row.Key then
                local spec=P.Species[pet.SpeciesId]
                row.Info.Text=string.format("%s · %s / %s\nLv%d (초원 적용 %d) · HP %d/%d\n%s · %s",spec.Name,spec.Element,spec.Role,pet.Level,pet.EffectiveLevel,pet.HP,pet.MaxHP,pet.Status,pet.HP==0 and "쓰러짐" or pet.Mode)
            end end
        elseif row.Info and self.Tab=="Wild" then
            for _,wild in ipairs(d.Wild) do if wild.Id==row.Key then
                row.Info.Text=string.format("%s Lv%d · %dm · HP %d/%d\n%s\n일반 %.0f%% / 강화+먹이 %.0f%%",P.Species[wild.SpeciesId].Name,wild.Level,wild.Distance,wild.HP,wild.MaxHP,
                    wild.Busy and "포획 진행 중" or (not wild.CanClaim and (wild.Owner.."의 포획 우선권") or (wild.Ready and "포획 가능 · 16m 이내 접근" or "HP 25% 이하로 약화하세요")),wild.Ready and wild.Chance*100 or 0,wild.Ready and wild.BetterChance*100 or 0)
            end end
        elseif row.Info and self.Tab=="Craft" then row.Info.Text=Recipes.Recipes[row.Key].Name.." · 보유 "..tostring((d.Items or {})[row.Key] or 0).."\n"..row.Cost end
    end
    local items=d.Items or {}
    self.Footer.Text=string.format("덫 %d · 강화 %d · 먹이 %d · 간식 %d\n%s",items.Trap or 0,items.BetterTrap or 0,items.Bait or 0,items.Snack or 0,self.Tab=="Craft" and "낮 · 기지 제작대에서 제작" or "미확정 펫: 우리 등록 + 밤 생존 필요")
end
return Controller
