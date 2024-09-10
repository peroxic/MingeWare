-- Define keys and defaults
local spawnKey = KEY_X
local guiKey = KEY_HOME
local cycleKey = KEY_N
local detectionRadius = 100
local highlightColorSelected = Color(0, 255, 0, 150)
local highlightColorUnselected = Color(255, 0, 0, 150)
local currentTheme = "dark"
local props = {}
local selectedProp
local selectedPlayer
local propMenu
local lastDetectionTime = 0
local detectionInterval = 2
local placementOptions = {
    ["Head"] = Vector(0, 0, 80),
    ["Chest"] = Vector(0, 0, 30),
    ["Legs"] = Vector(0, 0, -20),
    ["Feet"] = Vector(0, 0, -40)
}
local selectedPlacement = "Chest"
local logEntries = {}  -- Log entries for this session
local notificationDuration = 4
local notificationSpacing = 5
local lastNotificationTime = 0
local notificationPosition = "TopRight"
local displayCurrentTime = false
local customNotificationDuration = 4

-- Notification system
local notifications = {}

local function LogEvent(message)
    -- Log the current time with os.time() in a human-readable format
    local timestamp = os.date("%Y-%m-%d %H:%M:%S", os.time())
    table.insert(logEntries, {time = timestamp, message = message})
end

local function ShowNotification(message, isError)
    local currentTime = CurTime()
    if currentTime - lastNotificationTime < notificationSpacing then
        return
    end

    lastNotificationTime = currentTime
    local color = isError and Color(255, 0, 0, 255) or Color(0, 255, 0, 255)

    table.insert(notifications, {message = message, time = currentTime, color = color})

    -- Log the error or event with timestamp
    LogEvent(message)
end

local function DrawNotifications()
    local currentTime = CurTime()
    local xOffset, yOffset = ScrW() - 250, ScrH() - 50

    -- Set offsets based on position
    if notificationPosition == "TopLeft" then
        xOffset, yOffset = 10, 10
    elseif notificationPosition == "TopRight" then
        xOffset, yOffset = ScrW() - 250, 10
    elseif notificationPosition == "BottomLeft" then
        xOffset, yOffset = 10, ScrH() - 50
    elseif notificationPosition == "BottomRight" then
        xOffset, yOffset = ScrW() - 250, ScrH() - 50
    end

    for i, notif in ipairs(notifications) do
        if currentTime - notif.time > customNotificationDuration then
            table.remove(notifications, i)
        else
            local alpha = 255 * (1 - (currentTime - notif.time) / customNotificationDuration)
            local barWidth = (ScrW() / customNotificationDuration) * (currentTime - notif.time)

            surface.SetDrawColor(notif.color.r, notif.color.g, notif.color.b, alpha)
            surface.DrawRect(xOffset, yOffset, 240, 50)

            surface.SetDrawColor(Color(0, 0, 0, alpha))
            surface.DrawRect(xOffset, yOffset + 45, barWidth, 5)

            draw.SimpleText(notif.message, "DermaDefault", xOffset + 120, yOffset + 25, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            yOffset = yOffset - 55
        end
    end
end

-- Load and Save settings
local function LoadSettings()
    if file.Exists("mingeware_settings.txt", "DATA") then
        local settings = file.Read("mingeware_settings.txt", "DATA")
        local data = util.JSONToTable(settings)
        if data then
            props = data.props or {}
            detectionRadius = data.radius or 100
            highlightColorUnselected = Color(data.highlightColorUnselected[1], data.highlightColorUnselected[2], data.highlightColorUnselected[3], data.highlightColorUnselected[4]) or highlightColorUnselected
            highlightColorSelected = Color(data.highlightColorSelected[1], data.highlightColorSelected[2], data.highlightColorSelected[3], data.highlightColorSelected[4]) or highlightColorSelected
            selectedPlacement = data.placement or selectedPlacement
            notificationPosition = data.notificationPosition or notificationPosition
            displayCurrentTime = data.displayCurrentTime or displayCurrentTime
            customNotificationDuration = data.customNotificationDuration or customNotificationDuration
            currentTheme = data.currentTheme or currentTheme
        end
    end
end

local function SaveSettings()
    local data = {
        props = props,
        radius = detectionRadius,
        highlightColorUnselected = {highlightColorUnselected.r, highlightColorUnselected.g, highlightColorUnselected.b, highlightColorUnselected.a},
        highlightColorSelected = {highlightColorSelected.r, highlightColorSelected.g, highlightColorSelected.b, highlightColorSelected.a},
        placement = selectedPlacement,
        notificationPosition = notificationPosition,
        displayCurrentTime = displayCurrentTime,
        customNotificationDuration = customNotificationDuration,
        currentTheme = currentTheme
    }
    file.Write("mingeware_settings.txt", util.TableToJSON(data))
end

-- Create GUI
local function CreatePropMenu()
    local frame = vgui.Create("DFrame")
    frame:SetSize(600, 600)
    frame:SetTitle("MingeWare 2.0 Alpha - Developer Version")
    frame:SetVisible(false)
    frame:SetDraggable(true)
    frame:SetBackgroundColor(themeColors[currentTheme].background)
    frame:SetTitleBarHeight(0)
    frame:Center()

    local propertySheet = vgui.Create("DPropertySheet", frame)
    propertySheet:SetPos(10, 30)
    propertySheet:SetSize(580, 550)

    -- Props Tab
    local propTab = vgui.Create("DPanel", propertySheet)
    propTab:SetBackgroundColor(themeColors[currentTheme].background)

    local propDropdown = vgui.Create("DComboBox", propTab)
    propDropdown:SetPos(10, 10)
    propDropdown:SetSize(200, 20)
    propDropdown:SetValue("Select Prop")

    local function UpdatePropDropdown()
        propDropdown:Clear()
        for _, prop in ipairs(props) do
            propDropdown:AddChoice(prop, prop)
        end
    end

    UpdatePropDropdown()

    local modelInput = vgui.Create("DTextEntry", propTab)
    modelInput:SetPos(10, 40)
    modelInput:SetSize(200, 20)
    modelInput:SetPlaceholderText("Enter model path")

    local addButton = vgui.Create("DButton", propTab)
    addButton:SetPos(220, 40)
    addButton:SetSize(80, 20)
    addButton:SetText("Add Model")
    addButton:SetBackgroundColor(themeColors[currentTheme].button)
    addButton:SetTextColor(themeColors[currentTheme].text)
    addButton.DoClick = function()
        local modelPath = modelInput:GetValue()
        if modelPath and modelPath ~= "" then
            if not table.HasValue(props, modelPath) then
                if util.IsValidModel(modelPath) then
                    table.insert(props, modelPath)
                    UpdatePropDropdown()
                    SaveSettings()
                else
                    ShowNotification("[MingeWare]: Error: Model not found!", true)
                end
            else
                ShowNotification("[MingeWare]: Model already exists in the list!", true)
            end
        end
    end

    local removeButton = vgui.Create("DButton", propTab)
    removeButton:SetPos(310, 40)
    removeButton:SetSize(80, 20)
    removeButton:SetText("Remove Model")
    removeButton:SetBackgroundColor(themeColors[currentTheme].button)
    removeButton:SetTextColor(themeColors[currentTheme].text)
    removeButton.DoClick = function()
        local selected = propDropdown:GetSelected()
        if selected then
            propDropdown:RemoveChoice(selected)
            table.RemoveByValue(props, selected)
            SaveSettings()
        end
    end

    local radiusSlider = vgui.Create("DNumSlider", propTab)
    radiusSlider:SetPos(10, 70)
    radiusSlider:SetSize(300, 30)
    radiusSlider:SetText("Detection Radius")
    radiusSlider:SetMin(10)
    radiusSlider:SetMax(500)
    radiusSlider:SetValue(detectionRadius)
    radiusSlider:SetDecimals(0)
    radiusSlider.OnValueChanged = function(_, value)
        detectionRadius = value
        SaveSettings()
    end

    local previewLabel = vgui.Create("DLabel", propTab)
    previewLabel:SetPos(10, 110)
    previewLabel:SetSize(300, 20)
    previewLabel:SetText("Prop Preview:")
    
    local propPreview = vgui.Create("DModelPanel", propTab)
    propPreview:SetPos(10, 130)
    propPreview:SetSize(300, 300)
    local defaultModel = "models/props_c17/oildrum001.mdl"
    propPreview:SetModel(defaultModel)

    if not util.IsValidModel(defaultModel) then
        ShowNotification("[MingeWare]: Error: Default model not found!", true)
    end

    propDropdown.OnSelect = function(_, _, modelPath)
        if util.IsValidModel(modelPath) then
            propPreview:SetModel(modelPath)
            selectedProp = modelPath
            SaveSettings()
        else
            ShowNotification("[MingeWare]: Error: Model not found!", true)
        end
    end

    local placementDropdown = vgui.Create("DComboBox", propTab)
    placementDropdown:SetPos(10, 440)
    placementDropdown:SetSize(200, 20)
    placementDropdown:SetValue("Placement Offset")

    for option, _ in pairs(placementOptions) do
        placementDropdown:AddChoice(option, option)
    end

    placementDropdown.OnSelect = function(_, _, value)
        selectedPlacement = value
        SaveSettings()
    end

    -- Logs Tab
    local logTab = vgui.Create("DPanel", propertySheet)
    logTab:SetBackgroundColor(themeColors[currentTheme].background)

    local logList = vgui.Create("DListView", logTab)
    logList:SetPos(10, 10)
    logList:SetSize(560, 530)
    logList:AddColumn("Timestamp")
    logList:AddColumn("Message")

    -- Function to update the log entries
    local function UpdateLog()
        logList:Clear()
        for _, entry in ipairs(logEntries) do
            logList:AddLine(entry.time, entry.message)
        end
    end

    -- Update the log when the tab is opened
    propertySheet.OnActiveTabChanged = function(_, newTab)
        if newTab:GetPanel() == logTab then
            UpdateLog()
        end
    end

    -- Adding Visuals Tab
    local visualsTab = vgui.Create("DPanel", propertySheet)
    visualsTab:SetBackgroundColor(themeColors[currentTheme].background)

    -- Theme Changer
    local themeDropdown = vgui.Create("DComboBox", visualsTab)
    themeDropdown:SetPos(10, 10)
    themeDropdown:SetSize(200, 20)
    themeDropdown:SetValue("Select Theme")
    themeDropdown:AddChoice("dark")
    themeDropdown:AddChoice("light")
    themeDropdown.OnSelect = function(_, _, value)
        currentTheme = value
        SaveSettings()
    end

    -- Color selectors for highlights
    local highlightColorSelectedPicker = vgui.Create("DColorMixer", visualsTab)
    highlightColorSelectedPicker:SetPos(10, 40)
    highlightColorSelectedPicker:SetSize(250, 150)
    highlightColorSelectedPicker:SetColor(highlightColorSelected)
    highlightColorSelectedPicker:SetLabel("Selected Highlight Color")
    highlightColorSelectedPicker.ValueChanged = function(picker)
        highlightColorSelected = picker:GetColor()
        SaveSettings()
    end

    local highlightColorUnselectedPicker = vgui.Create("DColorMixer", visualsTab)
    highlightColorUnselectedPicker:SetPos(10, 200)
    highlightColorUnselectedPicker:SetSize(250, 150)
    highlightColorUnselectedPicker:SetColor(highlightColorUnselected)
    highlightColorUnselectedPicker:SetLabel("Unselected Highlight Color")
    highlightColorUnselectedPicker.ValueChanged = function(picker)
        highlightColorUnselected = picker:GetColor()
        SaveSettings()
    end

    -- Notification Settings
    local notificationDurationSlider = vgui.Create("DNumSlider", visualsTab)
    notificationDurationSlider:SetPos(10, 360)
    notificationDurationSlider:SetSize(300, 30)
    notificationDurationSlider:SetText("Notification Duration")
    notificationDurationSlider:SetMin(1)
    notificationDurationSlider:SetMax(10)
    notificationDurationSlider:SetValue(customNotificationDuration)
    notificationDurationSlider:SetDecimals(0)
    notificationDurationSlider.OnValueChanged = function(_, value)
        customNotificationDuration = value
        SaveSettings()
    end

    local notificationPositionDropdown = vgui.Create("DComboBox", visualsTab)
    notificationPositionDropdown:SetPos(10, 400)
    notificationPositionDropdown:SetSize(200, 20)
    notificationPositionDropdown:SetValue("Notification Position")
    notificationPositionDropdown:AddChoice("TopLeft")
    notificationPositionDropdown:AddChoice("TopRight")
    notificationPositionDropdown:AddChoice("BottomLeft")
    notificationPositionDropdown:AddChoice("BottomRight")
    notificationPositionDropdown.OnSelect = function(_, _, value)
        notificationPosition = value
        SaveSettings()
    end

    -- Adding Settings Tab
    local settingsTab = vgui.Create("DPanel", propertySheet)
    settingsTab:SetBackgroundColor(themeColors[currentTheme].background)
    -- Add settings-related settings here

    -- Adding all tabs to property sheet
    propertySheet:AddSheet("Props", propTab, "icon16/box.png")
    propertySheet:AddSheet("Visuals", visualsTab, "icon16/eye.png")
    propertySheet:AddSheet("Settings", settingsTab, "icon16/cog.png")
    propertySheet:AddSheet("Logs", logTab, "icon16/bug.png")

    return frame
end

-- Update time display
local function UpdateTime()
    if displayCurrentTime then
        local currentTime = os.date("%H:%M:%S")
        local xOffset = (notificationPosition == "TopLeft" or notificationPosition == "BottomLeft") and 10 or (ScrW() - 200)
        local yOffset = (notificationPosition == "TopLeft" or notificationPosition == "TopRight") and 10 or (ScrH() - 30)
        
        draw.SimpleText("Current Time: " .. currentTime, "DermaDefault", xOffset, yOffset, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
end

-- Spawn prop on player
local function SpawnPropOnPlayer(player)
    local prop = selectedProp
    if not prop or not file.Exists(prop, "GAME") then
        ShowNotification("[MingeWare]: Invalid prop model!", true)
        return
    end

    local offset = placementOptions[selectedPlacement] or Vector(0, 0, 30)
    local spawnPos = player:GetPos() + offset
    local ent = ents.Create("prop_physics")
    ent:SetModel(prop)
    ent:SetPos(spawnPos)
    ent:Spawn()
end

-- Efficient player detection
local function DetectPlayers()
    local currentTime = CurTime()
    if currentTime - lastDetectionTime < detectionInterval then return end
    lastDetectionTime = currentTime

    local plyList = player.GetAll()
    local playerList = {}

    for _, ply in ipairs(plyList) do
        if ply ~= LocalPlayer() and ply:Alive() then
            local dist = ply:GetPos():DistToSqr(LocalPlayer():GetPos())
            if dist <= detectionRadius ^ 2 then
                table.insert(playerList, ply)
            end
        end
    end

    return playerList
end

-- Highlight players
local function HighlightPlayers()
    local playerList = DetectPlayers()
    for _, ply in ipairs(playerList) do
        if ply ~= selectedPlayer then
            ply:SetColor(highlightColorUnselected)
        else
            ply:SetColor(highlightColorSelected)
        end
    end
end

-- Cycle through highlighted players
local function CycleHighlightedPlayers()
    local playerList = DetectPlayers()
    if #playerList == 0 then return end

    local currentIndex = table.KeyFromValue(playerList, selectedPlayer) or 0
    currentIndex = (currentIndex % #playerList) + 1
    selectedPlayer = playerList[currentIndex]
end

-- Key press detection
hook.Add("Think", "MingeWareThink", function()
    if input.IsKeyDown(spawnKey) then
        if selectedPlayer then
            SpawnPropOnPlayer(selectedPlayer)
        else
            ShowNotification("[MingeWare]: No player selected!", true)
        end
    end

    if input.IsKeyDown(guiKey) then
        if not propMenu then
            propMenu = CreatePropMenu()
        end
        propMenu:SetVisible(not propMenu:IsVisible())
    end

    if input.IsKeyDown(cycleKey) then
        CycleHighlightedPlayers()
    end

    HighlightPlayers()
end)

-- Draw notifications and time
hook.Add("HUDPaint", "DrawNotificationsAndTime", function()
    DrawNotifications()
    UpdateTime()
end)

-- Load settings when the script starts
LoadSettings()
