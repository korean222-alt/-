local Players = game:GetService("Players")
local Engine = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config.GameConfig)
local R = require(RS.Shared.Config.ResourceConfig)
local UI = {}
local ink, muted = Color3.fromRGB(238, 243, 238), Color3.fromRGB(174, 193, 184)
local function frame(parent, name, size, position, anchor)
    local p = Instance.new("Frame")
    p.Name, p.Size, p.Position, p.AnchorPoint = name, size, position, anchor or Vector2.new()
    p.BackgroundColor3, p.BackgroundTransparency, p.BorderSizePixel = Color3.fromRGB(21, 35, 34), 0.08, 0
    p.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius, corner.Parent = UDim.new(0, 12), p
    return p
end
local function text(parent, size, position, value, fontSize, color)
    local p = Instance.new("TextLabel")
    p.Size, p.Position, p.Text = size, position, value
    p.BackgroundTransparency, p.Font, p.TextSize = 1, Enum.Font.GothamMedium, fontSize or 16
    p.TextColor3, p.TextWrapped, p.Parent = color or ink, true, parent
    return p
end
function UI:Init(remotes)
    local gui = Instance.new("ScreenGui")
    gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "WildholdHUD", false, 10
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    local header = frame(gui, "Run", UDim2.new(0.92, 0, 0, 94), UDim2.new(0.5, 0, 0, 8), Vector2.new(0.5, 0))
    local cap = Instance.new("UISizeConstraint")
    cap.MaxSize, cap.Parent = Vector2.new(620, 94), header
    self.Title = text(header, UDim2.new(1, -20, 0, 25), UDim2.fromOffset(10, 8), "WILDHOLD · 서버 연결 중", 18)
    self.Core = text(header, UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 36), "CORE", 14, muted)
    local bar = frame(header, "CoreBar", UDim2.new(1, -28, 0, 8), UDim2.fromOffset(14, 67))
    bar.BackgroundColor3 = Color3.fromRGB(61, 74, 73)
    self.Bar = frame(bar, "Fill", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
    self.Bar.BackgroundColor3 = Color3.fromRGB(126, 221, 176)
    self.Objective = text(gui, UDim2.new(0.92, 0, 0, 44), UDim2.new(0.04, 0, 0, 109), "맵을 준비하고 있습니다", 16)
    self.Toast = text(gui, UDim2.new(0.92, 0, 0, 45), UDim2.new(0.04, 0, 0, 155), "", 16, Color3.fromRGB(250, 214, 134))
    local bag = frame(gui, "Resources", UDim2.new(0.72, 0, 0, 70), UDim2.new(0.5, 0, 1, -82), Vector2.new(0.5, 1))
    local bcap = Instance.new("UISizeConstraint")
    bcap.MaxSize, bcap.Parent = Vector2.new(620, 70), bag
    self.Bag = text(bag, UDim2.new(1, -12, 0, 28), UDim2.fromOffset(6, 4), "", 12)
    self.Bank = text(bag, UDim2.new(1, -12, 0, 28), UDim2.fromOffset(6, 34), "", 12, muted)
    self.ResultFrame = frame(gui, "Result", UDim2.new(0.86, 0, 0, 210), UDim2.fromScale(0.5, 0.49), Vector2.new(0.5, 0.5))
    local rcap = Instance.new("UISizeConstraint")
    rcap.MaxSize, rcap.Parent = Vector2.new(470, 210), self.ResultFrame
    self.ResultTitle = text(self.ResultFrame, UDim2.new(1, -32, 0, 42), UDim2.fromOffset(16, 20), "", 28)
    self.ResultBody = text(self.ResultFrame, UDim2.new(1, -32, 0, 115), UDim2.fromOffset(16, 73), "", 16, muted)
    self.ResultFrame.Visible = false
    remotes.State.OnClientEvent:Connect(function(data) self.Data = data; self:Update() end)
    remotes.Notice.OnClientEvent:Connect(function(message)
        self.Toast.Text, self.ToastUntil = message, os.clock() + 4
    end)
    local elapsed = 0
    Engine.RenderStepped:Connect(function(dt)
        elapsed = elapsed + dt
        if elapsed >= 0.1 then
            elapsed = 0
            if self.Data then self:UpdateTimer() end
            if self.ToastUntil and os.clock() > self.ToastUntil then self.Toast.Text = "" end
        end
    end)
end
function UI:ResourceText(wallet)
    local parts, total = {}, 0
    for _, kind in ipairs(R.Order) do
        local value = wallet and wallet[kind] or 0
        total = total + value
        table.insert(parts, R.Labels[kind] .. " " .. value)
    end
    return table.concat(parts, "  "), total
end
function UI:UpdateTimer()
    local d = self.Data
    local remaining = math.max(0, math.ceil(d.EndsAt - workspace:GetServerTimeNow()))
    local clock = string.format("%02d:%02d", math.floor(remaining / 60), remaining % 60)
    local phases = {Waiting = "출발 대기", Day = "낮", Night = "밤", Dawn = "새벽", Result = "결과"}
    self.Title.Text = string.format("WILDHOLD  ·  %s %d/%d  ·  %s", phases[d.Phase] or d.Phase, d.Night, d.Target, clock)
    if d.Phase == "Result" and d.Result then
        self.ResultBody.Text = string.format("%s\n생존한 밤 %d · 함께한 인원 %d\n%d초 뒤 새 원정 준비\n이 빌드의 자원·시설은 판마다 초기화됩니다.", d.Result.Reason, d.Result.Nights, d.Players, remaining)
    end
end
function UI:Update()
    local d = self.Data
    self.Core.Text = string.format("CORE  %d / %d    ·    적 %d    ·    등장 %d/%d", d.CoreHP, d.CoreMaxHP, d.Enemies, d.Spawned, d.Total)
    self.Bar.Size = UDim2.fromScale(math.clamp(d.CoreHP / d.CoreMaxHP, 0, 1), 1)
    local bag, total = self:ResourceText(d.Bag)
    self.Bag.Text = string.format("소지 %d/%d  |  %s", total, C.CarryCapacity, bag)
    self.Bank.Text = "공용  |  " .. self:ResourceText(d.Bank)
    if d.Phase == "Waiting" then self.Objective.Text = "출발 대기 · " .. d.Players .. "명 · 시작 후에는 새로 합류할 수 없습니다"
    elseif d.Phase == "Day" then
        if d.Stage == 1 then self.Objective.Text = "1단계 · 맵과 낮/밤 전환을 확인하세요"
        elseif total >= C.CarryCapacity then self.Objective.Text = "가방이 가득 찼습니다! 기지 창고 근처로 이동하세요"
        elseif d.Stage == 2 then self.Objective.Text = "채집 노드 근처에서 공격 → 드랍 밟기 → 창고 입금"
        else self.Objective.Text = "창으로 채집 → 창고 자동 입금 → 빈 자리에 건설 · E / 수리 R" end
    elseif d.Phase == "Night" then self.Objective.Text = "CORE를 지키세요! 공격: 클릭 / F / 터치 · 수리 비용 2배"
    elseif d.Phase == "Dawn" then self.Objective.Text = "밤 생존! 다음 방어를 준비하세요"
    else self.Objective.Text = "원정 종료 · 잠시 뒤 같은 팀으로 다시 시작합니다" end
    self.ResultFrame.Visible = d.Result ~= nil
    if d.Result then self.ResultTitle.Text = d.Result.Won and "방어 성공" or "원정 실패" end
    if d.Objective and d.Phase ~= "Result" then self.Objective.Text = d.Objective end
    self:UpdateTimer()
end
return UI
