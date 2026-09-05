-- Chicken Farm 2.0 - improved single-file version
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui", 15)
if not PlayerGui then warn("[Chicken Farm] PlayerGui fehlt.") return end

local Env = _G
pcall(function() if getgenv then Env = getgenv() end end)
if Env.__ChickenFarmRuntime and Env.__ChickenFarmRuntime.Stop then pcall(Env.__ChickenFarmRuntime.Stop) end

local VERSION = "2.0.0"
local SETTINGS_FILE = "ChickenFarm_" .. tostring(game.PlaceId) .. ".json"
local GROUP_INTERVAL, ERROR_COOLDOWN = 600, 10
local C = {
	background = Color3.fromRGB(20, 21, 24), surface = Color3.fromRGB(32, 34, 39),
	control = Color3.fromRGB(43, 46, 52), accent = Color3.fromRGB(62, 176, 92),
	danger = Color3.fromRGB(190, 65, 65), warning = Color3.fromRGB(218, 158, 54),
	text = Color3.fromRGB(242, 242, 244), muted = Color3.fromRGB(170, 174, 184),
	outline = Color3.fromRGB(65, 69, 78),
}
local DEFAULTS = {
	version = 2, chickenEnabled = false, selectedChickenAmount = 25,
	autoSellEggs = false, sellAtMultiplier = 1.25,
	autoProcessUpgrade = false, autoTierUpgrade = false,
	autoGroupReward = false, autoCollectCash = false, antiAFK = false,
	uiHotkey = "RightControl",
	uiPosition = { xScale = 0.5, xOffset = -215, yScale = 0.5, yOffset = -285 },
	lastGroupRewardAttempt = 0,
}

local function Clone(t)
	local result = {}
	for k, v in pairs(t) do result[k] = type(v) == "table" and Clone(v) or v end
	return result
end
local Settings = Clone(DEFAULTS)
local FILE_SUPPORT = type(readfile) == "function" and type(writefile) == "function" and type(isfile) == "function"
local lastJSON

local function ValidateSettings()
	local amounts = { [1] = true, [5] = true, [25] = true, [100] = true }
	Settings.selectedChickenAmount = tonumber(Settings.selectedChickenAmount) or 25
	if not amounts[Settings.selectedChickenAmount] then Settings.selectedChickenAmount = 25 end
	Settings.sellAtMultiplier = math.clamp(tonumber(Settings.sellAtMultiplier) or 1.25, .5, 1.5)
	Settings.sellAtMultiplier = math.floor(Settings.sellAtMultiplier * 20 + .5) / 20
	Settings.lastGroupRewardAttempt = math.max(0, tonumber(Settings.lastGroupRewardAttempt) or 0)
	for _, key in ipairs({"chickenEnabled","autoSellEggs","autoProcessUpgrade","autoTierUpgrade","autoGroupReward","autoCollectCash","antiAFK"}) do
		Settings[key] = Settings[key] == true
	end
	if typeof(Enum.KeyCode[tostring(Settings.uiHotkey)]) ~= "EnumItem" then Settings.uiHotkey = "RightControl" end
	if type(Settings.uiPosition) ~= "table" then Settings.uiPosition = Clone(DEFAULTS.uiPosition) end
	for k, fallback in pairs(DEFAULTS.uiPosition) do Settings.uiPosition[k] = tonumber(Settings.uiPosition[k]) or fallback end
	Settings.version = 2
end
local function LoadSettings()
	if not FILE_SUPPORT then return end
	local ok, data = pcall(function()
		if not isfile(SETTINGS_FILE) then return nil end
		return HttpService:JSONDecode(readfile(SETTINGS_FILE))
	end)
	if not ok or type(data) ~= "table" then return end
	for key, default in pairs(DEFAULTS) do
		if data[key] ~= nil then
			if type(default) == "table" and type(data[key]) == "table" then
				for child in pairs(default) do if data[key][child] ~= nil then Settings[key][child] = data[key][child] end end
			else Settings[key] = data[key] end
		end
	end
	ValidateSettings()
end
local function SaveSettings(force)
	if not FILE_SUPPORT then return end
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, Settings)
	if not ok or (not force and encoded == lastJSON) then return end
	if pcall(writefile, SETTINGS_FILE, encoded) then lastJSON = encoded end
end
LoadSettings()

local Runtime = { Alive = true, Connections = {}, Busy = {}, LastErrors = {}, Controls = {} }
Env.__ChickenFarmRuntime = Runtime
local function Track(connection) table.insert(Runtime.Connections, connection) return connection end
local function WaitPath(root, timeout, ...)
	local current = root
	for _, name in ipairs({...}) do
		current = current and current:WaitForChild(name, timeout)
		if not current then return nil, name end
	end
	return current
end

local Event, missing1 = WaitPath(ReplicatedStorage, 10, "Paper", "Remotes", "__remotefunction")
local EggMultiplier, missing2 = WaitPath(ReplicatedStorage, 10, "Values", "EggMultiplier")
local GameMainGui, missing3 = WaitPath(PlayerGui, 10, "Main")
if not Event or not EggMultiplier or not GameMainGui then
	warn("[Chicken Farm] Benötigtes Spielelement fehlt: " .. tostring(missing1 or missing2 or missing3))
	return
end
local EggsTextObject = WaitPath(GameMainGui, 5, "Eggs", "Amount", "Amt")
local CashTextObject = WaitPath(GameMainGui, 5, "Currencies", "Cash", "List", "Amount")
local GemsResetTextObject = WaitPath(GameMainGui, 5, "Currencies", "Gems", "List", "Collect", "Collected")

local SUFFIXES = {[""]=1,k=1e3,m=1e6,b=1e9,t=1e12,qd=1e15,qn=1e18,sx=1e21,sp=1e24,oc=1e27,no=1e30,dc=1e33}
local FORMATS = {{1e33,"Dc"},{1e30,"No"},{1e27,"Oc"},{1e24,"Sp"},{1e21,"Sx"},{1e18,"Qn"},{1e15,"Qd"},{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}}
local function ParseNumber(text)
	if text == nil then return nil end
	text = tostring(text):gsub("<.->",""):gsub("%$",""):gsub(",",""):gsub("%s+",""):gsub("%+","")
	local numberPart, suffix = text:match("^([%d%.]+)([%a]*)")
	local number, multiplier = tonumber(numberPart), SUFFIXES[(suffix or ""):lower()]
	return number and multiplier and number * multiplier or nil
end
local function FormatNumber(value)
	value = tonumber(value)
	if not value then return "N/V" end
	for _, item in ipairs(FORMATS) do if math.abs(value) >= item[1] then return string.format("%.2f%s", value / item[1], item[2]) end end
	return math.abs(value) >= 100 and string.format("%.0f", value) or string.format("%.2f", value)
end
local function FormatTime(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	local h, m, s = math.floor(seconds/3600), math.floor((seconds%3600)/60), seconds%60
	return h > 0 and string.format("%02dh %02dm %02ds",h,m,s) or string.format("%02dm %02ds",m,s)
end
local function ObjectText(object)
	if object and (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then return tostring(object.Text):gsub("<.->","") end
end

local oldUI = PlayerGui:FindFirstChild("PaperAutomationUI")
if oldUI then oldUI:Destroy() end
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name, ScreenGui.ResetOnSpawn, ScreenGui.DisplayOrder = "PaperAutomationUI", false, 99999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui
local Main = Instance.new("Frame")
Main.Name, Main.Size = "Main", UDim2.fromOffset(430,570)
Main.Position = UDim2.new(Settings.uiPosition.xScale,Settings.uiPosition.xOffset,Settings.uiPosition.yScale,Settings.uiPosition.yOffset)
Main.BackgroundColor3, Main.BorderSizePixel, Main.Active, Main.ClipsDescendants = C.background,0,true,true
Main.Parent = ScreenGui
local mainCorner = Instance.new("UICorner",Main) mainCorner.CornerRadius = UDim.new(0,14)
local stroke = Instance.new("UIStroke",Main) stroke.Color = C.outline
local Scale = Instance.new("UIScale",Main)
local function UpdateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		local v = camera.ViewportSize
		Scale.Scale = math.clamp(math.min((v.X-20)/430,(v.Y-20)/570),.62,1)
	end
end
UpdateScale()
if Workspace.CurrentCamera then Track(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale)) end

local function Round(object,radius) local corner=Instance.new("UICorner",object) corner.CornerRadius=UDim.new(0,radius or 8) end
local function Text(parent,text,size,color,bold)
	local x=Instance.new("TextLabel") x.BackgroundTransparency=1 x.Text=text x.TextColor3=color or C.text
	x.Font=bold and Enum.Font.GothamBold or Enum.Font.GothamMedium x.TextSize=size or 14
	x.TextXAlignment=Enum.TextXAlignment.Left x.Parent=parent return x
end
local function Button(parent,text,width)
	local x=Instance.new("TextButton") x.Size=UDim2.fromOffset(width or 90,34) x.BackgroundColor3=C.control
	x.BorderSizePixel=0 x.Text=text x.TextColor3=C.text x.Font=Enum.Font.GothamBold x.TextSize=13 x.Parent=parent Round(x) return x
end
local Header=Instance.new("Frame",Main) Header.Size=UDim2.new(1,0,0,52) Header.BackgroundTransparency=1
local Title=Text(Header,"🐔  Chicken Farm",20,C.text,true) Title.Size=UDim2.new(1,-118,1,0) Title.Position=UDim2.fromOffset(14,0)
local MinButton=Button(Header,"—",34) MinButton.Position=UDim2.new(1,-78,0,9) MinButton.TextSize=18
local CloseButton=Button(Header,"×",34) CloseButton.Position=UDim2.new(1,-40,0,9) CloseButton.BackgroundColor3=C.danger CloseButton.TextSize=18
local TabBar=Instance.new("Frame",Main) TabBar.Size=UDim2.new(1,-20,0,40) TabBar.Position=UDim2.fromOffset(10,52) TabBar.BackgroundTransparency=1
local FarmTab=Button(TabBar,"Farm",199) FarmTab.Size=UDim2.new(.5,-3,0,36)
local StatsTab=Button(TabBar,"Statistiken",199) StatsTab.Size=UDim2.new(.5,-3,0,36) StatsTab.Position=UDim2.new(.5,3,0,0)
local Pages=Instance.new("Frame",Main) Pages.Size=UDim2.new(1,0,1,-130) Pages.Position=UDim2.fromOffset(0,94) Pages.BackgroundTransparency=1
local function Page()
	local p=Instance.new("ScrollingFrame") p.Size=UDim2.fromScale(1,1) p.BackgroundTransparency=1 p.BorderSizePixel=0
	p.ScrollBarThickness=5 p.ScrollBarImageColor3=C.accent p.AutomaticCanvasSize=Enum.AutomaticSize.Y p.CanvasSize=UDim2.new() p.Parent=Pages
	local pad=Instance.new("UIPadding",p) pad.PaddingLeft=UDim.new(0,12) pad.PaddingRight=UDim.new(0,12) pad.PaddingTop=UDim.new(0,6) pad.PaddingBottom=UDim.new(0,12)
	local list=Instance.new("UIListLayout",p) list.Padding=UDim.new(0,8) list.SortOrder=Enum.SortOrder.LayoutOrder return p
end
local FarmPage, StatsPage = Page(), Page() StatsPage.Visible=false
local currentPage="Farm"
local Status=Instance.new("TextLabel",Main) Status.Size=UDim2.new(1,-20,0,28) Status.Position=UDim2.new(0,10,1,-32)
Status.BackgroundColor3=C.surface Status.Text="Bereit" Status.TextColor3=C.muted Status.Font=Enum.Font.GothamMedium
Status.TextSize=12 Status.TextTruncate=Enum.TextTruncate.AtEnd Round(Status,7)
local function SetStatus(message,kind)
	if not Runtime.Alive or not Status.Parent then return end
	Status.Text=tostring(message) Status.TextColor3=kind=="error" and C.danger or kind=="warning" and C.warning or kind=="success" and C.accent or C.muted
end
local function Row(parent,label,height)
	local row=Instance.new("Frame") row.Size=UDim2.new(1,0,0,height or 46) row.BackgroundColor3=C.surface row.BorderSizePixel=0 row.Parent=parent Round(row,9)
	local name=Text(row,label,14,C.text,false) name.Size=UDim2.new(1,-150,1,0) name.Position=UDim2.fromOffset(12,0) return row,name
end
local function Heading(parent,text)
	local label=Text(parent,text,13,C.muted,true) label.Size=UDim2.new(1,0,0,24) return label
end
local function ToggleVisual(button,enabled) button.Text=enabled and "AN" or "AUS" button.BackgroundColor3=enabled and C.accent or C.danger end
local function Toggle(parent,id,label,initial,callback)
	local row=Row(parent,label) local button=Button(row,"",86) button.Position=UDim2.new(1,-98,.5,-17)
	local enabled=initial==true ToggleVisual(button,enabled)
	Track(button.Activated:Connect(function() enabled=not enabled ToggleVisual(button,enabled) callback(enabled) SaveSettings() end))
	Runtime.Controls[id]={row=row,button=button,set=function(value) enabled=value==true ToggleVisual(button,enabled) end}
	return row
end

Heading(FarmPage,"AUTOMATISIERUNG")
local amountRow=Row(FarmPage,"Anzahl Hühner",58)
local amountButtons={}
for index,amount in ipairs({1,5,25,100}) do
	local button=Button(amountRow,tostring(amount),48) button.Size=UDim2.fromOffset(48,30) button.Position=UDim2.new(1,-220+(index-1)*52,.5,-15)
	amountButtons[amount]=button
	Track(button.Activated:Connect(function()
		Settings.selectedChickenAmount=amount
		for option,item in pairs(amountButtons) do item.BackgroundColor3=option==amount and C.accent or C.control end
		SaveSettings() SetStatus("Kaufmenge: "..amount.." Hühner","success")
	end))
end
for amount,button in pairs(amountButtons) do button.BackgroundColor3=amount==Settings.selectedChickenAmount and C.accent or C.control end
Toggle(FarmPage,"buy","Hühner automatisch kaufen",Settings.chickenEnabled,function(v) Settings.chickenEnabled=v end)
Toggle(FarmPage,"sell","Eier automatisch verkaufen",Settings.autoSellEggs,function(v)
	Settings.autoSellEggs=v if Runtime.Controls.threshold then Runtime.Controls.threshold.setEnabled(v) end
end)

local multiRow,multiLabel=Row(FarmPage,"Verkaufen ab Multiplikator",72) multiLabel.Size=UDim2.new(1,-24,0,30)
local MultiValue=Text(multiRow,"",14,C.text,true) MultiValue.Size=UDim2.fromOffset(65,28) MultiValue.Position=UDim2.new(1,-77,0,3) MultiValue.TextXAlignment=Enum.TextXAlignment.Right
local track=Instance.new("Frame",multiRow) track.Size=UDim2.new(1,-30,0,8) track.Position=UDim2.new(0,15,1,-22) track.BackgroundColor3=C.control track.BorderSizePixel=0 track.Active=true Round(track,4)
local fill=Instance.new("Frame",track) fill.BackgroundColor3=C.accent fill.BorderSizePixel=0 Round(fill,4)
local knob=Instance.new("Frame",track) knob.Size=UDim2.fromOffset(18,18) knob.AnchorPoint=Vector2.new(.5,.5) knob.BackgroundColor3=C.text knob.BorderSizePixel=0 knob.Active=true Round(knob,9)
local sliderDragging,thresholdEnabled=false,Settings.autoSellEggs
local function UpdateMultiplier(value,save)
	value=math.clamp(math.floor((value-.5)*20+.5)/20+.5,.5,1.5) Settings.sellAtMultiplier=value
	local alpha=value-.5 MultiValue.Text=string.format("%.2fx",value) fill.Size=UDim2.fromScale(alpha,1) knob.Position=UDim2.new(alpha,0,.5,0)
	if save then SaveSettings() end
end
local function EnableThreshold(enabled)
	thresholdEnabled=enabled multiRow.BackgroundTransparency=enabled and 0 or .35 multiLabel.TextColor3=enabled and C.text or C.muted track.Active=enabled knob.Active=enabled
end
Runtime.Controls.threshold={setEnabled=EnableThreshold}
local function Slide(input)
	if not thresholdEnabled then return end
	local alpha=math.clamp((input.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1) UpdateMultiplier(.5+alpha,false)
end
local function SliderStart(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then sliderDragging=true Slide(input) end
end
Track(track.InputBegan:Connect(SliderStart)) Track(knob.InputBegan:Connect(SliderStart))
Track(UserInputService.InputChanged:Connect(function(input)
	if sliderDragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then Slide(input) end
end))
Track(UserInputService.InputEnded:Connect(function(input)
	if sliderDragging and (input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch) then sliderDragging=false UpdateMultiplier(Settings.sellAtMultiplier,true) end
end))
UpdateMultiplier(Settings.sellAtMultiplier,false) EnableThreshold(Settings.autoSellEggs)

Toggle(FarmPage,"process","Prozess automatisch verbessern",Settings.autoProcessUpgrade,function(v) Settings.autoProcessUpgrade=v end)
Toggle(FarmPage,"tier","Kaufstufe automatisch verbessern",Settings.autoTierUpgrade,function(v) Settings.autoTierUpgrade=v end)
Toggle(FarmPage,"group","Gruppenbelohnung automatisch",Settings.autoGroupReward,function(v) Settings.autoGroupReward=v end)
Toggle(FarmPage,"cash","Cash automatisch einsammeln",Settings.autoCollectCash,function(v) Settings.autoCollectCash=v end)
Toggle(FarmPage,"afk","Anti-AFK",Settings.antiAFK,function(v) Settings.antiAFK=v end)
Heading(FarmPage,"OBERFLÄCHE")
local hotkeyRow=Row(FarmPage,"UI ein-/ausblenden") local HotkeyButton=Button(hotkeyRow,"",116) HotkeyButton.Position=UDim2.new(1,-128,.5,-17)
local uiHotkey=Enum.KeyCode[Settings.uiHotkey] or Enum.KeyCode.RightControl
local keyNames={RightControl="Rechte Strg",LeftControl="Linke Strg",RightShift="Rechte Shift",LeftShift="Linke Shift"}
local function KeyName(key) return keyNames[key.Name] or key.Name end
local waitingForHotkey=false HotkeyButton.Text=KeyName(uiHotkey)
Track(HotkeyButton.Activated:Connect(function() waitingForHotkey=true HotkeyButton.Text="Taste drücken …" SetStatus("Neue Taste drücken – ESC bricht ab","warning") end))
local resetRow=Row(FarmPage,"Zurücksetzen",50)
local ResetPosition=Button(resetRow,"Position",92) ResetPosition.Position=UDim2.new(1,-200,.5,-17)
local ResetAll=Button(resetRow,"Alles",88) ResetAll.Position=UDim2.new(1,-100,.5,-17) ResetAll.BackgroundColor3=C.danger

Heading(StatsPage,"AKTUELLE WERTE")
local Stat={}
local function AddStat(id,label)
	local row=Row(StatsPage,label) local value=Text(row,"N/V",14,C.text,true) value.Size=UDim2.fromOffset(190,46)
	value.Position=UDim2.new(1,-202,0,0) value.TextXAlignment=Enum.TextXAlignment.Right Stat[id]=value
end
AddStat("eggs","Eier") AddStat("eps","Eier pro Sekunde") AddStat("cash","Cash") AddStat("multiplier","Eier-Multiplikator")
AddStat("group","Nächste Gruppenbelohnung") AddStat("rebirth","Rebirth-Fortschritt") AddStat("gems","Gems Reset")

local lastEgg,lastEggTime,eggRate,lastDepositTime=nil,nil,nil,0
local rebirthCurrent,rebirthRequired,nextRebirthScan=nil,nil,0
local minimized=false
local function FindRebirth()
	local bestCurrent,bestRequired
	for _,object in ipairs(PlayerGui:GetDescendants()) do
		if Runtime.Alive and not object:IsDescendantOf(ScreenGui) then
			local text=ObjectText(object)
			if text and text:find("/",1,true) then
				local left,right=text:match("%$?%s*([%d%.]+%a*)%s*/%s*%$?%s*([%d%.]+%a*)")
				local current,required=ParseNumber(left),ParseNumber(right)
				local context=(object.Name.." "..(object.Parent and object.Parent.Name or "").." "..text):lower()
				local likely=context:find("rebirth",1,true)~=nil
				if current and required and required>0 and current<=required and (likely or not bestRequired) then
					if likely or not bestRequired or required>bestRequired then bestCurrent,bestRequired=current,required end
				end
			end
		end
	end
	return bestCurrent,bestRequired
end
local function GroupRemaining()
	local last=tonumber(Settings.lastGroupRewardAttempt) or 0
	return last<=0 and 0 or math.max(0,GROUP_INTERVAL-(os.time()-last))
end
local function UpdateStats()
	if not Runtime.Alive then return end
	local now=os.clock() local eggText=EggsTextObject and tostring(EggsTextObject.Text) or "N/V" local current=ParseNumber(eggText)
	if current then
		if lastEgg and lastEggTime and now-lastEggTime>0 and now-lastDepositTime>1.5 then
			local difference=current-lastEgg local rate=difference>=0 and difference/(now-lastEggTime) or nil
			if rate and rate<math.max(1,current)*100 then eggRate=eggRate and eggRate*.7+rate*.3 or rate end
		end
		lastEgg,lastEggTime=current,now
	end
	Stat.eggs.Text=eggText Stat.eps.Text=eggRate and FormatNumber(eggRate).."/s" or "Wird berechnet …"
	Stat.cash.Text=CashTextObject and tostring(CashTextObject.Text) or "N/V"
	Stat.multiplier.Text=string.format("%.2fx",tonumber(EggMultiplier.Value) or 0)
	Stat.group.Text=Settings.autoGroupReward and (GroupRemaining()<=0 and "Bereit" or FormatTime(GroupRemaining())) or "Ausgeschaltet"
	Stat.gems.Text=GemsResetTextObject and tostring(GemsResetTextObject.Text) or "N/V"
	if currentPage=="Stats" and now>=nextRebirthScan then nextRebirthScan=now+10 rebirthCurrent,rebirthRequired=FindRebirth() end
	Stat.rebirth.Text=rebirthCurrent and (FormatNumber(rebirthCurrent).." / "..FormatNumber(rebirthRequired)) or "Rebirth-Fenster öffnen"
end

local function WarnOnce(key,message)
	local now=os.clock() if now-(Runtime.LastErrors[key] or 0)<ERROR_COOLDOWN then return end
	Runtime.LastErrors[key]=now warn("[Chicken Farm] "..message)
end
local function ValidResult(result)
	if result==false then return false end
	if type(result)=="string" then
		local lower=result:lower()
		if lower:find("not enough",1,true) or lower:find("failed",1,true) or lower:find("error",1,true) then return false end
	end
	return true
end
local function InvokeAsync(key,args,callback)
	if not Runtime.Alive or Runtime.Busy[key] then return false end
	Runtime.Busy[key]=true
	task.spawn(function()
		local ok,result=pcall(function() return Event:InvokeServer(table.unpack(args)) end)
		if ok then ok=ValidResult(result) end Runtime.Busy[key]=nil
		if not Runtime.Alive then return end
		if ok then SetStatus(key.." erfolgreich","success")
		else SetStatus(key.." fehlgeschlagen","error") WarnOnce(key,key.." fehlgeschlagen: "..tostring(result)) end
		if callback then callback(ok,result) end
	end)
	return true
end
local function Worker(interval,enabled,action)
	task.spawn(function() while Runtime.Alive do if enabled() then action() end task.wait(interval) end end)
end
Worker(.5,function() return Settings.chickenEnabled end,function()
	InvokeAsync("Hühner gekauft",{"Buy Chickens",Settings.selectedChickenAmount})
end)
Worker(.5,function() return Settings.autoSellEggs end,function()
	local eggs=EggsTextObject and ParseNumber(EggsTextObject.Text)
	if eggs and eggs>0 and (tonumber(EggMultiplier.Value) or 0)>=Settings.sellAtMultiplier and os.clock()-lastDepositTime>=1 then
		InvokeAsync("Eier verkauft",{"Deposit Eggs"},function(ok)
			if ok then lastDepositTime=os.clock() lastEgg,lastEggTime,eggRate=nil,nil,nil end
		end)
	end
end)
Worker(1,function() return Settings.autoProcessUpgrade end,function()
	InvokeAsync("Prozess verbessert",{"Upgrade Process Level"})
end)
Worker(1,function() return Settings.autoTierUpgrade end,function()
	InvokeAsync("Kaufstufe verbessert",{"Upgrade Buy Tier Level"})
end)
Worker(1,function() return Settings.autoCollectCash end,function() InvokeAsync("Cash eingesammelt",{"Collect Cash"}) end)
Worker(1,function() return Settings.autoGroupReward and GroupRemaining()<=0 end,function()
	InvokeAsync("Gruppenbelohnung abgeholt",{"Claim Group Reward"},function(ok)
		if ok then Settings.lastGroupRewardAttempt=os.time() SaveSettings() end
	end)
end)
-- UI-Werte pausieren, solange das Fenster ausgeblendet oder minimiert ist.
Worker(.5,function() return Main.Visible and not minimized end,UpdateStats)

local function ShowPage(name)
	currentPage=name FarmPage.Visible=name=="Farm" StatsPage.Visible=name=="Stats"
	FarmTab.BackgroundColor3=name=="Farm" and C.accent or C.control StatsTab.BackgroundColor3=name=="Stats" and C.accent or C.control
	if name=="Stats" then nextRebirthScan=0 UpdateStats() end
end
Track(FarmTab.Activated:Connect(function() ShowPage("Farm") end))
Track(StatsTab.Activated:Connect(function() ShowPage("Stats") end)) ShowPage("Farm")

Track(MinButton.Activated:Connect(function()
	minimized=not minimized TabBar.Visible=not minimized Pages.Visible=not minimized Status.Visible=not minimized
	Main.Size=minimized and UDim2.fromOffset(430,52) or UDim2.fromOffset(430,570) MinButton.Text=minimized and "+" or "—"
end))
function Runtime.Stop()
	if not Runtime.Alive then return end Runtime.Alive=false SaveSettings(true)
	for _,connection in ipairs(Runtime.Connections) do pcall(function() connection:Disconnect() end) end Runtime.Connections={}
	if ScreenGui and ScreenGui.Parent then ScreenGui:Destroy() end
	if Env.__ChickenFarmRuntime==Runtime then Env.__ChickenFarmRuntime=nil end
end
Track(CloseButton.Activated:Connect(Runtime.Stop))
local function ResetWindowPosition()
	Settings.uiPosition=Clone(DEFAULTS.uiPosition)
	Main.Position=UDim2.new(Settings.uiPosition.xScale,Settings.uiPosition.xOffset,Settings.uiPosition.yScale,Settings.uiPosition.yOffset)
	SaveSettings() SetStatus("Fensterposition zurückgesetzt","success")
end
Track(ResetPosition.Activated:Connect(ResetWindowPosition))
Track(ResetAll.Activated:Connect(function()
	local position=Clone(Settings.uiPosition) Settings=Clone(DEFAULTS) Settings.uiPosition=position SaveSettings(true)
	SetStatus("Einstellungen zurückgesetzt – Script neu starten","warning")
end))

local dragging,dragStart,startPosition=false,nil,nil
Track(Header.InputBegan:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging,dragStart,startPosition=true,input.Position,Main.Position end
end))
Track(UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
		local delta=input.Position-dragStart
		Main.Position=UDim2.new(startPosition.X.Scale,startPosition.X.Offset+delta.X/Scale.Scale,startPosition.Y.Scale,startPosition.Y.Offset+delta.Y/Scale.Scale)
	end
end))
Track(UserInputService.InputEnded:Connect(function(input)
	if dragging and (input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch) then
		dragging=false
		local viewport=Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1920,1080)
		local size=Main.AbsoluteSize local pos=Main.AbsolutePosition
		local x=math.clamp(pos.X,0,math.max(0,viewport.X-size.X)) local y=math.clamp(pos.Y,0,math.max(0,viewport.Y-size.Y))
		Main.Position=UDim2.fromOffset(x/Scale.Scale,y/Scale.Scale)
		Settings.uiPosition={xScale=0,xOffset=Main.Position.X.Offset,yScale=0,yOffset=Main.Position.Y.Offset} SaveSettings()
	end
end))
Track(Player.Idled:Connect(function()
	if Settings.antiAFK then pcall(function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.zero) end) end
end))
Track(UserInputService.InputBegan:Connect(function(input,processed)
	if waitingForHotkey then
		if input.UserInputType~=Enum.UserInputType.Keyboard then return end waitingForHotkey=false
		if input.KeyCode~=Enum.KeyCode.Escape and input.KeyCode~=Enum.KeyCode.Unknown then
			uiHotkey=input.KeyCode Settings.uiHotkey=uiHotkey.Name SaveSettings() SetStatus("Hotkey gespeichert","success")
		else SetStatus("Hotkey-Auswahl abgebrochen","warning") end
		HotkeyButton.Text=KeyName(uiHotkey) return
	end
	if UserInputService:GetFocusedTextBox() or processed then return end
	if input.UserInputType==Enum.UserInputType.Keyboard and input.KeyCode==uiHotkey then Main.Visible=not Main.Visible end
end))
Track(ScreenGui.Destroying:Connect(function() Runtime.Alive=false end))

SaveSettings(true) UpdateStats()
SetStatus(FILE_SUPPORT and ("Version "..VERSION.." – bereit") or ("Version "..VERSION.." – Einstellungen werden nicht gespeichert"),FILE_SUPPORT and "success" or "warning")
print("[Chicken Farm] Version",VERSION,"geladen")
print("[Chicken Farm] Kaufmenge:",Settings.selectedChickenAmount)
print("[Chicken Farm] Verkauf ab:",string.format("%.2fx",Settings.sellAtMultiplier))
