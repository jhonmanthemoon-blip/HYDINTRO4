--// PINSAVE AUTO LOADER: downloads the 20 sheets + audio into workspace/pinsave (only what is missing), then plays the video
--// Run it with:
--// loadstring(game:HttpGet("https://raw.githubusercontent.com/jhonmanthemoon-blip/HYDINTRO4/main/pinsave.lua"))()
local DL_REPO     = "jhonmanthemoon-blip/HYDINTRO4"   -- <- change to your repo (public) that holds sheet_01.jpg ... sheet_20.jpg + audio.mp3
local DL_BRANCH   = "main"
-- it tries the main folder of the repo first, then a folder called pinsave, so both upload layouts work
local DL_BASES = {
    "https://raw.githubusercontent.com/" .. DL_REPO .. "/" .. DL_BRANCH .. "/",
    "https://raw.githubusercontent.com/" .. DL_REPO .. "/" .. DL_BRANCH .. "/pinsave/",
}
local DL_FOLDER   = "pinsave"
local DL_SHEETS   = 20
local DL_THREADS  = 4      -- downloads at the same time (sheets are big, 4 is plenty)

do
    local Players = game:GetService("Players")

    local function fetch(url)
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if ok and type(body) == "string" and #body > 0 then return body end
        local req = (syn and syn.request) or request or http_request or (http and http.request)
        if req then
            local ok2, res = pcall(req, {Url = url, Method = "GET"})
            if ok2 and res and res.StatusCode == 200 and type(res.Body) == "string" and #res.Body > 0 then
                return res.Body
            end
        end
        return nil
    end

    -- reject "404: Not Found" pages and broken downloads
    local function valid(name, body)
        if #body < 200 then return false end
        if name:sub(-4) == ".jpg" then
            return body:byte(1) == 0xFF and body:byte(2) == 0xD8
        end
        return true
    end

    local function haveFile(path)
        if not isfile(path) then return false end
        local ok, data = pcall(readfile, path)
        return ok and type(data) == "string" and #data >= 200
    end

    if not isfolder(DL_FOLDER) then makefolder(DL_FOLDER) end

    local names = {"audio.mp3"}
    for i = 1, DL_SHEETS do
        table.insert(names, string.format("sheet_%02d.jpg", i))
    end

    local missing = {}
    for _, name in ipairs(names) do
        if not haveFile(DL_FOLDER .. "/" .. name) then table.insert(missing, name) end
    end

    if #missing > 0 then
        -- small progress screen
        local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
        local old = playerGui:FindFirstChild("PinsaveDownload")
        if old then old:Destroy() end
        local gui = Instance.new("ScreenGui")
        gui.Name = "PinsaveDownload"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 999999
        gui.Parent = playerGui

        local bgf = Instance.new("Frame")
        bgf.Size = UDim2.fromScale(1, 1)
        bgf.BackgroundColor3 = Color3.new(0, 0, 0)
        bgf.BorderSizePixel = 0
        bgf.Parent = gui

        local label = Instance.new("TextLabel")
        label.AnchorPoint = Vector2.new(0.5, 0.5)
        label.Position = UDim2.fromScale(0.5, 0.45)
        label.Size = UDim2.fromOffset(500, 30)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 20
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Text = "Downloading video... 0 / " .. #missing
        label.Parent = bgf

        local track = Instance.new("Frame")
        track.AnchorPoint = Vector2.new(0.5, 0.5)
        track.Position = UDim2.fromScale(0.5, 0.52)
        track.Size = UDim2.fromOffset(360, 8)
        track.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        track.BorderSizePixel = 0
        track.Parent = bgf
        local fill = Instance.new("Frame")
        fill.Size = UDim2.fromScale(0, 1)
        fill.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
        fill.BorderSizePixel = 0
        fill.Parent = track

        local nextIndex, done, running = 0, 0, DL_THREADS
        local failed = {}

        local function worker()
            while true do
                nextIndex += 1
                local name = missing[nextIndex]
                if not name then return end
                local ok = false
                for attempt = 1, 3 do
                    for _, base in ipairs(DL_BASES) do
                        local body = fetch(base .. name)
                        if body and valid(name, body) then
                            writefile(DL_FOLDER .. "/" .. name, body)
                            ok = true
                            -- remember the base that worked so the next files try it first
                            if base ~= DL_BASES[1] then DL_BASES[1], DL_BASES[2] = DL_BASES[2], DL_BASES[1] end
                            break
                        end
                    end
                    if ok then break end
                    task.wait(0.3 * attempt)
                end
                if not ok then
                    if name == "audio.mp3" then
                        warn("[PINSAVE] audio.mp3 not found in the repo, playing without sound")
                    else
                        table.insert(failed, name)
                    end
                end
                done += 1
                label.Text = "Downloading video... " .. done .. " / " .. #missing
                fill.Size = UDim2.fromScale(done / #missing, 1)
            end
        end

        for _ = 1, DL_THREADS do
            task.spawn(function()
                worker()
                running -= 1
            end)
        end
        while running > 0 do task.wait(0.1) end

        if #failed > 0 then
            warn("[PINSAVE] could not download: " .. table.concat(failed, ", ", 1, math.min(#failed, 10)) .. (#failed > 10 and " ..." or ""))
            warn("[PINSAVE] check DL_REPO and that your repo is public and has the files")
            label.TextColor3 = Color3.fromRGB(255, 90, 90)
            label.Text = "Download failed (" .. #failed .. " files) - see console"
            task.wait(5)
            gui:Destroy()
            return
        end
        gui:Destroy()
    end
end

--// CONFIG (20 sheets, 4096x4096 each, 7 columns x 4 rows = 28 frames of 576x1024 per sheet, 560 frames, 16.3 seconds)
local FOLDER       = "pinsave/"
local SHEETS       = 20
local COLS         = 7
local PER_SHEET    = 28
local FRAME_W      = 576
local FRAME_H      = 1024
local SHEET_PX     = 4096
local FRAME_COUNT  = 560
local DURATION     = 16.3                    -- the video stops at 16.3 seconds
local FPS          = FRAME_COUNT / DURATION  -- 34.36 FPS
local LOOP         = false
local AUDIO        = true                    -- plays audio.mp3 and keeps the video in sync with it

--// SHAKE: the screen shakes when the light appears
local SHAKE        = true
local SHAKE_TIMES  = {10.03, 10.43, 12.43, 14.93}  -- seconds in the video where the light flashes
local SHAKE_LEN    = 0.45                          -- how long each shake lasts (seconds)
local SHAKE_POWER  = 0.035                         -- shake strength (fraction of the screen height)
local SHAKE_ZOOM   = 0.07                          -- extra zoom during the shake so no edges show

--// SERVICES
local RunService   = game:GetService("RunService")
local Players      = game:GetService("Players")
local SoundService = game:GetService("SoundService")

--// GUI (full screen)
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("SheetPlayerPinsave")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "SheetPlayerPinsave"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.new(0, 0, 0)
bg.BorderSizePixel = 0
bg.ClipsDescendants = true
bg.Parent = gui

-- everything that shakes lives inside the stage
local stage = Instance.new("Frame")
stage.AnchorPoint = Vector2.new(0.5, 0.5)
stage.Position = UDim2.fromScale(0.5, 0.5)
stage.Size = UDim2.fromScale(1, 1)
stage.BackgroundTransparency = 1
stage.BorderSizePixel = 0
stage.Parent = bg

local stageScale = Instance.new("UIScale")
stageScale.Scale = 1
stageScale.Parent = stage

local FULL   = UDim2.fromScale(1, 1)
local HIDDEN = UDim2.fromOffset(4, 4)

-- two sheet labels: one is on screen while the next sheet loads in the other
local labels = {}
for i = 1, 2 do
    local l = Instance.new("ImageLabel")
    l.AnchorPoint = Vector2.new(0.5, 0.5)
    l.Position = UDim2.fromScale(0.5, 0.5)
    l.Size = HIDDEN
    l.ZIndex = 1
    l.BackgroundTransparency = 1
    l.BorderSizePixel = 0
    l.ScaleType = Enum.ScaleType.Fit
    l.ImageRectSize = Vector2.new(FRAME_W, FRAME_H)
    l.Parent = stage
    labels[i] = l
end

--// SIMPLE SKIP BUTTON
local close = Instance.new("TextButton")
close.Name = "Skip"
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -18, 0, 18)
close.Size = UDim2.fromOffset(112, 42)
close.AutoButtonColor = true
close.BackgroundColor3 = Color3.fromRGB(35, 18, 65)
close.BackgroundTransparency = 0.08
close.BorderSizePixel = 0
close.Text = "SKIP  »"
close.Font = Enum.Font.GothamBold
close.TextSize = 17
close.TextColor3 = Color3.new(1, 1, 1)
close.ZIndex = 10
close.Parent = bg

local skipCorner = Instance.new("UICorner")
skipCorner.CornerRadius = UDim.new(0, 12)
skipCorner.Parent = close

--// SHEET LOADING
local slotSheet = {}

local function slotFor(sheet)
    return (sheet % 2) + 1
end

local function assignSheet(sheet)
    if sheet < 1 or sheet > SHEETS then return end
    local slot = slotFor(sheet)
    if slotSheet[slot] == sheet then return end
    local path = FOLDER .. string.format("sheet_%02d.jpg", sheet)
    if isfile then
        local okf, res = pcall(isfile, path)
        if okf and not res then
            warn("MISSING FILE (not in your executor workspace): " .. path)
        end
    end
    local ok, asset = pcall(getcustomasset, path)
    if ok and asset and asset ~= "" then
        labels[slot].Image = asset
    else
        warn("Failed to load " .. path .. ": " .. tostring(asset))
    end
    slotSheet[slot] = sheet
end

local function reallyLoaded(slot)
    local l = labels[slot]
    return l.IsLoaded or l.ContentImageSize.X > 0
end

-- load the first two sheets before starting so playback never waits (max 6 seconds)
assignSheet(1)
assignSheet(2)
local t0 = os.clock()
while os.clock() - t0 < 6 do
    if reallyLoaded(slotFor(1)) and reallyLoaded(slotFor(2)) then break end
    task.wait()
end

--// AUDIO
local sound
if AUDIO then
    local ok, asset = pcall(getcustomasset, FOLDER .. "audio.mp3")
    if ok and asset and asset ~= "" then
        sound = Instance.new("Sound")
        sound.SoundId = asset
        sound.Volume = 1
        sound.Parent = SoundService
        local t1 = os.clock()
        while not sound.IsLoaded and os.clock() - t1 < 2 do task.wait() end
        if sound.IsLoaded then
            sound:Play()
        else
            warn("audio.mp3 did not load, playing without sound")
            sound:Destroy()
            sound = nil
        end
    else
        warn("Could not load " .. FOLDER .. "audio.mp3")
    end
end

--// SHAKE
local function shakeStrength(t)
    local best = 0
    for _, s in ipairs(SHAKE_TIMES) do
        local d = t - s
        if d >= 0 and d < SHAKE_LEN then
            local k = math.exp(-d / 0.13) -- starts hard, fades out
            if k > best then best = k end
        end
    end
    return best
end

local function applyShake(t)
    if not SHAKE then return end
    local k = shakeStrength(t)
    if k > 0.01 then
        local cam = workspace.CurrentCamera
        local h = cam and cam.ViewportSize.Y or 720
        local amp = h * SHAKE_POWER * k
        stage.Position = UDim2.new(0.5, (math.random() * 2 - 1) * amp, 0.5, (math.random() * 2 - 1) * amp)
        stageScale.Scale = 1 + SHAKE_ZOOM * k
    else
        stage.Position = UDim2.fromScale(0.5, 0.5)
        stageScale.Scale = 1
    end
end

--// PLAYBACK
local frame = 0
local shownKey
local shownSlot
local conn

local function stop()
    if conn then conn:Disconnect() end
    if sound then sound:Stop() sound:Destroy() end
    gui:Destroy()
end
close.MouseButton1Click:Connect(stop)

conn = RunService.RenderStepped:Connect(function(dt)
    frame += math.min(dt, 0.1) * FPS

    -- the audio is the master clock, so picture and sound stay in sync
    if sound and sound.IsPlaying then
        local audioFrame = sound.TimePosition * FPS
        if math.abs(frame - audioFrame) > 3 then
            frame = audioFrame
        end
    end

    local f = math.floor(frame)
    if f >= FRAME_COUNT then
        if LOOP then
            frame, f = 0, 0
            if sound then sound.TimePosition = 0 end
        else
            stop()
            return
        end
    end

    local sheet = f // PER_SHEET + 1
    local idx   = f % PER_SHEET
    local slot  = slotFor(sheet)

    assignSheet(sheet)
    -- start loading the next sheet halfway through this one
    if idx >= PER_SHEET // 2 then
        assignSheet(sheet + 1)
    end

    local key = f
    if shownKey ~= key and reallyLoaded(slot) then
        local l = labels[slot]
        -- the sheet may have been scaled down by Roblox, so read its real size
        local sc = l.ContentImageSize.X / SHEET_PX
        if sc <= 0 then sc = 1 end
        local col = idx % COLS
        local row = idx // COLS
        l.ImageRectSize = Vector2.new(FRAME_W * sc, FRAME_H * sc)
        l.ImageRectOffset = Vector2.new(col * FRAME_W * sc, row * FRAME_H * sc)
        if shownSlot ~= slot then
            l.ZIndex = 2
            l.Size = FULL
            if shownSlot then
                labels[shownSlot].Size = HIDDEN
                labels[shownSlot].ZIndex = 1
            end
            shownSlot = slot
        end
        shownKey = key
    end

    applyShake(frame / FPS)
end)
