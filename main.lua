--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

--------------------------------------------------
-- SETTINGS FILE
--------------------------------------------------

local SETTINGS_FILE = "ChickenFarmSettings.json"

--------------------------------------------------
-- DEFAULT SETTINGS
--------------------------------------------------

local DEFAULT_SETTINGS = {

	chickenEnabled = false,
	selectedChickenAmount = 25,

	autoSellEggs = false,
	sellAtMultiplier = 1.25,

	autoProcessUpgrade = false,
	autoTierUpgrade = false,
	autoGroupReward = false,
	autoCollectCash = false,
	antiAFK = false,

	uiHotkey = "RightControl"

}

--------------------------------------------------
-- SETTINGS TABLE
--------------------------------------------------

local Settings = {}

for key, value in pairs(DEFAULT_SETTINGS) do
	Settings[key] = value
end

--------------------------------------------------
-- LOAD SETTINGS
--------------------------------------------------

local function LoadSettings()

	if type(readfile) ~= "function"
		or type(isfile) ~= "function"
	then

		warn(
			"[Chicken Farm] Settings können nicht geladen werden."
		)

		return
	end

	local success, data = pcall(function()

		if not isfile(SETTINGS_FILE) then
			return nil
		end

		local rawData =
			readfile(SETTINGS_FILE)

		return HttpService:JSONDecode(rawData)

	end)

	if not success then

		warn(
			"[Chicken Farm] Settings Load Error:",
			data
		)

		return

	end

	if type(data) ~= "table" then
		return
	end

	for key, defaultValue in pairs(DEFAULT_SETTINGS) do

		if data[key] ~= nil then
			Settings[key] = data[key]
		else
			Settings[key] = defaultValue
		end

	end

	print("[Chicken Farm] Settings loaded")

end

--------------------------------------------------
-- SAVE SETTINGS
--------------------------------------------------

local function SaveSettings()

	if type(writefile) ~= "function" then
		return
	end

	local success, err = pcall(function()

		local encoded =
			HttpService:JSONEncode(Settings)

		writefile(
			SETTINGS_FILE,
			encoded
		)

	end)

	if not success then

		warn(
			"[Chicken Farm] Settings Save Error:",
			err
		)

	end

end

--------------------------------------------------
-- LOAD SAVED SETTINGS
--------------------------------------------------

LoadSettings()

--------------------------------------------------
-- VALIDATE SETTINGS
--------------------------------------------------

local validChickenAmounts = {
	[1] = true,
	[5] = true,
	[25] = true,
	[100] = true
}

local loadedChickenAmount =
	tonumber(Settings.selectedChickenAmount)

if not validChickenAmounts[loadedChickenAmount] then
	loadedChickenAmount = 25
end

local loadedMultiplier =
	tonumber(Settings.sellAtMultiplier)
	or 1.25

loadedMultiplier =
	math.clamp(
		loadedMultiplier,
		0.5,
		1.5
	)

--------------------------------------------------
-- STATES
--------------------------------------------------

local chickenEnabled =
	Settings.chickenEnabled == true

local selectedChickenAmount =
	loadedChickenAmount

local autoSellEggs =
	Settings.autoSellEggs == true

local sellAtMultiplier =
	loadedMultiplier

local autoProcessUpgrade =
	Settings.autoProcessUpgrade == true

local autoTierUpgrade =
	Settings.autoTierUpgrade == true

local autoGroupReward =
	Settings.autoGroupReward == true

local autoCollectCash =
	Settings.autoCollectCash == true

local antiAFK =
	Settings.antiAFK == true

local chickenOptions = {
	1,
	5,
	25,
	100
}

--------------------------------------------------
-- UI HOTKEY
--------------------------------------------------

local savedHotkey =
	Enum.KeyCode[
		tostring(Settings.uiHotkey)
	]

local uiHotkey =
	savedHotkey
	or Enum.KeyCode.RightControl

local waitingForHotkey = false

--------------------------------------------------
-- RUNTIME / CLEANUP
--------------------------------------------------

local Environment =
	(getgenv and getgenv())
	or _G

if Environment.__ChickenFarmRuntime then

	local oldRuntime =
		Environment.__ChickenFarmRuntime

	if oldRuntime.Stop then
		pcall(oldRuntime.Stop)
	end

end

local Runtime = {

	Alive = true,
	Connections = {}

}

Environment.__ChickenFarmRuntime = Runtime

--------------------------------------------------
-- CONNECTION HELPER
--------------------------------------------------

local function TrackConnection(connection)

	table.insert(
		Runtime.Connections,
		connection
	)

	return connection

end

--------------------------------------------------
-- STOP OLD SCRIPT
--------------------------------------------------

function Runtime.Stop()

	Runtime.Alive = false

	for _, connection in ipairs(
		Runtime.Connections
	) do

		pcall(function()
			connection:Disconnect()
		end)

	end

	Runtime.Connections = {}

	local oldUI =
		PlayerGui:FindFirstChild(
			"PaperAutomationUI"
		)

	if oldUI then
		oldUI:Destroy()
	end

end

--------------------------------------------------
-- REMOTES / VALUES
--------------------------------------------------

local Event =
	ReplicatedStorage
		:WaitForChild("Paper")
		:WaitForChild("Remotes")
		:WaitForChild("__remotefunction")

local Values =
	ReplicatedStorage
		:WaitForChild("Values")

local EggMultiplier =
	Values
		:WaitForChild("EggMultiplier")

--------------------------------------------------
-- REMOTE HELPER
--------------------------------------------------

local function InvokeRemote(...)

	if not Runtime.Alive then
		return false
	end

	local args = {...}

	local success, result =
		pcall(function()

			return Event:InvokeServer(
				table.unpack(args)
			)

		end)

	if not success then

		warn(
			"[Chicken Farm] Remote Error:",
			result
		)

	end

	return success, result

end

--------------------------------------------------
-- REMOVE OLD UI
--------------------------------------------------

local oldUI =
	PlayerGui:FindFirstChild(
		"PaperAutomationUI"
	)

if oldUI then
	oldUI:Destroy()
end

--------------------------------------------------
-- SCREEN GUI
--------------------------------------------------

local ScreenGui =
	Instance.new("ScreenGui")

ScreenGui.Name =
	"PaperAutomationUI"

ScreenGui.ResetOnSpawn =
	false

ScreenGui.ZIndexBehavior =
	Enum.ZIndexBehavior.Sibling

ScreenGui.Parent =
	PlayerGui

--------------------------------------------------
-- MAIN FRAME
--------------------------------------------------

local Main =
	Instance.new("Frame")

Main.Name =
	"Main"

Main.Size =
	UDim2.new(
		0,
		350,
		0,
		650
	)

Main.Position =
	UDim2.new(
		0.5,
		-175,
		0.5,
		-325
	)

Main.BackgroundColor3 =
	Color3.fromRGB(
		25,
		25,
		25
	)

Main.BorderSizePixel =
	0

Main.Active =
	true

Main.Parent =
	ScreenGui

local MainCorner =
	Instance.new("UICorner")

MainCorner.CornerRadius =
	UDim.new(
		0,
		12
	)

MainCorner.Parent =
	Main

--------------------------------------------------
-- DRAGGING
--------------------------------------------------

local dragging = false
local dragInput = nil
local dragStart = nil
local startPosition = nil

TrackConnection(

	Main.InputBegan:Connect(function(input)

		if input.UserInputType ~=
			Enum.UserInputType.MouseButton1
		then
			return
		end

		dragging =
			true

		dragStart =
			input.Position

		startPosition =
			Main.Position

		local changedConnection

		changedConnection =
			input.Changed:Connect(function()

				if input.UserInputState ==
					Enum.UserInputState.End
				then

					dragging =
						false

					if changedConnection then

						changedConnection:
							Disconnect()

					end

				end

			end)

	end)

)

TrackConnection(

	Main.InputChanged:Connect(function(input)

		if input.UserInputType ==
			Enum.UserInputType.MouseMovement
		then

			dragInput =
				input

		end

	end)

)

TrackConnection(

	UserInputService.InputChanged:
		Connect(function(input)

			if not dragging then
				return
			end

			if input ~= dragInput then
				return
			end

			if not dragStart
				or not startPosition
			then
				return
			end

			local delta =
				input.Position
				- dragStart

			Main.Position =
				UDim2.new(

					startPosition.X.Scale,
					startPosition.X.Offset
						+ delta.X,

					startPosition.Y.Scale,
					startPosition.Y.Offset
						+ delta.Y

				)

		end)

)

--------------------------------------------------
-- TITLE
--------------------------------------------------

local Title =
	Instance.new("TextLabel")

Title.Size =
	UDim2.new(
		1,
		0,
		0,
		45
	)

Title.BackgroundTransparency =
	1

Title.Text =
	"🐔 Chicken Farm"

Title.TextColor3 =
	Color3.fromRGB(
		255,
		255,
		255
	)

Title.Font =
	Enum.Font.GothamBold

Title.TextSize =
	21

Title.Parent =
	Main

--------------------------------------------------
-- TOGGLE HELPER
--------------------------------------------------

local function createToggle(
	text,
	yPosition,
	initialState,
	callback
)

	local Label =
		Instance.new("TextLabel")

	Label.Size =
		UDim2.new(
			0,
			200,
			0,
			40
		)

	Label.Position =
		UDim2.new(
			0,
			15,
			0,
			yPosition
		)

	Label.BackgroundTransparency =
		1

	Label.Text =
		text

	Label.TextColor3 =
		Color3.fromRGB(
			230,
			230,
			230
		)

	Label.TextSize =
		15

	Label.Font =
		Enum.Font.Gotham

	Label.TextXAlignment =
		Enum.TextXAlignment.Left

	Label.Parent =
		Main

	--------------------------------------------------

	local Button =
		Instance.new("TextButton")

	Button.Size =
		UDim2.new(
			0,
			100,
			0,
			34
		)

	Button.Position =
		UDim2.new(
			1,
			-115,
			0,
			yPosition + 3
		)

	Button.TextColor3 =
		Color3.fromRGB(
			255,
			255,
			255
		)

	Button.Font =
		Enum.Font.GothamBold

	Button.TextSize =
		14

	Button.Parent =
		Main

	local Corner =
		Instance.new("UICorner")

	Corner.CornerRadius =
		UDim.new(
			0,
			8
		)

	Corner.Parent =
		Button

	--------------------------------------------------
	-- INITIAL STATE
	--------------------------------------------------

	local enabled =
		initialState == true

	local function updateVisual()

		if enabled then

			Button.Text =
				"AN"

			Button.BackgroundColor3 =
				Color3.fromRGB(
					45,
					170,
					75
				)

		else

			Button.Text =
				"AUS"

			Button.BackgroundColor3 =
				Color3.fromRGB(
					170,
					50,
					50
				)

		end

	end

	updateVisual()

	--------------------------------------------------
	-- BUTTON
	--------------------------------------------------

	TrackConnection(

		Button.MouseButton1Click:
			Connect(function()

				enabled =
					not enabled

				updateVisual()

				callback(
					enabled
				)

				SaveSettings()

			end)

	)

	return Button

end

--------------------------------------------------
-- CHICKEN AMOUNT LABEL
--------------------------------------------------

local ChickenLabel =
	Instance.new("TextLabel")

ChickenLabel.Size =
	UDim2.new(
		0,
		150,
		0,
		35
	)

ChickenLabel.Position =
	UDim2.new(
		0,
		15,
		0,
		50
	)

ChickenLabel.BackgroundTransparency =
	1

ChickenLabel.Text =
	"Chicken Amount"

ChickenLabel.TextColor3 =
	Color3.fromRGB(
		230,
		230,
		230
	)

ChickenLabel.Font =
	Enum.Font.Gotham

ChickenLabel.TextSize =
	15

ChickenLabel.TextXAlignment =
	Enum.TextXAlignment.Left

ChickenLabel.Parent =
	Main

--------------------------------------------------
-- CHICKEN DROPDOWN
--------------------------------------------------

local Dropdown =
	Instance.new("TextButton")

Dropdown.Size =
	UDim2.new(
		0,
		140,
		0,
		35
	)

Dropdown.Position =
	UDim2.new(
		1,
		-155,
		0,
		50
	)

Dropdown.BackgroundColor3 =
	Color3.fromRGB(
		45,
		45,
		45
	)

Dropdown.Text =
	tostring(
		selectedChickenAmount
	)
	.. " ▼"

Dropdown.TextColor3 =
	Color3.fromRGB(
		255,
		255,
		255
	)

Dropdown.Font =
	Enum.Font.Gotham

Dropdown.TextSize =
	15

Dropdown.Parent =
	Main

local DropdownCorner =
	Instance.new("UICorner")

DropdownCorner.CornerRadius =
	UDim.new(
		0,
		8
	)

DropdownCorner.Parent =
	Dropdown

--------------------------------------------------
-- DROPDOWN LIST
--------------------------------------------------

local DropdownList =
	Instance.new("Frame")

DropdownList.Size =
	UDim2.new(
		0,
		140,
		0,
		140
	)

DropdownList.Position =
	UDim2.new(
		1,
		-155,
		0,
		87
	)

DropdownList.BackgroundColor3 =
	Color3.fromRGB(
		35,
		35,
		35
	)

DropdownList.BorderSizePixel =
	0

DropdownList.Visible =
	false

DropdownList.ZIndex =
	20

DropdownList.Parent =
	Main

local DropdownListCorner =
	Instance.new("UICorner")

DropdownListCorner.CornerRadius =
	UDim.new(
		0,
		8
	)

DropdownListCorner.Parent =
	DropdownList

local Layout =
	Instance.new("UIListLayout")

Layout.SortOrder =
	Enum.SortOrder.LayoutOrder

Layout.Parent =
	DropdownList

--------------------------------------------------
-- CHICKEN OPTIONS
--------------------------------------------------

for _, amount in ipairs(
	chickenOptions
) do

	local Option =
		Instance.new("TextButton")

	Option.Size =
		UDim2.new(
			1,
			0,
			0,
			35
		)

	Option.BackgroundColor3 =
		Color3.fromRGB(
			40,
			40,
			40
		)

	Option.BorderSizePixel =
		0

	Option.Text =
		tostring(amount)

	Option.TextColor3 =
		Color3.fromRGB(
			255,
			255,
			255
		)

	Option.TextSize =
		15

	Option.Font =
		Enum.Font.Gotham

	Option.ZIndex =
		21

	Option.Parent =
		DropdownList

	TrackConnection(

		Option.MouseButton1Click:
			Connect(function()

				selectedChickenAmount =
					amount

				Settings.selectedChickenAmount =
					amount

				SaveSettings()

				Dropdown.Text =
					tostring(
						selectedChickenAmount
					)
					.. " ▼"

				DropdownList.Visible =
					false

			end)

	)

end

--------------------------------------------------
-- DROPDOWN BUTTON
--------------------------------------------------

TrackConnection(

	Dropdown.MouseButton1Click:
		Connect(function()

			DropdownList.Visible =
				not DropdownList.Visible

			if DropdownList.Visible then

				Dropdown.Text =
					tostring(
						selectedChickenAmount
					)
					.. " ▲"

			else

				Dropdown.Text =
					tostring(
						selectedChickenAmount
					)
					.. " ▼"

			end

		end)

)

--------------------------------------------------
-- AUTO BUY CHICKENS
--------------------------------------------------

createToggle(

	"Auto Buy Chickens",
	95,
	chickenEnabled,

	function(state)

		chickenEnabled =
			state

		Settings.chickenEnabled =
			state

	end

)

--------------------------------------------------
-- AUTO SELL EGGS
--------------------------------------------------

createToggle(

	"Auto Sell Eggs",
	140,
	autoSellEggs,

	function(state)

		autoSellEggs =
			state

		Settings.autoSellEggs =
			state

	end

)

--------------------------------------------------
-- CURRENT MULTIPLIER
--------------------------------------------------

local CurrentMultiplierLabel =
	Instance.new("TextLabel")

CurrentMultiplierLabel.Size =
	UDim2.new(
		0,
		200,
		0,
		32
	)

CurrentMultiplierLabel.Position =
	UDim2.new(
		0,
		15,
		0,
		180
	)

CurrentMultiplierLabel.BackgroundTransparency =
	1

CurrentMultiplierLabel.Text =
	"Current Egg Multiplier"

CurrentMultiplierLabel.TextColor3 =
	Color3.fromRGB(
		230,
		230,
		230
	)

CurrentMultiplierLabel.TextSize =
	15

CurrentMultiplierLabel.Font =
	Enum.Font.Gotham

CurrentMultiplierLabel.TextXAlignment =
	Enum.TextXAlignment.Left

CurrentMultiplierLabel.Parent =
	Main

--------------------------------------------------
-- CURRENT VALUE
--------------------------------------------------

local CurrentMultiplierValue =
	Instance.new("TextLabel")

CurrentMultiplierValue.Size =
	UDim2.new(
		0,
		100,
		0,
		32
	)

CurrentMultiplierValue.Position =
	UDim2.new(
		1,
		-115,
		0,
		180
	)

CurrentMultiplierValue.BackgroundColor3 =
	Color3.fromRGB(
		35,
		35,
		35
	)

CurrentMultiplierValue.TextColor3 =
	Color3.fromRGB(
		255,
		255,
		255
	)

CurrentMultiplierValue.Font =
	Enum.Font.GothamBold

CurrentMultiplierValue.TextSize =
	14

CurrentMultiplierValue.Parent =
	Main

local CurrentCorner =
	Instance.new("UICorner")

CurrentCorner.CornerRadius =
	UDim.new(
		0,
		8
	)

CurrentCorner.Parent =
	CurrentMultiplierValue

--------------------------------------------------
-- UPDATE MULTIPLIER DISPLAY
--------------------------------------------------

local function updateMultiplierDisplay()

	local value =
		tonumber(
			EggMultiplier.Value
		)
		or 0

	CurrentMultiplierValue.Text =
		string.format(
			"%.2fx",
			value
		)

end

updateMultiplierDisplay()

TrackConnection(

	EggMultiplier
		:GetPropertyChangedSignal("Value")
		:Connect(
			updateMultiplierDisplay
		)

)

--------------------------------------------------
-- SELL MULTIPLIER LABEL
--------------------------------------------------

local SellMultiplierLabel =
	Instance.new("TextLabel")

SellMultiplierLabel.Size =
	UDim2.new(
		0,
		200,
		0,
		35
	)

SellMultiplierLabel.Position =
	UDim2.new(
		0,
		15,
		0,
		220
	)

SellMultiplierLabel.BackgroundTransparency =
	1

SellMultiplierLabel.Text =
	"Sell at Multiplier"

SellMultiplierLabel.TextColor3 =
	Color3.fromRGB(
		230,
		230,
		230
	)

SellMultiplierLabel.Font =
	Enum.Font.Gotham

SellMultiplierLabel.TextSize =
	15

SellMultiplierLabel.TextXAlignment =
	Enum.TextXAlignment.Left

SellMultiplierLabel.Parent =
	Main

--------------------------------------------------
-- MULTIPLIER BOX
--------------------------------------------------

local MultiplierBox =
	Instance.new("TextBox")

MultiplierBox.Size =
	UDim2.new(
		0,
		100,
		0,
		32
	)

MultiplierBox.Position =
	UDim2.new(
		1,
		-115,
		0,
		222
	)

MultiplierBox.BackgroundColor3 =
	Color3.fromRGB(
		45,
		45,
		45
	)

MultiplierBox.Text =
	tostring(
		sellAtMultiplier
	)

MultiplierBox.PlaceholderText =
	"0.5 - 1.5"

MultiplierBox.TextColor3 =
	Color3.fromRGB(
		255,
		255,
		255
	)

MultiplierBox.Font =
	Enum.Font.Gotham

MultiplierBox.TextSize =
	14

MultiplierBox.ClearTextOnFocus =
	false

MultiplierBox.Parent =
	Main

local MultiplierCorner =
	Instance.new("UICorner")

MultiplierCorner.CornerRadius =
	UDim.new(
		0,
		8
	)

MultiplierCorner.Parent =
	MultiplierBox

--------------------------------------------------
-- MULTIPLIER INPUT
--------------------------------------------------

TrackConnection(

	MultiplierBox.FocusLost:
		Connect(function()

			local input =
				MultiplierBox.Text:
					gsub(
						",",
						"."
					)

			local number =
				tonumber(input)

			if number then

				number =
					math.clamp(
						number,
						0.5,
						1.5
					)

				number =
					math.floor(
						number
						* 100
						+ 0.5
					)
					/ 100

				sellAtMultiplier =
					number

				Settings.sellAtMultiplier =
					number

				SaveSettings()

			end

			MultiplierBox.Text =
				tostring(
					sellAtMultiplier
				)

		end)

)

--------------------------------------------------
-- AUTO PROCESS LEVEL
--------------------------------------------------

createToggle(

	"Auto Process Upgrade",
	270,
	autoProcessUpgrade,

	function(state)

		autoProcessUpgrade =
			state

		Settings.autoProcessUpgrade =
			state

	end

)

--------------------------------------------------
-- AUTO TIER LEVEL
--------------------------------------------------

createToggle(

	"Auto Tier Upgrade",
	315,
	autoTierUpgrade,

	function(state)

		autoTierUpgrade =
			state

		Settings.autoTierUpgrade =
			state

	end

)

--------------------------------------------------
-- GROUP REWARD
--------------------------------------------------

local lastGroupRewardAttempt =
	0

createToggle(

	"Auto Group Reward",
	360,
	autoGroupReward,

	function(state)

		autoGroupReward =
			state

		Settings.autoGroupReward =
			state

		if state then

			lastGroupRewardAttempt =
				0

		end

	end

)

--------------------------------------------------
-- AUTO COLLECT CASH
--------------------------------------------------

createToggle(

	"Auto Collect Cash",
	405,
	autoCollectCash,

	function(state)

		autoCollectCash =
			state

		Settings.autoCollectCash =
			state

	end

)

--------------------------------------------------
-- ANTI AFK
--------------------------------------------------

createToggle(

	"Anti AFK",
	450,
	antiAFK,

	function(state)

		antiAFK =
			state

		Settings.antiAFK =
			state

	end

)

--------------------------------------------------
-- HOTKEY LABEL
--------------------------------------------------

local HotkeyLabel =
	Instance.new("TextLabel")

HotkeyLabel.Size =
	UDim2.new(
		0,
		200,
		0,
		35
	)

HotkeyLabel.Position =
	UDim2.new(
		0,
		15,
		0,
		495
	)

HotkeyLabel.BackgroundTransparency =
	1

HotkeyLabel.Text =
	"UI Hotkey"

HotkeyLabel.TextColor3 =
	Color3.fromRGB(
		230,
		230,
		230
	)

HotkeyLabel.Font =
	Enum.Font.Gotham

HotkeyLabel.TextSize =
	15

HotkeyLabel.TextXAlignment =
	Enum.TextXAlignment.Left

HotkeyLabel.Parent =
	Main

--------------------------------------------------
-- KEY NAME
--------------------------------------------------

local function getKeyName(keyCode)

	if keyCode ==
		Enum.KeyCode.RightControl
	then
		return "RightCtrl"
	end

	if keyCode ==
		Enum.KeyCode.LeftControl
	then
		return "LeftCtrl"
	end

	if keyCode ==
		Enum.KeyCode.RightShift
	then
		return "RightShift"
	end

	if keyCode ==
		Enum.KeyCode.LeftShift
	then
		return "LeftShift"
	end

	return keyCode.Name

end

--------------------------------------------------
-- HOTKEY BUTTON
--------------------------------------------------

local HotkeyButton =
	Instance.new("TextButton")

HotkeyButton.Size =
	UDim2.new(
		0,
		100,
		0,
		32
	)

HotkeyButton.Position =
	UDim2.new(
		1,
		-115,
		0,
		497
	)

HotkeyButton.BackgroundColor3 =
	Color3.fromRGB(
		45,
		45,
		45
	)

HotkeyButton.Text =
	getKeyName(
		uiHotkey
	)

HotkeyButton.TextColor3 =
	Color3.fromRGB(
		255,
		255,
		255
	)

HotkeyButton.Font =
	Enum.Font.GothamBold

HotkeyButton.TextSize =
	13

HotkeyButton.Parent =
	Main

local HotkeyCorner =
	Instance.new("UICorner")

HotkeyCorner.CornerRadius =
	UDim.new(
		0,
		8
	)

HotkeyCorner.Parent =
	HotkeyButton

--------------------------------------------------
-- HOTKEY CHANGE
--------------------------------------------------

TrackConnection(

	HotkeyButton.MouseButton1Click:
		Connect(function()

			if waitingForHotkey then
				return
			end

			waitingForHotkey =
				true

			HotkeyButton.Text =
				"Press Key..."

		end)

)

--------------------------------------------------
-- HOTKEY INPUT
--------------------------------------------------

TrackConnection(

	UserInputService.InputBegan:
		Connect(function(
			input,
			gameProcessed
		)

			--------------------------------------------------
			-- SET NEW HOTKEY
			--------------------------------------------------

			if waitingForHotkey then

				if input.UserInputType ==
					Enum.UserInputType.Keyboard
				then

					if input.KeyCode ~=
						Enum.KeyCode.Unknown
					then

						uiHotkey =
							input.KeyCode

						Settings.uiHotkey =
							uiHotkey.Name

						SaveSettings()

						HotkeyButton.Text =
							getKeyName(
								uiHotkey
							)

						waitingForHotkey =
							false

						print(
							"[Settings] UI Hotkey:",
							uiHotkey.Name
						)

					end

				end

				return

			end

			--------------------------------------------------
			-- DON'T TOGGLE WHEN TYPING
			--------------------------------------------------

			if UserInputService:
				GetFocusedTextBox()
			then
				return
			end

			if gameProcessed then
				return
			end

			--------------------------------------------------
			-- UI VISIBILITY
			--------------------------------------------------

			if input.UserInputType ==
					Enum.UserInputType.Keyboard
				and input.KeyCode ==
					uiHotkey
			then

				Main.Visible =
					not Main.Visible

				if not Main.Visible then

					DropdownList.Visible =
						false

				end

			end

		end)

)

--------------------------------------------------
-- INFO
--------------------------------------------------

local Info =
	Instance.new("TextLabel")

Info.Size =
	UDim2.new(
		1,
		-30,
		0,
		90
	)

Info.Position =
	UDim2.new(
		0,
		15,
		0,
		540
	)

Info.BackgroundTransparency =
	1

Info.Text =
	"Egg Sell Range: 0.50x - 1.50x\n"
	.. "Group Reward: every 10 minutes\n"
	.. "UI Hotkey: "
	.. getKeyName(uiHotkey)

Info.TextColor3 =
	Color3.fromRGB(
		150,
		150,
		150
	)

Info.TextSize =
	12

Info.Font =
	Enum.Font.Gotham

Info.TextWrapped =
	true

Info.Parent =
	Main

--------------------------------------------------
-- KEEP INFO HOTKEY UPDATED
--------------------------------------------------

local function updateInfo()

	Info.Text =
		"Egg Sell Range: 0.50x - 1.50x\n"
		.. "Group Reward: every 10 minutes\n"
		.. "UI Hotkey: "
		.. getKeyName(uiHotkey)

end

TrackConnection(

	HotkeyButton:GetPropertyChangedSignal("Text"):
		Connect(function()

			if not waitingForHotkey then
				updateInfo()
			end

		end)

)

--------------------------------------------------
-- AUTO BUY CHICKENS
--------------------------------------------------

task.spawn(function()

	while Runtime.Alive do

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
-- AUTO SELL EGGS
--------------------------------------------------

task.spawn(function()

	local lastSell =
		0

	while Runtime.Alive do

		if autoSellEggs then

			local currentMultiplier =
				tonumber(
					EggMultiplier.Value
				)
				or 0

			if currentMultiplier >=
				sellAtMultiplier
			then

				local now =
					os.clock()

				if now - lastSell >= 1 then

					lastSell =
						now

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
-- AUTO PROCESS LEVEL
--------------------------------------------------

task.spawn(function()

	while Runtime.Alive do

		if autoProcessUpgrade then

			InvokeRemote(
				"Upgrade Process Level"
			)

		end

		task.wait(1)

	end

end)

--------------------------------------------------
-- AUTO TIER LEVEL
--------------------------------------------------

task.spawn(function()

	while Runtime.Alive do

		if autoTierUpgrade then

			InvokeRemote(
				"Upgrade Buy Tier Level"
			)

		end

		task.wait(1)

	end

end)

--------------------------------------------------
-- AUTO GROUP REWARD
--------------------------------------------------

task.spawn(function()

	while Runtime.Alive do

		if autoGroupReward then

			local now =
				os.clock()

			if lastGroupRewardAttempt == 0
				or
				now - lastGroupRewardAttempt >= 600
			then

				lastGroupRewardAttempt =
					now

				InvokeRemote(
					"Claim Group Reward"
				)

			end

		end

		task.wait(1)

	end

end)

--------------------------------------------------
-- AUTO COLLECT CASH
--------------------------------------------------

task.spawn(function()

	while Runtime.Alive do

		if autoCollectCash then

			InvokeRemote(
				"Collect Cash"
			)

		end

		task.wait(1)

	end

end)

--------------------------------------------------
-- ANTI AFK FUNCTION
--------------------------------------------------

local function PerformAntiAFK()

	--------------------------------------------------
	-- PRIMARY METHOD
	--------------------------------------------------

	local success =
		pcall(function()

			local VirtualInputManager =
				Instance.new(
					"VirtualInputManager"
				)

			VirtualInputManager:
				SendMouseButtonEvent(
					0,
					0,
					0,
					true,
					game,
					0
				)

			VirtualInputManager:
				SendMouseButtonEvent(
					0,
					0,
					0,
					false,
					game,
					0
				)

			VirtualInputManager:
				Destroy()

		end)

	--------------------------------------------------
	-- FALLBACK
	--------------------------------------------------

	if not success then

		pcall(function()

			VirtualUser:
				CaptureController()

			VirtualUser:
				ClickButton2(
					Vector2.zero
				)

		end)

	end

end

--------------------------------------------------
-- ANTI AFK EVENT
--------------------------------------------------

TrackConnection(

	Player.Idled:
		Connect(function()

			if not Runtime.Alive then
				return
			end

			if not antiAFK then
				return
			end

			PerformAntiAFK()

			print(
				"[Anti AFK] Idle prevented"
			)

		end)

)

--------------------------------------------------
-- GUI CLEANUP
--------------------------------------------------

TrackConnection(

	ScreenGui.Destroying:
		Connect(function()

			if
				Environment.__ChickenFarmRuntime
				== Runtime
			then

				Runtime.Alive =
					false

			end

		end)

)

--------------------------------------------------
-- ENSURE CURRENT VALUES ARE SAVED
--------------------------------------------------

Settings.chickenEnabled =
	chickenEnabled

Settings.selectedChickenAmount =
	selectedChickenAmount

Settings.autoSellEggs =
	autoSellEggs

Settings.sellAtMultiplier =
	sellAtMultiplier

Settings.autoProcessUpgrade =
	autoProcessUpgrade

Settings.autoTierUpgrade =
	autoTierUpgrade

Settings.autoGroupReward =
	autoGroupReward

Settings.autoCollectCash =
	autoCollectCash

Settings.antiAFK =
	antiAFK

Settings.uiHotkey =
	uiHotkey.Name

SaveSettings()

--------------------------------------------------
-- START INFO
--------------------------------------------------

print("------------------------------------")
print("Chicken Farm loaded")
print("Current Egg Multiplier:", EggMultiplier.Value)
print("Sell Eggs at:", sellAtMultiplier)
print("UI Hotkey:", uiHotkey.Name)

print(
	"Auto Buy Chickens:",
	chickenEnabled
)

print(
	"Auto Sell Eggs:",
	autoSellEggs
)

print(
	"Auto Process Upgrade:",
	autoProcessUpgrade
)

print(
	"Auto Tier Upgrade:",
	autoTierUpgrade
)

print(
	"Auto Group Reward:",
	autoGroupReward
)

print(
	"Auto Collect Cash:",
	autoCollectCash
)

print(
	"Anti AFK:",
	antiAFK
)

print("------------------------------------")
