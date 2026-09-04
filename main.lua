--------------------------------------------------
-- CHICKEN FARM - FULL VERSION
--------------------------------------------------

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
-- ENVIRONMENT
--------------------------------------------------

local Environment = _G

pcall(function()
	if getgenv then
		Environment = getgenv()
	end
end)

--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local SETTINGS_FILE =
	"ChickenFarm_" .. tostring(game.PlaceId) .. ".json"

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

	uiHotkey = "RightControl",

	uiPosition = {
		xScale = 0.5,
		xOffset = -205,
		yScale = 0.5,
		yOffset = -300
	},

	lastGroupRewardAttempt = 0
}

local Settings = {}

local function CopyDefaults()

	for key, value in pairs(DEFAULT_SETTINGS) do

		if type(value) == "table" then

			Settings[key] = {}

			for childKey, childValue in pairs(value) do
				Settings[key][childKey] = childValue
			end

		else

			Settings[key] = value

		end

	end

end

CopyDefaults()

--------------------------------------------------
-- FILE SUPPORT
--------------------------------------------------

local FILE_SUPPORT =
	type(readfile) == "function"
	and type(writefile) == "function"
	and type(isfile) == "function"

local lastSavedJSON = nil

--------------------------------------------------
-- LOAD SETTINGS
--------------------------------------------------

local function LoadSettings()

	if not FILE_SUPPORT then
		return
	end

	local success, data =
		pcall(function()

			if not isfile(SETTINGS_FILE) then
				return nil
			end

			return HttpService:JSONDecode(
				readfile(SETTINGS_FILE)
			)

		end)

	if not success
		or type(data) ~= "table"
	then
		return
	end

	for key, defaultValue in pairs(DEFAULT_SETTINGS) do

		if data[key] ~= nil then

			if type(defaultValue) == "table"
				and type(data[key]) == "table"
			then

				for childKey, childDefault in pairs(defaultValue) do

					if data[key][childKey] ~= nil then

						Settings[key][childKey] =
							data[key][childKey]

					else

						Settings[key][childKey] =
							childDefault

					end

				end

			else

				Settings[key] = data[key]

			end

		end

	end

end

LoadSettings()

--------------------------------------------------
-- SAVE SETTINGS
--------------------------------------------------

local function SaveSettings(force)

	if not FILE_SUPPORT then
		return
	end

	local success, encoded =
		pcall(function()

			return HttpService:JSONEncode(
				Settings
			)

		end)

	if not success then
		return
	end

	if not force
		and encoded == lastSavedJSON
	then
		return
	end

	local saved =
		pcall(function()

			writefile(
				SETTINGS_FILE,
				encoded
			)

		end)

	if saved then
		lastSavedJSON = encoded
	end

end

--------------------------------------------------
-- CHICKEN OPTIONS
--------------------------------------------------

local chickenOptions = {
	1,
	5,
	25,
	100
}

local validChickenAmounts = {
	[1] = true,
	[5] = true,
	[25] = true,
	[100] = true
}

local selectedChickenAmount =
	tonumber(
		Settings.selectedChickenAmount
	) or 25

if not validChickenAmounts[selectedChickenAmount] then
	selectedChickenAmount = 25
end

local sellAtMultiplier =
	math.clamp(
		tonumber(
			Settings.sellAtMultiplier
		) or 1.25,
		0.5,
		1.5
	)

--------------------------------------------------
-- STATES
--------------------------------------------------

local chickenEnabled =
	Settings.chickenEnabled == true

local autoSellEggs =
	Settings.autoSellEggs == true

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

--------------------------------------------------
-- HOTKEY
--------------------------------------------------

local uiHotkey =
	Enum.KeyCode.RightControl

pcall(function()

	local saved =
		Enum.KeyCode[
			tostring(
				Settings.uiHotkey
			)
		]

	if saved then
		uiHotkey = saved
	end

end)

local waitingForHotkey = false

--------------------------------------------------
-- STOP OLD SCRIPT
--------------------------------------------------

if Environment.__ChickenFarmRuntime then

	local old =
		Environment.__ChickenFarmRuntime

	if old.Stop then
		pcall(old.Stop)
	end

end

--------------------------------------------------
-- RUNTIME
--------------------------------------------------

local Runtime = {
	Alive = true,
	Connections = {},
	RemoteBusy = {},
	LastErrors = {}
}

Environment.__ChickenFarmRuntime =
	Runtime

--------------------------------------------------
-- TRACK CONNECTION
--------------------------------------------------

local function TrackConnection(connection)

	table.insert(
		Runtime.Connections,
		connection
	)

	return connection

end

--------------------------------------------------
-- STOP
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

	local ui =
		PlayerGui:FindFirstChild(
			"PaperAutomationUI"
		)

	if ui then
		ui:Destroy()
	end

end

--------------------------------------------------
-- REMOTE
--------------------------------------------------

local Event =
	ReplicatedStorage
		:WaitForChild("Paper")
		:WaitForChild("Remotes")
		:WaitForChild("__remotefunction")

--------------------------------------------------
-- GAME VALUES
--------------------------------------------------

local EggMultiplier =
	ReplicatedStorage
		:WaitForChild("Values")
		:WaitForChild("EggMultiplier")

--------------------------------------------------
-- GAME HUD
--------------------------------------------------

local GameMainGui =
	PlayerGui:WaitForChild("Main")

local EggsTextObject =
	GameMainGui
		:WaitForChild("Eggs")
		:WaitForChild("Amount")
		:WaitForChild("Amt")

local CashTextObject =
	GameMainGui
		:WaitForChild("Currencies")
		:WaitForChild("Cash")
		:WaitForChild("List")
		:WaitForChild("Amount")

local GemsResetTextObject =
	GameMainGui
		:WaitForChild("Currencies")
		:WaitForChild("Gems")
		:WaitForChild("List")
		:WaitForChild("Collect")
		:WaitForChild("Collected")

--------------------------------------------------
-- ERROR THROTTLE
--------------------------------------------------

local ERROR_COOLDOWN = 10

local function WarnThrottled(
	key,
	message
)

	local now = os.clock()

	local previous =
		Runtime.LastErrors[key]
		or 0

	if now - previous < ERROR_COOLDOWN then
		return
	end

	Runtime.LastErrors[key] =
		now

	warn(message)

end

--------------------------------------------------
-- REMOTE HELPER
--------------------------------------------------

local function InvokeRemote(
	key,
	...
)

	if not Runtime.Alive then
		return false
	end

	if Runtime.RemoteBusy[key] then
		return false
	end

	Runtime.RemoteBusy[key] = true

	local args =
		table.pack(...)

	local success, result =
		pcall(function()

			return Event:InvokeServer(
				table.unpack(
					args,
					1,
					args.n
				)
			)

		end)

	Runtime.RemoteBusy[key] = false

	if not success then

		WarnThrottled(
			key,
			"[Chicken Farm] "
				.. key
				.. " failed: "
				.. tostring(result)
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

ScreenGui.DisplayOrder =
	99999

ScreenGui.Parent =
	PlayerGui

--------------------------------------------------
-- MAIN
--------------------------------------------------

local Main =
	Instance.new("Frame")

Main.Size =
	UDim2.new(
		0,
		410,
		0,
		600
	)

local pos =
	Settings.uiPosition
	or DEFAULT_SETTINGS.uiPosition

Main.Position =
	UDim2.new(
		tonumber(pos.xScale) or 0.5,
		tonumber(pos.xOffset) or -205,
		tonumber(pos.yScale) or 0.5,
		tonumber(pos.yOffset) or -300
	)

Main.BackgroundColor3 =
	Color3.fromRGB(
		22,
		22,
		22
	)

Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

local MainCorner =
	Instance.new("UICorner")

MainCorner.CornerRadius =
	UDim.new(0,14)

MainCorner.Parent =
	Main

--------------------------------------------------
-- TITLE
--------------------------------------------------

local Title =
	Instance.new("TextLabel")

Title.Size =
	UDim2.new(
		1,
		-20,
		0,
		48
	)

Title.Position =
	UDim2.new(
		0,
		10,
		0,
		0
	)

Title.BackgroundTransparency =
	1

Title.Text =
	"🐔  Chicken Farm"

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
-- DRAG
--------------------------------------------------

local dragging = false
local dragStart = nil
local dragInput = nil
local startPosition = nil

TrackConnection(

	Title.InputBegan:
		Connect(function(input)

			if input.UserInputType ~=
				Enum.UserInputType.MouseButton1
			then
				return
			end

			dragging = true
			dragStart = input.Position
			startPosition = Main.Position

		end)

)

TrackConnection(

	Title.InputChanged:
		Connect(function(input)

			if input.UserInputType ==
				Enum.UserInputType.MouseMovement
			then

				dragInput = input

			end

		end)

)

TrackConnection(

	UserInputService.InputChanged:
		Connect(function(input)

			if not dragging
				or input ~= dragInput
			then
				return
			end

			local delta =
				input.Position
				- dragStart

			Main.Position =
				UDim2.new(
					startPosition.X.Scale,
					startPosition.X.Offset + delta.X,
					startPosition.Y.Scale,
					startPosition.Y.Offset + delta.Y
				)

		end)

)

TrackConnection(

	UserInputService.InputEnded:
		Connect(function(input)

			if input.UserInputType ~=
				Enum.UserInputType.MouseButton1
			then
				return
			end

			if not dragging then
				return
			end

			dragging = false

			Settings.uiPosition = {
				xScale = Main.Position.X.Scale,
				xOffset = Main.Position.X.Offset,
				yScale = Main.Position.Y.Scale,
				yOffset = Main.Position.Y.Offset
			}

			SaveSettings()

		end)

)

--------------------------------------------------
-- TAB BUTTON
--------------------------------------------------

local function CreateTab(
	text,
	position
)

	local Button =
		Instance.new("TextButton")

	Button.Size =
		UDim2.new(
			0.5,
			-15,
			0,
			38
		)

	Button.Position =
		position

	Button.BackgroundColor3 =
		Color3.fromRGB(
			45,
			45,
			45
		)

	Button.Text =
		text

	Button.TextColor3 =
		Color3.fromRGB(
			255,
			255,
			255
		)

	Button.Font =
		Enum.Font.GothamBold

	Button.TextSize =
		15

	Button.Parent =
		Main

	local Corner =
		Instance.new("UICorner")

	Corner.CornerRadius =
		UDim.new(0,8)

	Corner.Parent =
		Button

	return Button
end

local FarmTab =
	CreateTab(
		"Farm",
		UDim2.new(0,10,0,48)
	)

local StatsTab =
	CreateTab(
		"Stats",
		UDim2.new(0.5,5,0,48)
	)

--------------------------------------------------
-- PAGES
--------------------------------------------------

local FarmPage =
	Instance.new("Frame")

FarmPage.Size =
	UDim2.new(
		1,
		0,
		1,
		-96
	)

FarmPage.Position =
	UDim2.new(
		0,
		0,
		0,
		96
	)

FarmPage.BackgroundTransparency =
	1

FarmPage.Parent =
	Main

local StatsPage =
	Instance.new("Frame")

StatsPage.Size =
	FarmPage.Size

StatsPage.Position =
	FarmPage.Position

StatsPage.BackgroundTransparency =
	1

StatsPage.Visible =
	false

StatsPage.Parent =
	Main

--------------------------------------------------
-- TABS
--------------------------------------------------

local currentPage =
	"Farm"

local function UpdateTabs()

	FarmPage.Visible =
		currentPage == "Farm"

	StatsPage.Visible =
		currentPage == "Stats"

	FarmTab.BackgroundColor3 =
		currentPage == "Farm"
		and Color3.fromRGB(55,145,80)
		or Color3.fromRGB(45,45,45)

	StatsTab.BackgroundColor3 =
		currentPage == "Stats"
		and Color3.fromRGB(55,145,80)
		or Color3.fromRGB(45,45,45)

end

UpdateTabs()

TrackConnection(
	FarmTab.Activated:
		Connect(function()
			currentPage = "Farm"
			UpdateTabs()
		end)
)

TrackConnection(
	StatsTab.Activated:
		Connect(function()
			currentPage = "Stats"
			UpdateTabs()
		end)
)

--------------------------------------------------
-- TOGGLE
--------------------------------------------------

local function CreateToggle(
	text,
	y,
	initialState,
	callback
)

	local Label =
		Instance.new("TextLabel")

	Label.Size =
		UDim2.new(
			0,
			240,
			0,
			40
		)

	Label.Position =
		UDim2.new(
			0,
			18,
			0,
			y
		)

	Label.BackgroundTransparency =
		1

	Label.Text =
		text

	Label.TextColor3 =
		Color3.fromRGB(
			238,
			238,
			238
		)

	Label.Font =
		Enum.Font.GothamMedium

	Label.TextSize =
		15

	Label.TextXAlignment =
		Enum.TextXAlignment.Left

	Label.Parent =
		FarmPage

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
			-118,
			0,
			y + 3
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
		FarmPage

	local Corner =
		Instance.new("UICorner")

	Corner.CornerRadius =
		UDim.new(0,8)

	Corner.Parent =
		Button

	local enabled =
		initialState == true

	local function Update()

		if enabled then

			Button.Text = "AN"

			Button.BackgroundColor3 =
				Color3.fromRGB(
					48,
					165,
					78
				)

		else

			Button.Text = "AUS"

			Button.BackgroundColor3 =
				Color3.fromRGB(
					165,
					58,
					58
				)

		end

	end

	Update()

	TrackConnection(

		Button.Activated:
			Connect(function()

				enabled =
					not enabled

				Update()

				callback(
					enabled
				)

				SaveSettings()

			end)

	)

end

--------------------------------------------------
-- CHICKEN AMOUNT
--------------------------------------------------

local ChickenLabel =
	Instance.new("TextLabel")

ChickenLabel.Size =
	UDim2.new(0,220,0,38)

ChickenLabel.Position =
	UDim2.new(0,18,0,0)

ChickenLabel.BackgroundTransparency =
	1

ChickenLabel.Text =
	"Chicken Amount"

ChickenLabel.TextColor3 =
	Color3.fromRGB(
		238,
		238,
		238
	)

ChickenLabel.Font =
	Enum.Font.GothamMedium

ChickenLabel.TextSize =
	15

ChickenLabel.TextXAlignment =
	Enum.TextXAlignment.Left

ChickenLabel.Parent =
	FarmPage

--------------------------------------------------
-- DROPDOWN
--------------------------------------------------

local Dropdown =
	Instance.new("TextButton")

Dropdown.Size =
	UDim2.new(0,140,0,34)

Dropdown.Position =
	UDim2.new(1,-158,0,2)

Dropdown.BackgroundColor3 =
	Color3.fromRGB(45,45,45)

Dropdown.Text =
	tostring(selectedChickenAmount)
	.. " ▼"

Dropdown.TextColor3 =
	Color3.new(1,1,1)

Dropdown.Font =
	Enum.Font.GothamBold

Dropdown.TextSize =
	14

Dropdown.ZIndex =
	50

Dropdown.Parent =
	FarmPage

local DropdownCorner =
	Instance.new("UICorner")

DropdownCorner.CornerRadius =
	UDim.new(0,8)

DropdownCorner.Parent =
	Dropdown

--------------------------------------------------
-- DROPDOWN LIST
--------------------------------------------------

local DropdownList =
	Instance.new("Frame")

DropdownList.Size =
	UDim2.new(0,140,0,152)

DropdownList.Position =
	UDim2.new(1,-158,0,38)

DropdownList.BackgroundColor3 =
	Color3.fromRGB(30,30,30)

DropdownList.BorderSizePixel =
	0

DropdownList.Visible =
	false

DropdownList.ZIndex =
	100

DropdownList.Parent =
	FarmPage

local DropdownListCorner =
	Instance.new("UICorner")

DropdownListCorner.CornerRadius =
	UDim.new(0,8)

DropdownListCorner.Parent =
	DropdownList

for index, amount in ipairs(
	chickenOptions
) do

	local Option =
		Instance.new("TextButton")

	Option.Size =
		UDim2.new(1,-8,0,34)

	Option.Position =
		UDim2.new(
			0,
			4,
			0,
			4 + ((index - 1) * 36)
		)

	Option.BackgroundColor3 =
		Color3.fromRGB(42,42,42)

	Option.BorderSizePixel =
		0

	Option.Text =
		tostring(amount)

	Option.TextColor3 =
		Color3.new(1,1,1)

	Option.Font =
		Enum.Font.GothamBold

	Option.TextSize =
		15

	Option.Active =
		true

	Option.ZIndex =
		101 + index

	Option.Parent =
		DropdownList

	local Corner =
		Instance.new("UICorner")

	Corner.CornerRadius =
		UDim.new(0,6)

	Corner.Parent =
		Option

	TrackConnection(

		Option.Activated:
			Connect(function()

				selectedChickenAmount =
					amount

				Settings.selectedChickenAmount =
					amount

				Dropdown.Text =
					tostring(amount)
					.. " ▼"

				DropdownList.Visible =
					false

				SaveSettings()

			end)

	)

end

TrackConnection(

	Dropdown.Activated:
		Connect(function()

			DropdownList.Visible =
				not DropdownList.Visible

			Dropdown.Text =
				tostring(selectedChickenAmount)
				..
				(
					DropdownList.Visible
					and " ▲"
					or " ▼"
				)

		end)

)

--------------------------------------------------
-- AUTO BUY
--------------------------------------------------

CreateToggle(
	"Auto Buy Chickens",
	44,
	chickenEnabled,
	function(value)

		chickenEnabled =
			value

		Settings.chickenEnabled =
			value

	end
)

--------------------------------------------------
-- AUTO SELL
--------------------------------------------------

CreateToggle(
	"Auto Sell Eggs",
	86,
	autoSellEggs,
	function(value)

		autoSellEggs =
			value

		Settings.autoSellEggs =
			value

	end
)

--------------------------------------------------
-- CURRENT MULTIPLIER
--------------------------------------------------

local MultiLabel =
	Instance.new("TextLabel")

MultiLabel.Size =
	UDim2.new(0,230,0,36)

MultiLabel.Position =
	UDim2.new(0,18,0,128)

MultiLabel.BackgroundTransparency =
	1

MultiLabel.Text =
	"Current Egg Multiplier"

MultiLabel.TextColor3 =
	Color3.fromRGB(
		238,
		238,
		238
	)

MultiLabel.Font =
	Enum.Font.GothamMedium

MultiLabel.TextSize =
	15

MultiLabel.TextXAlignment =
	Enum.TextXAlignment.Left

MultiLabel.Parent =
	FarmPage

local MultiValue =
	Instance.new("TextLabel")

MultiValue.Size =
	UDim2.new(0,100,0,32)

MultiValue.Position =
	UDim2.new(1,-118,0,130)

MultiValue.BackgroundColor3 =
	Color3.fromRGB(39,39,39)

MultiValue.TextColor3 =
	Color3.new(1,1,1)

MultiValue.Font =
	Enum.Font.GothamBold

MultiValue.TextSize =
	15

MultiValue.Parent =
	FarmPage

--------------------------------------------------
-- SELL THRESHOLD
--------------------------------------------------

local SellLabel =
	Instance.new("TextLabel")

SellLabel.Size =
	UDim2.new(0,220,0,36)

SellLabel.Position =
	UDim2.new(0,18,0,168)

SellLabel.BackgroundTransparency =
	1

SellLabel.Text =
	"Sell at Multiplier"

SellLabel.TextColor3 =
	Color3.fromRGB(
		238,
		238,
		238
	)

SellLabel.Font =
	Enum.Font.GothamMedium

SellLabel.TextSize =
	15

SellLabel.TextXAlignment =
	Enum.TextXAlignment.Left

SellLabel.Parent =
	FarmPage

local MultiplierBox =
	Instance.new("TextBox")

MultiplierBox.Size =
	UDim2.new(0,100,0,32)

MultiplierBox.Position =
	UDim2.new(1,-118,0,170)

MultiplierBox.BackgroundColor3 =
	Color3.fromRGB(45,45,45)

MultiplierBox.Text =
	tostring(sellAtMultiplier)

MultiplierBox.PlaceholderText =
	"0.5 - 1.5"

MultiplierBox.TextColor3 =
	Color3.new(1,1,1)

MultiplierBox.Font =
	Enum.Font.GothamBold

MultiplierBox.TextSize =
	15

MultiplierBox.ClearTextOnFocus =
	false

MultiplierBox.Parent =
	FarmPage

local MultiplierCorner =
	Instance.new("UICorner")

MultiplierCorner.CornerRadius =
	UDim.new(0,8)

MultiplierCorner.Parent =
	MultiplierBox

TrackConnection(

	MultiplierBox.FocusLost:
		Connect(function()

			local value =
				tonumber(
					MultiplierBox.Text:
						gsub(",",".")
				)

			if value then

				value =
					math.clamp(
						value,
						0.5,
						1.5
					)

				value =
					math.floor(
						value * 100 + 0.5
					) / 100

				sellAtMultiplier =
					value

				Settings.sellAtMultiplier =
					value

				SaveSettings()

			end

			MultiplierBox.Text =
				tostring(
					sellAtMultiplier
				)

		end)

)

--------------------------------------------------
-- OTHER TOGGLES
--------------------------------------------------

CreateToggle(
	"Auto Process Upgrade",
	214,
	autoProcessUpgrade,
	function(value)

		autoProcessUpgrade =
			value

		Settings.autoProcessUpgrade =
			value

	end
)

CreateToggle(
	"Auto Tier Upgrade",
	256,
	autoTierUpgrade,
	function(value)

		autoTierUpgrade =
			value

		Settings.autoTierUpgrade =
			value

	end
)

CreateToggle(
	"Auto Group Reward",
	298,
	autoGroupReward,
	function(value)

		autoGroupReward =
			value

		Settings.autoGroupReward =
			value

	end
)

CreateToggle(
	"Auto Collect Cash",
	340,
	autoCollectCash,
	function(value)

		autoCollectCash =
			value

		Settings.autoCollectCash =
			value

	end
)

CreateToggle(
	"Anti AFK",
	382,
	antiAFK,
	function(value)

		antiAFK =
			value

		Settings.antiAFK =
			value

	end
)

--------------------------------------------------
-- HOTKEY
--------------------------------------------------

local function GetKeyName(key)

	if key == Enum.KeyCode.RightControl then
		return "Right Ctrl"
	end

	if key == Enum.KeyCode.LeftControl then
		return "Left Ctrl"
	end

	if key == Enum.KeyCode.RightShift then
		return "Right Shift"
	end

	if key == Enum.KeyCode.LeftShift then
		return "Left Shift"
	end

	return key.Name
end

local HotkeyLabel =
	Instance.new("TextLabel")

HotkeyLabel.Size =
	UDim2.new(0,220,0,36)

HotkeyLabel.Position =
	UDim2.new(0,18,0,428)

HotkeyLabel.BackgroundTransparency =
	1

HotkeyLabel.Text =
	"UI Hotkey"

HotkeyLabel.TextColor3 =
	Color3.fromRGB(
		238,
		238,
		238
	)

HotkeyLabel.Font =
	Enum.Font.GothamMedium

HotkeyLabel.TextSize =
	15

HotkeyLabel.TextXAlignment =
	Enum.TextXAlignment.Left

HotkeyLabel.Parent =
	FarmPage

local HotkeyButton =
	Instance.new("TextButton")

HotkeyButton.Size =
	UDim2.new(0,100,0,32)

HotkeyButton.Position =
	UDim2.new(1,-118,0,430)

HotkeyButton.BackgroundColor3 =
	Color3.fromRGB(45,45,45)

HotkeyButton.Text =
	GetKeyName(uiHotkey)

HotkeyButton.TextColor3 =
	Color3.new(1,1,1)

HotkeyButton.Font =
	Enum.Font.GothamBold

HotkeyButton.TextSize =
	13

HotkeyButton.Parent =
	FarmPage

local HotkeyCorner =
	Instance.new("UICorner")

HotkeyCorner.CornerRadius =
	UDim.new(0,8)

HotkeyCorner.Parent =
	HotkeyButton

TrackConnection(

	HotkeyButton.Activated:
		Connect(function()

			waitingForHotkey =
				true

			HotkeyButton.Text =
				"Press Key..."

		end)

)

--------------------------------------------------
-- STATS TITLE
--------------------------------------------------

local StatsTitle =
	Instance.new("TextLabel")

StatsTitle.Size =
	UDim2.new(1,-36,0,42)

StatsTitle.Position =
	UDim2.new(0,18,0,4)

StatsTitle.BackgroundTransparency =
	1

StatsTitle.Text =
	"Session Stats"

StatsTitle.TextColor3 =
	Color3.new(1,1,1)

StatsTitle.Font =
	Enum.Font.GothamBold

StatsTitle.TextSize =
	20

StatsTitle.TextXAlignment =
	Enum.TextXAlignment.Left

StatsTitle.Parent =
	StatsPage

--------------------------------------------------
-- STAT ROW
--------------------------------------------------

local function CreateStatRow(
	name,
	y
)

	local Label =
		Instance.new("TextLabel")

	Label.Size =
		UDim2.new(0.50,-20,0,42)

	Label.Position =
		UDim2.new(0,18,0,y)

	Label.BackgroundTransparency =
		1

	Label.Text =
		name

	Label.TextColor3 =
		Color3.fromRGB(
			225,
			225,
			225
		)

	Label.Font =
		Enum.Font.GothamMedium

	Label.TextSize =
		15

	Label.TextXAlignment =
		Enum.TextXAlignment.Left

	Label.Parent =
		StatsPage

	local Value =
		Instance.new("TextLabel")

	Value.Size =
		UDim2.new(0.50,-25,0,36)

	Value.Position =
		UDim2.new(0.5,7,0,y + 3)

	Value.BackgroundColor3 =
		Color3.fromRGB(39,39,39)

	Value.Text =
		"N/A"

	Value.TextColor3 =
		Color3.new(1,1,1)

	Value.Font =
		Enum.Font.GothamBold

	Value.TextSize =
		14

	Value.Parent =
		StatsPage

	local Corner =
		Instance.new("UICorner")

	Corner.CornerRadius =
		UDim.new(0,8)

	Corner.Parent =
		Value

	return Value
end

--------------------------------------------------
-- STATS
--------------------------------------------------

local EggsStat =
	CreateStatRow(
		"Eggs",
		52
	)

local EPSStat =
	CreateStatRow(
		"Eggs / second",
		100
	)

local CashStat =
	CreateStatRow(
		"Cash",
		148
	)

local MultiplierStat =
	CreateStatRow(
		"Egg Multiplier",
		196
	)

local GroupStat =
	CreateStatRow(
		"Next Group Reward",
		244
	)

local RebirthProgressStat =
	CreateStatRow(
		"Rebirth Progress",
		292
	)

local GemsResetStat =
	CreateStatRow(
		"Gems Reset",
		340
	)

--------------------------------------------------
-- NUMBER SUFFIXES
--------------------------------------------------

local SUFFIXES = {
	[""] = 1,
	["k"] = 1e3,
	["m"] = 1e6,
	["b"] = 1e9,
	["t"] = 1e12,
	["qd"] = 1e15,
	["qn"] = 1e18,
	["sx"] = 1e21,
	["sp"] = 1e24,
	["oc"] = 1e27,
	["no"] = 1e30,
	["dc"] = 1e33
}

local FORMAT_SUFFIXES = {
	{1e33, "Dc"},
	{1e30, "No"},
	{1e27, "Oc"},
	{1e24, "Sp"},
	{1e21, "Sx"},
	{1e18, "Qn"},
	{1e15, "Qd"},
	{1e12, "T"},
	{1e9, "B"},
	{1e6, "M"},
	{1e3, "K"}
}

--------------------------------------------------
-- PARSE LARGE NUMBER
--------------------------------------------------

local function ParseLargeNumber(text)

	if type(text) ~= "string" then
		return nil
	end

	text =
		text:
			gsub("<.->", ""):
			gsub("%$", ""):
			gsub(",", ""):
			gsub("%s+", ""):
			gsub("%+", "")

	local numberPart, suffix =
		text:match(
			"([%d%.]+)([%a]*)"
		)

	if not numberPart then
		return nil
	end

	local number =
		tonumber(numberPart)

	if not number then
		return nil
	end

	suffix =
		(suffix or ""):lower()

	local multiplier =
		SUFFIXES[suffix]

	if multiplier == nil then
		return nil
	end

	return number * multiplier
end

--------------------------------------------------
-- FORMAT LARGE NUMBER
--------------------------------------------------

local function FormatLargeNumber(value)

	value =
		tonumber(value)

	if not value then
		return "N/A"
	end

	local abs =
		math.abs(value)

	for _, entry in ipairs(
		FORMAT_SUFFIXES
	) do

		if abs >= entry[1] then

			return string.format(
				"%.2f%s",
				value / entry[1],
				entry[2]
			)

		end

	end

	if abs >= 100 then

		return string.format(
			"%.0f",
			value
		)

	end

	return string.format(
		"%.2f",
		value
	)
end

--------------------------------------------------
-- TIME FORMAT
--------------------------------------------------

local function FormatTime(seconds)

	if not seconds then
		return "N/A"
	end

	seconds =
		math.max(
			0,
			math.floor(seconds)
		)

	local hours =
		math.floor(
			seconds / 3600
		)

	local minutes =
		math.floor(
			(seconds % 3600) / 60
		)

	local secs =
		seconds % 60

	if hours > 0 then

		return string.format(
			"%02dh %02dm %02ds",
			hours,
			minutes,
			secs
		)

	end

	return string.format(
		"%02dm %02ds",
		minutes,
		secs
	)
end

--------------------------------------------------
-- GUI TEXT
--------------------------------------------------

local function GetObjectText(object)

	if object:IsA("TextLabel")
		or object:IsA("TextButton")
		or object:IsA("TextBox")
	then

		return tostring(
			object.Text
		):gsub(
			"<.->",
			""
		)

	end

	return nil
end

--------------------------------------------------
-- FIND REBIRTH REQUIREMENT
--------------------------------------------------

local function FindRebirthRequirement()

	local bestCurrent =
		nil

	local bestRequired =
		nil

	for _, object in ipairs(
		PlayerGui:GetDescendants()
	) do

		if not object:IsDescendantOf(
			ScreenGui
		) then

			local text =
				GetObjectText(
					object
				)

			if text
				and text:find(
					"/",
					1,
					true
				)
			then

				local left, right =
					text:match(
						"%$?%s*([%d%.]+%a*)%s*/%s*%$?%s*([%d%.]+%a*)"
					)

				if left
					and right
				then

					local current =
						ParseLargeNumber(
							left
						)

					local required =
						ParseLargeNumber(
							right
						)

					if current
						and required
						and required > 0
						and current <= required
					then

						if not bestRequired
							or required >
								bestRequired
						then

							bestCurrent =
								current

							bestRequired =
								required

						end

					end

				end

			end

		end

	end

	return bestCurrent,
		bestRequired
end

--------------------------------------------------
-- EGGS PER SECOND
--------------------------------------------------

local lastEggValue =
	nil

local lastEggTime =
	nil

local eggsPerSecond =
	nil

local lastDepositTime =
	0

--------------------------------------------------
-- GROUP REWARD
--------------------------------------------------

local GROUP_INTERVAL =
	600

local function GetGroupRemaining()

	local last =
		tonumber(
			Settings.lastGroupRewardAttempt
		) or 0

	if last <= 0 then
		return 0
	end

	return math.max(
		0,
		GROUP_INTERVAL
		- (
			os.time() - last
		)
	)
end

--------------------------------------------------
-- UPDATE STATS
--------------------------------------------------

local function UpdateStats()

	local nowClock =
		os.clock()

	--------------------------------------------------
	-- EGGS
	--------------------------------------------------

	local eggText =
		tostring(
			EggsTextObject.Text
		)

	EggsStat.Text =
		eggText

	local currentEgg =
		ParseLargeNumber(
			eggText
		)

	if currentEgg then

		if lastEggValue
			and lastEggTime
		then

			local elapsed =
				nowClock
				- lastEggTime

			local difference =
				currentEgg
				- lastEggValue

			if difference >= 0
				and elapsed > 0
				and nowClock - lastDepositTime > 1
			then

				local rate =
					difference
					/ elapsed

				if eggsPerSecond then

					eggsPerSecond =
						eggsPerSecond * 0.70
						+ rate * 0.30

				else

					eggsPerSecond =
						rate

				end

			end

		end

		lastEggValue =
			currentEgg

		lastEggTime =
			nowClock

	end

	if eggsPerSecond then

		EPSStat.Text =
			FormatLargeNumber(
				eggsPerSecond
			)
			.. "/s"

	else

		EPSStat.Text =
			"Berechne..."

	end

	--------------------------------------------------
	-- CASH
	--------------------------------------------------

	CashStat.Text =
		tostring(
			CashTextObject.Text
		)

	--------------------------------------------------
	-- MULTIPLIER
	--------------------------------------------------

	local multiplier =
		tonumber(
			EggMultiplier.Value
		)
		or 0

	MultiValue.Text =
		string.format(
			"%.2fx",
			multiplier
		)

	MultiplierStat.Text =
		MultiValue.Text

	--------------------------------------------------
	-- GROUP REWARD
	--------------------------------------------------

	if autoGroupReward then

		local remaining =
			GetGroupRemaining()

		if remaining <= 0 then

			GroupStat.Text =
				"Ready"

		else

			GroupStat.Text =
				FormatTime(
					remaining
				)

		end

	else

		GroupStat.Text =
			"AUS"

	end

	--------------------------------------------------
	-- REBIRTH PROGRESS
	--------------------------------------------------

	local rebirthCurrent,
		rebirthRequired =
		FindRebirthRequirement()

	if rebirthCurrent
		and rebirthRequired
	then

		RebirthProgressStat.Text =
			FormatLargeNumber(
				rebirthCurrent
			)
			.. " / "
			.. FormatLargeNumber(
				rebirthRequired
			)

	else

		RebirthProgressStat.Text =
			"Rebirth öffnen"

	end

	--------------------------------------------------
	-- GEMS RESET
	-- DIRECT ORIGINAL GAME TEXT
	--------------------------------------------------

	local success, gemsText =
		pcall(function()

			return tostring(
				GemsResetTextObject.Text
			)

		end)

	if success
		and gemsText
		and gemsText ~= ""
	then

		GemsResetStat.Text =
			gemsText

	else

		GemsResetStat.Text =
			"N/A"

	end

end

--------------------------------------------------
-- ANTI AFK
--------------------------------------------------

TrackConnection(

	Player.Idled:
		Connect(function()

			if not antiAFK then
				return
			end

			pcall(function()

				VirtualUser:
					CaptureController()

				VirtualUser:
					ClickButton2(
						Vector2.zero
					)

			end)

		end)

)

--------------------------------------------------
-- SCHEDULER
--------------------------------------------------

local nextBuy = 0
local nextSell = 0
local nextProcess = 0
local nextTier = 0
local nextCash = 0
local nextStats = 0

task.spawn(function()

	while Runtime.Alive do

		local now =
			os.clock()

		--------------------------------------------------
		-- BUY CHICKENS
		--------------------------------------------------

		if now >= nextBuy then

			nextBuy =
				now + 0.5

			if chickenEnabled then

				InvokeRemote(
					"Buy Chickens",
					"Buy Chickens",
					selectedChickenAmount
				)

			end

		end

		--------------------------------------------------
		-- SELL EGGS CONTINUOUSLY
		--------------------------------------------------

		if now >= nextSell then

			nextSell =
				now + 0.5

			if autoSellEggs then

				local multiplier =
					tonumber(
						EggMultiplier.Value
					)
					or 0

				if multiplier >=
					sellAtMultiplier
				then

					local success =
						InvokeRemote(
							"Deposit Eggs",
							"Deposit Eggs"
						)

					if success then

						lastDepositTime =
							os.clock()

					end

				end

			end

		end

		--------------------------------------------------
		-- PROCESS UPGRADE
		--------------------------------------------------

		if now >= nextProcess then

			nextProcess =
				now + 1

			if autoProcessUpgrade then

				InvokeRemote(
					"Upgrade Process Level",
					"Upgrade Process Level"
				)

			end

		end

		--------------------------------------------------
		-- TIER UPGRADE
		--------------------------------------------------

		if now >= nextTier then

			nextTier =
				now + 1

			if autoTierUpgrade then

				InvokeRemote(
					"Upgrade Buy Tier Level",
					"Upgrade Buy Tier Level"
				)

			end

		end

		--------------------------------------------------
		-- COLLECT CASH
		--------------------------------------------------

		if now >= nextCash then

			nextCash =
				now + 1

			if autoCollectCash then

				InvokeRemote(
					"Collect Cash",
					"Collect Cash"
				)

			end

		end

		--------------------------------------------------
		-- GROUP REWARD
		--------------------------------------------------

		if autoGroupReward
			and GetGroupRemaining() <= 0
		then

			Settings.lastGroupRewardAttempt =
				os.time()

			SaveSettings()

			InvokeRemote(
				"Claim Group Reward",
				"Claim Group Reward"
			)

		end

		--------------------------------------------------
		-- STATS
		--------------------------------------------------

		if now >= nextStats then

			nextStats =
				now + 0.5

			UpdateStats()

		end

		task.wait(0.05)

	end

end)

--------------------------------------------------
-- INPUT
--------------------------------------------------

TrackConnection(

	UserInputService.InputBegan:
		Connect(function(
			input,
			gameProcessed
		)

			--------------------------------------------------
			-- SET HOTKEY
			--------------------------------------------------

			if waitingForHotkey then

				if input.UserInputType ~=
					Enum.UserInputType.Keyboard
				then
					return
				end

				if input.KeyCode ==
					Enum.KeyCode.Escape
				then

					waitingForHotkey =
						false

					HotkeyButton.Text =
						GetKeyName(
							uiHotkey
						)

					return

				end

				if input.KeyCode ~=
					Enum.KeyCode.Unknown
				then

					uiHotkey =
						input.KeyCode

					Settings.uiHotkey =
						uiHotkey.Name

					waitingForHotkey =
						false

					HotkeyButton.Text =
						GetKeyName(
							uiHotkey
						)

					SaveSettings()

				end

				return

			end

			--------------------------------------------------
			-- IGNORE WHILE TYPING
			--------------------------------------------------

			if UserInputService:
				GetFocusedTextBox()
			then
				return
			end

			--------------------------------------------------
			-- ESC CLOSE DROPDOWN
			--------------------------------------------------

			if input.KeyCode ==
				Enum.KeyCode.Escape
			then

				DropdownList.Visible =
					false

				Dropdown.Text =
					tostring(
						selectedChickenAmount
					)
					.. " ▼"

				return

			end

			if gameProcessed then
				return
			end

			--------------------------------------------------
			-- UI HOTKEY
			--------------------------------------------------

			if input.UserInputType ==
					Enum.UserInputType.Keyboard
				and input.KeyCode ==
					uiHotkey
			then

				Main.Visible =
					not Main.Visible

				DropdownList.Visible =
					false

			end

		end)

)

--------------------------------------------------
-- CLEANUP
--------------------------------------------------

TrackConnection(

	ScreenGui.Destroying:
		Connect(function()

			if Environment.__ChickenFarmRuntime
				== Runtime
			then

				Runtime.Alive =
					false

			end

		end)

)

--------------------------------------------------
-- SAVE SETTINGS
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

SaveSettings(true)

--------------------------------------------------
-- INITIAL UPDATE
--------------------------------------------------

UpdateStats()

--------------------------------------------------
-- READY
--------------------------------------------------

print("------------------------------------")
print("Chicken Farm loaded")
print("Chicken Amount:", selectedChickenAmount)
print("Eggs:", EggsTextObject.Text)
print("Cash:", CashTextObject.Text)
print("Egg Multiplier:", EggMultiplier.Value)
print("Gems Reset:", GemsResetTextObject.Text)
print("Sell threshold:", sellAtMultiplier)
print("------------------------------------")
