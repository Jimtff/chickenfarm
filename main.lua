--[[
Chicken Farm 2.1 – Einzeldatei, ohne zusätzliche Abhängigkeiten

KURZANLEITUNG
Installation: Als LocalScript im passenden Roblox-Spiel ausführen, nur in einer
Umgebung, in der diese Automatisierungen erlaubt sind. Kein eigenständiges CLI.
Nutzung: Schalter im Tab „Farm“, Statistiken im zweiten Tab; rechte Strg blendet
das Fenster aus/ein. Die Titelleiste verschiebt, „–“ minimiert, „×“ beendet.
Der Hotkey ist einstellbar; ESC bricht die Tastenauswahl ab.

Konfiguration: ChickenFarm_<PlaceId>.json, sofern readfile/writefile/isfile
vorhanden sind. Roblox-Studio bietet diese Dateifunktionen standardmäßig nicht.
Alternativ vor dem Start eine Tabelle ChickenFarmConfig in _G/getgenv setzen.
Bekannte Felder werden validiert; unbekannte Felder werden ignoriert.
intervals: buy=0.2, sell=0.2, process=0.2, tier=1, cash=1, group=1.
network: timeout=10, retryBase=1, retryMax=30, maxRetries=3.
Alle Zeiten in Sekunden. Anzeigen und Scheduler verwenden dieselben Werte.
Ohne Dateiunterstützung gelten Änderungen bis zum nächsten Script-Start.

Netzwerk: InvokeServer besitzt hier keinen abbrechbaren Netzwerk-Timeout.
Bei ausbleibender Antwort bleibt die Anfrage gesperrt – auch bei erneutem Start.
Ein Timeout sendet KEINE zweite Kauf-/Verkaufsanfrage. Eine spätere Antwort löst
die Sperre; bei dauerhaften Hängern die Verbindung zum Spiel neu herstellen.
Technische Ablehnungen werden begrenzt mit wachsender Pause wiederholt.
„Nicht genügend Geld“ und bekannte Spiel-Cooldowns sind normale Wartezustände;
sie deaktivieren die Automatisierung nicht. Bei Transportfehlern ist das Ergebnis
unklar: Schalter aus/ein erst,
nachdem der Spielzustand geprüft wurde.
Ohne eindeutige Serverbestätigung wird kein Erfolg behauptet. Der vorhandene
600-s-Gruppen-Timer bleibt nach fehlerfreier, aber unbestätigter Antwort erhalten
und wird als Schätzung angezeigt. Das Serverprotokoll ist nicht Teil dieses Repos.
Bereits gesendete Anfragen können beim Beenden nicht zurückgenommen werden;
späte Antworten dürfen dann weder Einstellungen noch UI verändern.

Fehlerbehebung: Bei fehlenden Spielobjekten zuerst deren Pfade unter SOURCES
prüfen. Beschädigte Einstellungsdateien werden vor dem Ersetzen gesichert.
Es gibt weiterhin weder Sitzungszähler noch Zurücksetzen-Schaltflächen.
]]

local VERSION = "2.1.0"
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Input = game:GetService("UserInputService")
local Http = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local Player = Players.LocalPlayer

local Env = _G
if type(getgenv) == "function" then
    local ok, value = pcall(getgenv)
    if ok and type(value) == "table" then Env = value end
end

local previous = Env.__ChickenFarmRuntime
if type(previous) == "table" and type(previous.Stop) == "function" then
    pcall(previous.Stop)
end

local PlayerGui = Player and Player:WaitForChild("PlayerGui", 15)
if not PlayerGui then
    warn("[Chicken Farm] PlayerGui fehlt. Bitte im Roblox-Client nach dem Laden starten.")
    return
end

local FILE = "ChickenFarm_" .. tostring(game.PlaceId) .. ".json"
local FILE_SUPPORT = type(readfile) == "function"
    and type(writefile) == "function" and type(isfile) == "function"
local GROUP_INTERVAL = 600
local WIDTH, HEIGHT, HEADER = 430, 570, 52
local UI_PERIOD, REF_PERIOD, SCAN_PERIOD = 0.5, 2, 10
local COLOURS = {
    background = Color3.fromRGB(20, 21, 24),
    surface = Color3.fromRGB(32, 34, 39),
    control = Color3.fromRGB(43, 46, 52),
    accent = Color3.fromRGB(62, 176, 92),
    danger = Color3.fromRGB(190, 65, 65),
    warning = Color3.fromRGB(218, 158, 54),
    text = Color3.fromRGB(242, 242, 244),
    muted = Color3.fromRGB(170, 174, 184),
    outline = Color3.fromRGB(65, 69, 78),
}
local DEFAULTS = {
    version = 3,
    chickenEnabled = false, selectedChickenAmount = 25,
    autoSellEggs = false, sellAtMultiplier = 1.25,
    autoProcessUpgrade = false, autoTierUpgrade = false,
    autoGroupReward = false, autoCollectCash = false, antiAFK = false,
    uiHotkey = "RightControl",
    uiPosition = { xScale = 0.5, xOffset = -215, yScale = 0.5, yOffset = -285 },
    lastGroupRewardAttempt = 0,
    intervals = { buy = 0.2, sell = 0.2, process = 0.2, tier = 1, cash = 1, group = 1 },
    network = { timeout = 10, retryBase = 1, retryMax = 30, maxRetries = 3 },
}

local function Clone(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = Clone(item) end
    return copy
end

local function Finite(value)
    local number = tonumber(value)
    return number and number == number and math.abs(number) < math.huge and number or nil
end

local function Bounded(value, default, minimum, maximum)
    return math.clamp(Finite(value) or default, minimum, maximum)
end

local function SafeKey(name)
    local ok, key = pcall(function() return Enum.KeyCode[tostring(name)] end)
    if ok and key and key ~= Enum.KeyCode.Unknown and key ~= Enum.KeyCode.Escape then return key end
    return Enum.KeyCode.RightControl
end

local function MergeKnown(target, source, schema)
    if type(source) ~= "table" then return end
    for key, default in pairs(schema) do
        if source[key] ~= nil then
            if type(default) == "table" then
                MergeKnown(target[key], source[key], default)
            else
                target[key] = source[key]
            end
        end
    end
end

local function Validate(settings)
    for key, default in pairs(DEFAULTS) do
        if type(default) == "boolean" then settings[key] = settings[key] == true end
    end
    local amount = Finite(settings.selectedChickenAmount)
    local valid = { [1] = true, [5] = true, [25] = true, [100] = true }
    settings.selectedChickenAmount = valid[amount] and amount or 25
    settings.sellAtMultiplier = math.floor(Bounded(settings.sellAtMultiplier, 1.25, 0.5, 1.5) * 20 + 0.5) / 20
    settings.uiHotkey = SafeKey(settings.uiHotkey).Name
    for name, default in pairs(DEFAULTS.uiPosition) do
        local isScale = name == "xScale" or name == "yScale"
        settings.uiPosition[name] = Bounded(settings.uiPosition[name], default,
            isScale and 0 or -100000, isScale and 1 or 100000)
    end
    for id, default in pairs(DEFAULTS.intervals) do
        settings.intervals[id] = Bounded(settings.intervals[id], default, 0.1, 60)
    end
    local net = settings.network
    net.timeout = Bounded(net.timeout, 10, 2, 120)
    net.retryBase = Bounded(net.retryBase, 1, 0.5, 60)
    net.retryMax = Bounded(net.retryMax, 30, net.retryBase, 300)
    net.maxRetries = math.floor(Bounded(net.maxRetries, 3, 0, 8))
    local last = Finite(settings.lastGroupRewardAttempt) or 0
    settings.lastGroupRewardAttempt = last >= 0 and last <= os.time() and math.floor(last) or 0
    settings.version = DEFAULTS.version
    return settings
end

-- Reine Zahlenfunktionen: ungültige oder unvollständige Werte ergeben nil.
local SUFFIXES = { [""] = 1, k = 1e3, m = 1e6, b = 1e9, t = 1e12,
    qd = 1e15, qn = 1e18, sx = 1e21, sp = 1e24, oc = 1e27, no = 1e30, dc = 1e33 }
local FORMATS = { {1e33,"Dc"}, {1e30,"No"}, {1e27,"Oc"}, {1e24,"Sp"},
    {1e21,"Sx"}, {1e18,"Qn"}, {1e15,"Qd"}, {1e12,"T"}, {1e9,"B"}, {1e6,"M"}, {1e3,"K"} }

local function ParseNumber(text)
    if type(text) == "number" then return Finite(text) end
    if type(text) ~= "string" then return nil end
    -- Original-HUD: englische Tausendertrennzeichen; kein Dezimalkomma erraten.
    local clean = text:gsub("<.->", ""):gsub("%$", ""):gsub(",", ""):gsub("%s+", "")
    local part, suffix = clean:match("^%+?(%d+%.?%d*)(%a*)$")
    local number = Finite(part)
    local factor = SUFFIXES[(suffix or ""):lower()]
    return number and factor and Finite(number * factor) or nil
end

local function FormatNumber(value)
    value = Finite(value)
    if not value then return "Nicht verfügbar" end
    for _, entry in ipairs(FORMATS) do
        if math.abs(value) >= entry[1] then
            return string.format("%.2f%s", value / entry[1], entry[2])
        end
    end
    return string.format(math.abs(value) >= 100 and "%.0f" or "%.2f", value)
end

local function FormatTime(seconds)
    seconds = math.max(0, math.floor(Finite(seconds) or 0))
    local h, m, s = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60
    if h > 0 then return string.format("%02d h %02d min %02d s", h, m, s) end
    return string.format("%02d min %02d s", m, s)
end

local function Seconds(value)
    return (string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", ""):gsub("%.", ",")) .. " s"
end

-- Unbestätigte Antworten sind kein nachgewiesener Spiel-Erfolg.
local function WaitingResult(result)
    local message = result
    if type(result) == "table" then message = result.message or result.error or result.status end
    if type(message) ~= "string" then return nil end
    local text = message:lower()
    if text:find("not enough", 1, true) or text:find("insufficient", 1, true) then
        return "Nicht genügend Mittel"
    end
    if text:find("cooldown", 1, true) then return "Spiel-Cooldown" end
end

local function ClassifyResult(result)
    if result == false then return "rejected" end
    if result == true then return "confirmed" end
    if type(result) == "table" then
        if result.success == false or result.ok == false or result.Success == false
            or (result.error ~= nil and result.error ~= false and result.error ~= "") then
            return WaitingResult(result) and "waiting" or "rejected"
        end
        if result.success == true or result.ok == true or result.Success == true then return "confirmed" end
        if WaitingResult(result) then return "waiting" end
        result = result.status or result.message
    end
    if WaitingResult(result) then return "waiting" end
    if type(result) == "string" then
        local text = result:lower()
        if text:find("not enough", 1, true) or text:find("failed", 1, true)
            or text:find("error", 1, true) or text:find("cooldown", 1, true)
            or text:find("denied", 1, true) or text:find("rate limit", 1, true) then
            return "rejected"
        end
        if text == "success" or text == "ok" then return "confirmed" end
    end
    return "unknown"
end

local Runtime = {
    Alive = true, Stopped = false, Connections = {}, Tasks = {},
    LastLogs = {}, Controls = {}, Dirty = true, Jobs = {},
}
Env.__ChickenFarmRuntime = Runtime
local UI, Settings = {}, Clone(DEFAULTS)
local FlushSettings, QueueTick, Tick, Log
local saveThread, tickThread

local function Cancel(thread)
    if not thread then return end
    Runtime.Tasks[thread] = nil
    if coroutine.status(thread) ~= "dead" and thread ~= coroutine.running() then
        pcall(task.cancel, thread)
    end
end

local function Schedule(delay, callback)
    if not Runtime.Alive then return nil end
    local thread
    thread = coroutine.create(function()
        local ok, err = pcall(callback)
        Runtime.Tasks[thread] = nil
        if not ok and Runtime.Alive then
            Log("error", "callback", "Interner Fehler. Script neu starten; Details in der Konsole.", err)
        end
    end)
    Runtime.Tasks[thread] = true
    task.delay(delay, thread)
    return thread
end

local function Track(signal, callback)
    local connection = signal:Connect(function(...)
        if not Runtime.Alive then return end
        local ok, err = pcall(callback, ...)
        if not ok then Log("error", "event", "Ereignisfehler. Script neu starten; Details in der Konsole.", err) end
    end)
    Runtime.Connections[connection] = true
    return connection
end

local function Disconnect(connection)
    if connection then
        Runtime.Connections[connection] = nil
        pcall(function() connection:Disconnect() end)
    end
end

local function SetText(label, text)
    if label and label.Text ~= text then label.Text = text end
end

local function Status(message, kind)
    local now = os.clock()
    local weight = { info = 1, success = 1, warning = 2, error = 3 }
    if Runtime.MessageUntil and now < Runtime.MessageUntil
        and (weight[kind] or 1) < (Runtime.MessageWeight or 1) then return end
    Runtime.MessageWeight = weight[kind] or 1
    Runtime.MessageUntil = now + (kind == "error" and 8 or kind == "warning" and 5 or 0)
    Runtime.Message = message
    if UI.status then
        SetText(UI.status, message)
        UI.status.TextColor3 = kind == "error" and COLOURS.danger
            or kind == "warning" and COLOURS.warning
            or kind == "success" and COLOURS.accent or COLOURS.muted
    end
end

Log = function(kind, key, message, detail)
    if Runtime.Alive then Status(message, kind) end
    local now = os.clock()
    local last = Runtime.LastLogs[key]
    if last and now - last < 10 then return end
    Runtime.LastLogs[key] = now
    local output = "[Chicken Farm] " .. message
    if detail ~= nil then output = output .. " Details: " .. tostring(detail):sub(1, 350) end
    if kind == "error" or kind == "warning" then warn(output) else print(output) end
end

function Runtime.Stop(destroying)
    if Runtime.Stopped then return end
    Runtime.Stopped, Runtime.Alive = true, false
    if FlushSettings then FlushSettings() end
    for connection in pairs(Runtime.Connections) do pcall(function() connection:Disconnect() end) end
    Runtime.Connections = {}
    for thread in pairs(Runtime.Tasks) do Cancel(thread) end
    Runtime.Tasks = {}
    if UI.screen and not destroying then UI.screen:Destroy() end
    if Env.__ChickenFarmRuntime == Runtime then Env.__ChickenFarmRuntime = nil end
    Log("info", "stop", "Script beendet. Bereits gesendete Serveranfragen können noch abschließen.")
end

-- Schreibzugriffe bündeln; kaputte oder neuere Konfiguration nicht überschreiben.
local settingsDirty, saveAllowed, lastJSON = false, true, nil
local function LoadSettings()
    if not FILE_SUPPORT then return end
    local raw
    local ok, data = pcall(function()
        if not isfile(FILE) then return nil end
        raw = readfile(FILE)
        if #raw > 262144 then error("Einstellungsdatei ist größer als 256 KiB.") end
        return Http:JSONDecode(raw)
    end)
    if ok and data == nil and raw == nil then return end
    if not ok or type(data) ~= "table" then
        local backup = FILE .. ".defekt-" .. tostring(os.time()) .. ".bak"
        local saved = false
        if raw then saved = pcall(writefile, backup, raw) end
        saveAllowed = saved
        Log("warning", "load", saved
            and ("Einstellungen beschädigt. Standardwerte aktiv; Sicherung: " .. backup)
            or "Einstellungen nicht lesbar. Datei prüfen; vorhandene Datei wird nicht überschrieben.")
        return
    end
    if (Finite(data.version) or 1) > DEFAULTS.version then
        saveAllowed = false
        Log("warning", "new-settings", "Neuere Einstellungsdatei erkannt. Lesen möglich, Speichern gesperrt.")
    end
    MergeKnown(Settings, data, DEFAULTS)
    lastJSON = raw
end

LoadSettings()
MergeKnown(Settings, Env.ChickenFarmConfig, DEFAULTS)
Validate(Settings)

FlushSettings = function()
    if not settingsDirty or not FILE_SUPPORT or not saveAllowed then return end
    local ok, encoded = pcall(Http.JSONEncode, Http, Settings)
    if not ok then Log("error", "encode", "Einstellungen ungültig. Konfiguration prüfen.", encoded) return end
    if encoded == lastJSON then settingsDirty = false return end
    local saved, err = pcall(writefile, FILE, encoded)
    if saved then
        lastJSON, settingsDirty = encoded, false
    else
        Log("error", "save", "Speichern fehlgeschlagen. Schreibrechte der Umgebung prüfen.", err)
    end
end

local function SaveSoon()
    settingsDirty = true
    if not FILE_SUPPORT or not saveAllowed then return end
    Cancel(saveThread)
    saveThread = Schedule(0.4, function() saveThread = nil FlushSettings() end)
end

-- Sperren leben über einen Script-Neustart hinaus, bis die Serverantwort eintrifft.
local serverKey = tostring(game.PlaceId) .. ":" .. tostring(game.JobId)
local pendingStore = Env.__ChickenFarmPending
if type(pendingStore) ~= "table" or pendingStore.server ~= serverKey or type(pendingStore.calls) ~= "table" then
    pendingStore = { server = serverKey, calls = {} }
    Env.__ChickenFarmPending = pendingStore
end
local Pending = pendingStore.calls

local SOURCES = {
    remote = { root = ReplicatedStorage, path = {"Paper", "Remotes", "__remotefunction"}, class = "RemoteFunction" },
    multiplier = { root = ReplicatedStorage, path = {"Values", "EggMultiplier"}, property = "Value" },
    eggs = { root = PlayerGui, path = {"Main", "Eggs", "Amount", "Amt"}, property = "Text" },
    cash = { root = PlayerGui, path = {"Main", "Currencies", "Cash", "List", "Amount"}, property = "Text" },
    gems = { root = PlayerGui, path = {"Main", "Currencies", "Gems", "List", "Collect", "Collected"}, property = "Text" },
}
local Cache, Sources = {}, {}
local nextRefs, nextUI, nextScan = 0, 0, 0
local rebirthObject, rebirthSignal, rebirthValue
local eggSamples, eggRate = {}, nil
local lastDeposit = -math.huge
local groupEstimated = Settings.lastGroupRewardAttempt > 0
local bootDeadline = os.clock() + 15

local function FindPath(root, path)
    local current = root
    for _, name in ipairs(path) do
        current = current and current:FindFirstChild(name)
        if not current then return nil end
    end
    return current
end

local function IsText(object)
    return object and (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox"))
end

local function ReadSource(id, object, property)
    if id == "multiplier" then
        Cache.multiplier = Finite(object[property])
    else
        Cache[id] = tostring(object[property])
        if id == "eggs" then Cache.eggNumber = ParseNumber(Cache.eggs) end
        if id == "cash" then
            -- Geldänderung kann wartende Käufe/Upgrades früher wieder ermöglichen.
            local wake = false
            for _, job in pairs(Runtime.Jobs) do
                if job.waiting and job.cashSensitive and Settings[job.definition.setting] then
                    job.nextAt = math.min(job.nextAt, os.clock())
                    wake = true
                end
            end
            if wake and QueueTick then QueueTick(0) end
        end
    end
    Runtime.Dirty = true
end

local function RefreshSources()
    for id, spec in pairs(SOURCES) do
        local object = FindPath(spec.root, spec.path)
        if object then
            if spec.class and not object:IsA(spec.class) then object = nil end
            if spec.property == "Text" and not IsText(object) then object = nil end
            if id == "multiplier" and not (object:IsA("NumberValue") or object:IsA("IntValue")) then object = nil end
        end
        local old = Sources[id]
        if not old or old.object ~= object then
            if old then Disconnect(old.connection) end
            local source = { object = object }
            Sources[id] = source
            Cache[id] = nil
            if id == "eggs" then Cache.eggNumber = nil eggSamples, eggRate = {}, nil end
            if object and spec.property then
                ReadSource(id, object, spec.property)
                source.connection = Track(object:GetPropertyChangedSignal(spec.property), function()
                    ReadSource(id, object, spec.property)
                end)
            end
            Runtime.Dirty = true
        end
    end
end

local function ParseProgress(text)
    if type(text) ~= "string" then return nil end
    local left, right = text:gsub("<.->", ""):match("([%d%.,]+%s*%a*)%s*/%s*%$?%s*([%d%.,]+%s*%a*)")
    local current, required = ParseNumber(left), ParseNumber(right)
    if current and required and required > 0 then return current, required end
end

local function RebirthContext(object)
    local current = object
    while current and current ~= PlayerGui do
        if current.Name:lower():find("rebirth", 1, true) then return true end
        current = current.Parent
    end
    return IsText(object) and object.Text:lower():find("rebirth", 1, true) ~= nil
end

local function ClearRebirth()
    Disconnect(rebirthSignal)
    rebirthObject, rebirthSignal, rebirthValue = nil, nil, nil
end

local function ReadRebirth()
    if not rebirthObject or not rebirthObject:IsDescendantOf(PlayerGui) then ClearRebirth() return end
    local current, required = ParseProgress(rebirthObject.Text)
    rebirthValue = current and (FormatNumber(current) .. " / " .. FormatNumber(required)) or nil
    Runtime.Dirty = true
end

local function FindRebirth(now)
    if rebirthObject and rebirthObject:IsDescendantOf(PlayerGui) then
        ReadRebirth()
        if rebirthValue then return end
    end
    if now < nextScan then return end
    nextScan = now + SCAN_PERIOD
    ClearRebirth()
    -- Kein „irgendein Zahl/Zahl“-Fallback: falsche Anzeigen nicht als Rebirth ausgeben.
    local match
    for _, object in ipairs(PlayerGui:GetDescendants()) do
        if not object:IsDescendantOf(UI.screen) and IsText(object)
            and RebirthContext(object) and ParseProgress(object.Text) then
            if not match then match = object else match = nil break end
        end
    end
    if match then
        rebirthObject = match
        rebirthSignal = Track(match:GetPropertyChangedSignal("Text"), ReadRebirth)
        ReadRebirth()
    end
end

local function SampleEggs(now)
    local value = Cache.eggNumber
    if not value then eggSamples, eggRate = {}, nil return end
    local last = eggSamples[#eggSamples]
    if last and (now - last.time > 1.5 or value < last.value) then
        eggSamples, eggRate = {}, nil
        last = nil
    end
    if now - lastDeposit < 1.5 then return end
    eggSamples[#eggSamples + 1] = { time = now, value = value }
    while #eggSamples > 21 or (#eggSamples > 1 and now - eggSamples[1].time > 10) do
        table.remove(eggSamples, 1)
    end
    local first = eggSamples[1]
    if now - first.time >= 1 then eggRate = Finite(math.max(0, (value - first.value) / (now - first.time))) end
end

local function GroupRemaining()
    local last = Settings.lastGroupRewardAttempt
    return last <= 0 and 0 or math.max(0, GROUP_INTERVAL - (os.time() - last))
end

local DEFINITIONS = {
    { id = "buy", setting = "chickenEnabled", label = "Hühner automatisch kaufen", command = "Buy Chickens" },
    { id = "sell", setting = "autoSellEggs", label = "Eier automatisch verkaufen", command = "Deposit Eggs" },
    { id = "process", setting = "autoProcessUpgrade", label = "Prozess automatisch verbessern", command = "Upgrade Process Level" },
    { id = "tier", setting = "autoTierUpgrade", label = "Kaufstufe automatisch verbessern", command = "Upgrade Buy Tier Level" },
    { id = "group", setting = "autoGroupReward", label = "Gruppenbelohnung abholen", command = "Claim Group Reward" },
    { id = "cash", setting = "autoCollectCash", label = "Cash automatisch einsammeln", command = "Collect Cash" },
}
for _, definition in ipairs(DEFINITIONS) do
    Runtime.Jobs[definition.id] = { definition = definition, nextAt = 0, failures = 0 }
end

-- UI-Bausteine: eindeutige Reihenfolge, getrennte Textbereiche, keine Überlappungen.
local function New(class, parent, properties)
    local object = Instance.new(class)
    for key, value in pairs(properties or {}) do object[key] = value end
    object.Parent = parent
    return object
end

local function Round(object, radius)
    New("UICorner", object, { CornerRadius = UDim.new(0, radius or 8) })
end

local function Text(parent, text, size, bold)
    return New("TextLabel", parent, {
        BackgroundTransparency = 1, Text = text, TextColor3 = COLOURS.text,
        Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium,
        TextSize = size or 14, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
    })
end

local function Button(parent, text, width)
    local button = New("TextButton", parent, {
        Size = UDim2.fromOffset(width or 86, 34), BackgroundColor3 = COLOURS.control,
        BorderSizePixel = 0, Text = text, TextColor3 = COLOURS.text,
        Font = Enum.Font.GothamBold, TextSize = 13,
    })
    Round(button)
    return button
end

local pageOrder = {}
local function Row(parent, title, height)
    pageOrder[parent] = (pageOrder[parent] or 0) + 1
    local row = New("Frame", parent, {
        Size = UDim2.new(1, 0, 0, height or 54), BackgroundColor3 = COLOURS.surface,
        BorderSizePixel = 0, LayoutOrder = pageOrder[parent],
    })
    Round(row)
    local caption = Text(row, title, 13)
    caption.Size, caption.Position = UDim2.new(1, -116, 1, 0), UDim2.fromOffset(12, 0)
    return row, caption
end

local function Heading(parent, text)
    pageOrder[parent] = (pageOrder[parent] or 0) + 1
    local label = Text(parent, text, 12, true)
    label.Size, label.LayoutOrder = UDim2.new(1, 0, 0, 24), pageOrder[parent]
    label.TextColor3 = COLOURS.muted
end

local function Page(parent)
    local page = New("ScrollingFrame", parent, {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 5, ScrollBarImageColor3 = COLOURS.accent,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
        ScrollingDirection = Enum.ScrollingDirection.Y,
    })
    New("UIPadding", page, {
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 12),
    })
    New("UIListLayout", page, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
    return page
end

local oldUI = PlayerGui:FindFirstChild("PaperAutomationUI")
if oldUI then oldUI:Destroy() end
UI.screen = New("ScreenGui", PlayerGui, {
    Name = "PaperAutomationUI", ResetOnSpawn = false, DisplayOrder = 99999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
-- Der unskalierte Fensterhalter verwendet echte Bildschirmkoordinaten.
UI.host = New("Frame", UI.screen, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
UI.window = New("Frame", UI.host, { BackgroundTransparency = 1 })
UI.main = New("Frame", UI.window, {
    Size = UDim2.fromOffset(WIDTH, HEIGHT), BackgroundColor3 = COLOURS.background,
    BorderSizePixel = 0, Active = true, ClipsDescendants = true,
})
Round(UI.main, 14)
New("UIStroke", UI.main, { Color = COLOURS.outline })
UI.scale = New("UIScale", UI.main)
local header = New("Frame", UI.main, { Size = UDim2.new(1, 0, 0, HEADER), BackgroundTransparency = 1 })
local title = Text(header, "🐔  Chicken Farm", 20, true)
title.Size, title.Position, title.Active = UDim2.new(1, -105, 1, 0), UDim2.fromOffset(14, 0), true
local minimize = Button(header, "–", 34)
minimize.Position = UDim2.new(1, -78, 0, 9)
local close = Button(header, "×", 34)
close.Position, close.BackgroundColor3 = UDim2.new(1, -40, 0, 9), COLOURS.danger
UI.tabs = New("Frame", UI.main, {
    Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 52), BackgroundTransparency = 1,
})
local farmTab, statsTab = Button(UI.tabs, "Farm"), Button(UI.tabs, "Statistiken")
farmTab.Size, statsTab.Size = UDim2.new(0.5, -3, 0, 36), UDim2.new(0.5, -3, 0, 36)
statsTab.Position = UDim2.new(0.5, 3, 0, 0)
UI.pages = New("Frame", UI.main, {
    Size = UDim2.new(1, 0, 1, -150), Position = UDim2.fromOffset(0, 94), BackgroundTransparency = 1,
})
UI.farm, UI.stats = Page(UI.pages), Page(UI.pages)
UI.page, UI.minimized = "farm", false
UI.stats.Visible = false
UI.status = Text(UI.main, Runtime.Message or "Wird geladen …", 11)
UI.status.Size, UI.status.Position = UDim2.new(1, -20, 0, 46), UDim2.new(0, 10, 1, -50)
UI.status.BackgroundTransparency, UI.status.BackgroundColor3 = 0, COLOURS.surface
UI.status.TextXAlignment = Enum.TextXAlignment.Center
Round(UI.status)

local gesture, waitingForHotkey, uiKey = nil, false, SafeKey(Settings.uiHotkey)
local UpdateThreshold, LayoutWindow, EndGesture

local function IntervalText(id)
    if id == "afk" then return "Bei Inaktivität" end
    local prefix = id == "group" and "Prüfung alle " or "Alle "
    return prefix .. Seconds(Settings.intervals[id])
end

local function AddToggle(id, label, setting)
    local row, caption = Row(UI.farm, label, 66)
    caption.Size, caption.Position = UDim2.new(1, -116, 0, 36), UDim2.fromOffset(12, 1)
    local hint = Text(row, IntervalText(id), 11)
    hint.Size, hint.Position = UDim2.new(1, -116, 0, 26), UDim2.fromOffset(12, 36)
    hint.TextColor3 = COLOURS.muted
    local button = Button(row, "")
    button.Position = UDim2.new(1, -98, 0.5, -17)
    local function Update()
        local enabled = Settings[setting]
        button.Text, button.BackgroundColor3 = enabled and "AN" or "AUS", enabled and COLOURS.accent or COLOURS.danger
    end
    Update()
    Runtime.Controls[id] = { hint = hint, button = button, update = Update }
    Track(button.Activated, function()
        Settings[setting] = not Settings[setting]
        local job = Runtime.Jobs[id]
        if job then
            job.paused, job.failures, job.nextAt, job.hint = false, 0, 0, nil
            job.waiting, job.waits = false, 0
        end
        Update()
        if id == "sell" and UpdateThreshold then UpdateThreshold() end
        SaveSoon()
        Runtime.Dirty = true
        QueueTick(0)
    end)
end

Heading(UI.farm, "AUTOMATISIERUNG")
local amountRow, amountCaption = Row(UI.farm, "Anzahl Hühner", 54)
amountCaption.Size = UDim2.new(1, -224, 1, 0)
local amountButtons = {}
for index, amount in ipairs({1, 5, 25, 100}) do
    local button = Button(amountRow, tostring(amount), 46)
    button.Position = UDim2.new(1, -210 + (index - 1) * 50, 0.5, -17)
    amountButtons[amount] = button
    button.BackgroundColor3 = amount == Settings.selectedChickenAmount and COLOURS.accent or COLOURS.control
    Track(button.Activated, function()
        Settings.selectedChickenAmount = amount
        for option, item in pairs(amountButtons) do
            item.BackgroundColor3 = option == amount and COLOURS.accent or COLOURS.control
        end
        SaveSoon()
        Status("Kaufmenge: " .. amount .. " Hühner.", "info")
    end)
end
AddToggle("buy", DEFINITIONS[1].label, DEFINITIONS[1].setting)
AddToggle("sell", DEFINITIONS[2].label, DEFINITIONS[2].setting)
local multiplierRow, multiplierCaption = Row(UI.farm, "Verkaufen ab Multiplikator", 78)
multiplierCaption.Size, multiplierCaption.Position = UDim2.new(1, -100, 0, 36), UDim2.fromOffset(12, 0)
local multiplierValue = Text(multiplierRow, "", 14, true)
multiplierValue.Size, multiplierValue.Position = UDim2.fromOffset(72, 36), UDim2.new(1, -84, 0, 0)
multiplierValue.TextXAlignment = Enum.TextXAlignment.Right
-- Eine breite Trefferfläche erleichtert Maus- und Touch-Bedienung.
local sliderHit = New("Frame", multiplierRow, {
    Size = UDim2.new(1, -30, 0, 32), Position = UDim2.fromOffset(15, 40),
    BackgroundTransparency = 1, Active = true,
})
local sliderTrack = New("Frame", sliderHit, {
    Size = UDim2.new(1, 0, 0, 8), Position = UDim2.fromOffset(0, 12),
    BackgroundColor3 = COLOURS.control, BorderSizePixel = 0,
})
Round(sliderTrack, 4)
local fill = New("Frame", sliderTrack, { BackgroundColor3 = COLOURS.accent, BorderSizePixel = 0 })
Round(fill, 4)
local knob = New("Frame", sliderHit, {
    Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = COLOURS.text, BorderSizePixel = 0, Active = true,
})
Round(knob, 9)
UpdateThreshold = function()
    local alpha = Settings.sellAtMultiplier - 0.5
    multiplierValue.Text = string.format("%.2fx", Settings.sellAtMultiplier):gsub("%.", ",")
    fill.Size, knob.Position = UDim2.fromScale(alpha, 1), UDim2.new(alpha, 0, 0.5, 0)
    local enabled = Settings.autoSellEggs
    multiplierCaption.TextColor3 = enabled and COLOURS.text or COLOURS.muted
    fill.BackgroundColor3 = enabled and COLOURS.accent or COLOURS.control
    if not enabled and gesture and gesture.mode == "slider" then EndGesture() end
end
UpdateThreshold()
for index = 3, #DEFINITIONS do
    local definition = DEFINITIONS[index]
    AddToggle(definition.id, definition.label, definition.setting)
end
AddToggle("afk", "Anti-AFK", "antiAFK")
Heading(UI.farm, "OBERFLÄCHE")
local hotkeyRow = Row(UI.farm, "UI ein- / ausblenden", 54)
local hotkeyButton = Button(hotkeyRow, "", 110)
hotkeyButton.Position = UDim2.new(1, -122, 0.5, -17)
local KEY_NAMES = { RightControl = "Rechte Strg", LeftControl = "Linke Strg",
    RightShift = "Rechte Shift", LeftShift = "Linke Shift" }
local function KeyName() return KEY_NAMES[uiKey.Name] or uiKey.Name end
hotkeyButton.Text = KeyName()

Heading(UI.stats, "AKTUELLE WERTE")
local Stat = {}
for _, entry in ipairs({
    {"eggs", "Eier"}, {"eps", "Eier pro Sekunde (ca.)"}, {"cash", "Cash"},
    {"multiplier", "Eier-Multiplikator"}, {"group", "Nächste Gruppenbelohnung"},
    {"rebirth", "Rebirth-Fortschritt"}, {"gems", "Gems-Reset"},
}) do
    local row, caption = Row(UI.stats, entry[2], 58)
    caption.Size = UDim2.new(0.45, -18, 1, 0)
    local value = Text(row, "Nicht verfügbar", 12, true)
    value.Size, value.Position = UDim2.new(0.55, -18, 1, 0), UDim2.new(0.45, 6, 0, 0)
    value.TextXAlignment = Enum.TextXAlignment.Right
    Stat[entry[1]] = value
end

local positioned = false
local function RememberPosition()
    Settings.uiPosition = {
        xScale = 0, xOffset = UI.window.Position.X.Offset,
        yScale = 0, yOffset = UI.window.Position.Y.Offset,
    }
    SaveSoon()
end

local function MoveWindow(x, y)
    local size, window = UI.host.AbsoluteSize, UI.window.Size
    x = math.clamp(x, 0, math.max(0, size.X - window.X.Offset))
    y = math.clamp(y, 0, math.max(0, size.Y - window.Y.Offset))
    UI.window.Position = UDim2.fromOffset(x, y)
end

LayoutWindow = function()
    local size = UI.host.AbsoluteSize
    if size.X < 32 or size.Y < 32 then return end
    local scale = math.min(1, (size.X - 16) / WIDTH, (size.Y - 16) / HEIGHT)
    local height = UI.minimized and HEADER or HEIGHT
    UI.scale.Scale = scale
    UI.main.Size, UI.window.Size = UDim2.fromOffset(WIDTH, height), UDim2.fromOffset(WIDTH * scale, height * scale)
    if not positioned then
        local p = Settings.uiPosition
        local isDefault = p.xScale == 0.5 and p.xOffset == -215 and p.yScale == 0.5 and p.yOffset == -285
        local x = isDefault and (size.X - WIDTH * scale) / 2 or p.xScale * size.X + p.xOffset
        local y = isDefault and (size.Y - height * scale) / 2 or p.yScale * size.Y + p.yOffset
        MoveWindow(x, y)
        positioned = true
    else
        MoveWindow(UI.window.Position.X.Offset, UI.window.Position.Y.Offset)
    end
end

local function Slide(input)
    if not Settings.autoSellEggs or sliderHit.AbsoluteSize.X <= 0 then return end
    local alpha = math.clamp((input.Position.X - sliderHit.AbsolutePosition.X) / sliderHit.AbsoluteSize.X, 0, 1)
    Settings.sellAtMultiplier = math.floor((0.5 + alpha) * 20 + 0.5) / 20
    UpdateThreshold()
    Runtime.Dirty = true
end

EndGesture = function()
    if not gesture then return end
    local mode = gesture.mode
    gesture = nil
    UI.farm.ScrollingEnabled = true
    if mode == "drag" then RememberPosition() else SaveSoon() end
end

local function BeginGesture(mode, input)
    local kind = input.UserInputType
    if gesture or (kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch) then return end
    if mode == "slider" and not Settings.autoSellEggs then return end
    gesture = { mode = mode, input = input, start = input.Position, position = UI.window.Position }
    if mode == "slider" then UI.farm.ScrollingEnabled = false Slide(input) end
end

Track(title.InputBegan, function(input) BeginGesture("drag", input) end)
Track(sliderHit.InputBegan, function(input) BeginGesture("slider", input) end)
Track(knob.InputBegan, function(input) BeginGesture("slider", input) end)
Track(Input.InputChanged, function(input)
    if not gesture then return end
    local touch = gesture.input.UserInputType == Enum.UserInputType.Touch
    if touch and input ~= gesture.input then return end
    if not touch and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    if gesture.mode == "slider" then Slide(input) else
        local delta = input.Position - gesture.start
        MoveWindow(gesture.position.X.Offset + delta.X, gesture.position.Y.Offset + delta.Y)
    end
end)
Track(Input.InputEnded, function(input)
    if gesture and (input == gesture.input
        or (gesture.input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)) then
        EndGesture()
    end
end)
Track(Input.WindowFocusReleased, EndGesture)
Track(UI.host:GetPropertyChangedSignal("AbsoluteSize"), function() EndGesture() LayoutWindow() end)

local function CancelHotkey()
    waitingForHotkey = false
    hotkeyButton.Text = KeyName()
end
local function VisibleStats()
    return UI.window.Visible and not UI.minimized and UI.page == "stats"
end
local function ShowPage(name)
    CancelHotkey()
    UI.page = name
    UI.farm.Visible, UI.stats.Visible = name == "farm", name == "stats"
    farmTab.BackgroundColor3 = name == "farm" and COLOURS.accent or COLOURS.control
    statsTab.BackgroundColor3 = name == "stats" and COLOURS.accent or COLOURS.control
    nextUI, Runtime.Dirty = 0, true
    QueueTick(0)
end

Track(farmTab.Activated, function() ShowPage("farm") end)
Track(statsTab.Activated, function() ShowPage("stats") end)
Track(minimize.Activated, function()
    EndGesture()
    CancelHotkey()
    UI.minimized = not UI.minimized
    UI.tabs.Visible, UI.pages.Visible, UI.status.Visible = not UI.minimized, not UI.minimized, not UI.minimized
    minimize.Text = UI.minimized and "+" or "–"
    LayoutWindow()
    nextUI = 0
    QueueTick(0)
end)
Track(close.Activated, function() EndGesture() Runtime.Stop() end)
Track(UI.screen.Destroying, function() Runtime.Stop(true) end)
Track(hotkeyButton.Activated, function()
    waitingForHotkey = true
    hotkeyButton.Text = "Taste drücken …"
    Status("Neue Taste drücken; ESC bricht ab.", "info")
end)
Track(Input.InputBegan, function(input, processed)
    if Input:GetFocusedTextBox() then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if waitingForHotkey then
        if input.KeyCode == Enum.KeyCode.Escape then CancelHotkey() return end
        if input.KeyCode == Enum.KeyCode.Unknown then return end
        uiKey = input.KeyCode
        Settings.uiHotkey = uiKey.Name
        CancelHotkey()
        SaveSoon()
        local conflict = processed or uiKey == Enum.KeyCode.W or uiKey == Enum.KeyCode.A
            or uiKey == Enum.KeyCode.S or uiKey == Enum.KeyCode.D or uiKey == Enum.KeyCode.Space
        Status(conflict and "Hotkey gespeichert; diese Taste kann mit der Spielsteuerung kollidieren."
            or "Hotkey gespeichert.", conflict and "warning" or "success")
        return
    end
    if not processed and input.KeyCode == uiKey then
        EndGesture()
        UI.window.Visible = not UI.window.Visible
        nextUI = 0
        QueueTick(0)
    end
end)
Track(Player.Idled, function()
    if not Settings.antiAFK then return end
    local ok, err = pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end)
    if not ok then Log("warning", "afk", "Anti-AFK nicht verfügbar. Berechtigung der Umgebung prüfen.", err) end
end)
Track(PlayerGui.ChildAdded, function() nextRefs = 0 QueueTick(0) end)
Track(PlayerGui.ChildRemoved, function() nextRefs = 0 QueueTick(0) end)
Track(Player.CharacterAdded, function() nextRefs = 0 QueueTick(0) end)

local function RefreshUI(now)
    if not UI.window.Visible or UI.minimized then return end
    for _, definition in ipairs(DEFINITIONS) do
        local job = Runtime.Jobs[definition.id]
        local hint = IntervalText(definition.id)
        if Settings[definition.setting] and job.hint then hint = hint .. " · " .. job.hint end
        SetText(Runtime.Controls[definition.id].hint, hint)
    end
    if not VisibleStats() then return end
    SampleEggs(now)
    FindRebirth(now)
    SetText(Stat.eggs, Cache.eggs or "Nicht verfügbar")
    SetText(Stat.eps, eggRate and FormatNumber(eggRate) .. "/s"
        or now - lastDeposit < 1.5 and "Beim Verkaufen nicht messbar" or "Wird berechnet …")
    SetText(Stat.cash, Cache.cash or "Nicht verfügbar")
    SetText(Stat.multiplier, Cache.multiplier and string.format("%.2fx", Cache.multiplier):gsub("%.", ",") or "Nicht verfügbar")
    local group = "Ausgeschaltet"
    if Settings.autoGroupReward then
        local remaining = GroupRemaining()
        group = remaining <= 0 and "Bereit" or (groupEstimated and "ca. " or "") .. FormatTime(remaining)
    end
    SetText(Stat.group, group)
    SetText(Stat.rebirth, rebirthValue or "Rebirth-Fenster öffnen / Pfad prüfen")
    SetText(Stat.gems, Cache.gems or "Nicht verfügbar")
    Runtime.Dirty = false
end

local function FailureDetail(result)
    if type(result) == "table" then return result.message or result.error or result.status or "Ablehnung ohne Details" end
    return result
end

local function BeginRequest(job, event, now)
    local definition = job.definition
    local args = definition.id == "buy"
        and { definition.command, Settings.selectedChickenAmount } or { definition.command }
    local request = { started = now }
    Pending[definition.command] = request
    job.hint = "Antwort ausstehend"
    -- Ausschließlich der Remote-Aufruf benötigt einen separaten, wartenden Task.
    -- Er bleibt bei Stop bis zur Antwort gesperrt; kein blindes Wiederholen.
    request.thread = task.spawn(function()
        local ok, result = pcall(function() return event:InvokeServer(table.unpack(args)) end)
        if Pending[definition.command] == request then Pending[definition.command] = nil end
        if not Runtime.Alive then return end
        local classification = ok and ClassifyResult(result) or "transport"
        if classification == "transport" then
            job.paused, job.hint = true, "Ergebnis unklar – pausiert"
            Log("error", definition.id, definition.label .. ": Verbindung fehlgeschlagen. Spielzustand prüfen, dann aus/ein.", result)
        elseif classification == "waiting" then
            job.waiting, job.waits, job.failures = true, math.min((job.waits or 0) + 1, 8), 0
            job.cashSensitive = WaitingResult(result) == "Nicht genügend Mittel"
            local delay = math.min(Settings.network.retryMax, Settings.network.retryBase * 2 ^ (job.waits - 1))
            job.nextAt = os.clock() + delay
            job.hint = WaitingResult(result) .. " – wartet"
        elseif classification == "rejected" then
            job.waiting = false
            job.failures = job.failures + 1
            if job.failures > Settings.network.maxRetries then
                job.paused, job.hint = true, "Abgelehnt – aus/ein zum Fortsetzen"
                Log("warning", definition.id, definition.label .. ": wiederholt abgelehnt. Voraussetzungen prüfen, dann aus/ein.", FailureDetail(result))
            else
                local delay = math.min(Settings.network.retryMax, Settings.network.retryBase * 2 ^ (job.failures - 1))
                job.nextAt, job.hint = os.clock() + delay, "Wiederholung in " .. Seconds(delay)
                Log("warning", definition.id, definition.label .. ": abgelehnt; Wiederholung mit Pause.", FailureDetail(result))
            end
        else
            job.failures, job.hint, job.waiting, job.waits = 0, nil, false, 0
            if definition.id == "sell" then
                lastDeposit, eggSamples, eggRate = os.clock(), {}, nil
                job.nextAt = lastDeposit + Settings.intervals.sell
            elseif definition.id == "group" then
                -- Kompatibilität mit Remotes ohne Rückgabewert: Timer bleibt eine Schätzung.
                Settings.lastGroupRewardAttempt = os.time()
                groupEstimated = classification ~= "confirmed"
                job.nextAt = os.clock() + GROUP_INTERVAL
                SaveSoon()
            end
            Status(definition.label .. (classification == "confirmed"
                and ": vom Server bestätigt." or ": Anfrage beendet; Ergebnis unbestätigt."), "info")
        end
        Runtime.Dirty = true
        QueueTick(0)
    end)
end

local function StepJob(job, now)
    local definition = job.definition
    if not Settings[definition.setting] then return nil end
    local pending = Pending[definition.command]
    if pending then
        local deadline = pending.started + Settings.network.timeout
        if now >= deadline then
            job.hint = "Zeitlimit – keine Doppelanfrage"
            Log("error", "timeout-" .. definition.id,
                definition.label .. ": Antwort fehlt. Warten oder Spielverbindung neu herstellen.")
            return now + REF_PERIOD
        end
        job.hint = "Antwort ausstehend"
        return deadline
    end
    if job.paused then return nil end
    if now < job.nextAt then return job.nextAt end
    local interval = Settings.intervals[definition.id]
    job.nextAt = now + interval
    local source = Sources.remote
    if not source or not source.object or not source.object:IsDescendantOf(ReplicatedStorage) then
        job.hint = "Remote fehlt – Spiel/Pfad prüfen"
        job.nextAt = now + REF_PERIOD
        return job.nextAt
    end
    if definition.id == "sell" then
        local eggs, multiplier = Cache.eggNumber, Cache.multiplier
        if not eggs or not multiplier then job.hint = "Spielwerte fehlen – warten"
        elseif eggs <= 0 then job.hint = "Keine Eier vorhanden"
        elseif multiplier < Settings.sellAtMultiplier then job.hint = "Wartet auf Multiplikator"
        elseif now < lastDeposit + interval then job.hint = "Verkaufspause"
        else BeginRequest(job, source.object, now) end
    elseif definition.id == "group" and GroupRemaining() > 0 then
        job.nextAt, job.hint = now + GroupRemaining(), nil
    else
        BeginRequest(job, source.object, now)
    end
    return Pending[definition.command] and now + Settings.network.timeout or job.nextAt
end

QueueTick = function(delay)
    if not Runtime.Alive then return end
    Cancel(tickThread)
    tickThread = Schedule(delay, function()
        tickThread = nil
        local ok, err = pcall(Tick)
        if not ok and Runtime.Alive then
            Log("error", "scheduler", "Interner Scheduler-Fehler. Script neu starten; Details in der Konsole.", err)
            QueueTick(2)
        end
    end)
end

Tick = function()
    if not Runtime.Alive then return end
    local now = os.clock()
    if now >= nextRefs then
        nextRefs = now + REF_PERIOD
        RefreshSources()
        if now >= bootDeadline and (not Sources.remote.object or not Sources.multiplier.object or not Sources.eggs.object) then
            Log("warning", "missing", "Spielobjekte fehlen. Laden abwarten oder Pfade unter SOURCES prüfen.")
        end
    end
    local nextWake = nextRefs
    for _, definition in ipairs(DEFINITIONS) do
        local job = Runtime.Jobs[definition.id]
        local ok, due = pcall(StepJob, job, now)
        if ok then
            if due then nextWake = math.min(nextWake, due) end
        else
            job.paused, job.hint = true, "Interner Fehler – pausiert"
            Log("error", "job-" .. definition.id, definition.label .. ": Codefehler; Script neu starten.", due)
        end
    end
    if UI.window.Visible and not UI.minimized then
        if now >= nextUI then
            nextUI = now + UI_PERIOD
            local ok, err = pcall(RefreshUI, now)
            if not ok then Log("warning", "stats", "Anzeige konnte nicht aktualisiert werden. HUD/Pfade prüfen.", err) end
        end
        nextWake = math.min(nextWake, nextUI)
    end
    -- Keine Nachholsalven: versäumte Intervalle werden nicht als Burst gesendet.
    QueueTick(math.max(0.02, nextWake - os.clock()))
end

LayoutWindow()
ShowPage("farm")
Log("info", "start", "Version " .. VERSION .. " gestartet. Rechte Strg bzw. gespeicherter Hotkey blendet die UI aus.")
if not FILE_SUPPORT then
    Log("warning", "no-files", "Dateispeicherung nicht verfügbar; Einstellungen gelten nur in dieser Sitzung.")
end
SaveSoon()
QueueTick(0)
