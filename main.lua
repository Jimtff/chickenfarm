local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

--------------------------------------------------
-- REMOTES / VALUES
--------------------------------------------------

local Event = ReplicatedStorage
	:WaitForChild("Paper")
	:WaitForChild("Remotes")
	:WaitForChild("__remotefunction")

local Values = ReplicatedStorage:WaitForChild("Values")
local EggMultiplier = Values:WaitForChild("EggMultiplier")

--------------------------------------------------
-- STATES
--------------------------------------------------

local chickenEnabled = false
local selectedChickenAmount = 25

local autoSellEggs = false
local sellAtMultiplier = 1.25

local autoProcessUpgrade = false
local autoTierUpgrade = false
local autoGroupReward = false
local autoCollectCash = false
local antiAFK = false

local chickenOptions = {
	1,
	5,
	25,
	100
}

--------------------------------------------------
-- UI HOTKEY
--------------------------------------------------

local uiHotkey = Enum.KeyCode.RightControl
local waitingForHotkey = false

--------------------------------------------------
-- REMOTE HELPER
--------------------------------------------------

local function InvokeRemote(...)
	local args = {...}

	local success, result = pcall(function()
		return Event:InvokeServer(unpack(args))
	end)

	if not success then
		warn("[Paper Automation] Remote Error:", result)
	end

	return success, result
end

--------------------------------------------------
-- ALTE UI ENTFERNEN
--------------------------------------------------

local oldUI = PlayerGui:FindFirstChild("PaperAutomationUI")

if oldUI then
	oldUI:Destroy()
end

--------------------------------------------------
-- SCREEN GUI
--------------------------------------------------

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PaperAutomationUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

--------------------------------------------------
-- MAIN FRAME
--------------------------------------------------

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 350, 0, 650)
Main.Position = UDim2.new(0.5, -175, 0.5, -325)
Main.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = Main

--------------------------------------------------
-- DRAGGABLE
--------------------------------------------------

local dragging = false
local dragInput
local dragStart
local startPosition

Main.InputBegan:Connect(function(input)

	if input.UserInputType == Enum.UserInputType.MouseButton1 then

		dragging = true
		dragStart = input.Position
		startPosition = Main.Position

		input.Changed:Connect(function()

			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end

		end)
	end
end)

Main.InputChanged:Connect(function(input)

	if input.UserInputType == Enum.UserInputType.MouseMovement then
		dragInput = input
	end

end)

UserInputService.InputChanged:Connect(function(input)

	if input == dragInput and dragging then

		local delta = input.Position - dragStart

		Main.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)

	end

end)

--------------------------------------------------
-- TITEL
--------------------------------------------------

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 45)
Title.BackgroundTransparency = 1
Title.Text = "🐔 Chicken Farm"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 21
Title.Parent = Main

--------------------------------------------------
-- TOGGLE HELPER
--------------------------------------------------

local function createToggle(text, yPosition, callback)

	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(0, 200, 0, 40)
	Label.Position = UDim2.new(0, 15, 0, yPosition)
	Label.BackgroundTransparency = 1
	Label.Text = text
	Label.TextColor3 = Color3.fromRGB(230, 230, 230)
	Label.TextSize = 15
	Label.Font = Enum.Font.Gotham
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = Main

	local Button = Instance.new("TextButton")
	Button.Size = UDim2.new(0, 100, 0, 34)
	Button.Position = UDim2.new(1, -115, 0, yPosition + 3)
	Button.BackgroundColor3 = Color3.fromRGB(170, 50, 50)
	Button.Text = "AUS"
	Button.TextColor3 = Color3.fromRGB(255, 255, 255)
	Button.Font = Enum.Font.GothamBold
	Button.TextSize = 14
	Button.Parent = Main

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 8)
	Corner.Parent = Button

	local enabled = false

	Button.MouseButton1Click:Connect(function()

		enabled = not enabled

		if enabled then

			Button.Text = "AN"
			Button.BackgroundColor3 =
				Color3.fromRGB(45, 170, 75)

		else

			Button.Text = "AUS"
			Button.BackgroundColor3 =
				Color3.fromRGB(170, 50, 50)

		end

		callback(enabled)

	end)

	return Button
end

--------------------------------------------------
-- CHICKEN AMOUNT LABEL
--------------------------------------------------

local ChickenLabel = Instance.new("TextLabel")
ChickenLabel.Size = UDim2.new(0, 150, 0, 35)
ChickenLabel.Position = UDim2.new(0, 15, 0, 50)
ChickenLabel.BackgroundTransparency = 1
ChickenLabel.Text = "Chicken Amount"
ChickenLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
ChickenLabel.Font = Enum.Font.Gotham
ChickenLabel.TextSize = 15
ChickenLabel.TextXAlignment = Enum.TextXAlignment.Left
ChickenLabel.Parent = Main

--------------------------------------------------
-- CHICKEN DROPDOWN
--------------------------------------------------

local Dropdown = Instance.new("TextButton")
Dropdown.Size = UDim2.new(0, 140, 0, 35)
Dropdown.Position = UDim2.new(1, -155, 0, 50)
Dropdown.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
Dropdown.Text = tostring(selectedChickenAmount) .. " ▼"
Dropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
Dropdown.Font = Enum.Font.Gotham
Dropdown.TextSize = 15
Dropdown.Parent = Main

local DropdownCorner = Instance.new("UICorner")
DropdownCorner.CornerRadius = UDim.new(0, 8)
DropdownCorner.Parent = Dropdown

local DropdownList = Instance.new("Frame")
DropdownList.Size = UDim2.new(0, 140, 0, 140)
DropdownList.Position = UDim2.new(1, -155, 0, 87)
DropdownList.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
DropdownList.Visible = false
DropdownList.ZIndex = 20
DropdownList.Parent = Main

local DropdownListCorner = Instance.new("UICorner")
DropdownListCorner.CornerRadius = UDim.new(0, 8)
DropdownListCorner.Parent = DropdownList

local Layout = Instance.new("UIListLayout")
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = DropdownList

for _, amount in ipairs(chickenOptions) do

	local Option = Instance.new("TextButton")

	Option.Size = UDim2.new(1, 0, 0, 35)
	Option.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	Option.BorderSizePixel = 0
	Option.Text = tostring(amount)
	Option.TextColor3 = Color3.fromRGB(255, 255, 255)
	Option.TextSize = 15
	Option.Font = Enum.Font.Gotham
	Option.ZIndex = 21
	Option.Parent = DropdownList

	Option.MouseButton1Click:Connect(function()

		selectedChickenAmount = amount

		Dropdown.Text =
			tostring(selectedChickenAmount) .. " ▼"

		DropdownList.Visible = false

	end)

end

Dropdown.MouseButton1Click:Connect(function()

	DropdownList.Visible = not DropdownList.Visible

	if DropdownList.Visible then

		Dropdown.Text =
			tostring(selectedChickenAmount) .. " ▲"

	else

		Dropdown.Text =
			tostring(selectedChickenAmount) .. " ▼"

	end

end)

--------------------------------------------------
-- AUTO BUY CHICKENS
--------------------------------------------------

createToggle(
	"Auto Buy Chickens",
	95,
	function(state)
		chickenEnabled = state
	end
)

--------------------------------------------------
-- AUTO SELL EGGS
--------------------------------------------------

createToggle(
	"Auto Sell Eggs",
	140,
	function(state)
		autoSellEggs = state
	end
)

--------------------------------------------------
-- CURRENT EGG MULTIPLIER
--------------------------------------------------

local CurrentMultiplierLabel = Instance.new("TextLabel")
CurrentMultiplierLabel.Size = UDim2.new(0, 200, 0, 32)
CurrentMultiplierLabel.Position = UDim2.new(0, 15, 0, 180)
CurrentMultiplierLabel.BackgroundTransparency = 1
CurrentMultiplierLabel.Text = "Current Egg Multiplier"
CurrentMultiplierLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
CurrentMultiplierLabel.TextSize = 15
CurrentMultiplierLabel.Font = Enum.Font.Gotham
CurrentMultiplierLabel.TextXAlignment = Enum.TextXAlignment.Left
CurrentMultiplierLabel.Parent = Main

local CurrentMultiplierValue = Instance.new("TextLabel")
CurrentMultiplierValue.Size = UDim2.new(0, 100, 0, 32)
CurrentMultiplierValue.Position = UDim2.new(1, -115, 0, 180)
CurrentMultiplierValue.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
CurrentMultiplierValue.Text =
	string.format("%.2fx", tonumber(EggMultiplier.Value) or 0)

CurrentMultiplierValue.TextColor3 =
	Color3.fromRGB(255, 255, 255)

CurrentMultiplierValue.Font = Enum.Font.GothamBold
CurrentMultiplierValue.TextSize = 14
CurrentMultiplierValue.Parent = Main

local CurrentCorner = Instance.new("UICorner")
CurrentCorner.CornerRadius = UDim.new(0, 8)
CurrentCorner.Parent = CurrentMultiplierValue

--------------------------------------------------
-- LIVE MULTIPLIER UPDATE
--------------------------------------------------

local function updateMultiplierDisplay()

	local value =
		tonumber(EggMultiplier.Value) or 0

	CurrentMultiplierValue.Text =
		string.format("%.2fx", value)

end

EggMultiplier:GetPropertyChangedSignal("Value"):Connect(
	updateMultiplierDisplay
)

--------------------------------------------------
-- SELL AT MULTIPLIER
--------------------------------------------------

local SellMultiplierLabel = Instance.new("TextLabel")
SellMultiplierLabel.Size = UDim2.new(0, 200, 0, 35)
SellMultiplierLabel.Position = UDim2.new(0, 15, 0, 220)
SellMultiplierLabel.BackgroundTransparency = 1
SellMultiplierLabel.Text = "Sell at Multiplier"
SellMultiplierLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
SellMultiplierLabel.Font = Enum.Font.Gotham
SellMultiplierLabel.TextSize = 15
SellMultiplierLabel.TextXAlignment = Enum.TextXAlignment.Left
SellMultiplierLabel.Parent = Main

local MultiplierBox = Instance.new("TextBox")
MultiplierBox.Size = UDim2.new(0, 100, 0, 32)
MultiplierBox.Position = UDim2.new(1, -115, 0, 222)
MultiplierBox.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
MultiplierBox.Text = tostring(sellAtMultiplier)
MultiplierBox.PlaceholderText = "0.5 - 1.5"
MultiplierBox.TextColor3 = Color3.fromRGB(255, 255, 255)
MultiplierBox.Font = Enum.Font.Gotham
MultiplierBox.TextSize = 14
MultiplierBox.ClearTextOnFocus = false
MultiplierBox.Parent = Main

local MultiplierCorner = Instance.new("UICorner")
MultiplierCorner.CornerRadius = UDim.new(0, 8)
MultiplierCorner.Parent = MultiplierBox

--------------------------------------------------
-- MULTIPLIER INPUT
--------------------------------------------------

MultiplierBox.FocusLost:Connect(function()

	local input =
		string.gsub(MultiplierBox.Text, ",", ".")

	local number = tonumber(input)

	if number then

		number = math.clamp(
			number,
			0.5,
			1.5
		)

		sellAtMultiplier = number

	end

	MultiplierBox.Text =
		tostring(sellAtMultiplier)

	print(
		"[Settings] Sell Eggs at:",
		sellAtMultiplier
	)

end)

--------------------------------------------------
-- AUTO PROCESS LEVEL
--------------------------------------------------

createToggle(
	"Auto Process Upgrade",
	270,
	function(state)
		autoProcessUpgrade = state
	end
)

--------------------------------------------------
-- AUTO TIER LEVEL
--------------------------------------------------

createToggle(
	"Auto Tier Upgrade",
	315,
	function(state)
		autoTierUpgrade = state
	end
)

--------------------------------------------------
-- GROUP REWARD
--------------------------------------------------

createToggle(
	"Auto Group Reward",
	360,
	function(state)
		autoGroupReward = state
	end
)

--------------------------------------------------
-- AUTO COLLECT CASH
--------------------------------------------------

createToggle(
	"Auto Collect Cash",
	405,
	function(state)
		autoCollectCash = state
	end
)

--------------------------------------------------
-- ANTI AFK
--------------------------------------------------

createToggle(
	"Anti AFK",
	450,
	function(state)
		antiAFK = state
	end
)

--------------------------------------------------
-- HOTKEY LABEL
--------------------------------------------------

local HotkeyLabel = Instance.new("TextLabel")
HotkeyLabel.Size = UDim2.new(0, 200, 0, 35)
HotkeyLabel.Position = UDim2.new(0, 15, 0, 495)
HotkeyLabel.BackgroundTransparency = 1
HotkeyLabel.Text = "UI Hotkey"
HotkeyLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
HotkeyLabel.Font = Enum.Font.Gotham
HotkeyLabel.TextSize = 15
HotkeyLabel.TextXAlignment = Enum.TextXAlignment.Left
HotkeyLabel.Parent = Main

--------------------------------------------------
-- HOTKEY BUTTON
--------------------------------------------------

local HotkeyButton = Instance.new("TextButton")
HotkeyButton.Size = UDim2.new(0, 100, 0, 32)
HotkeyButton.Position = UDim2.new(1, -115, 0, 497)
HotkeyButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
HotkeyButton.Text = "RightCtrl"
HotkeyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
HotkeyButton.Font = Enum.Font.GothamBold
HotkeyButton.TextSize = 13
HotkeyButton.Parent = Main

local HotkeyCorner = Instance.new("UICorner")
HotkeyCorner.CornerRadius = UDim.new(0, 8)
HotkeyCorner.Parent = HotkeyButton

--------------------------------------------------
-- KEY NAME HELPER
--------------------------------------------------

local function getKeyName(keyCode)

	if keyCode == Enum.KeyCode.RightControl then
		return "RightCtrl"
	end

	if keyCode == Enum.KeyCode.LeftControl then
		return "LeftCtrl"
	end

	if keyCode == Enum.KeyCode.RightShift then
		return "RightShift"
	end

	if keyCode == Enum.KeyCode.LeftShift then
		return "LeftShift"
	end

	return keyCode.Name
end

--------------------------------------------------
-- HOTKEY ÄNDERN
--------------------------------------------------

HotkeyButton.MouseButton1Click:Connect(function()

	if waitingForHotkey then
		return
	end

	waitingForHotkey = true
	HotkeyButton.Text = "Press Key..."

end)

--------------------------------------------------
-- HOTKEY INPUT
--------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gameProcessed)

	--------------------------------------------------
	-- NEUEN HOTKEY SETZEN
	--------------------------------------------------

	if waitingForHotkey then

		if input.UserInputType == Enum.UserInputType.Keyboard then

			if input.KeyCode ~= Enum.KeyCode.Unknown then

				uiHotkey = input.KeyCode

				HotkeyButton.Text =
					getKeyName(uiHotkey)

				waitingForHotkey = false

				print(
					"[Settings] New UI Hotkey:",
					uiHotkey.Name
				)

			end

		end

		return
	end

	--------------------------------------------------
	-- NICHT BEIM TEXTSCHREIBEN AUSLÖSEN
	--------------------------------------------------

	if UserInputService:GetFocusedTextBox() then
		return
	end

	--------------------------------------------------
	-- UI TOGGLE
	--------------------------------------------------

	if input.KeyCode == uiHotkey then

		Main.Visible = not Main.Visible

		print(
			"[UI]",
			Main.Visible and "Visible" or "Hidden"
		)

	end

end)

--------------------------------------------------
-- INFO
--------------------------------------------------

local Info = Instance.new("TextLabel")
Info.Size = UDim2.new(1, -30, 0, 90)
Info.Position = UDim2.new(0, 15, 0, 540)
Info.BackgroundTransparency = 1

Info.Text =
	"Egg Sell Range: 0.50x - 1.50x\n" ..
	"Group Reward: every 10 minutes\n" ..
	"UI Hotkey: RightCtrl"

Info.TextColor3 = Color3.fromRGB(150, 150, 150)
Info.TextSize = 12
Info.Font = Enum.Font.Gotham
Info.TextWrapped = true
Info.Parent = Main

--------------------------------------------------
-- AUTO BUY CHICKENS LOOP
--------------------------------------------------

task.spawn(function()

	while true do

		if chickenEnabled then

			InvokeRemote(
				"Buy Chickens",
				selectedChickenAmount
			)

		end

		task.wait(0.5)

	end

end)

--------------------------------------------------
-- AUTO SELL EGGS LOOP
--------------------------------------------------

task.spawn(function()

	local lastSell = 0

	while true do

		if autoSellEggs then

			local currentMultiplier =
				tonumber(EggMultiplier.Value) or 0

			if currentMultiplier >= sellAtMultiplier then

				if tick() - lastSell >= 1 then

					lastSell = tick()

					print(
						"[Auto Sell] Deposit Eggs | Current:",
						currentMultiplier,
						"| Target:",
						sellAtMultiplier
					)

					InvokeRemote(
						"Deposit Eggs"
					)

				end

			end

		end

		task.wait(0.1)

	end

end)

--------------------------------------------------
-- AUTO PROCESS LEVEL UPGRADE LOOP
--------------------------------------------------

task.spawn(function()

	while true do

		if autoProcessUpgrade then

			InvokeRemote(
				"Upgrade Process Level"
			)

		end

		task.wait(1)

	end

end)

--------------------------------------------------
-- AUTO TIER LEVEL UPGRADE LOOP
--------------------------------------------------

task.spawn(function()

	while true do

		if autoTierUpgrade then

			InvokeRemote(
				"Upgrade Buy Tier Level"
			)

		end

		task.wait(1)

	end

end)

--------------------------------------------------
-- AUTO GROUP REWARD LOOP
--------------------------------------------------

task.spawn(function()

	while true do

		if autoGroupReward then

			print(
				"[Group Reward] Trying to claim reward"
			)

			InvokeRemote(
				"Claim Group Reward"
			)

		end

		task.wait(600)

	end

end)

--------------------------------------------------
-- AUTO COLLECT CASH LOOP
--------------------------------------------------

task.spawn(function()

	while true do

		if autoCollectCash then

			InvokeRemote(
				"Collect Cash"
			)

		end

		task.wait(1)

	end

end)

--------------------------------------------------
-- ANTI AFK
--------------------------------------------------

Player.Idled:Connect(function()

	if not antiAFK then
		return
	end

	pcall(function()

		local Camera =
			workspace.CurrentCamera

		if not Camera then
			return
		end

		VirtualUser:Button2Down(
			Vector2.zero,
			Camera.CFrame
		)

		task.wait(1)

		VirtualUser:Button2Up(
			Vector2.zero,
			Camera.CFrame
		)

		print(
			"[Anti AFK] Idle prevented"
		)

	end)

end)
