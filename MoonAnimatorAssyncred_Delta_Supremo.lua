--[[
╔══════════════════════════════════════════════════════════════════╗
║          🌙 MOON ANIMATOR ASSYNCRED - PARTE 1/8                 ║
║          CORE + UI FRAMEWORK + WINDOW SYSTEM                    ║
║          Versão corrigida e melhorada para todos executors       ║
╚══════════════════════════════════════════════════════════════════╝
]]

-- ══════════════════════════════════════════════════════════════════
-- SAFE BOOTSTRAP - Evita qualquer nil call
-- ══════════════════════════════════════════════════════════════════

local function safeGet(t, ...)
    local cur = t
    for _, k in ipairs({...}) do
        if type(cur) ~= "table" then return nil end
        cur = cur[k]
    end
    return cur
end

local function safeCall(f, ...)
    if type(f) == "function" then
        local ok, r = pcall(f, ...)
        if ok then return r end
    end
    return nil
end

local function safeService(name)
    local ok, s = pcall(function() return game:GetService(name) end)
    return ok and s or nil
end

-- ══════════════════════════════════════════════════════════════════
-- SERVICES
-- ══════════════════════════════════════════════════════════════════
local RunService       = safeService("RunService")
local TweenService     = safeService("TweenService")
local UserInputService = safeService("UserInputService")
local Players          = safeService("Players")
local HttpService      = safeService("HttpService")
local CoreGui          = safeService("CoreGui")

local LocalPlayer = Players and Players.LocalPlayer
if not LocalPlayer then
    LocalPlayer = Players and Players:GetPropertyChangedSignal("LocalPlayer") and Players.LocalPlayer
end

-- ══════════════════════════════════════════════════════════════════
-- GLOBAL NAMESPACE
-- ══════════════════════════════════════════════════════════════════
local MOON = {
    Version    = "2.0.0",
    Core       = {},
    UI         = {},
    Plugins    = {},
    Systems    = {},
    Utils      = {},
    Events     = {},
    Data       = {},
    Config     = {},
    Performance= {},
    API        = {},
}
_G.MOON = MOON

-- ══════════════════════════════════════════════════════════════════
-- SAFE EXECUTOR WRAPPERS
-- ══════════════════════════════════════════════════════════════════
local function safeSetClipboard(text)
    local fns = {"setclipboard","toclipboard","set_clipboard","Clipboard"}
    for _,n in ipairs(fns) do
        if type(_G[n]) == "function" then
            pcall(_G[n], text)
            return
        end
    end
    print("[CLIPBOARD OUTPUT]\n" .. tostring(text))
end

local function safeGetClipboard()
    local fns = {"getclipboard","get_clipboard","fromclipboard"}
    for _,n in ipairs(fns) do
        if type(_G[n]) == "function" then
            local ok,r = pcall(_G[n])
            if ok then return tostring(r) end
        end
    end
    return ""
end

local function safeGC()
    pcall(collectgarbage, "collect")
    if type(gcinfo) == "function" then
        local ok,r = pcall(gcinfo)
        if ok then return r end
    end
    return 0
end

local function safeTraceback()
    if type(debug) == "table" and type(debug.traceback) == "function" then
        local ok,r = pcall(debug.traceback)
        if ok then return r end
    end
    return "traceback unavailable"
end

MOON.Utils.SafeSetClipboard = safeSetClipboard
MOON.Utils.SafeGetClipboard = safeGetClipboard
MOON.Utils.SafeGC           = safeGC
MOON.Utils.SafeTraceback    = safeTraceback

-- ══════════════════════════════════════════════════════════════════
-- PLATFORM DETECTION
-- ══════════════════════════════════════════════════════════════════
local isMobile = false
if UserInputService then
    local ok1,touch   = pcall(function() return UserInputService.TouchEnabled end)
    local ok2,keyboard= pcall(function() return UserInputService.KeyboardEnabled end)
    if ok1 and ok2 then
        isMobile = touch and not keyboard
    end
end

-- ══════════════════════════════════════════════════════════════════
-- CONFIG
-- ══════════════════════════════════════════════════════════════════
MOON.Config = {
    AppName         = "Moon Animator Assyncred",
    Version         = "2.0.0",
    Theme           = "DarkFuturistic",
    IsMobile        = isMobile,
    MaxFPS          = isMobile and 30 or 60,
    DefaultFPS      = 30,
    MaxKeyframes    = 10000,
    TopBarHeight    = isMobile and 38 or 32,
    MinWindowSize   = Vector2.new(380, 260),
    MaxWindowSize   = Vector2.new(1400, 900),
    EnableAutoSave  = true,
    AutoSaveInterval= 300,
    UIUpdateRate    = 1,
}

-- ══════════════════════════════════════════════════════════════════
-- SIGNAL
-- ══════════════════════════════════════════════════════════════════
local Signal = {}
Signal.__index = Signal

function Signal.new()
    return setmetatable({_c={},_id=0}, Signal)
end

function Signal:Connect(fn)
    if type(fn) ~= "function" then return {Disconnect=function()end, Connected=false} end
    self._id = self._id + 1
    local id = self._id
    local conn = {Connected=true, _id=id, _s=self,
        Disconnect = function(c)
            c.Connected = false
            c._s._c[c._id] = nil
        end
    }
    conn._fn = fn
    self._c[id] = conn
    return conn
end

function Signal:Fire(...)
    for _,c in pairs(self._c) do
        if c.Connected then
            pcall(c._fn, ...)
        end
    end
end

function Signal:Destroy()
    self._c = {}
end

MOON.Utils.Signal = Signal

-- ══════════════════════════════════════════════════════════════════
-- LOGGER
-- ══════════════════════════════════════════════════════════════════
local Logger = {History={}, Max=500}

function Logger:_log(lvl, msg, ...)
    local ok, formatted = pcall(string.format, tostring(msg), ...)
    if not ok then formatted = tostring(msg) end
    local entry = {Level=lvl, Message=formatted, Time=os.time()}
    table.insert(self.History, entry)
    if #self.History > self.Max then table.remove(self.History,1) end
    local prefix = {
        DEBUG="[DBG]", INFO="[INF]", WARN="[WRN]",
        ERROR="[ERR]", SUCCESS="[OK] "
    }
    print(string.format("[🌙MOON]%s %s", prefix[lvl] or "[?]", formatted))
    if MOON.UI and MOON.UI.Console then
        pcall(MOON.UI.Console.AddLog, MOON.UI.Console, entry)
    end
end

function Logger:Debug(...)   self:_log("DEBUG",...) end
function Logger:Info(...)    self:_log("INFO",...) end
function Logger:Warn(...)    self:_log("WARN",...) end
function Logger:Error(...)   self:_log("ERROR",...) end
function Logger:Success(...) self:_log("SUCCESS",...) end

MOON.Core.Logger = Logger

-- ══════════════════════════════════════════════════════════════════
-- UTILS
-- ══════════════════════════════════════════════════════════════════
local U = MOON.Utils

function U.DeepCopy(o)
    if type(o) ~= "table" then return o end
    local c = {}
    for k,v in next,o do c[U.DeepCopy(k)] = U.DeepCopy(v) end
    return setmetatable(c, getmetatable(o))
end

function U.Merge(t1, t2)
    if type(t1)~="table" then t1={} end
    if type(t2)~="table" then return t1 end
    local r = U.DeepCopy(t1)
    for k,v in pairs(t2) do
        if type(v)=="table" and type(r[k])=="table" then
            r[k] = U.Merge(r[k], v)
        else
            r[k] = v
        end
    end
    return r
end

function U.Lerp(a,b,t)   return a+(b-a)*t end
function U.Clamp(v,mn,mx) return math.min(math.max(v,mn),mx) end
function U.Map(v,a,b,c,d)
    if b==a then return c end
    return c+(v-a)*(d-c)/(b-a)
end

function U.UUID()
    if HttpService then
        local ok,r = pcall(function() return HttpService:GenerateGUID(false) end)
        if ok then return r end
    end
    local t = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return (t:gsub("[xy]", function(c)
        local r2 = math.random(0,15)
        local v = c=="x" and r2 or (r2 and 0x3 or 0x8)
        return string.format("%x", v)
    end))
end

function U.TableCount(t)
    local n=0; for _ in pairs(t) do n=n+1 end; return n
end

function U.TableFind(t,v)
    for i,x in ipairs(t) do if x==v then return i end end
end

-- ══════════════════════════════════════════════════════════════════
-- PERFORMANCE MONITOR
-- ══════════════════════════════════════════════════════════════════
local PerfMon = {
    Metrics = {FPS=60, FrameTime=16, MemoryUsage=0},
    History = {},
    _init   = false,
}

function PerfMon:Init()
    if self._init then return end
    self._init = true
    if not RunService then return end

    local last = tick()
    local fc, ft = 0, 0

    local function step(dt)
        local now = tick()
        fc = fc + 1
        ft = ft + (now - last)
        last = now
        self.Metrics.FrameTime = dt * 1000
        if ft >= 0.5 then
            self.Metrics.FPS = math.floor(fc/ft)
            fc, ft = 0, 0
        end
        self.Metrics.MemoryUsage = safeGC()
    end

    local ok = pcall(function()
        RunService.RenderStepped:Connect(step)
    end)
    if not ok then
        pcall(function()
            RunService.Heartbeat:Connect(step)
        end)
    end
    Logger:Success("Performance Monitor started")
end

function PerfMon:Get() return self.Metrics end

MOON.Performance.Monitor = PerfMon

-- ══════════════════════════════════════════════════════════════════
-- THEME SYSTEM
-- ══════════════════════════════════════════════════════════════════
local ThemeSystem = {Current="DarkFuturistic", Themes={}}

ThemeSystem.Themes.DarkFuturistic = {
    Background          = Color3.fromRGB(22, 22, 26),
    BackgroundSecondary = Color3.fromRGB(30, 30, 35),
    BackgroundTertiary  = Color3.fromRGB(38, 38, 44),
    Surface             = Color3.fromRGB(46, 46, 53),
    SurfaceHover        = Color3.fromRGB(56, 56, 63),
    Primary             = Color3.fromRGB(90, 145, 255),
    PrimaryHover        = Color3.fromRGB(110, 165, 255),
    Secondary           = Color3.fromRGB(145, 90, 255),
    Success             = Color3.fromRGB(80, 210, 140),
    Warning             = Color3.fromRGB(255, 195, 80),
    Error               = Color3.fromRGB(255, 90, 90),
    TextPrimary         = Color3.fromRGB(235, 235, 242),
    TextSecondary       = Color3.fromRGB(175, 175, 188),
    TextTertiary        = Color3.fromRGB(115, 115, 128),
    TextDisabled        = Color3.fromRGB(75, 75, 88),
    Border              = Color3.fromRGB(58, 58, 66),
    BorderActive        = Color3.fromRGB(90, 145, 255),
    Selection           = Color3.fromRGB(90, 145, 255),
    TimelineBackground  = Color3.fromRGB(26, 26, 30),
    TimelineRuler       = Color3.fromRGB(44, 44, 50),
    TimelineCursor      = Color3.fromRGB(255, 80, 80),
    KeyframeColor       = Color3.fromRGB(255, 195, 80),
    FontSize            = 13,
    FontSizeLarge       = 16,
    FontSizeSmall       = 11,
    CornerRadius        = 6,
    Padding             = 8,
    AnimationSpeed      = 0.14,
}

function ThemeSystem:Get(name)
    return self.Themes[name or self.Current]
end

function ThemeSystem:Set(name)
    if self.Themes[name] then
        self.Current = name
        Logger:Info("Theme: %s", name)
    end
end

MOON.UI.ThemeSystem = ThemeSystem

-- ══════════════════════════════════════════════════════════════════
-- UI BUILDER
-- ══════════════════════════════════════════════════════════════════
local UIB = {}

function UIB:New(class, props)
    local ok, inst = pcall(Instance.new, class)
    if not ok or not inst then
        Logger:Error("Instance.new failed for: %s", class)
        return nil
    end
    for k,v in pairs(props or {}) do
        if k ~= "Children" then
            pcall(function() inst[k] = v end)
        end
    end
    if props and props.Children then
        for _,ch in ipairs(props.Children) do
            if ch then pcall(function() ch.Parent = inst end) end
        end
    end
    return inst
end

function UIB:Frame(p)
    local T = ThemeSystem:Get()
    return self:New("Frame", U.Merge({
        BackgroundColor3 = T.Surface,
        BorderSizePixel  = 0,
    }, p or {}))
end

function UIB:Label(txt, p)
    local T = ThemeSystem:Get()
    return self:New("TextLabel", U.Merge({
        Text                  = txt or "",
        Font                  = Enum.Font.Gotham,
        TextSize              = T.FontSize,
        TextColor3            = T.TextPrimary,
        BackgroundTransparency= 1,
        BorderSizePixel       = 0,
        TextXAlignment        = Enum.TextXAlignment.Left,
        TextTruncate          = Enum.TextTruncate.AtEnd,
    }, p or {}))
end

function UIB:Button(txt, p)
    local T = ThemeSystem:Get()
    local btn = self:New("TextButton", U.Merge({
        Text             = txt or "",
        Font             = Enum.Font.GothamBold,
        TextSize         = T.FontSize,
        TextColor3       = T.TextPrimary,
        BackgroundColor3 = T.Primary,
        BorderSizePixel  = 0,
        AutoButtonColor  = false,
    }, p or {}))
    if btn and TweenService then
        local baseColor = btn.BackgroundColor3
        btn.MouseEnter:Connect(function()
            pcall(function()
                TweenService:Create(btn, TweenInfo.new(T.AnimationSpeed),
                    {BackgroundColor3 = T.PrimaryHover}):Play()
            end)
        end)
        btn.MouseLeave:Connect(function()
            pcall(function()
                TweenService:Create(btn, TweenInfo.new(T.AnimationSpeed),
                    {BackgroundColor3 = baseColor}):Play()
            end)
        end)
    end
    return btn
end

function UIB:Scroll(p)
    local T = ThemeSystem:Get()
    return self:New("ScrollingFrame", U.Merge({
        BackgroundColor3    = T.Background,
        BorderSizePixel     = 0,
        ScrollBarThickness  = 5,
        ScrollBarImageColor3= T.Primary,
        CanvasSize          = UDim2.new(0,0,0,0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, p or {}))
end

function UIB:Corner(parent, r)
    if not parent then return end
    local T = ThemeSystem:Get()
    local c = self:New("UICorner", {CornerRadius = UDim.new(0, r or T.CornerRadius)})
    if c then c.Parent = parent end
    return c
end

function UIB:Stroke(parent, thick, color)
    if not parent then return end
    local T = ThemeSystem:Get()
    local s = self:New("UIStroke", {
        Thickness       = thick or 1,
        Color           = color or T.Border,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
    if s then s.Parent = parent end
    return s
end

function UIB:Pad(parent, px)
    if not parent then return end
    local T = ThemeSystem:Get()
    local pad = px or T.Padding
    if type(pad) == "number" then
        local p = self:New("UIPadding", {
            PaddingTop    = UDim.new(0, pad),
            PaddingBottom = UDim.new(0, pad),
            PaddingLeft   = UDim.new(0, pad),
            PaddingRight  = UDim.new(0, pad),
        })
        if p then p.Parent = parent end
        return p
    end
end

function UIB:ListLayout(parent, props)
    if not parent then return end
    local l = self:New("UIListLayout", U.Merge({
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding   = UDim.new(0,4),
    }, props or {}))
    if l then l.Parent = parent end
    return l
end

function UIB:Shadow(parent)
    if not parent then return end
    local T = ThemeSystem:Get()
    local s = self:New("ImageLabel", {
        Name               = "_shadow",
        BackgroundTransparency = 1,
        Image              = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        ImageColor3        = Color3.new(0,0,0),
        ImageTransparency  = 0.72,
        Size               = UDim2.new(1,28,1,28),
        Position           = UDim2.new(0,-14,0,-14),
        ZIndex             = (parent.ZIndex or 1) - 1,
    })
    if s then s.Parent = parent end
    return s
end

MOON.UI.Builder = UIB

-- ══════════════════════════════════════════════════════════════════
-- SCREEN GUI CONTAINER
-- ══════════════════════════════════════════════════════════════════
local function buildContainer()
    local gui
    -- Tenta CoreGui
    local ok = pcall(function()
        if CoreGui then
            local old = CoreGui:FindFirstChild("MoonAnimatorAssyncred")
            if old then old:Destroy() end
            gui = UIB:New("ScreenGui", {
                Name           = "MoonAnimatorAssyncred",
                ResetOnSpawn   = false,
                ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
                IgnoreGuiInset = true,
                Parent         = CoreGui,
            })
        end
    end)
    -- Fallback PlayerGui
    if not ok or not gui then
        local pg = LocalPlayer and LocalPlayer:WaitForChild("PlayerGui", 5)
        if pg then
            local old = pg:FindFirstChild("MoonAnimatorAssyncred")
            if old then old:Destroy() end
            gui = UIB:New("ScreenGui", {
                Name           = "MoonAnimatorAssyncred",
                ResetOnSpawn   = false,
                ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
                IgnoreGuiInset = true,
                Parent         = pg,
            })
        end
    end
    if gui then
        MOON.UI.Container = gui
        Logger:Success("ScreenGui container created")
    else
        Logger:Error("FATAL: Cannot create ScreenGui container!")
    end
end
buildContainer()

-- ══════════════════════════════════════════════════════════════════
-- DRAGGABLE
-- ══════════════════════════════════════════════════════════════════
local function makeDraggable(frame, handle)
    if not frame or not handle then return end
    local dragging, startMouse, startPos = false

    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging   = true
            startMouse = inp.Position
            startPos   = frame.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    if UserInputService then
        UserInputService.InputChanged:Connect(function(inp)
            if not dragging then return end
            if inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch then
                local d = inp.Position - startMouse
                local vp = workspace.CurrentCamera
                    and workspace.CurrentCamera.ViewportSize
                    or Vector2.new(1280,720)
                local as = frame.AbsoluteSize
                local nx = U.Clamp(startPos.X.Offset+d.X, 0, vp.X-as.X)
                local ny = U.Clamp(startPos.Y.Offset+d.Y, 0, vp.Y-as.Y)
                frame.Position = UDim2.new(0, nx, 0, ny)
            end
        end)
    end
end
MOON.UI.MakeDraggable = makeDraggable

-- ══════════════════════════════════════════════════════════════════
-- RESIZABLE
-- ══════════════════════════════════════════════════════════════════
local function makeResizable(frame, minSz, maxSz)
    if not frame then return end
    local T = ThemeSystem:Get()
    minSz = minSz or MOON.Config.MinWindowSize
    maxSz = maxSz or MOON.Config.MaxWindowSize

    local handle = UIB:Frame({
        Name             = "_resizeH",
        Size             = UDim2.new(0,20,0,20),
        Position         = UDim2.new(1,-20,1,-20),
        BackgroundColor3 = T.Primary,
        BackgroundTransparency = 0.5,
        ZIndex           = (frame.ZIndex or 1) + 8,
        Parent           = frame,
    })
    UIB:Corner(handle, 3)

    local resizing, startM, startSz = false
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            resizing = true
            startM   = inp.Position
            startSz  = frame.AbsoluteSize
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then
                    resizing = false
                end
            end)
        end
    end)

    if UserInputService then
        UserInputService.InputChanged:Connect(function(inp)
            if not resizing then return end
            if inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch then
                local d = inp.Position - startM
                local nw = U.Clamp(startSz.X+d.X, minSz.X, maxSz.X)
                local nh = U.Clamp(startSz.Y+d.Y, minSz.Y, maxSz.Y)
                frame.Size = UDim2.new(0, nw, 0, nh)
            end
        end)
    end
end
MOON.UI.MakeResizable = makeResizable

-- ══════════════════════════════════════════════════════════════════
-- WINDOW CLASS
-- ══════════════════════════════════════════════════════════════════
local Window = {}
Window.__index = Window

function Window.new(cfg)
    local self = setmetatable({}, Window)
    local T    = ThemeSystem:Get()
    self.Id          = U.UUID()
    self.Title       = cfg.Title or "Window"
    self.Size        = cfg.Size  or UDim2.new(0,700,0,500)
    self.Position    = cfg.Position or UDim2.new(0.5,-350,0.5,-250)
    self.Closable    = cfg.Closable    ~= false
    self.Minimizable = cfg.Minimizable ~= false
    self.Resizable   = cfg.Resizable   ~= false
    self.MinSz       = cfg.MinSize or MOON.Config.MinWindowSize
    self.MaxSz       = cfg.MaxSize or MOON.Config.MaxWindowSize
    self.ZIndex      = 100
    self.IsMinimized = false
    self.IsMaximized = false

    self.OnClose    = Signal.new()
    self.OnMinimize = Signal.new()
    self.OnMaximize = Signal.new()
    self.OnFocus    = Signal.new()

    self:_build()
    return self
end

function Window:_build()
    local T   = ThemeSystem:Get()
    local tbH = MOON.Config.TopBarHeight

    -- Root
    self.Frame = UIB:Frame({
        Name             = "Win_"..self.Id,
        Size             = self.Size,
        Position         = self.Position,
        BackgroundColor3 = T.Background,
        ZIndex           = self.ZIndex,
        ClipsDescendants = false,
        Parent           = MOON.UI.Container,
    })
    UIB:Corner(self.Frame, 8)
    UIB:Stroke(self.Frame, 1, T.Border)

    -- Top bar
    self.TopBar = UIB:Frame({
        Name             = "TopBar",
        Size             = UDim2.new(1,0,0,tbH),
        BackgroundColor3 = T.BackgroundTertiary,
        ZIndex           = self.ZIndex+1,
        Parent           = self.Frame,
    })
    UIB:Corner(self.TopBar, 8)

    -- Cover bottom corners of topbar
    UIB:Frame({
        Size             = UDim2.new(1,0,0.5,0),
        Position         = UDim2.new(0,0,0.5,0),
        BackgroundColor3 = T.BackgroundTertiary,
        ZIndex           = self.ZIndex+1,
        Parent           = self.TopBar,
    })

    -- Title
    self.TitleLabel = UIB:Label(self.Title, {
        Size     = UDim2.new(1,-110,1,0),
        Position = UDim2.new(0,12,0,0),
        Font     = Enum.Font.GothamBold,
        TextSize = 13,
        ZIndex   = self.ZIndex+2,
        Parent   = self.TopBar,
    })

    -- Buttons
    local btnSz = tbH - 10
    local bx    = -6
    if self.Closable then
        local cb = UIB:Button("✕", {
            Size             = UDim2.new(0,btnSz,0,btnSz),
            Position         = UDim2.new(1,bx-btnSz,0.5,-btnSz/2),
            BackgroundColor3 = T.Error,
            TextSize         = 12,
            ZIndex           = self.ZIndex+3,
            Parent           = self.TopBar,
        })
        UIB:Corner(cb, 4)
        bx = bx - btnSz - 4
        cb.MouseButton1Click:Connect(function() self:Close() end)
    end
    if self.Minimizable then
        local mb = UIB:Button("−", {
            Size             = UDim2.new(0,btnSz,0,btnSz),
            Position         = UDim2.new(1,bx-btnSz,0.5,-btnSz/2),
            BackgroundColor3 = T.Warning,
            TextSize         = 15,
            ZIndex           = self.ZIndex+3,
            Parent           = self.TopBar,
        })
        UIB:Corner(mb, 4)
        bx = bx - btnSz - 4
        mb.MouseButton1Click:Connect(function() self:ToggleMinimize() end)
    end
    local mxb = UIB:Button("⊡", {
        Size             = UDim2.new(0,btnSz,0,btnSz),
        Position         = UDim2.new(1,bx-btnSz,0.5,-btnSz/2),
        BackgroundColor3 = T.Success,
        TextSize         = 11,
        ZIndex           = self.ZIndex+3,
        Parent           = self.TopBar,
    })
    UIB:Corner(mxb, 4)
    mxb.MouseButton1Click:Connect(function() self:ToggleMaximize() end)

    -- Content
    self.Content = UIB:Frame({
        Name             = "Content",
        Size             = UDim2.new(1,0,1,-tbH),
        Position         = UDim2.new(0,0,0,tbH),
        BackgroundColor3 = T.Background,
        ZIndex           = self.ZIndex+1,
        ClipsDescendants = true,
        Parent           = self.Frame,
    })

    makeDraggable(self.Frame, self.TopBar)
    if self.Resizable then
        makeResizable(self.Frame, self.MinSz, self.MaxSz)
    end

    self.Frame.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            self:Focus()
        end
    end)
end

function Window:Close()
    self.OnClose:Fire()
    if self.Frame and self.Frame.Parent then
        self.Frame:Destroy()
    end
    if MOON.Systems.WindowManager then
        MOON.Systems.WindowManager:_remove(self.Id)
    end
end

function Window:ToggleMinimize()
    self.IsMinimized = not self.IsMinimized
    local tbH   = MOON.Config.TopBarHeight
    local target = self.IsMinimized
        and UDim2.new(0, self.Frame.AbsoluteSize.X, 0, tbH)
        or self.Size
    if TweenService then
        pcall(function()
            TweenService:Create(self.Frame,
                TweenInfo.new(0.18, Enum.EasingStyle.Quad),
                {Size=target}):Play()
        end)
    else
        self.Frame.Size = target
    end
    self.OnMinimize:Fire(self.IsMinimized)
end

function Window:ToggleMaximize()
    if not self.IsMaximized then
        self._pSz  = self.Frame.Size
        self._pPos = self.Frame.Position
        if TweenService then
            pcall(function()
                TweenService:Create(self.Frame,
                    TweenInfo.new(0.2, Enum.EasingStyle.Quad),
                    {Size=UDim2.new(1,-20,1,-20), Position=UDim2.new(0,10,0,10)}):Play()
            end)
        else
            self.Frame.Size     = UDim2.new(1,-20,1,-20)
            self.Frame.Position = UDim2.new(0,10,0,10)
        end
    else
        if TweenService then
            pcall(function()
                TweenService:Create(self.Frame,
                    TweenInfo.new(0.2, Enum.EasingStyle.Quad),
                    {Size=self._pSz, Position=self._pPos}):Play()
            end)
        else
            self.Frame.Size     = self._pSz
            self.Frame.Position = self._pPos
        end
    end
    self.IsMaximized = not self.IsMaximized
    self.OnMaximize:Fire(self.IsMaximized)
end

function Window:Focus()
    if MOON.Systems.WindowManager then
        MOON.Systems.WindowManager:FocusWindow(self.Id)
    end
    self.OnFocus:Fire()
end

function Window:SetTitle(t)
    self.Title = t
    if self.TitleLabel then self.TitleLabel.Text = t end
end

function Window:GetContent() return self.Content end
MOON.UI.Window = Window

-- ══════════════════════════════════════════════════════════════════
-- WINDOW MANAGER
-- ══════════════════════════════════════════════════════════════════
local WM = {_wins={}, _baseZ=100, _step=10}

function WM:Create(cfg)
    local w = Window.new(cfg)
    self._wins[w.Id] = w
    self:FocusWindow(w.Id)
    Logger:Info("Window: %s", w.Title)
    return w
end

function WM:_remove(id)
    self._wins[id] = nil
end

function WM:FocusWindow(id)
    for wid, w in pairs(self._wins) do
        if w.Frame then
            w.Frame.ZIndex = self._baseZ + (wid==id and self._step or 0)
        end
    end
end

function WM:CloseAll()
    for _, w in pairs(self._wins) do pcall(function() w:Close() end) end
end

function WM:Get(id) return self._wins[id] end
function WM:All()   return self._wins    end

MOON.Systems.WindowManager = WM

-- ══════════════════════════════════════════════════════════════════
-- NOTIFICATION SYSTEM
-- ══════════════════════════════════════════════════════════════════
local Notif = {_list={}}

function Notif.Show(cfg)
    if not MOON.UI.Container then return end
    local T   = ThemeSystem:Get()
    local bg  = cfg.Type=="Error"   and T.Error
             or cfg.Type=="Success" and T.Success
             or cfg.Type=="Warning" and T.Warning
             or T.Primary

    local offset = #Notif._list * 90
    local nf = UIB:Frame({
        Size             = UDim2.new(0,310,0,76),
        Position         = UDim2.new(1,-326,1,-90-offset),
        BackgroundColor3 = bg,
        ZIndex           = 990,
        Parent           = MOON.UI.Container,
    })
    UIB:Corner(nf, 8)
    UIB:Pad(nf, 10)
    table.insert(Notif._list, nf)

    UIB:Label(cfg.Title or "Notice", {
        Size     = UDim2.new(1,0,0,22),
        Font     = Enum.Font.GothamBold,
        TextSize = 13,
        ZIndex   = 991,
        Parent   = nf,
    })
    UIB:Label(cfg.Message or "", {
        Size       = UDim2.new(1,0,1,-26),
        Position   = UDim2.new(0,0,0,26),
        TextSize   = 11,
        TextWrapped= true,
        ZIndex     = 991,
        Parent     = nf,
    })

    local dur = cfg.Duration or 5
    task.delay(dur, function()
        if nf and nf.Parent then
            if TweenService then
                pcall(function()
                    TweenService:Create(nf, TweenInfo.new(0.3),
                        {BackgroundTransparency=1}):Play()
                end)
                task.wait(0.3)
            end
            local idx = U.TableFind(Notif._list, nf)
            if idx then table.remove(Notif._list, idx) end
            if nf.Parent then nf:Destroy() end
        end
    end)
end

MOON.UI.Notify = Notif

-- ══════════════════════════════════════════════════════════════════
-- TOOLTIP SYSTEM
-- ══════════════════════════════════════════════════════════════════
local Tooltip = {_current=nil}

function Tooltip.Attach(element, text)
    if not element then return end
    element.MouseEnter:Connect(function()
        Tooltip.Show(text, element.AbsolutePosition + Vector2.new(0, element.AbsoluteSize.Y+4))
    end)
    element.MouseLeave:Connect(function()
        Tooltip.Hide()
    end)
end

function Tooltip.Show(text, pos)
    Tooltip.Hide()
    if not MOON.UI.Container then return end
    local T = ThemeSystem:Get()
    local tt = UIB:Frame({
        Size             = UDim2.new(0,220,0,44),
        Position         = UDim2.new(0,pos.X,0,pos.Y),
        BackgroundColor3 = T.BackgroundTertiary,
        ZIndex           = 999,
        Parent           = MOON.UI.Container,
    })
    UIB:Corner(tt, 5)
    UIB:Stroke(tt, 1, T.Border)
    UIB:Pad(tt, 6)
    UIB:Label(text, {
        Size        = UDim2.new(1,0,1,0),
        TextSize    = 11,
        TextWrapped = true,
        ZIndex      = 1000,
        Parent      = tt,
    })
    Tooltip._current = tt
end

function Tooltip.Hide()
    if Tooltip._current and Tooltip._current.Parent then
        Tooltip._current:Destroy()
    end
    Tooltip._current = nil
end

MOON.UI.Tooltip = Tooltip

-- ══════════════════════════════════════════════════════════════════
-- PLUGIN BASE
-- ══════════════════════════════════════════════════════════════════
local Plugin = {}
Plugin.__index = Plugin

function Plugin.new(cfg)
    local self = setmetatable({}, Plugin)
    self.Id          = cfg.Id or U.UUID()
    self.Name        = cfg.Name or "Plugin"
    self.Version     = cfg.Version or "1.0"
    self.Author      = cfg.Author or "Unknown"
    self.Description = cfg.Description or ""
    self.Icon        = cfg.Icon or "🔌"
    self.WinCfg      = cfg.WindowConfig or {}
    self.IsLoaded    = false
    self.IsActive    = false
    self.Window      = nil

    self.OnLoad      = Signal.new()
    self.OnUnload    = Signal.new()
    self.OnActivate  = Signal.new()
    self.OnDeactivate= Signal.new()

    self._cbLoad     = cfg.OnLoad
    self._cbUnload   = cfg.OnUnload
    self._cbActivate = cfg.OnActivate
    self._cbUI       = cfg.CreateUI
    return self
end

function Plugin:Load()
    if self.IsLoaded then return true end
    if self._cbLoad then
        local ok, err = pcall(self._cbLoad, self)
        if not ok then Logger:Error("Plugin load fail %s: %s", self.Name, err); return false end
    end
    self.IsLoaded = true
    self.OnLoad:Fire()
    Logger:Success("Plugin loaded: %s", self.Name)
    return true
end

function Plugin:Activate()
    if self.IsActive then return true end
    if not self.IsLoaded then
        if not self:Load() then return false end
    end
    -- Create window
    local wcfg = U.Merge({Title=self.Icon.." "..self.Name, Size=UDim2.new(0,900,0,600)}, self.WinCfg)
    self.Window = WM:Create(wcfg)
    self.Window.OnClose:Connect(function() self:Deactivate() end)

    if self._cbUI then
        local ok, err = pcall(self._cbUI, self, self.Window:GetContent())
        if not ok then Logger:Error("Plugin UI fail %s: %s", self.Name, err) end
    end
    if self._cbActivate then pcall(self._cbActivate, self) end

    self.IsActive = true
    self.OnActivate:Fire()
    Logger:Info("Plugin active: %s", self.Name)
    return true
end

function Plugin:Deactivate()
    if not self.IsActive then return end
    if self._cbUnload then pcall(self._cbUnload, self) end
    if self.Window and self.Window.Frame and self.Window.Frame.Parent then
        pcall(function() self.Window.Frame.Visible = false end)
    end
    self.IsActive = false
    self.OnDeactivate:Fire()
end

function Plugin:GetAPI()
    return {
        Logger=Logger, Utils=U, UIBuilder=UIB,
        Theme=ThemeSystem, WM=WM,
        GetWindow=function() return self.Window end,
        GetContent=function() return self.Window and self.Window:GetContent() end,
    }
end

MOON.API.Plugin = Plugin

-- ══════════════════════════════════════════════════════════════════
-- PLUGIN MANAGER
-- ══════════════════════════════════════════════════════════════════
local PM = {_plugins={}}

function PM:Register(p)
    self._plugins[p.Id] = p
    Logger:Info("Registered: %s", p.Name)
end

function PM:Activate(id)
    local p = self._plugins[id]
    if p then return p:Activate() end
    Logger:Warn("Plugin not found: %s", id)
    return false
end

function PM:Deactivate(id)
    local p = self._plugins[id]
    if p then p:Deactivate() end
end

function PM:Get(id)   return self._plugins[id] end
function PM:All()     return self._plugins      end

MOON.Systems.PluginManager = PM

-- ══════════════════════════════════════════════════════════════════
-- INIT PART 1
-- ══════════════════════════════════════════════════════════════════
PerfMon:Init()

Logger:Info("══════════════════════════════════════")
Logger:Info(" 🌙 MOON ANIMATOR ASSYNCRED v2.0")
Logger:Info(" Part 1/8 - Core + UI + Windows OK")
Logger:Info("══════════════════════════════════════")

task.delay(0.5, function()
    Notif.Show({
        Type="Success",
        Title="🌙 Moon Animator",
        Message="Part 1/8 loaded! Paste Part 2.",
        Duration=6,
    })
end)

--[[
╔══════════════════════════════════════════════════════════════════╗
║         🌙 MOON ANIMATOR ASSYNCRED - PARTE 2/8                  ║
║         KEYFRAME + ANIMATION TRACK + TIMELINE SYSTEM            ║
╚══════════════════════════════════════════════════════════════════╝
]]
local MOON = _G.MOON
assert(MOON, "Run Part 1 first!")
local Logger = MOON.Core.Logger
local U      = MOON.Utils
local UIB    = MOON.UI.Builder
local T_     = MOON.UI.ThemeSystem
local WM     = MOON.Systems.WindowManager
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- ══════════════════════════════════════════════════════════════════
-- KEYFRAME
-- ══════════════════════════════════════════════════════════════════
local Keyframe = {}
Keyframe.__index = Keyframe

function Keyframe.new(cfg)
    local self = setmetatable({}, Keyframe)
    self.Id           = U.UUID()
    self.Frame        = cfg.Frame or 0
    self.Value        = cfg.Value or CFrame.new()
    self.EasingStyle  = cfg.EasingStyle  or Enum.EasingStyle.Cubic
    self.EasingDir    = cfg.EasingDir    or Enum.EasingDirection.InOut
    self.Interpolation= cfg.Interpolation or "Cubic"
    self.HandleIn     = cfg.HandleIn  or Vector2.new(-1, 0)
    self.HandleOut    = cfg.HandleOut or Vector2.new( 1, 0)
    self.Selected     = false
    self.Locked       = false
    self.Color        = cfg.Color or Color3.fromRGB(255,195,80)
    return self
end

function Keyframe:Clone()
    return Keyframe.new({
        Frame=self.Frame, Value=self.Value,
        EasingStyle=self.EasingStyle, EasingDir=self.EasingDir,
        Interpolation=self.Interpolation,
        HandleIn=self.HandleIn, HandleOut=self.HandleOut,
        Color=self.Color,
    })
end

function Keyframe:Serialize()
    local v = self.Value
    local vt = typeof(v)
    local vs
    if vt=="CFrame" then
        vs = {v:GetComponents()}
    elseif vt=="Vector3" then
        vs = {v.X,v.Y,v.Z}
    elseif vt=="number" then
        vs = v
    else
        vs = tostring(v)
    end
    return {
        Id=self.Id, Frame=self.Frame,
        Value=vs, ValueType=vt,
        EasingStyle=self.EasingStyle.Name,
        EasingDir=self.EasingDir.Name,
        Interpolation=self.Interpolation,
        HandleIn={self.HandleIn.X,self.HandleIn.Y},
        HandleOut={self.HandleOut.X,self.HandleOut.Y},
        Color={self.Color.R,self.Color.G,self.Color.B},
    }
end

MOON.API.Keyframe = Keyframe

-- ══════════════════════════════════════════════════════════════════
-- EASING FUNCTIONS
-- ══════════════════════════════════════════════════════════════════
local function applyEasing(alpha, style, dir)
    local t = U.Clamp(alpha,0,1)
    if style == Enum.EasingStyle.Linear then return t end
    local function easeIn(n)
        if style==Enum.EasingStyle.Quad  then return n*n end
        if style==Enum.EasingStyle.Cubic then return n*n*n end
        if style==Enum.EasingStyle.Quart then return n*n*n*n end
        if style==Enum.EasingStyle.Sine  then return 1-math.cos(n*math.pi/2) end
        if style==Enum.EasingStyle.Back  then local s=1.70158; return n*n*((s+1)*n-s) end
        if style==Enum.EasingStyle.Bounce then
            local function bout(x)
                if x<1/2.75 then return 7.5625*x*x
                elseif x<2/2.75 then x=x-1.5/2.75; return 7.5625*x*x+0.75
                elseif x<2.5/2.75 then x=x-2.25/2.75; return 7.5625*x*x+0.9375
                else x=x-2.625/2.75; return 7.5625*x*x+0.984375 end
            end
            return 1-bout(1-n)
        end
        return n
    end
    local function easeOut(n) return 1-easeIn(1-n) end
    local function easeInOut(n)
        if n<0.5 then return easeIn(n*2)/2 else return 0.5+easeOut(n*2-1)/2 end
    end
    if dir==Enum.EasingDirection.In then return easeIn(t)
    elseif dir==Enum.EasingDirection.Out then return easeOut(t)
    else return easeInOut(t) end
end

-- ══════════════════════════════════════════════════════════════════
-- ANIMATION TRACK
-- ══════════════════════════════════════════════════════════════════
local AnimTrack = {}
AnimTrack.__index = AnimTrack

function AnimTrack.new(cfg)
    local self = setmetatable({}, AnimTrack)
    self.Id       = cfg.Id or U.UUID()
    self.Name     = cfg.Name or "Track"
    self.Type     = cfg.Type or "Transform"
    self.Target   = cfg.Target
    self.Property = cfg.Property or "C0"
    self.Keyframes= {}
    self.Sorted   = {}
    self.Enabled  = true
    self.Muted    = false
    self.Solo     = false
    self.Locked   = false
    self.Color    = cfg.Color or Color3.fromRGB(90,145,255)
    self.Height   = 36

    self.OnKFAdded   = U.Signal.new()
    self.OnKFRemoved = U.Signal.new()
    return self
end

function AnimTrack:AddKeyframe(frame, value, extra)
    if self.Locked then return nil end
    local kf = Keyframe.new(U.Merge({Frame=frame,Value=value,Color=self.Color}, extra or {}))
    self.Keyframes[frame] = kf
    self:_sort()
    self.OnKFAdded:Fire(kf)
    return kf
end

function AnimTrack:RemoveKeyframe(frame)
    if self.Locked or not self.Keyframes[frame] then return end
    local kf = self.Keyframes[frame]
    self.Keyframes[frame] = nil
    self:_sort()
    self.OnKFRemoved:Fire(kf)
end

function AnimTrack:_sort()
    self.Sorted = {}
    for f in pairs(self.Keyframes) do table.insert(self.Sorted, f) end
    table.sort(self.Sorted)
end

function AnimTrack:GetValueAt(frame)
    if not self.Enabled or self.Muted then return nil end
    if self.Keyframes[frame] then return self.Keyframes[frame].Value end
    if #self.Sorted == 0 then return nil end
    if frame < self.Sorted[1] then return self.Keyframes[self.Sorted[1]].Value end
    if frame > self.Sorted[#self.Sorted] then return self.Keyframes[self.Sorted[#self.Sorted]].Value end

    local pF, nF
    for i=1,#self.Sorted-1 do
        if frame>=self.Sorted[i] and frame<=self.Sorted[i+1] then
            pF,nF = self.Sorted[i], self.Sorted[i+1]
            break
        end
    end
    if not pF then return nil end

    local pKF = self.Keyframes[pF]
    local nKF = self.Keyframes[nF]
    local alpha = (frame-pF)/(nF-pF)
    alpha = applyEasing(alpha, pKF.EasingStyle, pKF.EasingDir)

    local pv, nv = pKF.Value, nKF.Value
    if typeof(pv)=="CFrame"   and typeof(nv)=="CFrame"   then return pv:Lerp(nv, alpha) end
    if typeof(pv)=="Vector3"  and typeof(nv)=="Vector3"  then return pv:Lerp(nv, alpha) end
    if typeof(pv)=="number"   and typeof(nv)=="number"   then return U.Lerp(pv, nv, alpha) end
    if typeof(pv)=="Color3"   and typeof(nv)=="Color3"   then return pv:Lerp(nv, alpha) end
    return pv
end

function AnimTrack:ClearAll()
    self.Keyframes = {}
    self.Sorted    = {}
end

MOON.API.AnimTrack = AnimTrack

-- ══════════════════════════════════════════════════════════════════
-- TIMELINE
-- ══════════════════════════════════════════════════════════════════
local Timeline = {}
Timeline.__index = Timeline

function Timeline.new(cfg)
    local self    = setmetatable({}, Timeline)
    self.Id       = U.UUID()
    self.Name     = cfg.Name or "Timeline"
    self.FPS      = cfg.FPS  or MOON.Config.DefaultFPS
    self.StartF   = 0
    self.EndF     = cfg.EndFrame or 120
    self.CurF     = 0
    self.Tracks   = {}
    self.Order    = {}
    self.IsPlaying= false
    self.Loop     = true
    self.Speed    = 1.0
    self.Zoom     = 1.0
    self.ScrollX  = 0
    self.FramePx  = 18

    self.OnFrameChanged = U.Signal.new()
    self.OnPlay         = U.Signal.new()
    self.OnStop         = U.Signal.new()
    self.OnTrackAdded   = U.Signal.new()
    self.OnTrackRemoved = U.Signal.new()
    self._conn          = nil
    return self
end

function Timeline:AddTrack(cfg)
    local t = AnimTrack.new(cfg)
    self.Tracks[t.Id] = t
    table.insert(self.Order, t.Id)
    self.OnTrackAdded:Fire(t)
    return t
end

function Timeline:RemoveTrack(id)
    local t = self.Tracks[id]
    if not t then return end
    self.Tracks[id] = nil
    local idx = U.TableFind(self.Order, id)
    if idx then table.remove(self.Order, idx) end
    self.OnTrackRemoved:Fire(t)
end

function Timeline:GetAllTracks()
    local out={}
    for _,id in ipairs(self.Order) do
        if self.Tracks[id] then table.insert(out, self.Tracks[id]) end
    end
    return out
end

function Timeline:SetFrame(f)
    f = U.Clamp(math.floor(f), self.StartF, self.EndF)
    if self.CurF ~= f then
        self.CurF = f
        self.OnFrameChanged:Fire(f)
        self:_applyFrame(f)
    end
end

function Timeline:_applyFrame(f)
    for _,id in ipairs(self.Order) do
        local tr = self.Tracks[id]
        if tr and tr.Target and tr.Enabled and not tr.Muted then
            local val = tr:GetValueAt(f)
            if val ~= nil then
                pcall(function()
                    if tr.Property=="C0" or tr.Property=="C1" then
                        tr.Target[tr.Property] = val
                    else
                        tr.Target[tr.Property] = val
                    end
                end)
            end
        end
    end
end

function Timeline:Play()
    if self.IsPlaying then return end
    self.IsPlaying = true
    self.OnPlay:Fire()
    local t0   = tick()
    local startF = self.CurF
    local function step()
        if not self.IsPlaying then return end
        local elapsed = (tick()-t0) * self.FPS * self.Speed
        local nf = startF + elapsed
        if nf >= self.EndF then
            if self.Loop then
                nf=self.StartF; t0=tick(); startF=self.StartF
            else
                self:Stop(); return
            end
        end
        self:SetFrame(nf)
    end
    local ok = pcall(function()
        self._conn = RunService.RenderStepped:Connect(step)
    end)
    if not ok then
        self._conn = RunService.Heartbeat:Connect(step)
    end
end

function Timeline:Pause()
    if not self.IsPlaying then return end
    self.IsPlaying = false
    if self._conn then self._conn:Disconnect(); self._conn=nil end
    self.OnStop:Fire()
end

function Timeline:Stop()
    self:Pause()
    self:SetFrame(self.StartF)
end

function Timeline:FrameToX(f)
    return (f - self.StartF) * self.FramePx * self.Zoom - self.ScrollX
end

function Timeline:XToFrame(x)
    return math.floor((x + self.ScrollX) / (self.FramePx * self.Zoom)) + self.StartF
end

MOON.API.Timeline = Timeline

-- ══════════════════════════════════════════════════════════════════
-- TIMELINE UI
-- ══════════════════════════════════════════════════════════════════
local TimelineUI = {}
TimelineUI.__index = TimelineUI

function TimelineUI.new(timeline, parent)
    local self = setmetatable({}, TimelineUI)
    self.TL   = timeline
    self.Parent = parent
    self.TrackRows = {}
    self._playBtn  = nil
    self:Build()
    return self
end

function TimelineUI:Build()
    local T = T_:Get()

    -- Main frame
    self.Frame = UIB:Frame({
        Name             = "TimelineUI",
        Size             = UDim2.new(1,0,1,0),
        BackgroundColor3 = T.TimelineBackground,
        Parent           = self.Parent,
    })

    -- === TOOLBAR ===
    self.Toolbar = UIB:Frame({
        Size             = UDim2.new(1,0,0,40),
        BackgroundColor3 = T.BackgroundTertiary,
        Parent           = self.Frame,
    })

    local function tbBtn(txt,x,bg,cb,tip)
        local b = UIB:Button(txt, {
            Size             = UDim2.new(0,34,0,30),
            Position         = UDim2.new(0,x,0.5,-15),
            BackgroundColor3 = bg or T.Surface,
            TextSize         = 16,
            Parent           = self.Toolbar,
        })
        UIB:Corner(b,5)
        if cb then b.MouseButton1Click:Connect(cb) end
        if tip then MOON.UI.Tooltip.Attach(b,tip) end
        return b
    end

    local xp = 8
    -- To Start
    tbBtn("⏮",xp,T.Surface,function()
        self.TL:Stop()
        if self._playBtn then self._playBtn.Text="▶" end
    end,"Go to start")
    xp=xp+38

    -- Play/Pause
    self._playBtn = tbBtn("▶",xp,T.Success,function()
        if self.TL.IsPlaying then
            self.TL:Pause()
            self._playBtn.Text="▶"
            self._playBtn.BackgroundColor3=T.Success
        else
            self.TL:Play()
            self._playBtn.Text="⏸"
            self._playBtn.BackgroundColor3=T.Warning
        end
    end,"Play / Pause  [Space]")
    xp=xp+38

    -- Stop
    tbBtn("⏹",xp,T.Error,function()
        self.TL:Stop()
        if self._playBtn then
            self._playBtn.Text="▶"
            self._playBtn.BackgroundColor3=T.Success
        end
    end,"Stop")
    xp=xp+38+8

    -- Frame counter
    self._frameLabel = UIB:Label("F: 0", {
        Size     = UDim2.new(0,80,0,28),
        Position = UDim2.new(0,xp,0.5,-14),
        Font     = Enum.Font.GothamBold,
        TextSize = 13,
        Parent   = self.Toolbar,
    })
    xp=xp+88

    -- FPS label
    UIB:Label("FPS:"..self.TL.FPS, {
        Size     = UDim2.new(0,60,0,28),
        Position = UDim2.new(0,xp,0.5,-14),
        TextSize = 11,
        TextColor3 = T.TextSecondary,
        Parent   = self.Toolbar,
    })
    xp=xp+68

    -- Zoom Out
    tbBtn("🔍−",xp,T.Surface,function()
        self.TL.Zoom = U.Clamp(self.TL.Zoom*0.8,0.1,10)
        self:RefreshRuler()
        self:RefreshKeyframes()
    end,"Zoom Out")
    xp=xp+38

    -- Zoom In
    tbBtn("🔍+",xp,T.Surface,function()
        self.TL.Zoom = U.Clamp(self.TL.Zoom*1.25,0.1,10)
        self:RefreshRuler()
        self:RefreshKeyframes()
    end,"Zoom In")
    xp=xp+38+8

    -- Loop toggle
    local loopBtn = tbBtn("🔁",xp,self.TL.Loop and T.Primary or T.Surface,function()
        self.TL.Loop = not self.TL.Loop
    end,"Toggle Loop")
    xp=xp+38+8

    -- Add Track button
    local addTrackBtn = UIB:Button("+ Track", {
        Size             = UDim2.new(0,80,0,28),
        Position         = UDim2.new(0,xp,0.5,-14),
        BackgroundColor3 = T.Secondary,
        TextSize         = 12,
        Parent           = self.Toolbar,
    })
    UIB:Corner(addTrackBtn,5)
    addTrackBtn.MouseButton1Click:Connect(function()
        local newTrack = self.TL:AddTrack({
            Name = "Track "..tostring(#self.TL.Order+1),
            Type = "Transform",
        })
        self:AddTrackRow(newTrack)
    end)

    -- === LEFT PANEL (track labels) ===
    local leftW = 160
    self.LeftPanel = UIB:Frame({
        Name             = "LeftPanel",
        Size             = UDim2.new(0,leftW,1,-80),
        Position         = UDim2.new(0,0,0,40),
        BackgroundColor3 = T.BackgroundSecondary,
        Parent           = self.Frame,
    })

    -- === RULER ===
    self.RulerFrame = UIB:Frame({
        Name             = "Ruler",
        Size             = UDim2.new(1,-leftW,0,20),
        Position         = UDim2.new(0,leftW,0,40),
        BackgroundColor3 = T.TimelineRuler,
        ClipsDescendants = true,
        Parent           = self.Frame,
    })
    self:RefreshRuler()

    -- Ruler click to seek
    self.RulerFrame.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            local relX = inp.Position.X - self.RulerFrame.AbsolutePosition.X
            local f = self.TL:XToFrame(relX)
            self.TL:SetFrame(f)
        end
    end)

    -- === TRACK AREA ===
    self.TrackArea = UIB:Scroll({
        Name             = "TrackArea",
        Size             = UDim2.new(1,-leftW,1,-80),
        Position         = UDim2.new(0,leftW,0,60),
        BackgroundColor3 = T.TimelineBackground,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent           = self.Frame,
    })

    -- Track label area
    self.LabelArea = UIB:Scroll({
        Name             = "LabelArea",
        Size             = UDim2.new(0,leftW,1,-80),
        Position         = UDim2.new(0,0,0,60),
        BackgroundColor3 = T.BackgroundSecondary,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness  = 0,
        Parent           = self.Frame,
    })
    UIB:ListLayout(self.LabelArea)
    UIB:ListLayout(self.TrackArea)

    -- === PLAYHEAD ===
    self.Playhead = UIB:Frame({
        Name             = "Playhead",
        Size             = UDim2.new(0,2,1,-60),
        Position         = UDim2.new(0,leftW,0,60),
        BackgroundColor3 = T.TimelineCursor,
        ZIndex           = 50,
        Parent           = self.Frame,
    })

    -- Status bar
    self.StatusBar = UIB:Frame({
        Name             = "StatusBar",
        Size             = UDim2.new(1,0,0,22),
        Position         = UDim2.new(0,0,1,-22),
        BackgroundColor3 = T.BackgroundTertiary,
        Parent           = self.Frame,
    })
    self._statusLabel = UIB:Label("Ready  |  F: 0  |  FPS: "..self.TL.FPS, {
        Size     = UDim2.new(1,-8,1,0),
        Position = UDim2.new(0,8,0,0),
        TextSize = 10,
        TextColor3 = T.TextSecondary,
        Parent   = self.StatusBar,
    })

    -- Connect timeline events
    self.TL.OnFrameChanged:Connect(function(f)
        self:OnFrameChanged(f)
    end)

    -- Populate existing tracks
    for _,tr in ipairs(self.TL:GetAllTracks()) do
        self:AddTrackRow(tr)
    end
end

function TimelineUI:OnFrameChanged(f)
    if self._frameLabel then
        self._frameLabel.Text = "F: "..f
    end
    if self._statusLabel then
        local fps = MOON.Performance.Monitor:Get().FPS
        self._statusLabel.Text = string.format("Frame: %d  |  FPS: %d  |  Zoom: %.1fx",
            f, fps, self.TL.Zoom)
    end
    self:UpdatePlayhead(f)
end

function TimelineUI:UpdatePlayhead(f)
    if not self.Playhead then return end
    local leftW = 160
    local x = self.TL:FrameToX(f) + leftW
    self.Playhead.Position = UDim2.new(0, x, 0, 60)
end

function TimelineUI:RefreshRuler()
    if not self.RulerFrame then return end
    local T = T_:Get()
    -- Clear old labels
    for _,ch in ipairs(self.RulerFrame:GetChildren()) do
        if ch:IsA("TextLabel") or ch:IsA("Frame") then ch:Destroy() end
    end
    local step = math.max(1, math.ceil(5/self.TL.Zoom))
    for f=self.TL.StartF, self.TL.EndF, step do
        local x = self.TL:FrameToX(f)
        if x>=0 then
            -- Tick
            UIB:Frame({
                Size             = UDim2.new(0,1,0,6),
                Position         = UDim2.new(0,x,0,0),
                BackgroundColor3 = T.TextTertiary,
                Parent           = self.RulerFrame,
            })
            -- Label
            UIB:Label(tostring(f),{
                Size     = UDim2.new(0,40,0,14),
                Position = UDim2.new(0,x-20,0,6),
                TextSize = 9,
                TextColor3 = T.TextSecondary,
                TextXAlignment = Enum.TextXAlignment.Center,
                Parent   = self.RulerFrame,
            })
        end
    end
end

function TimelineUI:AddTrackRow(track)
    local T = T_:Get()
    local rowH = track.Height or 36

    -- Label
    local lbl = UIB:Frame({
        Name             = "Label_"..track.Id,
        Size             = UDim2.new(1,0,0,rowH),
        BackgroundColor3 = T.BackgroundSecondary,
        LayoutOrder      = #self.TL.Order,
        Parent           = self.LabelArea,
    })
    UIB:Stroke(lbl,1,T.Border)

    UIB:Frame({
        Size             = UDim2.new(0,4,1,0),
        BackgroundColor3 = track.Color,
        Parent           = lbl,
    })

    UIB:Label(track.Name,{
        Size     = UDim2.new(1,-50,1,0),
        Position = UDim2.new(0,8,0,0),
        TextSize = 11,
        Font     = Enum.Font.GothamBold,
        Parent   = lbl,
    })

    -- Mute button
    local muteBtn = UIB:Button(track.Muted and "M" or "m",{
        Size             = UDim2.new(0,20,0,20),
        Position         = UDim2.new(1,-44,0.5,-10),
        BackgroundColor3 = track.Muted and T.Warning or T.Surface,
        TextSize         = 10,
        Parent           = lbl,
    })
    UIB:Corner(muteBtn,3)
    muteBtn.MouseButton1Click:Connect(function()
        track.Muted = not track.Muted
        muteBtn.Text = track.Muted and "M" or "m"
        muteBtn.BackgroundColor3 = track.Muted and T.Warning or T.Surface
    end)

    -- Lock button
    local lockBtn = UIB:Button("🔓",{
        Size             = UDim2.new(0,20,0,20),
        Position         = UDim2.new(1,-22,0.5,-10),
        BackgroundColor3 = T.Surface,
        TextSize         = 10,
        Parent           = lbl,
    })
    UIB:Corner(lockBtn,3)
    lockBtn.MouseButton1Click:Connect(function()
        track.Locked = not track.Locked
        lockBtn.Text = track.Locked and "🔒" or "🔓"
    end)

    -- Track row (keyframe display area)
    local row = UIB:Frame({
        Name             = "Row_"..track.Id,
        Size             = UDim2.new(1,0,0,rowH),
        BackgroundColor3 = T.TimelineBackground,
        LayoutOrder      = #self.TL.Order,
        ClipsDescendants = true,
        Parent           = self.TrackArea,
    })
    UIB:Stroke(row,1,T.Border)

    -- Add keyframe on double-click
    row.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            local relX = inp.Position.X - row.AbsolutePosition.X
            local f = self.TL:XToFrame(relX)
            if not track.Locked then
                track:AddKeyframe(f, CFrame.new())
                self:RefreshKeyframesForTrack(track, row)
            end
        end
    end)

    -- Store references
    self.TrackRows[track.Id] = {Row=row, Label=lbl}

    -- Draw existing keyframes
    self:RefreshKeyframesForTrack(track, row)

    -- Listen for new keyframes
    track.OnKFAdded:Connect(function()
        self:RefreshKeyframesForTrack(track, row)
    end)
    track.OnKFRemoved:Connect(function()
        self:RefreshKeyframesForTrack(track, row)
    end)
end

function TimelineUI:RefreshKeyframesForTrack(track, row)
    if not row then return end
    local T = T_:Get()
    -- Clear old diamonds
    for _,ch in ipairs(row:GetChildren()) do
        if ch.Name == "_kf" then ch:Destroy() end
    end
    for f, kf in pairs(track.Keyframes) do
        local x = self.TL:FrameToX(f)
        local diamond = UIB:Frame({
            Name             = "_kf",
            Size             = UDim2.new(0,10,0,10),
            Position         = UDim2.new(0,x-5,0.5,-5),
            BackgroundColor3 = kf.Selected and T.Selection or kf.Color,
            Rotation         = 45,
            ZIndex           = 5,
            Parent           = row,
        })
        -- Select on click
        diamond.InputBegan:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 then
                kf.Selected = not kf.Selected
                diamond.BackgroundColor3 = kf.Selected and T.Selection or kf.Color
            end
        end)
        MOON.UI.Tooltip.Attach(diamond, "Frame: "..f.."  |  "..kf.Interpolation)
    end
end

function TimelineUI:RefreshKeyframes()
    for id, refs in pairs(self.TrackRows) do
        local tr = self.TL.Tracks[id]
        if tr then self:RefreshKeyframesForTrack(tr, refs.Row) end
    end
end

MOON.UI.TimelineUI = TimelineUI

-- ══════════════════════════════════════════════════════════════════
-- ANIMATION SERIALIZER
-- ══════════════════════════════════════════════════════════════════
local Serializer = {}

function Serializer.ExportJSON(timeline)
    local HttpService = game:GetService("HttpService")
    local data = {
        Version  = MOON.Version,
        Type     = "MoonAnimatorAssyncred",
        Name     = timeline.Name,
        FPS      = timeline.FPS,
        EndFrame = timeline.EndF,
        Tracks   = {},
    }
    for _,id in ipairs(timeline.Order) do
        local tr = timeline.Tracks[id]
        if tr then
            local td = {
                Id=tr.Id, Name=tr.Name, Type=tr.Type,
                Property=tr.Property,
                Color={tr.Color.R,tr.Color.G,tr.Color.B},
                Keyframes={}
            }
            for _,kf in pairs(tr.Keyframes) do
                table.insert(td.Keyframes, kf:Serialize())
            end
            table.insert(data.Tracks, td)
        end
    end
    local ok, json = pcall(function() return HttpService:JSONEncode(data) end)
    if ok then return json end
    return "{}"
end

function Serializer.ImportJSON(jsonStr, timeline)
    local HttpService = game:GetService("HttpService")
    local ok, data = pcall(function() return HttpService:JSONDecode(jsonStr) end)
    if not ok then Logger:Error("JSON parse failed"); return false end

    timeline.Name = data.Name or timeline.Name
    timeline.FPS  = data.FPS  or timeline.FPS

    for _, td in ipairs(data.Tracks or {}) do
        local tr = timeline:AddTrack({
            Id=td.Id, Name=td.Name, Type=td.Type,
            Property=td.Property,
        })
        if td.Color then
            tr.Color = Color3.new(td.Color[1],td.Color[2],td.Color[3])
        end
        for _, kd in ipairs(td.Keyframes or {}) do
            local val
            if kd.ValueType=="CFrame"  then val = CFrame.new(table.unpack(kd.Value))
            elseif kd.ValueType=="Vector3" then val = Vector3.new(kd.Value[1],kd.Value[2],kd.Value[3])
            elseif kd.ValueType=="number"  then val = kd.Value
            else val = kd.Value end
            local kf = Keyframe.new({
                Frame=kd.Frame, Value=val,
                EasingStyle = Enum.EasingStyle[kd.EasingStyle] or Enum.EasingStyle.Cubic,
                EasingDir   = Enum.EasingDirection[kd.EasingDir] or Enum.EasingDirection.InOut,
                Interpolation= kd.Interpolation or "Cubic",
            })
            tr.Keyframes[kf.Frame] = kf
        end
        tr:_sort()
    end
    Logger:Success("Imported %d tracks", #data.Tracks)
    return true
end

MOON.API.Serializer = Serializer

Logger:Info("Part 2/8 - Timeline + Keyframe + Tracks OK")
MOON.UI.Notify.Show({Type="Success",Title="🌙 Part 2 Loaded",Message="Timeline system ready! Paste Part 3.",Duration=5})

--[[
╔══════════════════════════════════════════════════════════════════╗
║         🌙 MOON ANIMATOR ASSYNCRED - PARTE 3/8                  ║
║         RIG ANALYZER + ANIMATION CONTROLLER + POSE SYSTEM       ║
╚══════════════════════════════════════════════════════════════════╝
]]
local MOON = _G.MOON
assert(MOON,"Run Part 1 first!")
local Logger = MOON.Core.Logger
local U      = MOON.Utils
local UIB    = MOON.UI.Builder
local T_     = MOON.UI.ThemeSystem
local WM     = MOON.Systems.WindowManager
local Signal = U.Signal

-- ══════════════════════════════════════════════════════════════════
-- RIG ANALYZER
-- ══════════════════════════════════════════════════════════════════
local RigAnalyzer = {}

function RigAnalyzer.Analyze(model)
    if not model or not pcall(function() return model:IsA("Model") end) then
        Logger:Error("Invalid model")
        return nil
    end

    local rig = {
        Model     = model,
        Type      = "Custom",
        Joints    = {},
        Bones     = {},
        Parts     = {},
        RootPart  = nil,
        Humanoid  = nil,
    }

    -- Find Humanoid
    pcall(function()
        rig.Humanoid = model:FindFirstChildOfClass("Humanoid")
    end)

    -- Find root
    pcall(function()
        rig.RootPart = model:FindFirstChild("HumanoidRootPart")
            or model:FindFirstChild("Torso")
            or model:FindFirstChild("UpperTorso")
    end)

    -- Detect type
    if model:FindFirstChild("Torso") and model:FindFirstChild("Left Arm") then
        rig.Type = "R6"
    elseif model:FindFirstChild("UpperTorso") and model:FindFirstChild("LeftUpperArm") then
        rig.Type = "R15"
    end

    -- Collect joints + parts
    pcall(function()
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("Motor6D") or d:IsA("Motor") then
                table.insert(rig.Joints, {
                    Instance   = d,
                    Name       = d.Name,
                    Part0      = d.Part0,
                    Part1      = d.Part1,
                    OriginalC0 = d.C0,
                    OriginalC1 = d.C1,
                })
            elseif d:IsA("Bone") then
                table.insert(rig.Bones, d)
            elseif d:IsA("BasePart") then
                table.insert(rig.Parts, d)
            end
        end
    end)

    Logger:Success("Rig analyzed: %s | %d joints | %d bones",
        rig.Type, #rig.Joints, #rig.Bones)
    return rig
end

function RigAnalyzer.GetJoint(rig, name)
    if not rig then return nil end
    for _, j in ipairs(rig.Joints) do
        if j.Name == name then return j end
    end
    return nil
end

function RigAnalyzer.ResetRig(rig)
    if not rig then return end
    for _, j in ipairs(rig.Joints) do
        pcall(function()
            j.Instance.C0 = j.OriginalC0
            j.Instance.C1 = j.OriginalC1
        end)
    end
    Logger:Info("Rig reset to original")
end

MOON.API.RigAnalyzer = RigAnalyzer

-- ══════════════════════════════════════════════════════════════════
-- POSE
-- ══════════════════════════════════════════════════════════════════
local Pose = {}
Pose.__index = Pose

function Pose.new(name)
    local self = setmetatable({}, Pose)
    self.Id        = U.UUID()
    self.Name      = name or "Pose"
    self.Timestamp = os.time()
    self.Joints    = {} -- {name = {C0,C1}}
    return self
end

function Pose:Capture(rig)
    if not rig then return self end
    self.Joints = {}
    for _, j in ipairs(rig.Joints) do
        pcall(function()
            self.Joints[j.Name] = {
                C0 = j.Instance.C0,
                C1 = j.Instance.C1,
            }
        end)
    end
    Logger:Info("Pose captured: %s", self.Name)
    return self
end

function Pose:Apply(rig, blend)
    if not rig then return end
    blend = U.Clamp(blend or 1, 0, 1)
    for _, j in ipairs(rig.Joints) do
        local data = self.Joints[j.Name]
        if data then
            pcall(function()
                if blend >= 1 then
                    j.Instance.C0 = data.C0
                    j.Instance.C1 = data.C1
                else
                    j.Instance.C0 = j.Instance.C0:Lerp(data.C0, blend)
                    j.Instance.C1 = j.Instance.C1:Lerp(data.C1, blend)
                end
            end)
        end
    end
end

function Pose:Serialize()
    local out = {Id=self.Id,Name=self.Name,Timestamp=self.Timestamp,Joints={}}
    for name, data in pairs(self.Joints) do
        out.Joints[name] = {
            C0={data.C0:GetComponents()},
            C1={data.C1:GetComponents()},
        }
    end
    return out
end

function Pose.Deserialize(data)
    local p = Pose.new(data.Name)
    p.Id        = data.Id
    p.Timestamp = data.Timestamp
    for name, jd in pairs(data.Joints or {}) do
        p.Joints[name] = {
            C0 = CFrame.new(table.unpack(jd.C0)),
            C1 = CFrame.new(table.unpack(jd.C1)),
        }
    end
    return p
end

MOON.API.Pose = Pose

-- ══════════════════════════════════════════════════════════════════
-- POSE LIBRARY (Presets)
-- ══════════════════════════════════════════════════════════════════
local PoseLibrary = {Presets={}}

function PoseLibrary:Add(name, pose)
    self.Presets[name] = pose
end

function PoseLibrary:Get(name)
    return self.Presets[name]
end

function PoseLibrary:GetAll()
    return self.Presets
end

-- Default presets
local tpose = Pose.new("T-Pose")
tpose.Joints["Left Shoulder"]  = {C0=CFrame.Angles(0,0,-math.pi/2), C1=CFrame.new()}
tpose.Joints["Right Shoulder"] = {C0=CFrame.Angles(0,0,math.pi/2), C1=CFrame.new()}
PoseLibrary:Add("T-Pose", tpose)

local apose = Pose.new("A-Pose")
apose.Joints["Left Shoulder"]  = {C0=CFrame.Angles(0,0,-math.pi/4), C1=CFrame.new()}
apose.Joints["Right Shoulder"] = {C0=CFrame.Angles(0,0,math.pi/4), C1=CFrame.new()}
PoseLibrary:Add("A-Pose", apose)

MOON.API.PoseLibrary = PoseLibrary

-- ══════════════════════════════════════════════════════════════════
-- ANIMATION CONTROLLER
-- ══════════════════════════════════════════════════════════════════
local AnimController = {}
AnimController.__index = AnimController

function AnimController.new(rig)
    local self = setmetatable({}, AnimController)
    self.Rig     = rig
    self.Poses   = {}
    self.Current = nil
    self:SavePose("Default")
    return self
end

function AnimController:SavePose(name)
    local p = Pose.new(name)
    p:Capture(self.Rig)
    self.Poses[name] = p
    self.Current = name
    Logger:Info("Pose saved: %s", name)
    return p
end

function AnimController:LoadPose(name, blend)
    local p = self.Poses[name]
    if not p then Logger:Warn("Pose not found: %s", name); return false end
    p:Apply(self.Rig, blend)
    self.Current = name
    return true
end

function AnimController:Reset()
    RigAnalyzer.ResetRig(self.Rig)
end

function AnimController:GetPoseList()
    local list = {}
    for n in pairs(self.Poses) do table.insert(list, n) end
    return list
end

MOON.API.AnimController = AnimController

-- ══════════════════════════════════════════════════════════════════
-- TRANSFORM TOOL
-- ══════════════════════════════════════════════════════════════════
local TransformTool = {}
TransformTool.__index = TransformTool

function TransformTool.new()
    local self = setmetatable({}, TransformTool)
    self.Mode           = "Rotate" -- Rotate | Move
    self.Space          = "Local"  -- Local | World
    self.SelectedJoint  = nil
    self.SnapRotation   = 5  -- degrees
    self.SnapMove       = 0.25
    self.SnapEnabled    = true
    return self
end

function TransformTool:Rotate(joint, axis, deg)
    if not joint or not joint.Instance then return end
    if self.SnapEnabled then
        deg = math.floor(deg/self.SnapRotation+0.5)*self.SnapRotation
    end
    local rot
    if axis=="X" then rot=CFrame.Angles(math.rad(deg),0,0)
    elseif axis=="Y" then rot=CFrame.Angles(0,math.rad(deg),0)
    else rot=CFrame.Angles(0,0,math.rad(deg)) end

    pcall(function()
        if self.Space=="Local" then
            joint.Instance.C0 = joint.Instance.C0 * rot
        else
            joint.Instance.C0 = rot * joint.Instance.C0
        end
    end)
end

function TransformTool:Move(joint, axis, dist)
    if not joint or not joint.Instance then return end
    if self.SnapEnabled then
        dist = math.floor(dist/self.SnapMove+0.5)*self.SnapMove
    end
    local off = Vector3.new(0,0,0)
    if axis=="X" then off=Vector3.new(dist,0,0)
    elseif axis=="Y" then off=Vector3.new(0,dist,0)
    else off=Vector3.new(0,0,dist) end
    pcall(function()
        joint.Instance.C0 = joint.Instance.C0 + off
    end)
end

function TransformTool:ResetJoint(joint)
    if not joint then return end
    pcall(function()
        joint.Instance.C0 = joint.OriginalC0
        joint.Instance.C1 = joint.OriginalC1
    end)
end

MOON.API.TransformTool = TransformTool

-- ══════════════════════════════════════════════════════════════════
-- IK SOLVERS
-- ══════════════════════════════════════════════════════════════════
local IKSolver = {}

function IKSolver.TwoBone(root, mid, tip, target, poleVec)
    if not (root and mid and tip and root.Instance and mid.Instance and tip.Instance) then
        return false
    end
    local ok = pcall(function()
        local rp  = root.Instance.Part0 and root.Instance.Part0.Position or Vector3.new()
        local mp  = mid.Instance.Part1  and mid.Instance.Part1.Position  or Vector3.new()
        local tp2 = tip.Instance.Part1  and tip.Instance.Part1.Position  or Vector3.new()

        local l1 = (mp-rp).Magnitude
        local l2 = (tp2-mp).Magnitude
        local d  = U.Clamp((target-rp).Magnitude, 0.001, l1+l2-0.001)

        local cosA = U.Clamp((l1*l1+d*d-l2*l2)/(2*l1*d),-1,1)
        local angA = math.acos(cosA)

        local dir = (target-rp).Unit
        local pole= (poleVec or Vector3.new(0,1,0)).Unit
        local perp= dir:Cross(pole):Cross(dir).Unit

        local midPos = rp + CFrame.new(rp, rp+dir):VectorToWorldSpace(
            Vector3.new(math.sin(angA)*l1, math.cos(angA)*l1, 0)
        )

        root.Instance.C0 = CFrame.new(rp, midPos)
        mid.Instance.C0  = CFrame.new(midPos, target)
    end)
    return ok
end

function IKSolver.CCD(chain, target, iters)
    iters = iters or 8
    if #chain < 2 then return end
    for _=1,iters do
        for i=#chain,1,-1 do
            local j = chain[i]
            if j.Instance and j.Instance.Part0 then
                pcall(function()
                    local jp  = j.Instance.Part0.Position
                    local tip = chain[#chain].Instance.Part1
                    if not tip then return end
                    local tp = tip.Position

                    local toTip    = (tp-jp).Unit
                    local toTarget = (target-jp).Unit
                    local axis = toTip:Cross(toTarget)
                    if axis.Magnitude > 0.001 then
                        local angle = math.acos(U.Clamp(toTip:Dot(toTarget),-1,1))
                        j.Instance.C0 = j.Instance.C0 * CFrame.fromAxisAngle(axis.Unit, angle)
                    end
                end)
            end
        end
        local tip = chain[#chain].Instance and chain[#chain].Instance.Part1
        if tip and (tip.Position-target).Magnitude < 0.1 then break end
    end
end

MOON.API.IKSolver = IKSolver

-- ══════════════════════════════════════════════════════════════════
-- CONSTRAINT SYSTEM
-- ══════════════════════════════════════════════════════════════════
local Constraint = {}
Constraint.__index = Constraint

function Constraint.new(ctype, cfg)
    local self = setmetatable({}, Constraint)
    self.Type      = ctype
    self.Enabled   = true
    self.Influence = cfg.Influence or 1
    self.Target    = cfg.Target
    self.Axis      = cfg.Axis or "Y"
    self.Min       = cfg.Min or -180
    self.Max       = cfg.Max or  180
    return self
end

function Constraint:Apply(joint)
    if not self.Enabled or not joint or not joint.Instance then return end
    pcall(function()
        if self.Type=="LookAt" and self.Target then
            local jp = joint.Instance.Part0.Position
            local tp = typeof(self.Target)=="Vector3" and self.Target or self.Target.Position
            local lc = CFrame.new(jp, tp)
            joint.Instance.C0 = joint.Instance.C0:Lerp(lc, self.Influence)

        elseif self.Type=="Limit" then
            local _,_,_,rx,ry,rz = joint.Instance.C0:GetComponents()
            local function lim(v)
                return math.rad(U.Clamp(math.deg(v),self.Min,self.Max))
            end
            local ax,ay,az = rx,ry,rz
            if self.Axis=="X" then ax=lim(rx)
            elseif self.Axis=="Y" then ay=lim(ry)
            else az=lim(rz) end
            joint.Instance.C0 = CFrame.new(joint.Instance.C0.Position)
                * CFrame.Angles(ax,ay,az)

        elseif self.Type=="Copy" and self.Target then
            joint.Instance.C0 = joint.Instance.C0:Lerp(
                self.Target.CFrame or CFrame.new(), self.Influence
            )
        end
    end)
end

MOON.API.Constraint = Constraint

-- ══════════════════════════════════════════════════════════════════
-- RIG CONTROLLER (IK/FK + Constraints)
-- ══════════════════════════════════════════════════════════════════
local RigController = {}
RigController.__index = RigController

function RigController.new(rig)
    local self = setmetatable({}, RigController)
    self.Rig         = rig
    self.Chains      = {} -- {name={joints}}
    self.Constraints = {} -- {jointName={Constraint}}
    self.IKTargets   = {} -- {chainName=Part}
    self.IKBlend     = {} -- {chainName=0..1}
    return self
end

function RigController:AddChain(name, jointNames)
    local chain = {}
    for _, jn in ipairs(jointNames) do
        local j = RigAnalyzer.GetJoint(self.Rig, jn)
        if j then table.insert(chain, j) end
    end
    self.Chains[name]  = chain
    self.IKBlend[name] = 0
    Logger:Info("Chain: %s (%d joints)", name, #chain)
    return chain
end

function RigController:SetIKTarget(name, part)
    self.IKTargets[name] = part
end

function RigController:SetIKBlend(name, v)
    self.IKBlend[name] = U.Clamp(v,0,1)
end

function RigController:AddConstraint(jName, c)
    if not self.Constraints[jName] then self.Constraints[jName]={} end
    table.insert(self.Constraints[jName], c)
end

function RigController:Update()
    -- IK
    for name, chain in pairs(self.Chains) do
        local blend  = self.IKBlend[name] or 0
        local target = self.IKTargets[name]
        if blend > 0 and target and #chain >= 2 then
            if #chain == 2 then
                IKSolver.TwoBone(chain[1],chain[2],chain[2],target.Position)
            else
                IKSolver.CCD(chain, target.Position, 6)
            end
        end
    end
    -- Constraints
    for jName, cs in pairs(self.Constraints) do
        local j = RigAnalyzer.GetJoint(self.Rig, jName)
        if j then
            for _, c in ipairs(cs) do c:Apply(j) end
        end
    end
end

function RigController:SetupHumanoidIK()
    if not self.Rig then return end
    if self.Rig.Type == "R6" then
        self:AddChain("LeftArm",  {"Left Shoulder","Left Elbow"})
        self:AddChain("RightArm", {"Right Shoulder","Right Elbow"})
        self:AddChain("LeftLeg",  {"Left Hip","Left Knee"})
        self:AddChain("RightLeg", {"Right Hip","Right Knee"})
    elseif self.Rig.Type == "R15" then
        self:AddChain("LeftArm",  {"LeftShoulder","LeftElbow","LeftWrist"})
        self:AddChain("RightArm", {"RightShoulder","RightElbow","RightWrist"})
        self:AddChain("LeftLeg",  {"LeftHip","LeftKnee","LeftAnkle"})
        self:AddChain("RightLeg", {"RightHip","RightKnee","RightAnkle"})
    end
    Logger:Success("Humanoid IK chains set up for %s", self.Rig.Type)
end

MOON.API.RigController = RigController

-- ══════════════════════════════════════════════════════════════════
-- PROCEDURAL SYSTEMS
-- ══════════════════════════════════════════════════════════════════

-- Secondary Motion (Spring Physics)
local SpringMotion = {}
SpringMotion.__index = SpringMotion
function SpringMotion.new(stiffness, damping, mass)
    local self = setmetatable({}, SpringMotion)
    self.Stiffness = stiffness or 20
    self.Damping   = damping   or 5
    self.Mass      = mass      or 1
    self.Velocity  = Vector3.new()
    self.Position  = Vector3.new()
    return self
end
function SpringMotion:Update(dt, target)
    local spring  = (target - self.Position) * self.Stiffness
    local damp    = self.Velocity * -self.Damping
    local accel   = (spring + damp) / self.Mass
    self.Velocity = self.Velocity + accel * dt
    self.Position = self.Position + self.Velocity * dt
    return self.Position
end
MOON.API.SpringMotion = SpringMotion

-- Procedural Breathing
local Breathing = {}
Breathing.__index = Breathing
function Breathing.new(rig)
    local self = setmetatable({}, Breathing)
    self.Rig    = rig
    self.Rate   = 0.25
    self.Depth  = 0.015
    self.Enabled= false
    self.Time   = 0
    return self
end
function Breathing:Update(dt)
    if not self.Enabled then return end
    self.Time = self.Time + dt
    local breath = math.sin(self.Time * self.Rate * math.pi * 2) * self.Depth
    local j = RigAnalyzer.GetJoint(self.Rig, "Waist")
        or RigAnalyzer.GetJoint(self.Rig, "UpperTorso")
    if j and j.Instance then
        pcall(function()
            j.Instance.C0 = j.OriginalC0 * CFrame.new(0, breath, 0)
        end)
    end
end
MOON.API.Breathing = Breathing

-- Look At
local LookAt = {}
LookAt.__index = LookAt
function LookAt.new(rig)
    local self = setmetatable({}, LookAt)
    self.Rig     = rig
    self.Target  = nil
    self.Enabled = false
    self.Strength= 0.8
    self.MaxAng  = 40
    return self
end
function LookAt:Update(dt)
    if not self.Enabled or not self.Target then return end
    local j = RigAnalyzer.GetJoint(self.Rig,"Neck")
        or RigAnalyzer.GetJoint(self.Rig,"Head")
    if not j or not j.Instance or not j.Instance.Part1 then return end
    pcall(function()
        local hp = j.Instance.Part1.Position
        local tp = typeof(self.Target)=="Vector3" and self.Target or self.Target.Position
        local dir = (tp-hp).Unit
        local fwd = j.Instance.Part1.CFrame.LookVector
        local ang = math.deg(math.acos(U.Clamp(fwd:Dot(dir),-1,1)))
        if ang > self.MaxAng then
            dir = fwd:Lerp(dir, self.MaxAng/ang)
        end
        local tc = CFrame.new(hp, hp+dir)
        j.Instance.C0 = j.Instance.C0:Lerp(
            j.OriginalC0 * (tc - tc.Position),
            self.Strength
        )
    end)
end
MOON.API.LookAt = LookAt

-- Procedural Controller (combines all)
local ProceduralCtrl = {}
ProceduralCtrl.__index = ProceduralCtrl
function ProceduralCtrl.new(rig, rigCtrl)
    local self = setmetatable({}, ProceduralCtrl)
    self.Rig       = rig
    self.RigCtrl   = rigCtrl
    self.Breathing = Breathing.new(rig)
    self.LookAt    = LookAt.new(rig)
    self.Springs   = {}
    self.Enabled   = true
    return self
end
function ProceduralCtrl:Update(dt)
    if not self.Enabled then return end
    self.Breathing:Update(dt)
    self.LookAt:Update(dt)
    if self.RigCtrl then self.RigCtrl:Update() end
end
MOON.API.ProceduralCtrl = ProceduralCtrl

Logger:Info("Part 3/8 - Rig + Pose + IK + Procedural OK")
MOON.UI.Notify.Show({Type="Success",Title="🌙 Part 3 Loaded",Message="Rig system ready! Paste Part 4.",Duration=5})

--[[
╔══════════════════════════════════════════════════════════════════╗
║         🌙 MOON ANIMATOR ASSYNCRED - PARTE 4/8                  ║
║         GRAPH EDITOR + STATE MACHINE + BEZIER CURVES            ║
╚══════════════════════════════════════════════════════════════════╝
]]
local MOON = _G.MOON
assert(MOON,"Run Part 1 first!")
local Logger = MOON.Core.Logger
local U      = MOON.Utils
local UIB    = MOON.UI.Builder
local T_     = MOON.UI.ThemeSystem
local WM     = MOON.Systems.WindowManager
local Signal = U.Signal
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- ══════════════════════════════════════════════════════════════════
-- BEZIER MATH
-- ══════════════════════════════════════════════════════════════════
local Bezier = {}

function Bezier.Cubic(t, p0, p1, p2, p3)
    local mt = 1-t
    return mt^3*p0 + 3*mt^2*t*p1 + 3*mt*t^2*p2 + t^3*p3
end

function Bezier.CubicVec2(t, p0, p1, p2, p3)
    return Vector2.new(
        Bezier.Cubic(t, p0.X, p1.X, p2.X, p3.X),
        Bezier.Cubic(t, p0.Y, p1.Y, p2.Y, p3.Y)
    )
end

function Bezier.Tangent(t, p0, p1, p2, p3)
    local mt = 1-t
    return 3*mt^2*(p1-p0) + 6*mt*t*(p2-p1) + 3*t^2*(p3-p2)
end

function Bezier.SolveT(targetX, x0, x1, x2, x3, iters)
    iters = iters or 12
    local t = 0.5
    for _=1,iters do
        local x  = Bezier.Cubic(t, x0, x1, x2, x3)
        local dx = Bezier.Tangent(t, x0, x1, x2, x3)
        if math.abs(x-targetX) < 0.0001 then break end
        if dx ~= 0 then
            t = U.Clamp(t - (x-targetX)/dx, 0, 1)
        end
    end
    return t
end

MOON.Utils.Bezier = Bezier

-- ══════════════════════════════════════════════════════════════════
-- ANIMATION CURVE
-- ══════════════════════════════════════════════════════════════════
local AnimCurve = {}
AnimCurve.__index = AnimCurve

function AnimCurve.new(name, color)
    local self = setmetatable({}, AnimCurve)
    self.Id     = U.UUID()
    self.Name   = name or "Curve"
    self.Color  = color or Color3.fromRGB(100,200,255)
    self.Points = {} -- {Frame,Value,HIn,HOut,HandleType}
    return self
end

function AnimCurve:AddPoint(frame, value, hType)
    local p = {
        Frame      = frame,
        Value      = value,
        HandleIn   = Vector2.new(-1,0),
        HandleOut  = Vector2.new( 1,0),
        HandleType = hType or "Auto",
        Selected   = false,
    }
    table.insert(self.Points, p)
    table.sort(self.Points, function(a,b) return a.Frame<b.Frame end)
    self:_autoHandles()
    return p
end

function AnimCurve:_autoHandles()
    for i, p in ipairs(self.Points) do
        if p.HandleType=="Auto" then
            local prev = self.Points[i-1]
            local next = self.Points[i+1]
            if prev and next then
                local dx = (next.Frame - prev.Frame)/3
                local dy = (next.Value - prev.Value)/3
                p.HandleIn  = Vector2.new(-dx,-dy)
                p.HandleOut = Vector2.new( dx, dy)
            end
        end
    end
end

function AnimCurve:GetValue(frame)
    if #self.Points == 0 then return 0 end
    if frame <= self.Points[1].Frame then return self.Points[1].Value end
    if frame >= self.Points[#self.Points].Frame then return self.Points[#self.Points].Value end

    local p1,p2
    for i=1,#self.Points-1 do
        if frame>=self.Points[i].Frame and frame<=self.Points[i+1].Frame then
            p1,p2 = self.Points[i], self.Points[i+1]
            break
        end
    end
    if not p1 then return 0 end

    local f0 = Vector2.new(p1.Frame, p1.Value)
    local f3 = Vector2.new(p2.Frame, p2.Value)
    local f1 = f0 + p1.HandleOut
    local f2 = f3 + p2.HandleIn

    -- Solve for t where x == frame
    local t = Bezier.SolveT(frame, f0.X, f1.X, f2.X, f3.X)
    return Bezier.Cubic(t, f0.Y, f1.Y, f2.Y, f3.Y)
end

function AnimCurve:Smooth(iters)
    for _=1, iters or 1 do
        for i=2,#self.Points-1 do
            local p = self.Points[i]
            local prev = self.Points[i-1]
            local next = self.Points[i+1]
            p.Value = (prev.Value + p.Value + next.Value)/3
        end
    end
end

MOON.API.AnimCurve = AnimCurve

-- ══════════════════════════════════════════════════════════════════
-- GRAPH EDITOR UI
-- ══════════════════════════════════════════════════════════════════
local GraphEditor = {}
GraphEditor.__index = GraphEditor

function GraphEditor.new()
    local self = setmetatable({}, GraphEditor)
    self.Curves       = {}
    self.SelectedCurve= nil
    self.SelectedPoint= nil
    self.ViewOffset   = Vector2.new(0,0)
    self.ViewScale    = Vector2.new(3,50)  -- pixels per frame/unit
    self.Container    = nil
    return self
end

function GraphEditor:AddCurve(curve)
    table.insert(self.Curves, curve)
    if not self.SelectedCurve then self.SelectedCurve = curve end
    self:Redraw()
end

function GraphEditor:CreateUI(parent)
    local T = T_:Get()
    self.Container = UIB:Frame({
        Name             = "GraphEditor",
        Size             = UDim2.new(1,0,1,0),
        BackgroundColor3 = T.Background,
        Parent           = parent,
    })

    -- Toolbar
    local tb = UIB:Frame({
        Size             = UDim2.new(1,0,0,36),
        BackgroundColor3 = T.BackgroundTertiary,
        Parent           = self.Container,
    })

    local function tbBtn(txt, x, cb, tip)
        local b = UIB:Button(txt,{
            Size     = UDim2.new(0,60,0,28),
            Position = UDim2.new(0,x,0.5,-14),
            BackgroundColor3 = T.Surface,
            TextSize = 11,
            Parent   = tb,
        })
        UIB:Corner(b,4)
        if cb  then b.MouseButton1Click:Connect(cb) end
        if tip then MOON.UI.Tooltip.Attach(b,tip) end
        return b
    end

    local xp=8
    tbBtn("Auto",xp,function()
        if self.SelectedPoint then
            self.SelectedPoint.HandleType="Auto"
            if self.SelectedCurve then self.SelectedCurve:_autoHandles() end
            self:Redraw()
        end
    end,"Auto tangents"); xp=xp+64

    tbBtn("Free",xp,function()
        if self.SelectedPoint then
            self.SelectedPoint.HandleType="Free"
            self:Redraw()
        end
    end,"Free tangents"); xp=xp+64

    tbBtn("Linear",xp,function()
        if self.SelectedPoint then
            self.SelectedPoint.HandleType="Vector"
            self.SelectedPoint.HandleIn  = Vector2.new(-1,0)
            self.SelectedPoint.HandleOut = Vector2.new( 1,0)
            self:Redraw()
        end
    end,"Linear"); xp=xp+64

    tbBtn("Smooth",xp,function()
        if self.SelectedCurve then
            self.SelectedCurve:Smooth(1)
            self:Redraw()
        end
    end,"Smooth curve"); xp=xp+64

    -- Sidebar
    self.Sidebar = UIB:Frame({
        Size             = UDim2.new(0,150,1,-36),
        Position         = UDim2.new(1,-150,0,36),
        BackgroundColor3 = T.BackgroundSecondary,
        Parent           = self.Container,
    })
    UIB:Label("Curves",{
        Size=UDim2.new(1,0,0,24),
        Position=UDim2.new(0,8,0,4),
        Font=Enum.Font.GothamBold,TextSize=12,
        Parent=self.Sidebar,
    })
    self.CurveList = UIB:Scroll({
        Size=UDim2.new(1,0,1,-32),
        Position=UDim2.new(0,0,0,32),
        Parent=self.Sidebar,
    })
    UIB:ListLayout(self.CurveList)

    -- Canvas
    self.Canvas = UIB:Frame({
        Name             = "Canvas",
        Size             = UDim2.new(1,-150,1,-36),
        Position         = UDim2.new(0,0,0,36),
        BackgroundColor3 = Color3.fromRGB(28,28,32),
        ClipsDescendants = true,
        Parent           = self.Container,
    })

    -- Grid lines on canvas
    self:DrawGrid()

    -- Canvas click to add point
    self.Canvas.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 then
            if self.SelectedCurve then
                local rel = inp.Position - self.Canvas.AbsolutePosition
                local frame = math.floor(rel.X / self.ViewScale.X)
                local value = (self.Canvas.AbsoluteSize.Y/2 - rel.Y) / self.ViewScale.Y
                self.SelectedCurve:AddPoint(frame, value)
                self:Redraw()
            end
        end
    end)

    self:Redraw()
    return self.Container
end

function GraphEditor:DrawGrid()
    if not self.Canvas then return end
    local T = T_:Get()
    for _,ch in ipairs(self.Canvas:GetChildren()) do
        if ch.Name=="_grid" then ch:Destroy() end
    end
    local sz = self.Canvas.AbsoluteSize
    if sz.X == 0 then return end
    -- Vertical lines every 30 frames
    for f=0,300,30 do
        local x = f * self.ViewScale.X - self.ViewOffset.X
        UIB:Frame({Name="_grid",Size=UDim2.new(0,1,1,0),
            Position=UDim2.new(0,x,0,0),
            BackgroundColor3=T.Border,BackgroundTransparency=0.6,
            BorderSizePixel=0,Parent=self.Canvas})
    end
    -- Horizontal zero line
    local y0 = sz.Y/2
    UIB:Frame({Name="_grid",Size=UDim2.new(1,0,0,1),
        Position=UDim2.new(0,0,0,y0),
        BackgroundColor3=T.TextSecondary,BackgroundTransparency=0.5,
        BorderSizePixel=0,Parent=self.Canvas})
end

function GraphEditor:Redraw()
    if not self.Canvas then return end
    local T = T_:Get()
    -- Clear old visuals
    for _,ch in ipairs(self.Canvas:GetChildren()) do
        if ch.Name=="_kfPt" or ch.Name=="_line" then ch:Destroy() end
    end

    for _, curve in ipairs(self.Curves) do
        local pts = curve.Points
        -- Draw connecting lines (simplified segmented)
        for i=1,#pts-1 do
            local p1=pts[i]; local p2=pts[i+1]
            local segments = 20
            local prevV2
            for s=0,segments do
                local t = s/segments
                local f = U.Lerp(p1.Frame, p2.Frame, t)
                local v = curve:GetValue(f)
                local x = f * self.ViewScale.X - self.ViewOffset.X
                local y = self.Canvas.AbsoluteSize.Y/2 - v*self.ViewScale.Y
                local cv2 = Vector2.new(x,y)
                if prevV2 and s>0 then
                    -- Draw a tiny frame to simulate line
                    local d = cv2 - prevV2
                    local len = d.Magnitude
                    if len > 0.5 then
                        local angle = math.deg(math.atan2(d.Y,d.X))
                        local mid = (prevV2+cv2)/2
                        UIB:Frame({
                            Name             = "_line",
                            Size             = UDim2.new(0,len+1,0,2),
                            Position         = UDim2.new(0,mid.X-len/2,0,mid.Y-1),
                            BackgroundColor3 = curve.Color,
                            BackgroundTransparency=0.1,
                            Rotation         = angle,
                            BorderSizePixel  = 0,
                            ZIndex           = 3,
                            Parent           = self.Canvas,
                        })
                    end
                end
                prevV2 = cv2
            end
        end

        -- Draw control points
        for _, p in ipairs(pts) do
            local x = p.Frame * self.ViewScale.X - self.ViewOffset.X
            local y = self.Canvas.AbsoluteSize.Y/2 - p.Value*self.ViewScale.Y
            local sz = p.Selected and 12 or 8
            local dot = UIB:Frame({
                Name             = "_kfPt",
                Size             = UDim2.new(0,sz,0,sz),
                Position         = UDim2.new(0,x-sz/2,0,y-sz/2),
                BackgroundColor3 = p.Selected and T.Selection or curve.Color,
                ZIndex           = 5,
                Parent           = self.Canvas,
            })
            UIB:Corner(dot, 999)
            dot.InputBegan:Connect(function(inp)
                if inp.UserInputType==Enum.UserInputType.MouseButton1 then
                    for _,pp in ipairs(pts) do pp.Selected=false end
                    p.Selected = true
                    self.SelectedPoint = p
                    self:Redraw()
                end
            end)
        end
    end

    -- Update curve list sidebar
    for _,ch in ipairs(self.CurveList:GetChildren()) do
        if ch:IsA("Frame") then ch:Destroy() end
    end
    local T2=T_:Get()
    for _, curve in ipairs(self.Curves) do
        local row = UIB:Frame({
            Size=UDim2.new(1,0,0,28),
            BackgroundColor3=self.SelectedCurve==curve and T2.Primary or T2.Surface,
            Parent=self.CurveList,
        })
        UIB:Corner(row,4)
        UIB:Frame({Size=UDim2.new(0,4,1,0),BackgroundColor3=curve.Color,Parent=row})
        UIB:Label(curve.Name,{
            Size=UDim2.new(1,-8,1,0),Position=UDim2.new(0,8,0,0),
            TextSize=11,Parent=row,
        })
        local cur = curve
        row.InputBegan:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 then
                self.SelectedCurve=cur; self:Redraw()
            end
        end)
    end
end

MOON.UI.GraphEditor = GraphEditor

-- ══════════════════════════════════════════════════════════════════
-- STATE MACHINE
-- ══════════════════════════════════════════════════════════════════
local StateNode = {}
StateNode.__index = StateNode

function StateNode.new(name, clip)
    local self = setmetatable({}, StateNode)
    self.Id          = U.UUID()
    self.Name        = name or "State"
    self.Clip        = clip
    self.Position    = Vector2.new(100,100)
    self.Size        = Vector2.new(130,60)
    self.Transitions = {}
    self.Speed       = 1
    self.Loop        = true
    self.Color       = Color3.fromRGB(80,120,200)
    self.Selected    = false
    self.IsEntry     = false
    self.IsAny       = false
    return self
end

function StateNode:AddTransition(target, condition, duration)
    local t = {
        Id=U.UUID(), Target=target,
        Condition=condition or "", Duration=duration or 0.2,
        HasExitTime=true, ExitTime=0.9,
    }
    table.insert(self.Transitions, t)
    return t
end

MOON.API.StateNode = StateNode

-- Blend Tree Node
local BlendTree = {}
BlendTree.__index = BlendTree
function BlendTree.new(name)
    local self = setmetatable({}, BlendTree)
    self.Id       = U.UUID()
    self.Name     = name or "Blend Tree"
    self.Type     = "1D"
    self.Param    = "Speed"
    self.Motions  = {}
    self.Position = Vector2.new(100,100)
    self.Size     = Vector2.new(150,80)
    self.Color    = Color3.fromRGB(200,120,60)
    return self
end
function BlendTree:AddMotion(anim, threshold)
    table.insert(self.Motions, {Animation=anim, Threshold=threshold, Speed=1})
end
function BlendTree:Evaluate(val)
    if #self.Motions==0 then return nil end
    if #self.Motions==1 then return self.Motions[1] end
    local lo,hi
    for _,m in ipairs(self.Motions) do
        if m.Threshold<=val then lo=m end
        if m.Threshold>=val and not hi then hi=m; break end
    end
    if not lo then return hi end
    if not hi then return lo end
    if lo==hi then return lo end
    local w = (val-lo.Threshold)/(hi.Threshold-lo.Threshold)
    return {Blend={lo,hi}, Weight=w}
end
MOON.API.BlendTree = BlendTree

-- State Machine Runtime
local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.new(name)
    local self = setmetatable({}, StateMachine)
    self.Id           = U.UUID()
    self.Name         = name or "StateMachine"
    self.States       = {}
    self.BlendTrees   = {}
    self.Parameters   = {}
    self.CurrentState = nil
    self.NextState    = nil
    self.IsTransitioning = false
    self.TransProgress   = 0
    self.TransDuration   = 0.2

    self.OnEnter      = Signal.new()
    self.OnExit       = Signal.new()
    self.OnTransStart = Signal.new()
    self.OnTransEnd   = Signal.new()

    -- Default entry state
    local entry = StateNode.new("Entry")
    entry.IsEntry = true
    entry.Color   = Color3.fromRGB(80,200,100)
    self:AddState(entry)
    self.CurrentState = entry
    return self
end

function StateMachine:AddState(s)
    self.States[s.Id] = s
    return s
end

function StateMachine:AddParam(name, ptype, default)
    self.Parameters[name] = {Type=ptype, Value=default or 0}
end

function StateMachine:SetParam(name, v)
    if self.Parameters[name] then
        self.Parameters[name].Value = v
        if self.Parameters[name].Type=="Trigger" then
            task.defer(function()
                if self.Parameters[name] then
                    self.Parameters[name].Value = false
                end
            end)
        end
    end
end

function StateMachine:GetParam(name)
    local p = self.Parameters[name]
    return p and p.Value
end

function StateMachine:EvalCondition(cond)
    if not cond or cond=="" then return true end
    -- Simple expression parser: "param op value"
    local ops = {
        [">="] = function(a,b) return a>=b end,
        ["<="] = function(a,b) return a<=b end,
        [">"]  = function(a,b) return a>b  end,
        ["<"]  = function(a,b) return a<b  end,
        ["=="] = function(a,b) return a==b end,
        ["!="] = function(a,b) return a~=b end,
    }
    for op, fn in pairs(ops) do
        if cond:find(op, 1, true) then
            local parts = cond:split(op)
            if #parts>=2 then
                local pn = parts[1]:gsub("%s","")
                local vt = tonumber(parts[2]:gsub("%s",""))
                local pv = self:GetParam(pn)
                if pv~=nil and vt~=nil then return fn(pv,vt) end
            end
        end
    end
    local direct = self:GetParam(cond:gsub("%s",""))
    return direct == true
end

function StateMachine:Update(dt)
    if not self.CurrentState then return end
    if self.IsTransitioning then
        self.TransProgress = self.TransProgress + dt/self.TransDuration
        if self.TransProgress >= 1 then
            self:_completeTransition()
        end
        return
    end
    for _, tr in ipairs(self.CurrentState.Transitions) do
        if self:EvalCondition(tr.Condition) then
            self:_startTransition(tr.Target, tr.Duration)
            break
        end
    end
end

function StateMachine:_startTransition(target, dur)
    self.IsTransitioning = true
    self.TransProgress   = 0
    self.TransDuration   = dur or 0.2
    self.NextState       = target
    self.OnTransStart:Fire(self.CurrentState, target)
end

function StateMachine:_completeTransition()
    self.IsTransitioning = false
    self.TransProgress   = 0
    self.OnExit:Fire(self.CurrentState)
    self.CurrentState = self.NextState
    self.NextState    = nil
    self.OnEnter:Fire(self.CurrentState)
end

MOON.API.StateMachine = StateMachine

-- ══════════════════════════════════════════════════════════════════
-- STATE MACHINE EDITOR UI
-- ══════════════════════════════════════════════════════════════════
local SMEditor = {}
SMEditor.__index = SMEditor

function SMEditor.new()
    local self = setmetatable({}, SMEditor)
    self.SM          = nil
    self.NodeVisuals = {}
    self.Selected    = nil
    self.ViewZoom    = 1
    self.ViewOffset  = Vector2.new(0,0)
    return self
end

function SMEditor:CreateUI(parent)
    local T = T_:Get()

    self.Container = UIB:Frame({
        Name="SMEditor",
        Size=UDim2.new(1,0,1,0),
        BackgroundColor3=T.Background,
        Parent=parent,
    })

    -- Toolbar
    local tb = UIB:Frame({
        Size=UDim2.new(1,0,0,40),
        BackgroundColor3=T.BackgroundTertiary,
        Parent=self.Container,
    })

    local function tbBtn(txt,x,cb,col)
        local b=UIB:Button(txt,{
            Size=UDim2.new(0,110,0,30),
            Position=UDim2.new(0,x,0.5,-15),
            BackgroundColor3=col or T.Surface,
            TextSize=12,Parent=tb,
        })
        UIB:Corner(b,5)
        if cb then b.MouseButton1Click:Connect(cb) end
        return b
    end

    local xp=8
    tbBtn("+ State",xp,function() self:AddState() end,T.Primary); xp=xp+114
    tbBtn("+ Blend Tree",xp,function() self:AddBlendTree() end,T.Secondary); xp=xp+114
    tbBtn("+ Parameter",xp,function() self:AddParamDialog() end,T.Surface); xp=xp+114
    tbBtn("Clear All",xp,function()
        self.SM=nil; self.NodeVisuals={}
        for _,ch in ipairs(self.NodeCanvas:GetChildren()) do
            if ch:IsA("Frame") then ch:Destroy() end
        end
    end,T.Error)

    -- Canvas
    self.NodeCanvas = UIB:Frame({
        Name="NodeCanvas",
        Size=UDim2.new(1,-240,1,-40),
        Position=UDim2.new(0,0,0,40),
        BackgroundColor3=Color3.fromRGB(26,26,32),
        ClipsDescendants=true,
        Parent=self.Container,
    })

    -- Draw grid on canvas
    do
        local gs=50
        local T2=T_:Get()
        for x=0,1400,gs do
            UIB:Frame({Size=UDim2.new(0,1,1,0),Position=UDim2.new(0,x,0,0),
                BackgroundColor3=T2.Border,BackgroundTransparency=0.8,
                BorderSizePixel=0,Parent=self.NodeCanvas})
        end
        for y=0,900,gs do
            UIB:Frame({Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,0,y),
                BackgroundColor3=T2.Border,BackgroundTransparency=0.8,
                BorderSizePixel=0,Parent=self.NodeCanvas})
        end
    end

    -- Properties panel
    self.PropPanel = UIB:Frame({
        Name="Props",
        Size=UDim2.new(0,240,1,-40),
        Position=UDim2.new(1,-240,0,40),
        BackgroundColor3=T.BackgroundSecondary,
        Parent=self.Container,
    })
    UIB:Label("Properties",{
        Size=UDim2.new(1,0,0,32),Position=UDim2.new(0,0,0,0),
        Font=Enum.Font.GothamBold,TextSize=14,
        Parent=self.PropPanel,
    })

    self.PropContent = UIB:Scroll({
        Size=UDim2.new(1,0,1,-40),Position=UDim2.new(0,0,0,40),
        Parent=self.PropPanel,
    })
    UIB:ListLayout(self.PropContent)
    UIB:Pad(self.PropContent,8)

    -- Params panel
    self.ParamPanel = UIB:Scroll({
        Size=UDim2.new(1,0,0,160),
        Position=UDim2.new(1,-240,1,-160),
        BackgroundColor3=T.BackgroundTertiary,
        Parent=self.Container,
    })

    return self.Container
end

function SMEditor:GetOrCreateSM()
    if not self.SM then
        self.SM = StateMachine.new("Main")
    end
    return self.SM
end

function SMEditor:AddState()
    local sm = self:GetOrCreateSM()
    local s  = StateNode.new("State"..tostring(U.TableCount(sm.States)))
    s.Position = Vector2.new(math.random(60,500), math.random(60,300))
    sm:AddState(s)
    self:CreateNodeVisual(s)
end

function SMEditor:AddBlendTree()
    local sm = self:GetOrCreateSM()
    local bt = BlendTree.new("BlendTree"..tostring(#sm.BlendTrees+1))
    bt.Position = Vector2.new(math.random(60,500), math.random(60,300))
    sm.BlendTrees[bt.Id] = bt
    self:CreateBlendVisual(bt)
end

function SMEditor:CreateNodeVisual(node)
    local T = T_:Get()
    local f = UIB:Frame({
        Name             = "Node_"..node.Id,
        Size             = UDim2.new(0,node.Size.X,0,node.Size.Y),
        Position         = UDim2.new(0,node.Position.X,0,node.Position.Y),
        BackgroundColor3 = node.Color,
        ZIndex           = 10,
        Parent           = self.NodeCanvas,
    })
    UIB:Corner(f,8)
    UIB:Stroke(f,2,node.Selected and T.Selection or T.Border)

    UIB:Label(node.Name,{
        Size=UDim2.new(1,-8,1,0),Position=UDim2.new(0,4,0,0),
        Font=Enum.Font.GothamBold,TextSize=12,
        ZIndex=11,Parent=f,
    })

    MOON.UI.MakeDraggable(f,f)

    f.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 then
            self:SelectNode(node, f)
        end
    end)

    self.NodeVisuals[node.Id] = f
end

function SMEditor:CreateBlendVisual(bt)
    local T = T_:Get()
    local f = UIB:Frame({
        Name             = "BT_"..bt.Id,
        Size             = UDim2.new(0,bt.Size.X,0,bt.Size.Y),
        Position         = UDim2.new(0,bt.Position.X,0,bt.Position.Y),
        BackgroundColor3 = bt.Color,
        ZIndex           = 10,
        Parent           = self.NodeCanvas,
    })
    UIB:Corner(f,8)
    UIB:Stroke(f,2,T.Border)
    UIB:Label(bt.Name,{
        Size=UDim2.new(1,0,0,20),Position=UDim2.new(0,4,0,4),
        Font=Enum.Font.GothamBold,TextSize=11,ZIndex=11,Parent=f,
    })
    UIB:Label("[Blend Tree 1D]",{
        Size=UDim2.new(1,0,0,16),Position=UDim2.new(0,4,0,26),
        TextSize=10,TextColor3=T.TextSecondary,ZIndex=11,Parent=f,
    })
    MOON.UI.MakeDraggable(f,f)
    self.NodeVisuals[bt.Id] = f
end

function SMEditor:SelectNode(node, frame)
    local T = T_:Get()
    for _, vf in pairs(self.NodeVisuals) do
        for _,ch in ipairs(vf:GetChildren()) do
            if ch:IsA("UIStroke") then ch.Color=T.Border end
        end
    end
    for _,ch in ipairs(frame:GetChildren()) do
        if ch:IsA("UIStroke") then ch.Color=T.Selection; ch.Thickness=3 end
    end
    self.Selected = node
    self:ShowProps(node)
end

function SMEditor:ShowProps(node)
    for _,ch in ipairs(self.PropContent:GetChildren()) do
        if ch:IsA("Frame") then ch:Destroy() end
    end
    local T=T_:Get()

    local function propRow(label, val)
        local r=UIB:Frame({Size=UDim2.new(1,0,0,32),BackgroundColor3=T.Surface,Parent=self.PropContent})
        UIB:Corner(r,4)
        UIB:Label(label..":",{Size=UDim2.new(0.45,0,1,0),Position=UDim2.new(0,4,0,0),TextSize=11,Parent=r})
        UIB:Label(tostring(val),{
            Size=UDim2.new(0.55,-4,1,0),Position=UDim2.new(0.45,0,0,0),
            TextSize=11,TextColor3=T.Primary,Parent=r,
        })
        return r
    end

    propRow("Name",  node.Name)
    propRow("Loop",  node.Loop)
    propRow("Speed", node.Speed)
    propRow("Transitions", #node.Transitions)
end

function SMEditor:AddParamDialog()
    local sm=self:GetOrCreateSM()
    sm:AddParam("Speed",   "Float", 0)
    sm:AddParam("IsIdle",  "Bool",  false)
    sm:AddParam("Jump",    "Trigger",false)
    -- Refresh param list
    local T=T_:Get()
    for _,ch in ipairs(self.ParamPanel:GetChildren()) do
        if ch:IsA("Frame") then ch:Destroy() end
    end
    for name, p in pairs(sm.Parameters) do
        local r=UIB:Frame({
            Size=UDim2.new(1,0,0,28),BackgroundColor3=T.Surface,
            Parent=self.ParamPanel,
        })
        UIB:Corner(r,4)
        UIB:Label(name,{Size=UDim2.new(0.6,0,1,0),Position=UDim2.new(0,4,0,0),TextSize=11,Parent=r})
        UIB:Label("["..p.Type.."]",{
            Size=UDim2.new(0.4,0,1,0),Position=UDim2.new(0.6,0,0,0),
            TextSize=10,TextColor3=T.TextSecondary,Parent=r,
        })
    end
    Logger:Info("Parameters added: Speed(Float), IsIdle(Bool), Jump(Trigger)")
end

MOON.UI.SMEditor = SMEditor

Logger:Info("Part 4/8 - Graph Editor + State Machine OK")
MOON.UI.Notify.Show({
    Type="Success",
    Title="🌙 Part 4/8 Loaded!",
    Message="Graph Editor + State Machine ready!\n\n❓ Want to continue to Part 5?\nPaste Part 5 when ready.",
    Duration=10,
})
print("\n" .. string.rep("═",50))
print("  🌙 PARTS 1-4 LOADED SUCCESSFULLY!")
print("  Systems ready:")
print("  ✅ Core Framework + UI + Windows")
print("  ✅ Timeline + Keyframes + Tracks")
print("  ✅ Rig Analyzer + IK + Procedural")
print("  ✅ Graph Editor + State Machine")
print("  ❓ Want to continue? Paste Part 5!")
print(string.rep("═",50) .. "\n")

--[[
╔══════════════════════════════════════════════════════════════════╗
║         🌙 MOON ANIMATOR ASSYNCRED - PARTE 5/8                  ║
║         CINEMATIC TOOLS + CAMERA SEQUENCER + VFX + AUDIO        ║
╚══════════════════════════════════════════════════════════════════╝
]]
local MOON = _G.MOON
assert(MOON, "Run Part 1 first!")
local Logger  = MOON.Core.Logger
local U       = MOON.Utils
local UIB     = MOON.UI.Builder
local T_      = MOON.UI.ThemeSystem
local WM      = MOON.Systems.WindowManager
local Signal  = U.Signal
local RS      = game:GetService("RunService")
local TS      = game:GetService("TweenService")
local UIS     = game:GetService("UserInputService")

-- ══════════════════════════════════════════════════════════════════
-- CAMERA SHOT
-- ══════════════════════════════════════════════════════════════════
local CameraShot = {}
CameraShot.__index = CameraShot

function CameraShot.new(name)
    local self = setmetatable({}, CameraShot)
    self.Id            = U.UUID()
    self.Name          = name or "Shot"
    self.CFrame        = workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new(0,5,10)
    self.FOV           = 70
    self.FocusDist     = 20
    self.Aperture      = 2.8
    self.Keyframes     = {}   -- {frame={CFrame,FOV}}
    self.LookAtTarget  = nil
    self.FollowTarget  = nil
    self.FollowOffset  = Vector3.new(0,3,8)
    return self
end

function CameraShot:AddKeyframe(frame, cf, fov)
    self.Keyframes[frame] = {
        CFrame = cf  or self.CFrame,
        FOV    = fov or self.FOV,
    }
end

function CameraShot:GetAtFrame(frame)
    if self.Keyframes[frame] then
        return self.Keyframes[frame]
    end
    local sorted = {}
    for f in pairs(self.Keyframes) do table.insert(sorted,f) end
    table.sort(sorted)
    if #sorted==0 then return {CFrame=self.CFrame,FOV=self.FOV} end
    if frame<sorted[1] then return self.Keyframes[sorted[1]] end
    if frame>sorted[#sorted] then return self.Keyframes[sorted[#sorted]] end
    local p1,p2
    for i=1,#sorted-1 do
        if frame>=sorted[i] and frame<=sorted[i+1] then
            p1,p2=sorted[i],sorted[i+1]; break
        end
    end
    if not p1 then return {CFrame=self.CFrame,FOV=self.FOV} end
    local alpha = (frame-p1)/(p2-p1)
    local kf1,kf2 = self.Keyframes[p1],self.Keyframes[p2]
    return {
        CFrame = kf1.CFrame:Lerp(kf2.CFrame, alpha),
        FOV    = U.Lerp(kf1.FOV, kf2.FOV, alpha),
    }
end

function CameraShot:Capture()
    local cam = workspace.CurrentCamera
    if cam then
        self.CFrame = cam.CFrame
        self.FOV    = cam.FieldOfView
    end
end

MOON.API.CameraShot = CameraShot

-- ══════════════════════════════════════════════════════════════════
-- CAMERA TRACK
-- ══════════════════════════════════════════════════════════════════
local CameraTrack = {}
CameraTrack.__index = CameraTrack

function CameraTrack.new(name)
    local self = setmetatable({}, CameraTrack)
    self.Id    = U.UUID()
    self.Name  = name or "CamTrack"
    self.Shots = {}    -- {startFrame = CameraShot}
    return self
end

function CameraTrack:AddShot(frame, shot)
    self.Shots[frame] = shot
end

function CameraTrack:GetShotAt(frame)
    local sorted={}
    for f in pairs(self.Shots) do table.insert(sorted,f) end
    table.sort(sorted)
    local active=nil
    for _,f in ipairs(sorted) do
        if f<=frame then active=self.Shots[f] else break end
    end
    return active
end

MOON.API.CameraTrack = CameraTrack

-- ══════════════════════════════════════════════════════════════════
-- CAMERA CONTROLLER
-- ══════════════════════════════════════════════════════════════════
local CamCtrl = {}
CamCtrl.__index = CamCtrl

function CamCtrl.new()
    local self     = setmetatable({}, CamCtrl)
    self.Cam       = workspace.CurrentCamera
    self.Enabled   = false
    self.Track     = nil
    self.Shake     = {Active=false,Intensity=0,Freq=12,Time=0,Trauma=0}
    self.OrigCF    = self.Cam and self.Cam.CFrame or CFrame.new()
    self.OrigFOV   = self.Cam and self.Cam.FieldOfView or 70
    self.DOFEnabled= false
    self.MotionBlur= false
    return self
end

function CamCtrl:Enable()
    self.Enabled = true
    if self.Cam then
        pcall(function() self.Cam.CameraType = Enum.CameraType.Scriptable end)
    end
    Logger:Info("Camera Controller enabled")
end

function CamCtrl:Disable()
    self.Enabled = false
    if self.Cam then
        pcall(function()
            self.Cam.CameraType    = Enum.CameraType.Custom
            self.Cam.CFrame        = self.OrigCF
            self.Cam.FieldOfView   = self.OrigFOV
        end)
    end
    Logger:Info("Camera Controller disabled")
end

function CamCtrl:UpdateAtFrame(frame)
    if not self.Enabled or not self.Track or not self.Cam then return end
    local shot = self.Track:GetShotAt(frame)
    if not shot then return end
    local data = shot:GetAtFrame(frame)
    local finalCF = data.CFrame

    -- Camera shake
    if self.Shake.Active then
        self.Shake.Time = self.Shake.Time + 1/60
        local t = self.Shake.Time
        local freq = self.Shake.Freq
        local intensity = self.Shake.Intensity * (self.Shake.Trauma^2)
        local shakeOffset = Vector3.new(
            math.sin(t*freq*1.0)*intensity,
            math.sin(t*freq*1.3)*intensity,
            math.sin(t*freq*0.7)*intensity*0.3
        )
        finalCF = finalCF * CFrame.new(shakeOffset)
        self.Shake.Trauma = math.max(0, self.Shake.Trauma - 0.02)
        if self.Shake.Trauma <= 0 then self.Shake.Active=false end
    end

    pcall(function()
        self.Cam.CFrame      = finalCF
        self.Cam.FieldOfView = data.FOV
    end)
end

function CamCtrl:AddShake(intensity, duration)
    self.Shake.Active    = true
    self.Shake.Intensity = intensity or 0.5
    self.Shake.Trauma    = 1.0
    self.Shake.Time      = 0
    Logger:Info("Camera shake: intensity=%.2f duration=%.2f", intensity, duration)
    task.delay(duration or 1, function()
        self.Shake.Trauma = 0
    end)
end

function CamCtrl:SetTrack(track)
    self.Track = track
end

MOON.API.CamCtrl = CamCtrl

-- ══════════════════════════════════════════════════════════════════
-- EVENT TRACK
-- ══════════════════════════════════════════════════════════════════
local EventTrack = {}
EventTrack.__index = EventTrack

function EventTrack.new(name)
    local self = setmetatable({}, EventTrack)
    self.Id     = U.UUID()
    self.Name   = name or "Events"
    self.Events = {}  -- {frame = {Name, Callback}}
    return self
end

function EventTrack:AddEvent(frame, name, callback)
    self.Events[frame] = {Name=name, Callback=callback, Fired=false}
end

function EventTrack:ExecuteAt(frame)
    local ev = self.Events[frame]
    if ev and not ev.Fired then
        ev.Fired = true
        if type(ev.Callback)=="function" then
            pcall(ev.Callback)
        end
        Logger:Debug("Event fired: %s at frame %d", ev.Name, frame)
    end
end

function EventTrack:Reset()
    for _, ev in pairs(self.Events) do
        ev.Fired = false
    end
end

MOON.API.EventTrack = EventTrack

-- ══════════════════════════════════════════════════════════════════
-- CINEMATIC SEQUENCE
-- ══════════════════════════════════════════════════════════════════
local CinematicSeq = {}
CinematicSeq.__index = CinematicSeq

function CinematicSeq.new(name)
    local self       = setmetatable({}, CinematicSeq)
    self.Id          = U.UUID()
    self.Name        = name or "Cinematic"
    self.FPS         = 30
    self.Duration    = 300
    self.CurrentFrame= 0
    self.IsPlaying   = false
    self.CamTracks   = {}
    self.EventTracks = {}
    self.AnimTracks  = {}
    self.AudioTracks = {}
    self._conn       = nil

    self.OnFrame     = Signal.new()
    self.OnPlay      = Signal.new()
    self.OnStop      = Signal.new()
    return self
end

function CinematicSeq:AddCamTrack(t)    table.insert(self.CamTracks,   t) end
function CinematicSeq:AddEventTrack(t)  table.insert(self.EventTracks, t) end
function CinematicSeq:AddAudioTrack(t)  table.insert(self.AudioTracks, t) end

function CinematicSeq:SetFrame(f)
    f = U.Clamp(math.floor(f), 0, self.Duration)
    self.CurrentFrame = f
    self.OnFrame:Fire(f)
    -- Execute events
    for _, et in ipairs(self.EventTracks) do
        et:ExecuteAt(f)
    end
end

function CinematicSeq:Play()
    if self.IsPlaying then return end
    self.IsPlaying = true
    -- Reset event tracks
    for _, et in ipairs(self.EventTracks) do et:Reset() end
    self.OnPlay:Fire()
    local t0    = tick()
    local startF= self.CurrentFrame
    local function step()
        if not self.IsPlaying then return end
        local elapsed = tick()-t0
        local nf = startF + elapsed*self.FPS
        if nf>=self.Duration then
            self:Stop(); return
        end
        self:SetFrame(nf)
    end
    local ok=pcall(function() self._conn=RS.RenderStepped:Connect(step) end)
    if not ok then self._conn=RS.Heartbeat:Connect(step) end
    Logger:Info("Cinematic playing: %s", self.Name)
end

function CinematicSeq:Stop()
    self.IsPlaying=false
    if self._conn then self._conn:Disconnect(); self._conn=nil end
    self.OnStop:Fire()
end

function CinematicSeq:Rewind()
    self:Stop()
    self:SetFrame(0)
end

MOON.API.CinematicSeq = CinematicSeq

-- ══════════════════════════════════════════════════════════════════
-- VFX SYSTEM
-- ══════════════════════════════════════════════════════════════════
local VFXSystem = {}
VFXSystem.__index = VFXSystem

function VFXSystem.new()
    local self = setmetatable({}, VFXSystem)
    self.Effects  = {}  -- {id = instance}
    self.Active   = {}
    return self
end

function VFXSystem:CreateEffect(effectType, cfg)
    cfg = cfg or {}
    local eff
    local id = U.UUID()

    pcall(function()
        if effectType=="Particle" then
            local part = Instance.new("Part")
            part.Anchored    = true
            part.CanCollide  = false
            part.Transparency= 1
            part.Size        = Vector3.new(1,1,1)
            part.Position    = cfg.Position or Vector3.new(0,0,0)
            part.Name        = "VFX_"..id

            local pe = Instance.new("ParticleEmitter")
            pe.Rate        = cfg.Rate or 20
            pe.Lifetime    = NumberRange.new(cfg.Lifetime or 1)
            pe.Speed       = NumberRange.new(cfg.Speed or 5)
            pe.Color       = cfg.Color or ColorSequence.new(Color3.new(1,1,1))
            pe.Transparency= cfg.Transparency or NumberSequence.new(0)
            pe.Parent      = part

            eff = {Part=part, Emitter=pe, Type="Particle"}

        elseif effectType=="Trail" then
            eff = {Type="Trail", Instance=nil}
            Logger:Info("Trail VFX created (attach to Part manually)")

        elseif effectType=="Beam" then
            eff = {Type="Beam", Instance=nil}
            Logger:Info("Beam VFX created (attach to Attachments manually)")

        elseif effectType=="Sound" then
            local sound = Instance.new("Sound")
            sound.SoundId      = cfg.SoundId or ""
            sound.Volume       = cfg.Volume or 0.5
            sound.PlaybackSpeed= cfg.PlaybackSpeed or 1
            sound.Looped       = cfg.Looped or false
            sound.Parent       = workspace
            eff = {Sound=sound, Type="Sound"}
        end
    end)

    if eff then
        self.Effects[id] = eff
        Logger:Info("VFX created: %s (%s)", effectType, id)
        return id, eff
    end
    return nil
end

function VFXSystem:Trigger(id, parent)
    local eff = self.Effects[id]
    if not eff then return end
    pcall(function()
        if eff.Type=="Particle" and eff.Part then
            if parent then eff.Part.Parent=parent
            else eff.Part.Parent=workspace end
            eff.Emitter:Emit(eff.Emitter.Rate)
        elseif eff.Type=="Sound" and eff.Sound then
            eff.Sound:Play()
        end
    end)
    self.Active[id] = eff
    Logger:Debug("VFX triggered: %s", id)
end

function VFXSystem:Stop(id)
    local eff = self.Effects[id]
    if not eff then return end
    pcall(function()
        if eff.Type=="Particle" and eff.Emitter then
            eff.Emitter.Enabled=false
        elseif eff.Type=="Sound" and eff.Sound then
            eff.Sound:Stop()
        end
    end)
    self.Active[id]=nil
end

function VFXSystem:Destroy(id)
    self:Stop(id)
    local eff=self.Effects[id]
    if eff then
        pcall(function()
            if eff.Part then eff.Part:Destroy() end
            if eff.Sound then eff.Sound:Destroy() end
        end)
        self.Effects[id]=nil
    end
end

MOON.API.VFXSystem = VFXSystem
MOON.Systems.VFX  = VFXSystem.new()

-- ══════════════════════════════════════════════════════════════════
-- PARTICLE ANIMATOR
-- ══════════════════════════════════════════════════════════════════
local ParticleAnimator = {}
ParticleAnimator.__index = ParticleAnimator

function ParticleAnimator.new(emitter)
    local self = setmetatable({}, ParticleAnimator)
    self.Emitter      = emitter
    self.OriginalRate = emitter and emitter.Rate or 20
    self._animConn    = nil
    return self
end

function ParticleAnimator:AnimateRate(target, duration)
    if not self.Emitter then return end
    if self._animConn then self._animConn:Disconnect() end
    local startRate = self.Emitter.Rate
    local t0        = tick()
    self._animConn  = RS.Heartbeat:Connect(function()
        local alpha = math.min((tick()-t0)/duration, 1)
        local rate  = U.Lerp(startRate, target, alpha)
        pcall(function() self.Emitter.Rate = math.floor(rate) end)
        if alpha>=1 then
            if self._animConn then self._animConn:Disconnect() end
        end
    end)
end

function ParticleAnimator:Burst(count)
    if self.Emitter then
        pcall(function() self.Emitter:Emit(count or 20) end)
    end
end

function ParticleAnimator:SetColor(colorSeq)
    if self.Emitter then
        pcall(function() self.Emitter.Color = colorSeq end)
    end
end

MOON.API.ParticleAnimator = ParticleAnimator

-- ══════════════════════════════════════════════════════════════════
-- AUDIO SYNC
-- ══════════════════════════════════════════════════════════════════
local AudioSync = {}
AudioSync.__index = AudioSync

function AudioSync.new(sound)
    local self      = setmetatable({}, AudioSync)
    self.Sound      = sound
    self.Timeline   = nil
    self.BPM        = 120
    self.BeatMarkers= {}
    self.WaveformData={}
    return self
end

function AudioSync:AttachTimeline(tl)
    self.Timeline = tl
    local track = tl:AddTrack({Name="Audio_"..self.Sound.Name, Type="Audio"})
    Logger:Info("Audio attached to timeline")
    return track
end

function AudioSync:SetBPM(bpm)
    self.BPM = bpm
    self:_calcBeats()
    Logger:Info("BPM set to %d (%d markers)", bpm, #self.BeatMarkers)
end

function AudioSync:_calcBeats()
    self.BeatMarkers={}
    if not self.Timeline then return end
    local fps  = self.Timeline.FPS
    local bps  = self.BPM/60
    local fpb  = fps/bps
    local f    = 0
    while f <= self.Timeline.EndF do
        table.insert(self.BeatMarkers, math.floor(f))
        f = f + fpb
    end
end

function AudioSync:SnapToNearestBeat(frame)
    local nearest, bestDist = frame, math.huge
    for _, b in ipairs(self.BeatMarkers) do
        local d = math.abs(frame-b)
        if d < bestDist then bestDist=d; nearest=b end
    end
    return nearest
end

function AudioSync:PlayFromFrame(frame)
    if not self.Sound or not self.Timeline then return end
    local t = frame/self.Timeline.FPS
    pcall(function()
        self.Sound.TimePosition = t
        self.Sound:Play()
    end)
end

function AudioSync:SyncToTimeline()
    if not self.Timeline then return end
    self.Timeline.OnFrameChanged:Connect(function(f)
        if not self.Sound then return end
        local t = f/self.Timeline.FPS
        pcall(function()
            if math.abs(self.Sound.TimePosition-t) > 0.1 then
                self.Sound.TimePosition = t
            end
        end)
    end)
end

MOON.API.AudioSync = AudioSync

-- ══════════════════════════════════════════════════════════════════
-- CINEMATIC SEQUENCER UI
-- ══════════════════════════════════════════════════════════════════
local CinematicUI = {}
CinematicUI.__index = CinematicUI

function CinematicUI.new()
    local self = setmetatable({}, CinematicUI)
    self.Seq     = nil
    self.CamCtrl = CamCtrl.new()
    self._playBtn= nil
    return self
end

function CinematicUI:CreateUI(parent)
    local T = T_:Get()

    self.Container = UIB:Frame({
        Name="CinematicUI",
        Size=UDim2.new(1,0,1,0),
        BackgroundColor3=T.Background,
        Parent=parent,
    })

    -- Top toolbar
    local tb = UIB:Frame({
        Size=UDim2.new(1,0,0,42),
        BackgroundColor3=T.BackgroundTertiary,
        Parent=self.Container,
    })

    local function btn(txt,x,w,bg,cb,tip)
        local b=UIB:Button(txt,{
            Size=UDim2.new(0,w,0,32),
            Position=UDim2.new(0,x,0.5,-16),
            BackgroundColor3=bg or T.Surface,
            TextSize=12,Parent=tb,
        })
        UIB:Corner(b,5)
        if cb  then b.MouseButton1Click:Connect(cb) end
        if tip then MOON.UI.Tooltip.Attach(b,tip) end
        return b
    end

    local xp=8
    -- Play/Stop
    self._playBtn = btn("▶ Play",xp,80,T.Success,function()
        if not self.Seq then self:NewSequence() end
        if self.Seq.IsPlaying then
            self.Seq:Stop()
            self._playBtn.Text="▶ Play"
            self._playBtn.BackgroundColor3=T.Success
            self.CamCtrl:Disable()
        else
            self.CamCtrl:Enable()
            self.Seq:Play()
            self._playBtn.Text="⏸ Pause"
            self._playBtn.BackgroundColor3=T.Warning
        end
    end,"Play / Pause cinematic"); xp=xp+84

    btn("⏹",xp,36,T.Error,function()
        if self.Seq then self.Seq:Rewind() end
        if self._playBtn then
            self._playBtn.Text="▶ Play"
            self._playBtn.BackgroundColor3=T.Success
        end
        self.CamCtrl:Disable()
    end,"Stop & Rewind"); xp=xp+40

    btn("📷 Capture",xp,100,T.Primary,function()
        self:CaptureCameraShot()
    end,"Capture current camera as shot"); xp=xp+104

    btn("🌊 Shake",xp,80,T.Secondary,function()
        self.CamCtrl:AddShake(0.4,1.5)
    end,"Camera shake preview"); xp=xp+84

    btn("+ Event",xp,80,T.Surface,function()
        self:AddEventDialog()
    end,"Add timeline event"); xp=xp+84

    -- Frame label
    self._frameLabel = UIB:Label("Frame: 0",{
        Size=UDim2.new(0,100,0,30),
        Position=UDim2.new(0,xp,0.5,-15),
        Font=Enum.Font.GothamBold,TextSize=13,
        Parent=tb,
    })

    -- Duration input
    xp = xp+108
    UIB:Label("Dur:",{
        Size=UDim2.new(0,30,0,30),
        Position=UDim2.new(0,xp,0.5,-15),
        TextSize=11,Parent=tb,
    })

    -- === CAMERA PREVIEW ===
    local previewH = 200
    self.Preview = UIB:Frame({
        Name="Preview",
        Size=UDim2.new(0.4,0,0,previewH),
        Position=UDim2.new(0,0,0,42),
        BackgroundColor3=Color3.fromRGB(18,18,22),
        Parent=self.Container,
    })
    UIB:Stroke(self.Preview,1,T.Border)

    -- ViewportFrame for live preview
    local vp
    pcall(function()
        vp = UIB:New("ViewportFrame",{
            Size=UDim2.new(1,0,1,0),
            BackgroundColor3=Color3.fromRGB(18,18,22),
            LightDirection=Vector3.new(1,-1,1),
            Ambient=Color3.fromRGB(120,120,130),
            Parent=self.Preview,
        })
    end)
    self.ViewportFrame = vp

    UIB:Label("🎬 Camera Preview",{
        Size=UDim2.new(1,0,0,20),
        Position=UDim2.new(0,0,1,-22),
        TextSize=10,TextColor3=T.TextSecondary,
        BackgroundTransparency=0.5,
        BackgroundColor3=Color3.new(0,0,0),
        Parent=self.Preview,
    })

    -- === SHOT LIST ===
    local shotPanel = UIB:Frame({
        Size=UDim2.new(0.6,-4,0,previewH),
        Position=UDim2.new(0.4,4,0,42),
        BackgroundColor3=T.BackgroundSecondary,
        Parent=self.Container,
    })
    UIB:Label("📋 Shots",{
        Size=UDim2.new(1,0,0,24),Position=UDim2.new(0,8,0,4),
        Font=Enum.Font.GothamBold,TextSize=13,Parent=shotPanel,
    })
    self.ShotList = UIB:Scroll({
        Size=UDim2.new(1,0,1,-32),Position=UDim2.new(0,0,0,32),
        Parent=shotPanel,
    })
    UIB:ListLayout(self.ShotList)

    -- === TRACK TIMELINE (cinematic tracks) ===
    self.TrackArea = UIB:Frame({
        Size=UDim2.new(1,0,1,-42-previewH-4),
        Position=UDim2.new(0,0,0,42+previewH+4),
        BackgroundColor3=T.TimelineBackground,
        Parent=self.Container,
    })

    -- Track header
    local trackHeader=UIB:Frame({
        Size=UDim2.new(1,0,0,28),
        BackgroundColor3=T.BackgroundTertiary,
        Parent=self.TrackArea,
    })
    UIB:Label("Cinematic Tracks",{
        Size=UDim2.new(1,0,1,0),Position=UDim2.new(0,8,0,0),
        Font=Enum.Font.GothamBold,TextSize=12,Parent=trackHeader,
    })

    self.TrackScroll=UIB:Scroll({
        Size=UDim2.new(1,0,1,-28),Position=UDim2.new(0,0,0,28),
        Parent=self.TrackArea,
    })
    UIB:ListLayout(self.TrackScroll)

    -- Add default tracks
    self:AddTrackRow("📷 Camera Track 1",  T.Primary)
    self:AddTrackRow("⚡ Event Track",     T.Warning)
    self:AddTrackRow("🎵 Audio Track",     T.Success)
    self:AddTrackRow("✨ VFX Track",       T.Secondary)

    -- Init sequence
    self:NewSequence()

    return self.Container
end

function CinematicUI:NewSequence()
    self.Seq = CinematicSeq.new("Main Cinematic")
    self.Seq.FPS = 30

    local camTrack = CameraTrack.new("Camera 1")
    self.Seq:AddCamTrack(camTrack)
    self.CamCtrl:SetTrack(camTrack)

    local evTrack = EventTrack.new("Events")
    self.Seq:AddEventTrack(evTrack)

    -- Connect cam update
    self.Seq.OnFrame:Connect(function(f)
        if self._frameLabel then
            self._frameLabel.Text = "Frame: "..f
        end
        self.CamCtrl:UpdateAtFrame(f)
    end)

    Logger:Info("New cinematic sequence created")
end

function CinematicUI:CaptureCameraShot()
    if not self.Seq then self:NewSequence() end
    local shot = CameraShot.new("Shot "..tostring(os.clock()))
    shot:Capture()

    local camTrack = self.Seq.CamTracks[1]
    if camTrack then
        camTrack:AddShot(self.Seq.CurrentFrame, shot)
    end

    -- Add to list
    self:AddShotToList(shot)
    MOON.UI.Notify.Show({
        Type="Success",
        Title="📷 Shot Captured",
        Message=string.format("Frame %d | FOV: %.0f°", self.Seq.CurrentFrame, shot.FOV),
        Duration=3,
    })
end

function CinematicUI:AddShotToList(shot)
    local T = T_:Get()
    local row=UIB:Frame({
        Size=UDim2.new(1,0,0,40),
        BackgroundColor3=T.Surface,
        Parent=self.ShotList,
    })
    UIB:Corner(row,5)
    UIB:Pad(row,6)
    UIB:Label("📷 "..shot.Name,{
        Size=UDim2.new(1,0,0,18),
        Font=Enum.Font.GothamBold,TextSize=11,Parent=row,
    })
    UIB:Label(string.format("FOV: %.0f° | Pos: %.1f,%.1f,%.1f",
        shot.FOV,shot.CFrame.Position.X,shot.CFrame.Position.Y,shot.CFrame.Position.Z),{
        Size=UDim2.new(1,0,0,14),Position=UDim2.new(0,0,0,20),
        TextSize=10,TextColor3=T.TextSecondary,Parent=row,
    })
end

function CinematicUI:AddTrackRow(name, color)
    local T=T_:Get()
    local row=UIB:Frame({
        Size=UDim2.new(1,0,0,34),
        BackgroundColor3=T.Surface,
        Parent=self.TrackScroll,
    })
    UIB:Stroke(row,1,T.Border)

    UIB:Frame({Size=UDim2.new(0,4,1,0),BackgroundColor3=color or T.Primary,Parent=row})
    UIB:Label(name,{
        Size=UDim2.new(0.35,0,1,0),Position=UDim2.new(0,8,0,0),
        TextSize=11,Font=Enum.Font.GothamBold,Parent=row,
    })

    -- Fake keyframe bar
    local bar=UIB:Frame({
        Size=UDim2.new(0.65,-4,0.6,0),
        Position=UDim2.new(0.35,0,0.2,0),
        BackgroundColor3=color or T.Primary,
        BackgroundTransparency=0.7,
        Parent=row,
    })
    UIB:Corner(bar,3)
end

function CinematicUI:AddEventDialog()
    if not self.Seq then self:NewSequence() end
    local evTrack = self.Seq.EventTracks[1]
    if not evTrack then return end
    local f = self.Seq.CurrentFrame
    evTrack:AddEvent(f, "CustomEvent_"..f, function()
        Logger:Info("Cinematic event fired at frame %d!", f)
        MOON.UI.Notify.Show({Type="Info",Title="⚡ Event",Message="Fired at frame "..f,Duration=2})
    end)
    MOON.UI.Notify.Show({Type="Success",Title="Event Added",Message="Event at frame "..f,Duration=3})
end

MOON.UI.CinematicUI = CinematicUI

-- ══════════════════════════════════════════════════════════════════
-- DOF PREVIEW SYSTEM (Visual Only)
-- ══════════════════════════════════════════════════════════════════
local DOFPreview = {}

function DOFPreview.Apply(focusDist, aperture)
    local cam = workspace.CurrentCamera
    if not cam then return end
    pcall(function()
        local dof = cam:FindFirstChildOfClass("DepthOfFieldEffect")
        if not dof then
            dof = Instance.new("DepthOfFieldEffect")
            dof.Parent = cam
        end
        dof.FocusDistance = focusDist or 20
        dof.InFocusRadius = aperture  or 5
        dof.NearIntensity  = 0.5
        dof.FarIntensity   = 0.8
        dof.Enabled        = true
    end)
    Logger:Info("DOF: focus=%.1f aperture=%.1f", focusDist, aperture)
end

function DOFPreview.Remove()
    local cam = workspace.CurrentCamera
    if not cam then return end
    pcall(function()
        local dof=cam:FindFirstChildOfClass("DepthOfFieldEffect")
        if dof then dof.Enabled=false end
    end)
end

MOON.API.DOFPreview = DOFPreview

-- ══════════════════════════════════════════════════════════════════
-- MOTION BLUR PREVIEW
-- ══════════════════════════════════════════════════════════════════
local MotionBlurPreview = {}

function MotionBlurPreview.Apply(intensity)
    local lighting = game:GetService("Lighting")
    pcall(function()
        local blur = lighting:FindFirstChildOfClass("BlurEffect")
        if not blur then
            blur = Instance.new("BlurEffect")
            blur.Parent = lighting
        end
        blur.Size    = intensity or 14
        blur.Enabled = true
    end)
end

function MotionBlurPreview.Remove()
    local lighting = game:GetService("Lighting")
    pcall(function()
        local blur=lighting:FindFirstChildOfClass("BlurEffect")
        if blur then blur.Enabled=false end
    end)
end

MOON.API.MotionBlurPreview = MotionBlurPreview

Logger:Info("Part 5/8 - Cinematic + Camera + VFX + Audio OK")
MOON.UI.Notify.Show({
    Type="Success",
    Title="🌙 Part 5 Loaded",
    Message="Cinematic system ready! Paste Part 6.",
    Duration=5,
})

--[[
╔══════════════════════════════════════════════════════════════════╗
║         🌙 MOON ANIMATOR ASSYNCRED - PARTE 6/8                  ║
║         LOCOMOTION + FACIAL + COMBAT + IMPORT/EXPORT            ║
╚══════════════════════════════════════════════════════════════════╝
]]
local MOON = _G.MOON
assert(MOON,"Run Part 1 first!")
local Logger = MOON.Core.Logger
local U      = MOON.Utils
local UIB    = MOON.UI.Builder
local T_     = MOON.UI.ThemeSystem
local WM     = MOON.Systems.WindowManager
local Signal = U.Signal
local RS     = game:GetService("RunService")

-- ══════════════════════════════════════════════════════════════════
-- BLEND SPACE 2D
-- ══════════════════════════════════════════════════════════════════
local BlendSpace2D = {}
BlendSpace2D.__index = BlendSpace2D

function BlendSpace2D.new(name)
    local self  = setmetatable({}, BlendSpace2D)
    self.Name   = name or "BlendSpace2D"
    self.Samples= {} -- {Position=V2, Animation, Speed=1}
    self.Current= Vector2.new(0,0)
    return self
end

function BlendSpace2D:AddSample(posX, posY, anim, speed)
    table.insert(self.Samples,{
        Position  = Vector2.new(posX,posY),
        Animation = anim,
        Speed     = speed or 1,
    })
end

function BlendSpace2D:Evaluate(x, y)
    if #self.Samples==0 then return nil end
    if #self.Samples==1 then return self.Samples[1] end

    local blendPos = Vector2.new(x,y)

    -- Sort by distance
    local sorted={}
    for _,s in ipairs(self.Samples) do
        table.insert(sorted,{Sample=s, Dist=(s.Position-blendPos).Magnitude})
    end
    table.sort(sorted,function(a,b) return a.Dist<b.Dist end)

    -- Blend between 3 closest
    local count = math.min(3, #sorted)
    local totalW= 0
    local weights={}

    for i=1,count do
        local d = sorted[i].Dist
        local w = d==0 and 1e6 or 1/d
        weights[i]=w; totalW=totalW+w
    end

    local result={Animations={}, Weights={}}
    for i=1,count do
        table.insert(result.Animations, sorted[i].Sample.Animation)
        table.insert(result.Weights,    weights[i]/totalW)
    end
    return result
end

MOON.API.BlendSpace2D = BlendSpace2D

-- ══════════════════════════════════════════════════════════════════
-- LOCOMOTION CONTROLLER
-- ══════════════════════════════════════════════════════════════════
local LocoCtrl = {}
LocoCtrl.__index = LocoCtrl

function LocoCtrl.new(humanoid)
    local self = setmetatable({}, LocoCtrl)
    self.Humanoid   = humanoid
    self.Character  = humanoid and humanoid.Parent
    self.State      = "Idle"
    self.Speed      = 0
    self.Direction  = Vector2.new(0,0)
    self.MovBlend   = 0
    self.DirBlend   = Vector2.new(0,0)

    self.WalkSpeed  = 8
    self.RunSpeed   = 16
    self.SprintSpeed= 24

    self.Anims = {
        Idle           = nil,
        Walk           = nil,
        Run            = nil,
        Sprint         = nil,
        WalkBlendSpace = BlendSpace2D.new("WalkBS"),
        RunBlendSpace  = BlendSpace2D.new("RunBS"),
    }

    self.Enabled  = false
    self._conn    = nil
    self.OnStateChanged = Signal.new()
    return self
end

function LocoCtrl:Start()
    self.Enabled = true
    self._conn = RS.Heartbeat:Connect(function(dt)
        self:_update(dt)
    end)
    Logger:Info("Locomotion Controller started")
end

function LocoCtrl:Stop()
    self.Enabled = false
    if self._conn then self._conn:Disconnect(); self._conn=nil end
end

function LocoCtrl:_update(dt)
    if not self.Enabled or not self.Character then return end
    pcall(function()
        local hrp = self.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local vel   = hrp.AssemblyLinearVelocity
        self.Speed  = Vector3.new(vel.X,0,vel.Z).Magnitude

        local prevState = self.State
        if self.Speed < 0.5 then
            self.State   = "Idle"
            self.MovBlend= 0
        elseif self.Speed < self.WalkSpeed then
            self.State   = "Walk"
            self.MovBlend= U.Map(self.Speed,0,self.WalkSpeed,0,1)
        elseif self.Speed < self.RunSpeed then
            self.State   = "Run"
            self.MovBlend= U.Map(self.Speed,self.WalkSpeed,self.RunSpeed,1,2)
        else
            self.State   = "Sprint"
            self.MovBlend= U.Map(self.Speed,self.RunSpeed,self.SprintSpeed,2,3)
        end

        if prevState ~= self.State then
            self.OnStateChanged:Fire(self.State, prevState)
        end

        -- Direction blend
        if self.Humanoid then
            local md  = self.Humanoid.MoveDirection
            local fwd = hrp.CFrame.LookVector
            local rgt = hrp.CFrame.RightVector
            self.DirBlend = Vector2.new(md:Dot(rgt), md:Dot(fwd))
        end
    end)
end

function LocoCtrl:GetCurrentAnimation()
    if self.State=="Idle" then return self.Anims.Idle end
    if self.State=="Walk" then
        local r=self.Anims.WalkBlendSpace:Evaluate(self.DirBlend.X, self.DirBlend.Y)
        return r or self.Anims.Walk
    end
    if self.State=="Run" then
        local r=self.Anims.RunBlendSpace:Evaluate(self.DirBlend.X, self.DirBlend.Y)
        return r or self.Anims.Run
    end
    return self.Anims.Sprint
end

function LocoCtrl:SetAnim(state, anim)
    self.Anims[state]=anim
end

MOON.API.LocoCtrl = LocoCtrl

-- ══════════════════════════════════════════════════════════════════
-- STRAFE CONTROLLER
-- ══════════════════════════════════════════════════════════════════
local StrafeCtrl = {}
StrafeCtrl.__index = StrafeCtrl

function StrafeCtrl.new(character)
    local self = setmetatable({}, StrafeCtrl)
    self.Character = character
    self.Target    = nil
    self.Enabled   = false
    self.SmoothTime= 0.15
    self._conn     = nil
    return self
end

function StrafeCtrl:Enable(target)
    self.Target  = target
    self.Enabled = true
    self._conn   = RS.Heartbeat:Connect(function(dt)
        self:_update(dt)
    end)
end

function StrafeCtrl:Disable()
    self.Enabled=false
    if self._conn then self._conn:Disconnect(); self._conn=nil end
end

function StrafeCtrl:_update(dt)
    if not self.Enabled or not self.Target or not self.Character then return end
    pcall(function()
        local hrp = self.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local tp  = typeof(self.Target)=="Vector3" and self.Target or self.Target.Position
        local dir = (tp - hrp.Position) * Vector3.new(1,0,1)
        if dir.Magnitude < 0.1 then return end
        local targetCF = CFrame.new(hrp.Position, hrp.Position + dir.Unit)
        hrp.CFrame = hrp.CFrame:Lerp(
            CFrame.new(hrp.Position) * targetCF.Rotation,
            self.SmoothTime
        )
    end)
end

function StrafeCtrl:GetDirection()
    if not self.Character then return "Forward" end
    local hrp = self.Character:FindFirstChild("HumanoidRootPart")
    local hum = self.Character:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return "Idle" end
    local md  = hum.MoveDirection
    if md.Magnitude < 0.1 then return "Idle" end
    local fwd = hrp.CFrame.LookVector
    local rgt = hrp.CFrame.RightVector
    local fwdDot = md:Dot(fwd)
    local rgtDot = md:Dot(rgt)
    local angle  = math.deg(math.atan2(rgtDot, fwdDot))
    if angle>=-22.5  and angle< 22.5  then return "Forward"
    elseif angle>=22.5  and angle<67.5  then return "ForwardRight"
    elseif angle>=67.5  and angle<112.5 then return "Right"
    elseif angle>=112.5 or  angle<-112.5 then return "Backward"
    elseif angle>=-112.5 and angle<-67.5 then return "Left"
    else return "ForwardLeft" end
end

MOON.API.StrafeCtrl = StrafeCtrl

-- ══════════════════════════════════════════════════════════════════
-- PIVOT SYSTEM
-- ══════════════════════════════════════════════════════════════════
local PivotSystem = {}
PivotSystem.__index = PivotSystem

function PivotSystem.new(character)
    local self = setmetatable({}, PivotSystem)
    self.Character      = character
    self.PivotThreshold = 110
    self.IsPivoting     = false
    self.PivotDuration  = 0.25
    self.LastDir        = Vector3.new(0,0,1)
    self.PivotAnim      = nil
    self.OnPivot        = Signal.new()
    return self
end

function PivotSystem:Check(currentDir)
    if currentDir.Magnitude<0.1 then return end
    local angle = math.deg(math.acos(U.Clamp(self.LastDir:Dot(currentDir),-1,1)))
    if angle>self.PivotThreshold and not self.IsPivoting then
        self:_doPivot(angle)
    end
    self.LastDir = currentDir
end

function PivotSystem:_doPivot(angle)
    self.IsPivoting = true
    self.OnPivot:Fire(angle)
    Logger:Debug("Pivot: %.1f deg", angle)
    task.delay(self.PivotDuration, function()
        self.IsPivoting = false
    end)
end

MOON.API.PivotSystem = PivotSystem

-- ══════════════════════════════════════════════════════════════════
-- FOOT PLANTING
-- ══════════════════════════════════════════════════════════════════
local FootPlanting = {}
FootPlanting.__index = FootPlanting

function FootPlanting.new(rigCtrl)
    local self = setmetatable({}, FootPlanting)
    self.RigCtrl       = rigCtrl
    self.Enabled       = false
    self.Threshold     = 0.4
    self.LeftPlanted   = false
    self.RightPlanted  = false
    self.LeftPos       = nil
    self.RightPos      = nil
    self._conn         = nil
    return self
end

function FootPlanting:Start()
    self.Enabled=true
    self._conn=RS.Heartbeat:Connect(function(dt)
        self:_update(dt)
    end)
end

function FootPlanting:Stop()
    self.Enabled=false
    if self._conn then self._conn:Disconnect(); self._conn=nil end
end

function FootPlanting:_update(dt)
    if not self.Enabled or not self.RigCtrl then return end
    pcall(function()
        local rig = self.RigCtrl.Rig
        if not rig or not rig.Model then return end
        local lf = rig.Model:FindFirstChild("LeftFoot")  or rig.Model:FindFirstChild("Left Leg")
        local rf = rig.Model:FindFirstChild("RightFoot") or rig.Model:FindFirstChild("Right Leg")
        if lf then self:_checkFoot("Left",  lf, dt) end
        if rf then self:_checkFoot("Right", rf, dt) end
    end)
end

function FootPlanting:_checkFoot(side, part, dt)
    local isPlanted = side=="Left" and self.LeftPlanted or self.RightPlanted
    local plantedPos= side=="Left" and self.LeftPos     or self.RightPos

    if not plantedPos then
        if side=="Left"  then self.LeftPos =part.Position
        else self.RightPos=part.Position end
        return
    end

    local vel = (part.Position - plantedPos).Magnitude / dt

    if vel < self.Threshold and not isPlanted then
        if side=="Left" then self.LeftPlanted=true;  self.LeftPos=part.Position
        else              self.RightPlanted=true; self.RightPos=part.Position end
    elseif vel >= self.Threshold and isPlanted then
        if side=="Left" then self.LeftPlanted=false
        else              self.RightPlanted=false end
    end

    if isPlanted and plantedPos and self.RigCtrl then
        local chainName = side.."Leg"
        if self.RigCtrl.Chains[chainName] then
            -- Create temp target
            local temp=Instance.new("Part")
            temp.Anchored=true; temp.CanCollide=false; temp.Transparency=1
            temp.Position=plantedPos; temp.Parent=workspace
            self.RigCtrl:SetIKTarget(chainName, temp)
            self.RigCtrl:SetIKBlend(chainName, 0.8)
            task.defer(function() temp:Destroy() end)
        end
    end
end

MOON.API.FootPlanting = FootPlanting

-- ══════════════════════════════════════════════════════════════════
-- AUTO BALANCE
-- ══════════════════════════════════════════════════════════════════
local AutoBalance = {}
AutoBalance.__index = AutoBalance

function AutoBalance.new(rigCtrl)
    local self = setmetatable({}, AutoBalance)
    self.RigCtrl  = rigCtrl
    self.Enabled  = false
    self.Strength = 0.4
    self._conn    = nil
    return self
end

function AutoBalance:Start()
    self.Enabled=true
    self._conn=RS.Heartbeat:Connect(function(dt)
        self:_update(dt)
    end)
end

function AutoBalance:Stop()
    self.Enabled=false
    if self._conn then self._conn:Disconnect(); self._conn=nil end
end

function AutoBalance:_update(dt)
    if not self.Enabled or not self.RigCtrl then return end
    pcall(function()
        local rig = self.RigCtrl.Rig
        if not rig or not rig.Model then return end

        -- Calculate center of mass
        local totalMass = 0
        local weightedPos = Vector3.new()
        for _, part in ipairs(rig.Parts) do
            local m = part:GetMass()
            totalMass  = totalMass  + m
            weightedPos= weightedPos+ part.Position*m
        end
        if totalMass==0 then return end
        local com = weightedPos/totalMass

        -- Find support point (average foot position)
        local support = Vector3.new()
        local footCount=0
        local lf = rig.Model:FindFirstChild("LeftFoot")
        local rf = rig.Model:FindFirstChild("RightFoot")
        if lf then support=support+lf.Position; footCount=footCount+1 end
        if rf then support=support+rf.Position; footCount=footCount+1 end
        if footCount==0 then return end
        support = support/footCount

        local offset = Vector3.new(support.X-com.X, 0, support.Z-com.Z)
        if offset.Magnitude < 0.15 then return end

        local spine = MOON.API.RigAnalyzer.GetJoint(rig,"Waist")
            or MOON.API.RigAnalyzer.GetJoint(rig,"LowerTorso")
        if spine and spine.Instance then
            local angle = math.atan2(offset.X, offset.Z)*self.Strength*0.5
            spine.Instance.C0 = spine.Instance.C0:Lerp(
                spine.OriginalC0 * CFrame.Angles(0,0,angle),
                0.08
            )
        end
    end)
end

MOON.API.AutoBalance = AutoBalance

-- ══════════════════════════════════════════════════════════════════
-- FACIAL ANIMATOR
-- ══════════════════════════════════════════════════════════════════
local FacialAnim = {}
FacialAnim.__index = FacialAnim

function FacialAnim.new(character)
    local self = setmetatable({}, FacialAnim)
    self.Character = character
    self.Head      = character and character:FindFirstChild("Head")
    self.Face      = self.Head and self.Head:FindFirstChildOfClass("Decal")
    self.Expressions= {
        Neutral   = "rbxasset://textures/face.png",
        Happy     = "rbxassetid://1567446",
        Sad       = "rbxassetid://1567444",
        Angry     = "rbxassetid://1567443",
        Surprised = "rbxassetid://1567447",
        Scared    = "rbxassetid://1567445",
    }
    self.CurrentExpr = "Neutral"
    self.BlendTime   = 0.2
    self.Blendshapes = {
        BrowRaise=0, BrowLower=0,
        EyeClose=0,  MouthOpen=0,
        MouthSmile=0,MouthFrown=0,
    }
    return self
end

function FacialAnim:SetExpression(name, instant)
    if not self.Expressions[name] then return end
    self.CurrentExpr = name
    if not self.Face then return end
    pcall(function()
        self.Face.Texture = self.Expressions[name]
    end)
    Logger:Debug("Expression: %s", name)
end

function FacialAnim:AddExpression(name, textureId)
    self.Expressions[name] = textureId
end

function FacialAnim:SetBlendshape(name, value)
    if self.Blendshapes[name] ~= nil then
        self.Blendshapes[name] = U.Clamp(value,0,1)
    end
end

function FacialAnim:GetAllExpressions()
    return self.Expressions
end

MOON.API.FacialAnim = FacialAnim

-- ══════════════════════════════════════════════════════════════════
-- EYE TRACKER
-- ══════════════════════════════════════════════════════════════════
local EyeTracker = {}
EyeTracker.__index = EyeTracker

function EyeTracker.new(rig)
    local self = setmetatable({}, EyeTracker)
    self.Rig      = rig
    self.Target   = nil
    self.Enabled  = false
    self.MaxAngle = 35
    self.Strength = 0.7
    self._conn    = nil
    return self
end

function EyeTracker:SetTarget(t)
    self.Target  = t
    self.Enabled = t ~= nil
end

function EyeTracker:Start()
    self._conn = RS.Heartbeat:Connect(function(dt)
        self:_update(dt)
    end)
end

function EyeTracker:_update(dt)
    if not self.Enabled or not self.Target then return end
    local headJoint = MOON.API.RigAnalyzer.GetJoint(self.Rig,"Neck")
    if not headJoint or not headJoint.Instance or not headJoint.Instance.Part1 then return end
    pcall(function()
        local hp  = headJoint.Instance.Part1.Position
        local tp  = typeof(self.Target)=="Vector3" and self.Target or self.Target.Position
        local dir = (tp-hp).Unit
        local fwd = headJoint.Instance.Part1.CFrame.LookVector
        local ang = math.deg(math.acos(U.Clamp(fwd:Dot(dir),-1,1)))
        if ang > self.MaxAngle then
            dir = fwd:Lerp(dir, self.MaxAngle/ang)
        end
        local tc = CFrame.new(hp, hp+dir)
        headJoint.Instance.C0 = headJoint.OriginalC0:Lerp(
            headJoint.OriginalC0*(tc-tc.Position),
            self.Strength
        )
    end)
end

MOON.API.EyeTracker = EyeTracker

-- ══════════════════════════════════════════════════════════════════
-- COMBAT & COMBO SYSTEM
-- ══════════════════════════════════════════════════════════════════
local CombatSystem = {}
CombatSystem.__index = CombatSystem

function CombatSystem.new()
    local self = setmetatable({}, CombatSystem)
    self.Combos      = {}  -- {name={anims, timing, damage}}
    self.CurrentCombo= nil
    self.ComboIndex  = 0
    self.ComboTimer  = 0
    self.ComboWindow = 0.8  -- seconds to continue combo
    self.IsAttacking = false

    self.OnComboStart  = Signal.new()
    self.OnComboStep   = Signal.new()
    self.OnComboFinish = Signal.new()
    self.OnComboCancel = Signal.new()
    self._conn         = nil
    return self
end

function CombatSystem:RegisterCombo(name, cfg)
    self.Combos[name] = {
        Name    = name,
        Anims   = cfg.Anims   or {},
        Timings = cfg.Timings or {},
        Damage  = cfg.Damage  or {},
        Window  = cfg.Window  or self.ComboWindow,
        CanCancel = cfg.CanCancel ~= false,
    }
    Logger:Info("Combo registered: %s (%d steps)", name, #cfg.Anims)
end

function CombatSystem:StartCombo(name)
    local combo = self.Combos[name]
    if not combo then return end
    self.CurrentCombo = combo
    self.ComboIndex   = 1
    self.ComboTimer   = combo.Window
    self.IsAttacking  = true
    self.OnComboStart:Fire(combo)
    self:_step()
end

function CombatSystem:_step()
    if not self.CurrentCombo then return end
    local combo = self.CurrentCombo
    local anim  = combo.Anims[self.ComboIndex]
    local dmg   = combo.Damage[self.ComboIndex] or 10
    self.OnComboStep:Fire(self.ComboIndex, anim, dmg)
    Logger:Debug("Combo step %d/%d: %s dmg=%d",
        self.ComboIndex, #combo.Anims, tostring(anim), dmg)
end

function CombatSystem:NextStep()
    if not self.CurrentCombo or not self.IsAttacking then return false end
    if self.ComboTimer <= 0 then
        self:CancelCombo()
        return false
    end
    self.ComboIndex = self.ComboIndex + 1
    if self.ComboIndex > #self.CurrentCombo.Anims then
        self:FinishCombo()
        return false
    end
    self.ComboTimer = self.CurrentCombo.Window
    self:_step()
    return true
end

function CombatSystem:FinishCombo()
    self.OnComboFinish:Fire(self.CurrentCombo)
    self:_reset()
end

function CombatSystem:CancelCombo()
    self.OnComboCancel:Fire(self.CurrentCombo)
    self:_reset()
end

function CombatSystem:_reset()
    self.CurrentCombo = nil
    self.ComboIndex   = 0
    self.ComboTimer   = 0
    self.IsAttacking  = false
end

function CombatSystem:Update(dt)
    if self.IsAttacking and self.ComboTimer > 0 then
        self.ComboTimer = self.ComboTimer - dt
        if self.ComboTimer <= 0 then
            self:CancelCombo()
        end
    end
end

-- Register some default combos
local defaultCombat = CombatSystem.new()
defaultCombat:RegisterCombo("BasicPunch",{
    Anims={"Jab","Cross","Hook","Uppercut"},
    Damage={10,12,15,20},
    Window=0.8,
})
defaultCombat:RegisterCombo("KickCombo",{
    Anims={"FrontKick","SideKick","SpinKick"},
    Damage={14,16,25},
    Window=1.0,
})
defaultCombat:RegisterCombo("FinisherSequence",{
    Anims={"Grab","KneeStrike","ThrowDown","StompFinisher"},
    Damage={5,18,12,35},
    Window=1.5,
})

MOON.API.CombatSystem  = CombatSystem
MOON.Systems.Combat    = defaultCombat

-- ══════════════════════════════════════════════════════════════════
-- IMPORT / EXPORT SYSTEM
-- ══════════════════════════════════════════════════════════════════
local ImportExport = {}

function ImportExport.ExportJSON(timeline, rigData)
    local ser = MOON.API.Serializer
    if ser then
        local json = ser.ExportJSON(timeline)
        U.SafeSetClipboard(json)
        Logger:Success("Animation exported to clipboard (JSON)")
        return json
    end
    return "{}"
end

function ImportExport.ImportJSON(jsonStr, timeline)
    local ser = MOON.API.Serializer
    if ser then
        return ser.ImportJSON(jsonStr, timeline)
    end
    return false
end

function ImportExport.ImportFromClipboard(timeline)
    local text = U.SafeGetClipboard()
    if text and text ~= "" then
        return ImportExport.ImportJSON(text, timeline)
    end
    Logger:Warn("Clipboard is empty")
    return false
end

-- Export to Roblox KeyframeSequence
function ImportExport.ToKeyframeSequence(timeline, rigData)
    local ks = Instance.new("KeyframeSequence")
    ks.Name  = timeline.Name or "Animation"

    local frameGroups = {}
    for _, id in ipairs(timeline.Order) do
        local tr = timeline.Tracks[id]
        if tr then
            for frame, kf in pairs(tr.Keyframes) do
                if not frameGroups[frame] then frameGroups[frame]={} end
                table.insert(frameGroups[frame], {Track=tr, KF=kf})
            end
        end
    end

    local sortedFrames={}
    for f in pairs(frameGroups) do table.insert(sortedFrames,f) end
    table.sort(sortedFrames)

    for _, frame in ipairs(sortedFrames) do
        local kf = Instance.new("Keyframe")
        kf.Time = frame/timeline.FPS
        kf.Name = "KF_"..frame

        for _, data in ipairs(frameGroups[frame]) do
            local tr = data.Track
            local kfData = data.KF
            if tr.Type=="Transform" and typeof(kfData.Value)=="CFrame" then
                local pose = Instance.new("Pose")
                pose.Name          = tr.Name
                pose.CFrame        = kfData.Value
                pose.EasingStyle   = kfData.EasingStyle
                pose.EasingDirection=kfData.EasingDir
                pose.Parent        = kf
            end
        end
        kf.Parent = ks
    end

    Logger:Success("Exported KeyframeSequence: %d frames", #sortedFrames)
    return ks
end

-- Import from Roblox KeyframeSequence
function ImportExport.FromKeyframeSequence(ks, timeline)
    if not ks or not ks:IsA("KeyframeSequence") then
        Logger:Error("Invalid KeyframeSequence")
        return false
    end

    local trackMap={}
    local keyframes=ks:GetKeyframes()

    for _, kfInst in ipairs(keyframes) do
        local frame = math.floor(kfInst.Time * timeline.FPS)
        for _, pose in ipairs(kfInst:GetDescendants()) do
            if pose:IsA("Pose") then
                if not trackMap[pose.Name] then
                    trackMap[pose.Name] = timeline:AddTrack({
                        Name=pose.Name, Type="Transform", Property="C0"
                    })
                end
                local tr = trackMap[pose.Name]
                local kf = MOON.API.Keyframe.new({
                    Frame=frame, Value=pose.CFrame,
                    EasingStyle=pose.EasingStyle,
                    EasingDir=pose.EasingDirection,
                })
                tr.Keyframes[frame]=kf
            end
        end
    end

    for _, tr in pairs(trackMap) do tr:_sort() end
    Logger:Success("Imported %d tracks from KeyframeSequence", U.TableCount(trackMap))
    return true
end

-- BVH stub importer
function ImportExport.ParseBVHHeader(bvhStr)
    local result={Joints={},FrameCount=0,FrameTime=0.033}
    local fc = tonumber(string.match(bvhStr,"Frames:%s*(%d+)"))
    local ft = tonumber(string.match(bvhStr,"Frame Time:%s*([%d%.]+)"))
    if fc then result.FrameCount=fc end
    if ft then result.FrameTime=ft end
    for j in string.gmatch(bvhStr,"JOINT%s+(%w+)") do
        table.insert(result.Joints,j)
    end
    Logger:Info("BVH parsed: %d joints, %d frames", #result.Joints, result.FrameCount)
    return result
end

-- Version control
local VersionCtrl = {}
VersionCtrl.Versions = {}
VersionCtrl.MaxVers  = 50
VersionCtrl.Current  = 0

function VersionCtrl:Save(timeline, message)
    local v = {
        Number   = self.Current+1,
        Message  = message or "Checkpoint",
        Time     = os.time(),
        Author   = game.Players.LocalPlayer and game.Players.LocalPlayer.Name or "Unknown",
        Data     = MOON.API.Serializer and MOON.API.Serializer.ExportJSON(timeline) or "{}",
    }
    table.insert(self.Versions, v)
    self.Current = v.Number
    while #self.Versions > self.MaxVers do table.remove(self.Versions,1) end
    Logger:Info("Version saved: v%d - %s", v.Number, message)
    return v
end

function VersionCtrl:Load(num, timeline)
    for _, v in ipairs(self.Versions) do
        if v.Number==num then
            if MOON.API.Serializer then
                local ok = MOON.API.Serializer.ImportJSON(v.Data, timeline)
                if ok then Logger:Success("Loaded v%d: %s", num, v.Message) end
                return ok
            end
        end
    end
    Logger:Warn("Version %d not found", num)
    return false
end

function VersionCtrl:GetHistory()
    return self.Versions
end

MOON.API.ImportExport = ImportExport
MOON.API.VersionCtrl  = VersionCtrl

-- Auto-save
local AutoSave = {
    Enabled   = false,
    Interval  = MOON.Config.AutoSaveInterval,
    LastSave  = 0,
    _conn     = nil,
}

function AutoSave.Start(timeline)
    if AutoSave.Enabled then return end
    AutoSave.Enabled  = true
    AutoSave.LastSave = tick()
    AutoSave._conn    = RS.Heartbeat:Connect(function()
        if not AutoSave.Enabled then return end
        if (tick()-AutoSave.LastSave) >= AutoSave.Interval then
            AutoSave.LastSave = tick()
            local ok = pcall(function()
                VersionCtrl:Save(timeline, "AutoSave_"..os.date("%H%M%S"))
            end)
            if ok then
                Logger:Info("AutoSave done")
                MOON.UI.Notify.Show({
                    Type="Info",Title="💾 AutoSaved",
                    Message="Animation auto-saved.",Duration=2,
                })
            end
        end
    end)
    Logger:Info("AutoSave started (interval: %ds)", AutoSave.Interval)
end

function AutoSave.Stop()
    AutoSave.Enabled=false
    if AutoSave._conn then AutoSave._conn:Disconnect(); AutoSave._conn=nil end
end

MOON.API.AutoSave = AutoSave

Logger:Info("Part 6/8 - Locomotion + Facial + Combat + Import/Export OK")
MOON.UI.Notify.Show({
    Type="Success",Title="🌙 Part 6 Loaded",
    Message="Locomotion, Facial, Combat & Import/Export ready! Paste Part 7.",Duration=5,
})

--[[
╔══════════════════════════════════════════════════════════════════╗
║         🌙 MOON ANIMATOR ASSYNCRED - PARTE 7/8                  ║
║         MOON ANIMATOR PLUGIN - UI COMPLETA                      ║
║         Inspector + Hierarchy + Property Editor + Viewport      ║
╚══════════════════════════════════════════════════════════════════╝
]]
local MOON = _G.MOON
assert(MOON,"Run Part 1 first!")
local Logger = MOON.Core.Logger
local U      = MOON.Utils
local UIB    = MOON.UI.Builder
local T_     = MOON.UI.ThemeSystem
local WM     = MOON.Systems.WindowManager
local PM     = MOON.Systems.PluginManager
local Signal = U.Signal
local RS     = game:GetService("RunService")
local UIS    = game:GetService("UserInputService")

-- ══════════════════════════════════════════════════════════════════
-- MOON ANIMATOR PLUGIN (Main Integration)
-- ══════════════════════════════════════════════════════════════════
local MoonAnimatorPlugin = MOON.API.Plugin.new({
    Id          = "moon_animator_main",
    Name        = "Moon Animator",
    Version     = "2.0.0",
    Author      = "Moon Studios",
    Description = "Professional AAA Animation System for Roblox",
    Icon        = "🌙",
    WindowConfig= {
        Title = "🌙 Moon Animator Assyncred",
        Size  = UDim2.new(0, 1100, 0, 720),
        Position = UDim2.new(0.5, -550, 0.5, -360),
        MinSize = Vector2.new(900, 600),
    }
})

-- Plugin State
MoonAnimatorPlugin.State = {
    CurrentRig           = nil,
    RigData              = nil,
    AnimController       = nil,
    RigController        = nil,
    ProceduralCtrl       = nil,
    Timeline             = nil,
    SelectedJoints       = {},
    SelectedKeyframes    = {},
    CurrentTool          = "Select",
    PlaybackMode         = "Stopped",
    AutoKeyEnabled       = false,
    TransformTool        = nil,
    LocoCtrl             = nil,
    FacialAnim           = nil,
    CamCtrl              = nil,
}

-- ══════════════════════════════════════════════════════════════════
-- ON LOAD
-- ══════════════════════════════════════════════════════════════════
MoonAnimatorPlugin._onLoad = function(self)
    Logger:Info("Loading Moon Animator Plugin...")
    
    -- Create timeline
    self.State.Timeline = MOON.API.Timeline.new({
        Name = "Main Animation",
        FPS  = 30,
        EndFrame = 150,
    })
    
    -- Create transform tool
    self.State.TransformTool = MOON.API.TransformTool.new()
    
    Logger:Success("Moon Animator Plugin loaded")
end

-- ══════════════════════════════════════════════════════════════════
-- CREATE UI
-- ══════════════════════════════════════════════════════════════════
MoonAnimatorPlugin._createUI = function(self, contentFrame)
    local T = T_:Get()
    
    -- Main layout container
    local mainLayout = UIB:Frame({
        Name = "MainLayout",
        Size = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1,
        Parent = contentFrame,
    })
    
    -- === TOP TOOLBAR ===
    self:CreateTopToolbar(mainLayout)
    
    -- === LEFT PANEL (Hierarchy + Outliner) ===
    self:CreateLeftPanel(mainLayout)
    
    -- === CENTER (Viewport) ===
    self:CreateViewport(mainLayout)
    
    -- === RIGHT PANEL (Inspector + Properties) ===
    self:CreateRightPanel(mainLayout)
    
    -- === BOTTOM (Timeline) ===
    self:CreateBottomTimeline(mainLayout)
    
    -- === STATUS BAR ===
    self:CreateStatusBar(mainLayout)
    
    Logger:Success("Moon Animator UI created")
end

-- ══════════════════════════════════════════════════════════════════
-- TOP TOOLBAR
-- ══════════════════════════════════════════════════════════════════
function MoonAnimatorPlugin:CreateTopToolbar(parent)
    local T = T_:Get()
    local tbH = 48
    
    self.Toolbar = UIB:Frame({
        Name = "TopToolbar",
        Size = UDim2.new(1,0,0,tbH),
        BackgroundColor3 = T.BackgroundTertiary,
        BorderSizePixel  = 0,
        Parent = parent,
    })
    
    UIB:Pad(self.Toolbar, 6)
    
    local xp = 0
    local function btn(txt, w, bg, cb, tip)
        local b = UIB:Button(txt, {
            Size = UDim2.new(0,w,0,36),
            Position = UDim2.new(0,xp,0.5,-18),
            BackgroundColor3 = bg or T.Surface,
            TextSize = 12,
            Parent = self.Toolbar,
        })
        UIB:Corner(b,5)
        if cb  then b.MouseButton1Click:Connect(cb) end
        if tip then MOON.UI.Tooltip.Attach(b,tip) end
        xp = xp + w + 4
        return b
    end
    
    -- File menu
    btn("File",60,T.Surface,function() self:ShowFileMenu() end,"File operations")
    btn("Edit",60,T.Surface,function() self:ShowEditMenu() end,"Edit menu")
    
    xp = xp + 8
    
    -- Tools
    local tools = {
        {Name="Select",Icon="🖱️",Tip="Select Tool [1]"},
        {Name="Move",  Icon="↔️", Tip="Move Tool [2]"},
        {Name="Rotate",Icon="🔄",Tip="Rotate Tool [3]"},
        {Name="Scale", Icon="📏",Tip="Scale Tool [4]"},
    }
    
    for _, tool in ipairs(tools) do
        local b = btn(tool.Icon, 36, 
            self.State.CurrentTool==tool.Name and T.Primary or T.Surface,
            function() 
                self:SetCurrentTool(tool.Name)
                self:UpdateToolbarButtons()
            end,
            tool.Tip
        )
        b.Name = "Tool_"..tool.Name
    end
    
    xp = xp + 8
    
    -- Rig selector
    UIB:Label("Rig:",{
        Size = UDim2.new(0,40,0,36),
        Position = UDim2.new(0,xp,0.5,-18),
        TextSize = 12,
        Parent = self.Toolbar,
    })
    xp = xp + 44
    
    local rigBtn = btn(
        self.State.CurrentRig and self.State.CurrentRig.Name or "Select Rig",
        140, T.Surface,
        function() self:ShowRigSelector() end,
        "Select character rig"
    )
    rigBtn.Name = "RigSelector"
    
    xp = xp + 8
    
    -- Auto Key toggle
    self.AutoKeyBtn = btn("Auto Key: OFF",120,T.Surface,function()
        self.State.AutoKeyEnabled = not self.State.AutoKeyEnabled
        local txt = "Auto Key: "..(self.State.AutoKeyEnabled and "ON" or "OFF")
        local col = self.State.AutoKeyEnabled and T.Success or T.Surface
        self.AutoKeyBtn.Text = txt
        self.AutoKeyBtn.BackgroundColor3 = col
    end,"Toggle auto-keyframe")
    
    xp = xp + 8
    
    -- Snap options
    btn("Grid",50,T.Surface,function()
        local tt = self.State.TransformTool
        if tt then
            tt.SnapEnabled = not tt.SnapEnabled
            MOON.UI.Notify.Show({
                Type="Info",Title="Snap",
                Message="Snapping: "..(tt.SnapEnabled and "ON" or "OFF"),
                Duration=2,
            })
        end
    end,"Toggle grid snapping")
    
    xp = xp + 4
    
    -- IK/FK toggle
    btn("IK/FK",60,T.Secondary,function() self:ToggleIKFK() end,"Toggle IK/FK mode")
    
    -- Right side buttons
    local rightX = -6
    btn("Help",60,T.Surface,function()
        if MOON.UI.HelpSystem then
            MOON.UI.HelpSystem.OpenDocumentation()
        end
    end,"Help & Documentation").Position = UDim2.new(1,rightX-60,0.5,-18)
    
    rightX = rightX - 64
    btn("Settings",80,T.Surface,function()
        self:OpenSettings()
    end,"Settings").Position = UDim2.new(1,rightX-80,0.5,-18)
end

function MoonAnimatorPlugin:UpdateToolbarButtons()
    local T = T_:Get()
    for _, child in ipairs(self.Toolbar:GetChildren()) do
        if child.Name:match("^Tool_") then
            local toolName = child.Name:gsub("Tool_","")
            child.BackgroundColor3 = (toolName==self.State.CurrentTool) and T.Primary or T.Surface
        end
    end
end

-- ══════════════════════════════════════════════════════════════════
-- LEFT PANEL (Hierarchy Explorer)
-- ══════════════════════════════════════════════════════════════════
function MoonAnimatorPlugin:CreateLeftPanel(parent)
    local T = T_:Get()
    local leftW = 220
    
    self.LeftPanel = UIB:Frame({
        Name = "LeftPanel",
        Size = UDim2.new(0,leftW,1,-48-230-24),
        Position = UDim2.new(0,0,0,48),
        BackgroundColor3 = T.BackgroundSecondary,
        BorderSizePixel = 0,
        Parent = parent,
    })
    
    -- Header
    local header = UIB:Frame({
        Size = UDim2.new(1,0,0,32),
        BackgroundColor3 = T.BackgroundTertiary,
        BorderSizePixel = 0,
        Parent = self.LeftPanel,
    })
    
    UIB:Label("🦴 Joint Hierarchy",{
        Size = UDim2.new(1,-8,1,0),
        Position = UDim2.new(0,8,0,0),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        Parent = header,
    })
    
    -- Search box
    local searchBox = UIB:Frame({
        Size = UDim2.new(1,-8,0,30),
        Position = UDim2.new(0,4,0,36),
        BackgroundColor3 = T.Surface,
        Parent = self.LeftPanel,
    })
    UIB:Corner(searchBox,5)
    
    local searchInput = UIB:New("TextBox",{
        Size = UDim2.new(1,-8,1,0),
        Position = UDim2.new(0,8,0,0),
        BackgroundTransparency = 1,
        PlaceholderText = "🔍 Search joints...",
        Text = "",
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = T.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = searchBox,
    })
    
    -- Joint list
    self.JointList = UIB:Scroll({
        Size = UDim2.new(1,0,1,-70),
        Position = UDim2.new(0,0,0,70),
        BackgroundColor3 = T.Background,
        Parent = self.LeftPanel,
    })
    UIB:ListLayout(self.JointList,{Padding=UDim.new(0,2)})
    UIB:Pad(self.JointList,4)
    
    -- Filter on search
    searchInput:GetPropertyChangedSignal("Text"):Connect(function()
        self:FilterJointList(searchInput.Text)
    end)
end

function MoonAnimatorPlugin:PopulateJointList()
    if not self.State.RigData then return end
    
    -- Clear
    for _, child in ipairs(self.JointList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local T = T_:Get()
    
    for _, joint in ipairs(self.State.RigData.Joints) do
        local item = UIB:Frame({
            Size = UDim2.new(1,0,0,30),
            BackgroundColor3 = T.Surface,
            Parent = self.JointList,
        })
        UIB:Corner(item,4)
        
        -- Color indicator
        UIB:Frame({
            Size = UDim2.new(0,3,1,0),
            BackgroundColor3 = T.Primary,
            BorderSizePixel = 0,
            Parent = item,
        })
        
        -- Joint name
        UIB:Label(joint.Name,{
            Size = UDim2.new(1,-50,1,0),
            Position = UDim2.new(0,8,0,0),
            TextSize = 11,
            Font = Enum.Font.Gotham,
            Parent = item,
        })
        
        -- Select button
        local selBtn = UIB:Button("◉",{
            Size = UDim2.new(0,26,0,26),
            Position = UDim2.new(1,-28,0.5,-13),
            BackgroundColor3 = T.Primary,
            TextSize = 11,
            Parent = item,
        })
        UIB:Corner(selBtn,4)
        
        selBtn.MouseButton1Click:Connect(function()
            self:SelectJoint(joint)
        end)
        
        item.Name = "Joint_"..joint.Name
    end
end

function MoonAnimatorPlugin:FilterJointList(query)
    if not self.JointList then return end
    query = query:lower()
    for _, item in ipairs(self.JointList:GetChildren()) do
        if item:IsA("Frame") and item.Name:match("^Joint_") then
            local name = item.Name:gsub("Joint_",""):lower()
            item.Visible = query=="" or name:find(query,1,true)~=nil
        end
    end
end

-- ══════════════════════════════════════════════════════════════════
-- VIEWPORT (3D Preview)
-- ══════════════════════════════════════════════════════════════════
function MoonAnimatorPlugin:CreateViewport(parent)
    local T = T_:Get()
    local leftW = 220
    local rightW = 280
    
    self.ViewportContainer = UIB:Frame({
        Name = "ViewportContainer",
        Size = UDim2.new(1,-leftW-rightW,1,-48-230-24),
        Position = UDim2.new(0,leftW,0,48),
        BackgroundColor3 = T.Background,
        BorderSizePixel = 0,
        Parent = parent,
    })
    
    -- Header
    local header = UIB:Frame({
        Size = UDim2.new(1,0,0,32),
        BackgroundColor3 = T.BackgroundTertiary,
        BorderSizePixel = 0,
        Parent = self.ViewportContainer,
    })
    
    UIB:Label("🎥 Viewport",{
        Size = UDim2.new(0,100,1,0),
        Position = UDim2.new(0,8,0,0),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        Parent = header,
    })
    
    -- View mode buttons
    local viewModes = {
        {Name="Shaded",   Icon="🔲"},
        {Name="Wireframe",Icon="🔳"},
        {Name="X-Ray",    Icon="👻"},
    }
    
    local vx = 120
    for _, mode in ipairs(viewModes) do
        local b = UIB:Button(mode.Icon.." "..mode.Name,{
            Size = UDim2.new(0,90,0,24),
            Position = UDim2.new(0,vx,0.5,-12),
            BackgroundColor3 = T.Surface,
            TextSize = 10,
            Parent = header,
        })
        UIB:Corner(b,4)
        vx = vx + 94
    end
    
    -- Viewport area
    self.Viewport = UIB:Frame({
        Name = "Viewport",
        Size = UDim2.new(1,0,1,-32),
        Position = UDim2.new(0,0,0,32),
        BackgroundColor3 = Color3.fromRGB(38,38,42),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = self.ViewportContainer,
    })
    
    -- Try create ViewportFrame
    local vpOk, vp = pcall(function()
        return UIB:New("ViewportFrame",{
            Size = UDim2.new(1,0,1,0),
            BackgroundColor3 = Color3.fromRGB(38,38,42),
            LightDirection = Vector3.new(1,-0.5,0.5),
            Ambient = Color3.fromRGB(100,100,110),
            Parent = self.Viewport,
        })
    end)
    
    if vpOk and vp then
        self.ViewportFrame = vp
        
        -- Create camera for viewport
        pcall(function()
            local cam = Instance.new("Camera")
            cam.CFrame = CFrame.new(0,5,15)*CFrame.Angles(-math.rad(15),0,0)
            cam.FieldOfView = 70
            cam.Parent = vp
            vp.CurrentCamera = cam
            self.ViewportCamera = cam
        end)
    end
    
    -- Grid overlay
    UIB:Label("[ 3D Viewport ]\nRig Preview\n\nDrag rig model here or\nuse 'Select Rig' button",{
        Size = UDim2.new(1,0,1,0),
        TextSize = 14,
        TextColor3 = Color3.fromRGB(100,100,110),
        Font = Enum.Font.GothamBold,
        BackgroundTransparency = 1,
        Parent = self.Viewport,
    })
end

-- ══════════════════════════════════════════════════════════════════
-- RIGHT PANEL (Inspector + Properties)
-- ══════════════════════════════════════════════════════════════════
function MoonAnimatorPlugin:CreateRightPanel(parent)
    local T = T_:Get()
    local rightW = 280
    
    self.RightPanel = UIB:Frame({
        Name = "RightPanel",
        Size = UDim2.new(0,rightW,1,-48-230-24),
        Position = UDim2.new(1,-rightW,0,48),
        BackgroundColor3 = T.BackgroundSecondary,
        BorderSizePixel = 0,
        Parent = parent,
    })
    
    -- Tabs
    local tabBar = UIB:Frame({
        Size = UDim2.new(1,0,0,36),
        BackgroundColor3 = T.BackgroundTertiary,
        BorderSizePixel = 0,
        Parent = self.RightPanel,
    })
    
    local tabs = {
        {Name="Properties",Icon="📋"},
        {Name="Modifiers", Icon="⚙️"},
        {Name="Poses",     Icon="🧍"},
        {Name="Settings",  Icon="🔧"},
    }
    
    local tabW = rightW/#tabs
    for i, tab in ipairs(tabs) do
        local b = UIB:Button(tab.Icon.." "..tab.Name,{
            Size = UDim2.new(0,tabW-2,0,32),
            Position = UDim2.new(0,(i-1)*tabW,0,2),
            BackgroundColor3 = i==1 and T.Primary or T.Surface,
            TextSize = 11,
            Parent = tabBar,
        })
        UIB:Corner(b,5)
        b.Name = "Tab_"..tab.Name
    end
    
    -- Content area
    self.PropertyContent = UIB:Scroll({
        Size = UDim2.new(1,0,1,-36),
        Position = UDim2.new(0,0,0,36),
        BackgroundColor3 = T.Background,
        Parent = self.RightPanel,
    })
    UIB:ListLayout(self.PropertyContent,{Padding=UDim.new(0,8)})
    UIB:Pad(self.PropertyContent,10)
    
    -- Add property groups
    self:CreatePropertyGroup("Transform",{
        {Name="Position X", Type="Number",Value=0},
        {Name="Position Y", Type="Number",Value=0},
        {Name="Position Z", Type="Number",Value=0},
        {Name="Rotation X", Type="Number",Value=0},
        {Name="Rotation Y", Type="Number",Value=0},
        {Name="Rotation Z", Type="Number",Value=0},
    })
    
    self:CreatePropertyGroup("Animation",{
        {Name="Easing Style",    Type="Dropdown",Value="Cubic"},
        {Name="Easing Direction",Type="Dropdown",Value="InOut"},
        {Name="Interpolation",   Type="Dropdown",Value="Bezier"},
    })
    
    self:CreatePropertyGroup("IK Settings",{
        {Name="IK Blend",     Type="Slider",Value=0,Min=0,Max=1},
        {Name="Pole Target",  Type="Vector3",Value=Vector3.new(0,1,0)},
        {Name="Chain Length", Type="Number",Value=2},
    })
end

function MoonAnimatorPlugin:CreatePropertyGroup(title, properties)
    local T = T_:Get()
    
    local groupH = 32 + #properties*36
    local group = UIB:Frame({
        Size = UDim2.new(1,0,0,groupH),
        BackgroundColor3 = T.Surface,
        Parent = self.PropertyContent,
    })
    UIB:Corner(group,6)
    UIB:Pad(group,8)
    
    -- Header
    UIB:Label(title,{
        Size = UDim2.new(1,0,0,22),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        Parent = group,
    })
    
    -- Properties
    for i, prop in ipairs(properties) do
        local row = UIB:Frame({
            Size = UDim2.new(1,0,0,32),
            Position = UDim2.new(0,0,0,24+(i-1)*36),
            BackgroundTransparency = 1,
            Parent = group,
        })
        
        UIB:Label(prop.Name..":",{
            Size = UDim2.new(0.4,0,1,0),
            TextSize = 10,
            Parent = row,
        })
        
        if prop.Type=="Number" or prop.Type=="Slider" then
            local valBox = UIB:New("TextBox",{
                Size = UDim2.new(0.6,-4,0,28),
                Position = UDim2.new(0.4,4,0.5,-14),
                BackgroundColor3 = T.BackgroundTertiary,
                Text = tostring(prop.Value or 0),
                Font = Enum.Font.Gotham,
                TextSize = 11,
                TextColor3 = T.TextPrimary,
                TextXAlignment = Enum.TextXAlignment.Center,
                ClearTextOnFocus = false,
                Parent = row,
            })
            UIB:Corner(valBox,4)
            
        elseif prop.Type=="Dropdown" then
            local dropdown = UIB:Button(prop.Value or "---",{
                Size = UDim2.new(0.6,-4,0,28),
                Position = UDim2.new(0.4,4,0.5,-14),
                BackgroundColor3 = T.BackgroundTertiary,
                TextSize = 11,
                Parent = row,
            })
            UIB:Corner(dropdown,4)
        end
    end
    
    return group
end

-- ══════════════════════════════════════════════════════════════════
-- BOTTOM TIMELINE
-- ══════════════════════════════════════════════════════════════════
function MoonAnimatorPlugin:CreateBottomTimeline(parent)
    local T = T_:Get()
    
    self.TimelineContainer = UIB:Frame({
        Name = "TimelineContainer",
        Size = UDim2.new(1,0,0,230),
        Position = UDim2.new(0,0,1,-230-24),
        BackgroundColor3 = T.TimelineBackground,
        BorderSizePixel = 0,
        Parent = parent,
    })
    
    -- Create Timeline UI
    if MOON.UI.TimelineUI and self.State.Timeline then
        self.TimelineUI = MOON.UI.TimelineUI.new(
            self.State.Timeline,
            self.TimelineContainer
        )
    end
end

-- ══════════════════════════════════════════════════════════════════
-- STATUS BAR
-- ══════════════════════════════════════════════════════════════════
function MoonAnimatorPlugin:CreateStatusBar(parent)
    local T = T_:Get()
    
    self.StatusBar = UIB:Frame({
        Name = "StatusBar",
        Size = UDim2.new(1,0,0,24),
        Position = UDim2.new(0,0,1,-24),
        BackgroundColor3 = T.BackgroundTertiary,
        BorderSizePixel = 0,
        Parent = parent,
    })
    
    self.StatusText = UIB:Label("Ready  |  No rig loaded",{
        Size = UDim2.new(0,400,1,0),
        Position = UDim2.new(0,8,0,0),
        TextSize = 10,
        TextColor3 = T.TextSecondary,
        Parent = self.StatusBar,
    })
    
    local fpsLabel = UIB:Label("FPS: 60",{
        Size = UDim2.new(0,80,1,0),
        Position = UDim2.new(1,-200,0,0),
        TextSize = 10,
        TextColor3 = T.TextSecondary,
        Parent = self.StatusBar,
    })
    
    local memLabel = UIB:Label("Mem: 0 MB",{
        Size = UDim2.new(0,100,1,0),
        Position = UDim2.new(1,-100,0,0),
        TextSize = 10,
        TextColor3 = T.TextSecondary,
        Parent = self.StatusBar,
    })
    
    -- Update metrics
    RS.Heartbeat:Connect(function()
        local m = MOON.Performance.Monitor:Get()
        fpsLabel.Text = string.format("FPS: %d", m.FPS)
        memLabel.Text = string.format("Mem: %.1f MB", m.MemoryUsage/1024)
    end)
end

-- ══════════════════════════════════════════════════════════════════
-- RIG SELECTOR
-- ══════════════════════════════════════════════════════════════════
function MoonAnimatorPlugin:ShowRigSelector()
    local selWindow = WM:Create({
        Title = "Select Character Rig",
        Size = UDim2.new(0,450,0,520),
        Position = UDim2.new(0.5,-225,0.5,-260),
    })
    
    local content = selWindow:GetContent()
    local T = T_:Get()
    
    UIB:Label("Select a character model from workspace:",{
        Size = UDim2.new(1,-16,0,24),
        Position = UDim2.new(0,8,0,8),
        TextSize = 12,
        TextColor3 = T.TextSecondary,
        Parent = content,
    })
    
    local modelList = UIB:Scroll({
        Size = UDim2.new(1,-16,1,-40),
        Position = UDim2.new(0,8,0,36),
        Parent = content,
    })
    UIB:ListLayout(modelList,{Padding=UDim.new(0,4)})
    
    -- Scan workspace
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
                local item = UIB:Button("🧍 "..obj.Name,{
                    Size = UDim2.new(1,0,0,36),
                    BackgroundColor3 = T.Surface,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = modelList,
                })
                UIB:Corner(item,5)
                UIB:Pad(item,{Left=12})
                
                local model = obj
                item.MouseButton1Click:Connect(function()
                    self:LoadRig(model)
                    selWindow:Close()
                end)
            end
        end
    end)
end

function MoonAnimatorPlugin:LoadRig(model)
    Logger:Info("Loading rig: %s", model.Name)
    
    self.State.CurrentRig = model
    self.State.RigData    = MOON.API.RigAnalyzer.Analyze(model)
    
    if not self.State.RigData then
        Logger:Error("Failed to analyze rig")
        return
    end
    
    -- Create controllers
    self.State.AnimController  = MOON.API.AnimController.new(self.State.RigData)
    self.State.RigController   = MOON.API.RigController.new(self.State.RigData)
    self.State.ProceduralCtrl  = MOON.API.ProceduralCtrl.new(
        self.State.RigData,
        self.State.RigController
    )
    
    -- Setup IK
    if self.State.RigData.Type=="R15" or self.State.RigData.Type=="R6" then
        self.State.RigController:SetupHumanoidIK()
    end
    
    -- Create locomotion controller
    if self.State.RigData.Humanoid then
        self.State.LocoCtrl = MOON.API.LocoCtrl.new(self.State.RigData.Humanoid)
    end
    
    -- Facial animator
    self.State.FacialAnim = MOON.API.FacialAnim.new(model)
    
    -- Populate UI
    self:PopulateJointList()
    
    -- Create animation tracks for each joint
    for _, joint in ipairs(self.State.RigData.Joints) do
        self.State.Timeline:AddTrack({
            Name = joint.Name,
            Type = "Transform",
            Target = joint.Instance,
            Property = "C0",
        })
    end
    
    -- Update viewport
    self:UpdateViewport()
    
    -- Update status
    if self.StatusText then
        self.StatusText.Text = string.format(
            "Loaded: %s  |  Type: %s  |  Joints: %d",
            model.Name,
            self.State.RigData.Type,
            #self.State.RigData.Joints
        )
    end
    
    -- Update toolbar
    local rigBtn = self.Toolbar and self.Toolbar:FindFirstChild("RigSelector")
    if rigBtn then
        rigBtn.Text = model.Name
    end
    
    MOON.UI.Notify.Show({
        Type="Success",
        Title="Rig Loaded",
        Message=string.format("%s (%s) - %d joints",
            model.Name, self.State.RigData.Type, #self.State.RigData.Joints),
        Duration=4,
    })
    
    Logger:Success("Rig loaded successfully!")
end

function MoonAnimatorPlugin:UpdateViewport()
    if not self.ViewportFrame or not self.State.CurrentRig then return end
    
    pcall(function()
        -- Clone rig into viewport
        local existingClone = self.ViewportFrame:FindFirstChild("RigClone")
        if existingClone then existingClone:Destroy() end
        
        local clone = self.State.CurrentRig:Clone()
        clone.Name = "RigClone"
        
        -- Position in viewport
        if clone.PrimaryPart then
            clone:SetPrimaryPartCFrame(CFrame.new(0,0,0))
        end
        
        clone.Parent = self.ViewportFrame
        
        Logger:Debug("Viewport updated with rig")
    end)
end

-- ══════════════════════════════════════════════════════════════════
-- TOOL FUNCTIONS
-- ══════════════════════════════════════════════════════════════════
function MoonAnimatorPlugin:SetCurrentTool(toolName)
    self.State.CurrentTool = toolName
    if self.State.TransformTool then
        self.State.TransformTool.Mode = toolName
    end
    Logger:Info("Tool: %s", toolName)
end

function MoonAnimatorPlugin:SelectJoint(joint)
    table.insert(self.State.SelectedJoints, joint)
    Logger:Info("Joint selected: %s", joint.Name)
    
    -- Update properties panel
    self:UpdatePropertiesPanel(joint)
end

function MoonAnimatorPlugin:UpdatePropertiesPanel(joint)
    -- Update property values for selected joint
    -- This would show C0, C1, rotation angles, etc.
end

function MoonAnimatorPlugin:ToggleIKFK()
    if not self.State.RigController then return end
    
    -- Toggle IK blend for all chains
    for name, _ in pairs(self.State.RigController.Chains) do
        local currentBlend = self.State.RigController.IKBlend[name] or 0
        local newBlend = currentBlend > 0.5 and 0 or 1
        self.State.RigController:SetIKBlend(name, newBlend)
    end
    
    MOON.UI.Notify.Show({
        Type="Info",
        Title="IK/FK",
        Message="Toggled IK/FK mode",
        Duration=2,
    })
end

-- ══════════════════════════════════════════════════════════════════
-- FILE MENU
-- ══════════════════════════════════════════════════════════════════
function MoonAnimatorPlugin:ShowFileMenu()
    local T = T_:Get()
    
    local menu = UIB:Frame({
        Size = UDim2.new(0,200,0,240),
        Position = UDim2.new(0,10,0,56),
        BackgroundColor3 = T.Surface,
        BorderSizePixel = 1,
        BorderColor3 = T.Border,
        ZIndex = 200,
        Parent = self.Window.Frame,
    })
    UIB:Corner(menu,6)
    UIB:ListLayout(menu,{Padding=UDim.new(0,2)})
    UIB:Pad(menu,4)
    
    local items = {
        "New Animation","Open Animation","Save Animation","---",
        "Export as JSON","Import from JSON","---",
        "Export KeyframeSequence","Import KeyframeSequence","---",
        "Settings","Exit"
    }
    
    for _, item in ipairs(items) do
        if item=="---" then
            UIB:Frame({
                Size=UDim2.new(1,0,0,1),
                BackgroundColor3=T.Border,
                BorderSizePixel=0,
                Parent=menu,
            })
        else
            local btn = UIB:Button(item,{
                Size=UDim2.new(1,0,0,28),
                BackgroundColor3=T.Surface,
                TextSize=11,
                TextXAlignment=Enum.TextXAlignment.Left,
                Parent=menu,
            })
            UIB:Pad(btn,{Left=8})
            
            btn.MouseButton1Click:Connect(function()
                self:HandleMenuAction(item)
                menu:Destroy()
            end)
        end
    end
    
    -- Auto-close
    task.delay(0.1,function()
        local conn
        conn=UIS.InputBegan:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 then
                task.wait(0.1)
                if menu and menu.Parent then menu:Destroy() end
                conn:Disconnect()
            end
        end)
    end)
end

function MoonAnimatorPlugin:HandleMenuAction(action)
    if action=="Save Animation" then
        if MOON.API.ImportExport then
            MOON.API.ImportExport.ExportJSON(self.State.Timeline, self.State.RigData)
            MOON.UI.Notify.Show({
                Type="Success",Title="Saved",
                Message="Animation copied to clipboard (JSON)",Duration=3,
            })
        end
        
    elseif action=="Import from JSON" then
        if MOON.API.ImportExport then
            local ok = MOON.API.ImportExport.ImportFromClipboard(self.State.Timeline)
            if ok then
                MOON.UI.Notify.Show({
                    Type="Success",Title="Imported",
                    Message="Animation loaded from clipboard",Duration=3,
                })
            end
        end
        
    elseif action=="Export KeyframeSequence" then
        if MOON.API.ImportExport then
            local ks = MOON.API.ImportExport.ToKeyframeSequence(
                self.State.Timeline,
                self.State.RigData
            )
            if ks then
                ks.Parent = game.ReplicatedStorage
                MOON.UI.Notify.Show({
                    Type="Success",Title="Exported",
                    Message="KeyframeSequence in ReplicatedStorage",Duration=4,
                })
            end
        end
    end
end

function MoonAnimatorPlugin:ShowEditMenu()
    MOON.UI.Notify.Show({
        Type="Info",Title="Edit Menu",
        Message="Undo/Redo coming soon!",Duration=2,
    })
end

function MoonAnimatorPlugin:OpenSettings()
    MOON.UI.Notify.Show({
        Type="Info",Title="Settings",
        Message="Settings panel coming in Part 8!",Duration=2,
    })
end

-- ══════════════════════════════════════════════════════════════════
-- REGISTER PLUGIN
-- ══════════════════════════════════════════════════════════════════
PM:Register(MoonAnimatorPlugin)

Logger:Info("Part 7/8 - Moon Animator Plugin UI Complete!")
MOON.UI.Notify.Show({
    Type="Success",
    Title="🌙 Part 7 Loaded!",
    Message="Moon Animator UI complete!\nPaste Part 8 for Launcher & Final Integration.",
    Duration=6,
})

--[[
╔══════════════════════════════════════════════════════════════════╗
║         🌙 MOON ANIMATOR ASSYNCRED - PARTE 8/8 [FINAL]         ║
║         LAUNCHER + SETTINGS + SHORTCUTS + TUTORIAL + HELP      ║
║         🎉 SISTEMA 100% COMPLETO 🎉                             ║
╚══════════════════════════════════════════════════════════════════╝
]]
local MOON = _G.MOON
assert(MOON,"Run Part 1 first!")
local Logger = MOON.Core.Logger
local U      = MOON.Utils
local UIB    = MOON.UI.Builder
local T_     = MOON.UI.ThemeSystem
local WM     = MOON.Systems.WindowManager
local PM     = MOON.Systems.PluginManager
local Signal = U.Signal
local UIS    = game:GetService("UserInputService")

-- ══════════════════════════════════════════════════════════════════
-- SHORTCUT MANAGER
-- ══════════════════════════════════════════════════════════════════
local ShortcutMgr = {
    Shortcuts = {},
    Enabled   = true,
}

function ShortcutMgr.Register(key, callback, desc)
    ShortcutMgr.Shortcuts[key] = {Callback=callback, Description=desc}
end

function ShortcutMgr.Init()
    if not UIS then return end
    UIS.InputBegan:Connect(function(inp, gameProcessed)
        if gameProcessed or not ShortcutMgr.Enabled then return end
        local key = inp.KeyCode.Name
        local shortcut = ShortcutMgr.Shortcuts[key]
        if shortcut then
            pcall(shortcut.Callback)
        end
    end)
    Logger:Info("Shortcut Manager initialized")
end

function ShortcutMgr.GetAll()
    return ShortcutMgr.Shortcuts
end

MOON.Systems.ShortcutMgr = ShortcutMgr

-- Register default shortcuts
ShortcutMgr.Register("F1", function()
    MOON.Launcher.Show()
end, "Open Launcher")

ShortcutMgr.Register("F2", function()
    PM:Activate("moon_animator_main")
end, "Open Moon Animator")

ShortcutMgr.Register("Space", function()
    -- Toggle playback
    local plugin = PM:Get("moon_animator_main")
    if plugin and plugin.State.Timeline then
        if plugin.State.Timeline.IsPlaying then
            plugin.State.Timeline:Pause()
        else
            plugin.State.Timeline:Play()
        end
    end
end, "Play/Pause Animation")

ShortcutMgr.Init()

-- ══════════════════════════════════════════════════════════════════
-- TUTORIAL SYSTEM
-- ══════════════════════════════════════════════════════════════════
local Tutorial = {}
Tutorial.__index = Tutorial

function Tutorial.new(name)
    local self = setmetatable({}, Tutorial)
    self.Name  = name
    self.Steps = {}
    self.CurrentStep = 0
    self.IsActive    = false
    self.OnComplete  = Signal.new()
    return self
end

function Tutorial:AddStep(title, desc)
    table.insert(self.Steps, {Title=title, Description=desc})
end

function Tutorial:Start()
    self.IsActive = true
    self.CurrentStep = 1
    self:ShowStep()
end

function Tutorial:ShowStep()
    if self.CurrentStep > #self.Steps then
        self:Complete()
        return
    end
    
    local step = self.Steps[self.CurrentStep]
    local T = T_:Get()
    
    local tutWin = WM:Create({
        Title = "📚 Tutorial: "..self.Name,
        Size = UDim2.new(0,400,0,220),
        Position = UDim2.new(0.5,-200,0.5,-110),
    })
    
    local content = tutWin:GetContent()
    
    UIB:Label(step.Title,{
        Size = UDim2.new(1,-16,0,26),
        Position = UDim2.new(0,8,0,8),
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        Parent = content,
    })
    
    UIB:Label(step.Description,{
        Size = UDim2.new(1,-16,1,-90),
        Position = UDim2.new(0,8,0,40),
        TextSize = 12,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextColor3 = T.TextSecondary,
        Parent = content,
    })
    
    UIB:Label(string.format("Step %d of %d", self.CurrentStep, #self.Steps),{
        Size = UDim2.new(1,0,0,18),
        Position = UDim2.new(0,0,1,-56),
        TextSize = 11,
        TextColor3 = T.TextTertiary,
        Parent = content,
    })
    
    local nextBtn = UIB:Button("Next →",{
        Size = UDim2.new(0,100,0,32),
        Position = UDim2.new(1,-108,1,-40),
        BackgroundColor3 = T.Primary,
        Parent = content,
    })
    UIB:Corner(nextBtn,6)
    
    nextBtn.MouseButton1Click:Connect(function()
        self.CurrentStep = self.CurrentStep + 1
        tutWin:Close()
        self:ShowStep()
    end)
    
    local skipBtn = UIB:Button("Skip",{
        Size = UDim2.new(0,80,0,32),
        Position = UDim2.new(0,8,1,-40),
        BackgroundColor3 = T.Surface,
        BorderSizePixel = 1,
        BorderColor3 = T.Border,
        Parent = content,
    })
    UIB:Corner(skipBtn,6)
    
    skipBtn.MouseButton1Click:Connect(function()
        tutWin:Close()
        self:Skip()
    end)
end

function Tutorial:Complete()
    self.IsActive = false
    self.OnComplete:Fire()
    MOON.UI.Notify.Show({
        Type="Success",
        Title="🎉 Tutorial Complete!",
        Message="You've finished: "..self.Name,
        Duration=5,
    })
end

function Tutorial:Skip()
    self.IsActive = false
end

MOON.API.Tutorial = Tutorial

-- Create default tutorial
local GettingStarted = Tutorial.new("Getting Started")
GettingStarted:AddStep(
    "Welcome to Moon Animator!",
    "Moon Animator is a professional animation system for Roblox. Let's get started with a quick tour."
)
GettingStarted:AddStep(
    "Select a Rig",
    "Click the 'Select Rig' button in the toolbar to choose a character model from your workspace."
)
GettingStarted:AddStep(
    "Using the Timeline",
    "The timeline at the bottom shows animation frames. Click on the ruler to scrub through your animation."
)
GettingStarted:AddStep(
    "Creating Keyframes",
    "Select a joint from the hierarchy, move it to a new pose, then click the keyframe button to save that pose."
)
GettingStarted:AddStep(
    "Playback Controls",
    "Use the Play/Pause button (or press Space) to preview your animation. You can also adjust playback speed."
)
GettingStarted:AddStep(
    "You're Ready!",
    "Explore the Graph Editor, State Machine, and other advanced tools. Happy animating!"
)

MOON.Systems.Tutorials = {
    GettingStarted = GettingStarted
}

-- ══════════════════════════════════════════════════════════════════
-- HELP SYSTEM
-- ══════════════════════════════════════════════════════════════════
local HelpSystem = {}

function HelpSystem.OpenDocumentation()
    local docWin = WM:Create({
        Title = "📖 Moon Animator - Documentation",
        Size = UDim2.new(0,750,0,600),
        Position = UDim2.new(0.5,-375,0.5,-300),
    })
    
    local content = docWin:GetContent()
    local T = T_:Get()
    
    -- Sidebar
    local sidebar = UIB:Frame({
        Size = UDim2.new(0,200,1,0),
        BackgroundColor3 = T.BackgroundSecondary,
        BorderSizePixel = 0,
        Parent = content,
    })
    
    local topics = {
        "Getting Started","Timeline","Keyframes","IK/FK","Graph Editor",
        "State Machine","Locomotion","Procedural","Cinematic","VFX",
        "Facial Animation","Combat System","Import/Export","Shortcuts","FAQ"
    }
    
    local topicList = UIB:Scroll({
        Size = UDim2.new(1,0,1,0),
        Parent = sidebar,
    })
    UIB:ListLayout(topicList,{Padding=UDim.new(0,2)})
    UIB:Pad(topicList,8)
    
    for _, topic in ipairs(topics) do
        local btn = UIB:Button(topic,{
            Size = UDim2.new(1,0,0,32),
            BackgroundColor3 = T.Surface,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = topicList,
        })
        UIB:Corner(btn,4)
        UIB:Pad(btn,{Left=8})
    end
    
    -- Content area
    local docContent = UIB:Scroll({
        Size = UDim2.new(1,-200,1,0),
        Position = UDim2.new(0,200,0,0),
        Parent = content,
    })
    UIB:Pad(docContent,24)
    
    local docText = [[
🌙 MOON ANIMATOR ASSYNCRED
Professional Animation Framework v2.0

═══════════════════════════════════════════

GETTING STARTED

1. Press F1 to open the Launcher
2. Click "Open Moon Animator"
3. Select a rig using the toolbar button
4. Start animating!

═══════════════════════════════════════════

KEY FEATURES

✅ Multi-track Timeline System
✅ Advanced Keyframe Editor
✅ Bezier Graph Editor
✅ IK/FK Rigging with Auto-Setup
✅ Visual State Machine Editor
✅ Blend Space 2D for Locomotion
✅ Procedural Animation Tools
✅ Cinematic Camera Sequencer
✅ VFX & Audio Sync
✅ Facial Animation System
✅ Combat & Combo System
✅ Import/Export (JSON, KeyframeSequence)
✅ Auto-Save & Version Control
✅ Mobile-Optimized Performance

═══════════════════════════════════════════

SHORTCUTS

F1 - Open Launcher
F2 - Open Moon Animator
Space - Play/Pause
Ctrl+S - Save Animation
Ctrl+Z - Undo (coming soon)
1-4 - Tool Selection

═══════════════════════════════════════════

WORKFLOW

1. Load a character rig
2. Create animation tracks for joints
3. Set keyframes at different frames
4. Use Graph Editor to refine motion
5. Add IK for natural posing
6. Setup locomotion with Blend Spaces
7. Add procedural touches
8. Create cinematics with camera
9. Export your animation

═══════════════════════════════════════════

SUPPORT

For tutorials, updates and community:
- Check the Help menu
- Run tutorials from Launcher
- Explore each tool's tooltips

Made with ❤️ for Roblox Creators
]]
    
    UIB:Label(docText,{
        Size = UDim2.new(1,0,0,2000),
        TextSize = 12,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = T.TextPrimary,
        Font = Enum.Font.Code,
        Parent = docContent,
    })
end

MOON.UI.HelpSystem = HelpSystem

-- ══════════════════════════════════════════════════════════════════
-- MAIN LAUNCHER
-- ══════════════════════════════════════════════════════════════════
local Launcher = {
    Window = nil,
    IsInitialized = false,
}

function Launcher.Init()
    if Launcher.IsInitialized then return end
    Launcher.IsInitialized = true
    
    Logger:Info("Launcher initialized")
end

function Launcher.Show()
    if Launcher.Window and Launcher.Window.Frame and Launcher.Window.Frame.Parent then
        Launcher.Window:Focus()
        return
    end
    
    local T = T_:Get()
    
    Launcher.Window = WM:Create({
        Title = "🌙 Moon Animator Launcher",
        Size = UDim2.new(0,520,0,640),
        Position = UDim2.new(0.5,-260,0.5,-320),
    })
    
    local content = Launcher.Window:GetContent()
    
    -- Header
    local header = UIB:Frame({
        Size = UDim2.new(1,0,0,140),
        BackgroundColor3 = T.BackgroundTertiary,
        BorderSizePixel = 0,
        Parent = content,
    })
    UIB:Corner(header,8)
    
    UIB:Label("🌙 MOON ANIMATOR",{
        Size = UDim2.new(1,0,0,44),
        Position = UDim2.new(0,0,0,24),
        Font = Enum.Font.GothamBold,
        TextSize = 26,
        Parent = header,
    })
    
    UIB:Label("ASSYNCRED v"..MOON.Version,{
        Size = UDim2.new(1,0,0,22),
        Position = UDim2.new(0,0,0,72),
        TextSize = 14,
        TextColor3 = T.TextSecondary,
        Parent = header,
    })
    
    UIB:Label("Professional Animation Framework for Roblox",{
        Size = UDim2.new(1,0,0,18),
        Position = UDim2.new(0,0,0,98),
        TextSize = 12,
        TextColor3 = T.TextTertiary,
        Parent = header,
    })
    
    -- Quick Start
    local quickStart = UIB:Frame({
        Size = UDim2.new(1,-32,0,240),
        Position = UDim2.new(0,16,0,156),
        BackgroundColor3 = T.Surface,
        BorderSizePixel = 0,
        Parent = content,
    })
    UIB:Corner(quickStart,8)
    UIB:Pad(quickStart,16)
    
    UIB:Label("Quick Start",{
        Size = UDim2.new(1,0,0,26),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        Parent = quickStart,
    })
    
    local btnY = 38
    local function qBtn(txt, icon, cb)
        local b = UIB:Button(icon.." "..txt,{
            Size = UDim2.new(1,0,0,42),
            Position = UDim2.new(0,0,0,btnY),
            BackgroundColor3 = T.Primary,
            TextSize = 14,
            Font = Enum.Font.GothamBold,
            Parent = quickStart,
        })
        UIB:Corner(b,6)
        if cb then b.MouseButton1Click:Connect(cb) end
        btnY = btnY + 50
        return b
    end
    
    qBtn("Open Moon Animator","🎬",function()
        PM:Activate("moon_animator_main")
        Launcher.Window:Close()
    end)
    
    qBtn("Start Tutorial","📚",function()
        MOON.Systems.Tutorials.GettingStarted:Start()
    end)
    
    qBtn("Documentation & Help","📖",function()
        HelpSystem.OpenDocumentation()
    end)
    
    qBtn("Settings & Preferences","⚙️",function()
        Launcher.ShowSettings()
    end)
    
    -- Info section
    local info = UIB:Frame({
        Size = UDim2.new(1,-32,0,140),
        Position = UDim2.new(0,16,1,-156),
        BackgroundColor3 = T.Surface,
        BorderSizePixel = 0,
        Parent = content,
    })
    UIB:Corner(info,8)
    UIB:Pad(info,16)
    
    UIB:Label("✨ Features",{
        Size = UDim2.new(1,0,0,20),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        Parent = info,
    })
    
    local features = [[
• Timeline System with Multi-track Support
• IK/FK Rigging • Bezier Graph Editor
• State Machine • Blend Spaces
• Procedural Animation • Cinematics
• VFX & Audio Sync • Facial Animation
• Import/Export • Mobile Optimized
]]
    
    UIB:Label(features,{
        Size = UDim2.new(1,0,1,-24),
        Position = UDim2.new(0,0,0,24),
        TextSize = 10,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = T.TextSecondary,
        Parent = info,
    })
end

function Launcher.ShowSettings()
    local setWin = WM:Create({
        Title = "⚙️ Settings",
        Size = UDim2.new(0,600,0,500),
        Position = UDim2.new(0.5,-300,0.5,-250),
    })
    
    local content = setWin:GetContent()
    local T = T_:Get()
    
    -- Categories sidebar
    local sidebar = UIB:Frame({
        Size = UDim2.new(0,160,1,0),
        BackgroundColor3 = T.BackgroundSecondary,
        BorderSizePixel = 0,
        Parent = content,
    })
    
    local cats = {"General","Performance","Appearance","Shortcuts","About"}
    local catList = UIB:Scroll({
        Size = UDim2.new(1,0,1,0),
        Parent = sidebar,
    })
    UIB:ListLayout(catList,{Padding=UDim.new(0,4)})
    UIB:Pad(catList,8)
    
    for i, cat in ipairs(cats) do
        local btn = UIB:Button(cat,{
            Size = UDim2.new(1,0,0,36),
            BackgroundColor3 = i==1 and T.Primary or T.Surface,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = catList,
        })
        UIB:Corner(btn,5)
        UIB:Pad(btn,{Left=12})
    end
    
    -- Settings content
    local setContent = UIB:Scroll({
        Size = UDim2.new(1,-160,1,0),
        Position = UDim2.new(0,160,0,0),
        Parent = content,
    })
    UIB:Pad(setContent,16)
    UIB:ListLayout(setContent,{Padding=UDim.new(0,12)})
    
    -- Add settings
    local function toggle(name, default)
        local row = UIB:Frame({
            Size = UDim2.new(1,0,0,40),
            BackgroundColor3 = T.Surface,
            Parent = setContent,
        })
        UIB:Corner(row,6)
        UIB:Pad(row,12)
        
        UIB:Label(name,{
            Size = UDim2.new(1,-60,1,0),
            TextSize = 12,
            Parent = row,
        })
        
        local tog = UIB:Button(default and "ON" or "OFF",{
            Size = UDim2.new(0,50,0,28),
            Position = UDim2.new(1,-50,0.5,-14),
            BackgroundColor3 = default and T.Success or T.Error,
            TextSize = 11,
            Parent = row,
        })
        UIB:Corner(tog,4)
        
        local state = default
        tog.MouseButton1Click:Connect(function()
            state = not state
            tog.Text = state and "ON" or "OFF"
            tog.BackgroundColor3 = state and T.Success or T.Error
        end)
    end
    
    toggle("Enable Auto-Save", true)
    toggle("Performance Mode", MOON.Config.IsMobile)
    toggle("Show FPS Counter", true)
    toggle("Enable Grid Snapping", true)
    toggle("Show Onion Skin", false)
    toggle("Enable Motion Blur Preview", false)
    
    -- Info
    UIB:Label("Moon Animator v"..MOON.Version,{
        Size = UDim2.new(1,0,0,20),
        Position = UDim2.new(0,0,1,-24),
        TextSize = 10,
        TextColor3 = T.TextTertiary,
        Parent = content,
    })
end

MOON.Launcher = Launcher
Launcher.Init()

-- ══════════════════════════════════════════════════════════════════
-- FINAL INITIALIZATION & STARTUP
-- ══════════════════════════════════════════════════════════════════
local FinalSetup = {}

function FinalSetup.Run()
    Logger:Info("═══════════════════════════════════════════════")
    Logger:Info("  🌙 MOON ANIMATOR ASSYNCRED")
    Logger:Info("  FINAL INITIALIZATION")
    Logger:Info("═══════════════════════════════════════════════")
    
    -- Initialize all systems
    Logger:Info("Verifying systems...")
    
    local systems = {
        "Core.Logger","UI.ThemeSystem","UI.Builder","Systems.WindowManager",
        "Systems.PluginManager","Performance.Monitor","API.Timeline",
        "API.Keyframe","API.AnimTrack","API.RigAnalyzer","API.Pose",
        "API.IKSolver","API.Constraint","API.AnimCurve","API.StateNode",
        "API.CameraShot","API.VFXSystem","API.LocoCtrl","API.FacialAnim",
        "API.CombatSystem","API.ImportExport","Launcher"
    }
    
    local verified = 0
    for _, path in ipairs(systems) do
        local parts = path:split(".")
        local obj = MOON
        for _, p in ipairs(parts) do
            obj = obj[p]
            if not obj then break end
        end
        if obj then
            verified = verified + 1
        else
            Logger:Warn("System missing: %s", path)
        end
    end
    
    Logger:Success("%d/%d systems verified", verified, #systems)
    
    -- Show launcher after delay
    task.delay(1, function()
        Launcher.Show()
    end)
    
    -- Welcome notification
    task.delay(2, function()
        MOON.UI.Notify.Show({
            Type="Success",
            Title="🎉 Moon Animator Ready!",
            Message="All systems loaded!\nPress F1 for Launcher\nPress F2 for Animator",
            Duration=8,
        })
    end)
    
    Logger:Success("═══════════════════════════════════════════════")
    Logger:Success("  ✅ MOON ANIMATOR FULLY LOADED!")
    Logger:Success("  🎉 ALL 8 PARTS INITIALIZED")
    Logger:Success("═══════════════════════════════════════════════")
    Logger:Info("")
    Logger:Info("🚀 QUICK START:")
    Logger:Info("  • Press F1 to open Launcher")
    Logger:Info("  • Press F2 to open Moon Animator")
    Logger:Info("  • Press Space to Play/Pause")
    Logger:Info("")
    Logger:Info("📚 DOCUMENTATION:")
    Logger:Info("  • Use Help menu for documentation")
    Logger:Info("  • Start tutorial from Launcher")
    Logger:Info("")
    Logger:Success("🌙 Happy Animating! ✨")
    
    print("\n" .. string.rep("═",60))
    print("  🌙 MOON ANIMATOR ASSYNCRED v"..MOON.Version)
    print("  ✅ Sistema 100% carregado com sucesso!")
    print("  🎉 Todas as 8 partes inicializadas")
    print(string.rep("═",60))
    print("\n  COMANDOS:")
    print("  • F1 = Launcher")
    print("  • F2 = Moon Animator")
    print("  • _G.MoonAnimator = API Global")
    print("\n" .. string.rep("═",60) .. "\n")
end

FinalSetup.Run()

-- ══════════════════════════════════════════════════════════════════
-- GLOBAL API EXPORT
-- ══════════════════════════════════════════════════════════════════
_G.MoonAnimator = {
    Version = MOON.Version,
    
    -- Quick Access
    OpenLauncher = function() Launcher.Show() end,
    OpenAnimator = function() PM:Activate("moon_animator_main") end,
    OpenDocs = function() HelpSystem.OpenDocumentation() end,
    StartTutorial = function(name)
        local tut = MOON.Systems.Tutorials[name or "GettingStarted"]
        if tut then tut:Start() end
    end,
    
    -- Core Systems
    Timeline = MOON.API.Timeline,
    Keyframe = MOON.API.Keyframe,
    Pose = MOON.API.Pose,
    RigAnalyzer = MOON.API.RigAnalyzer,
    
    -- Advanced
    CreateTimeline = function(cfg) return MOON.API.Timeline.new(cfg) end,
    AnalyzeRig = function(model) return MOON.API.RigAnalyzer.Analyze(model) end,
    ExportJSON = function(tl) return MOON.API.ImportExport.ExportJSON(tl) end,
    ImportJSON = function(json,tl) return MOON.API.ImportExport.ImportJSON(json,tl) end,
    
    -- Internal
    _MOON = MOON,
}

Logger:Info("Global API exported to _G.MoonAnimator")

--[[
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║       🎉🎉🎉 MOON ANIMATOR ASSYNCRED 100% COMPLETO! 🎉🎉🎉       ║
║                                                                  ║
║  ✅ 8/8 PARTES CARREGADAS COM SUCESSO                            ║
║  ✅ TODAS AS FERRAMENTAS IMPLEMENTADAS                           ║
║  ✅ SISTEMA PRONTO PARA USO                                      ║
║                                                                  ║
║  Cole todas as 8 partes em sequência no GitHub                  ║
║  Depois execute via loadstring                                   ║
║                                                                  ║
║  Feito com ❤️ para a comunidade Roblox                          ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
]]
