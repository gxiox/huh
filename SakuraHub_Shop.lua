--// ============================================================
--//  SAKURA HUB  |  SHOP  (UI + ร้านค้า + ใส่โค้ดปุ่มเดียว)
--//  วางใน autoexec เพื่อให้รันต่อหลังวาป
--//  - ธีมอนิเมะโทนอุ่น: ครีม / ทองอำพัน / ชมพูซากุระ
--//  - พื้นหลังขยับ: กลีบซากุระร่วง + แสงลอย + ภาพพื้นหลัง (ใส่รูปเองได้)
--//  - มี: Toggle / Slider / Dropdown (เดี่ยว+หลายตัวเลือก) / Button
--//        TextBox / Keybind / Status / Config + สล็อตเซฟ + Export/Import
--// ============================================================

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local StatsService = game:GetService("Stats")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local GuiParent = PlayerGui
pcall(function()
    if gethui then
        GuiParent = gethui()
    end
end)

--==================================================
-- FONT  (Nunito = กลมๆ น่ารัก; ถ้าโหลดไม่ได้จะใช้ฟอนต์เริ่มต้น)
--==================================================
local function MakeFont(weight)
    local ok, f = pcall(function()
        return Font.new("rbxasset://fonts/families/Nunito.json", weight, Enum.FontStyle.Normal)
    end)
    return ok and f or nil
end
local FNT = {
    R = MakeFont(Enum.FontWeight.Regular),
    M = MakeFont(Enum.FontWeight.SemiBold),
    B = MakeFont(Enum.FontWeight.Bold),
    X = MakeFont(Enum.FontWeight.ExtraBold),
}
local function SetFont(obj, f)
    if f then
        pcall(function()
            obj.FontFace = f
        end)
    end
end

-- เสียงตอนกดเปิด/ปิด (เปลี่ยนเป็น "rbxassetid://เลข" ได้)
local SOUND_ON = "rbxasset://sounds/switch.wav"
local SOUND_OFF = "rbxasset://sounds/button.wav"

--==================================================
-- CONFIG  (Auto Save / Auto Load)
--==================================================
local CONFIG_FILE = "SakuraHubShop_Config.json"
local PROFILE_DIR = "SakuraHubShop"

local Defaults = {
    -- สี (ธีมเริ่มต้น: ครีม + ทองอำพัน + ชมพูซากุระ)
    UIAccentColor = "#EFA53A",
    UIAccent2Color = "#F4A0B5",
    UIBackgroundColor = "#FFF6EA",
    UIButtonColor = "#F7E4CF",
    -- พื้นหลังขยับ
    AnimBackground = true,
    PetalCount = 18,
    AnimSpeed = 100,
    PanelAlpha = 22,
    BgImageId = "",
    ArtImageId = "",
    ArtOpacity = 55,
    -- ร้านค้า
    AutoShop = false,
    ShopCoinsAll = false,
    ShopGemsAll = false,
    ShopCoinsPick = "Trait",
    ShopGemsPick = "",
    -- โค้ด (จำว่าใส่ไปแล้วอะไรบ้าง)
    RedeemedCodes = "",
    -- ระบบ
    SoundEnabled = true,
    StatsVisible = true,
    UIScalePercent = 100,
    ToggleKey = "RightShift",
    ProfileSlot = "Slot 1",
    ImportText = "",
    -- สถานะ UI
    LastTab = "Home",
    WindowVisible = true,
    Maximized = false,
    CollapsedSections = "",
    WindowX = 0.5,
    WindowY = 0.5,
    FloatX = 0.05,
    FloatY = 0.25,
    StatsX = 0.5,
    StatsY = 0.045,
}

-- คีย์ที่ไม่เก็บลงสล็อต/ไม่ export (ตำแหน่งหน้าต่าง ฯลฯ)
local ProfileExclude = {
    WindowX = true, WindowY = true, FloatX = true, FloatY = true,
    StatsX = true, StatsY = true, LastTab = true, WindowVisible = true,
    Maximized = true, CollapsedSections = true, ImportText = true,
    ProfileSlot = true, RedeemedCodes = true,
}

local Config = {}
for k, v in pairs(Defaults) do
    Config[k] = v
end

local LoadedFromFile = false

local function LoadConfig()
    if not (isfile and readfile) then
        return
    end
    local ok, exists = pcall(isfile, CONFIG_FILE)
    if not (ok and exists) then
        return
    end
    pcall(function()
        local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
        if type(data) == "table" then
            for k, v in pairs(Defaults) do
                if type(data[k]) == type(v) then
                    Config[k] = data[k]
                end
            end
            LoadedFromFile = true
        end
    end)
end

LoadConfig()
for _, k in ipairs({ "WindowX", "WindowY" }) do
    Config[k] = math.clamp(Config[k], 0.05, 0.95)
end
for _, k in ipairs({ "FloatX", "FloatY", "StatsX", "StatsY" }) do
    Config[k] = math.clamp(Config[k], 0.02, 0.98)
end
Config.UIScalePercent = math.clamp(Config.UIScalePercent, 60, 120)

local SaveHooks = {}
local SaveToken = 0

local function Fire(state)
    for _, h in ipairs(SaveHooks) do
        pcall(h, state)
    end
end

local function WriteNow()
    if not writefile then
        return "unsupported"
    end
    local ok = pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(Config))
    end)
    return ok and "saved" or "failed"
end

local function SaveConfig(instant)
    SaveToken = SaveToken + 1
    local token = SaveToken
    Fire("saving")
    local function commit()
        if token ~= SaveToken then
            return
        end
        local result = WriteNow()
        Fire(result)
        if result == "saved" then
            task.delay(1.8, function()
                if token == SaveToken then
                    Fire("idle")
                end
            end)
        end
    end
    if instant then
        commit()
    else
        task.delay(0.3, commit)
    end
end

local function SetConfig(key, value)
    if Config[key] == value then
        return
    end
    Config[key] = value
    SaveConfig()
end

--==================================================
-- THEME  (ทุกสีคำนวณจาก Config และอัปเดตสดทันที)
--==================================================
local function RGB(r, g, b)
    return Color3.fromRGB(r, g, b)
end

local function Lum(c)
    return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

local function Hex(key, fallback)
    local ok, c = pcall(Color3.fromHex, Config[key])
    return ok and c or fallback
end

local Theme = {}

local function ComputeTheme()
    local bg = Hex("UIBackgroundColor", RGB(255, 246, 234))
    local dark = Lum(bg) < 0.5
    local to = dark and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
    Theme.Dark = dark
    Theme.Bg = bg
    Theme.Surface = dark and bg:Lerp(to, 0.06) or bg:Lerp(Color3.new(1, 1, 1), 0.55)
    Theme.Surface2 = dark and bg:Lerp(to, 0.11) or bg:Lerp(to, 0.05)
    Theme.Stroke = bg:Lerp(to, dark and 0.2 or 0.14)
    Theme.Text = dark and RGB(250, 244, 240) or RGB(74, 52, 44)
    Theme.Sub = Theme.Text:Lerp(bg, 0.3)
    Theme.Muted = Theme.Text:Lerp(bg, 0.55)
    Theme.Accent = Hex("UIAccentColor", RGB(239, 165, 58))
    Theme.Accent2 = Hex("UIAccent2Color", RGB(244, 160, 181))
    Theme.OnAccent = Lum(Theme.Accent) > 0.62 and RGB(70, 44, 30) or RGB(255, 255, 255)
    Theme.Button = Hex("UIButtonColor", RGB(247, 228, 207))
    Theme.Good = RGB(86, 190, 125)
    Theme.Warn = RGB(240, 175, 60)
    Theme.Bad = RGB(232, 90, 110)
end

ComputeTheme()

local ThemeHooks = {}

local function OnTheme(fn)
    ThemeHooks[#ThemeHooks + 1] = fn
    pcall(fn)
end

local function Bind(obj, prop, key)
    OnTheme(function()
        obj[prop] = Theme[key]
    end)
end

local function ApplyTheme()
    ComputeTheme()
    for _, fn in ipairs(ThemeHooks) do
        pcall(fn)
    end
end

--==================================================
-- HELPERS
--==================================================
local Orders = setmetatable({}, { __mode = "k" })
local function Next(parent)
    Orders[parent] = (Orders[parent] or 0) + 1
    return Orders[parent]
end

local function New(className, props, parent)
    local obj = Instance.new(className)
    for k, v in pairs(props or {}) do
        obj[k] = v
    end
    obj.Parent = parent
    return obj
end

local function Corner(parent, radius)
    return New("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function Stroke(parent, color, thickness, transparency)
    return New("UIStroke", {
        Color = color,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function Pad(parent, l, r, t, b)
    return New("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0),
        PaddingRight = UDim.new(0, r or 0),
        PaddingTop = UDim.new(0, t or 0),
        PaddingBottom = UDim.new(0, b or 0),
    }, parent)
end

local function List(parent, padding)
    return New("UIListLayout", {
        Padding = UDim.new(0, padding or 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, parent)
end

local function Text(parent, text, size, font, color, align)
    local l = New("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = text or "",
        TextSize = size or 13,
        TextXAlignment = align or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
    SetFont(l, font or FNT.R)
    if type(color) == "string" then
        Bind(l, "TextColor3", color)
    elseif color then
        l.TextColor3 = color
    end
    return l
end

local function Tween(obj, t, props, style, dir)
    local tw = TweenService:Create(
        obj,
        TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    )
    tw:Play()
    return tw
end

local function Apply(obj, animate, props)
    if animate then
        Tween(obj, 0.16, props)
    else
        for k, v in pairs(props) do
            obj[k] = v
        end
    end
end

local function PanelAlpha()
    return math.clamp(Config.PanelAlpha / 100, 0, 0.7)
end

-- การ์ดกระจกฝ้า (โปร่งตามค่า PanelAlpha เพื่อให้เห็นพื้นหลังขยับ)
local function Panel(parent, size, class)
    local f = New(class or "Frame", { BorderSizePixel = 0, LayoutOrder = Next(parent) }, parent)
    if class == "TextButton" then
        f.Text = ""
        f.AutoButtonColor = false
    end
    if size then
        f.Size = size
    end
    OnTheme(function()
        f.BackgroundColor3 = Theme.Surface
        f.BackgroundTransparency = PanelAlpha()
    end)
    Corner(f, 14)
    Bind(Stroke(f, Theme.Stroke, 1, 0.35), "Color", "Stroke")
    return f
end

local function HoverRow(btn)
    local st = btn:FindFirstChildOfClass("UIStroke")
    btn.MouseEnter:Connect(function()
        Tween(btn, 0.12, { BackgroundColor3 = Theme.Surface2 })
        if st then
            Tween(st, 0.12, { Transparency = 0.05 })
        end
    end)
    local sc
    if btn:IsA("GuiButton") then
        sc = New("UIScale", { Scale = 1 }, btn)
        btn.MouseButton1Down:Connect(function()
            Tween(sc, 0.08, { Scale = 0.985 })
        end)
        btn.MouseButton1Up:Connect(function()
            Tween(sc, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
        end)
    end
    btn.MouseLeave:Connect(function()
        Tween(btn, 0.12, { BackgroundColor3 = Theme.Surface })
        if st then
            Tween(st, 0.12, { Transparency = 0.35 })
        end
        if sc then
            Tween(sc, 0.12, { Scale = 1 })
        end
    end)
end

-- ไล่เฉด Accent -> Accent2 (วัตถุที่ใช้ต้องตั้ง BackgroundColor3 เป็นสีขาว)
local function AccentGrad(parent, rotation)
    local g = New("UIGradient", { Rotation = rotation or 0 }, parent)
    OnTheme(function()
        g.Color = ColorSequence.new(Theme.Accent, Theme.Accent2)
    end)
    return g
end

local function Tint(parent, radius)
    local t = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, parent)
    Corner(t, radius or 14)
    local g = AccentGrad(t, 25)
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.72),
        NumberSequenceKeypoint.new(1, 0.95),
    })
    return t
end

local function IsPointer(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function IsMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
end

local function AssetUrl(s)
    s = tostring(s or "")
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    if s == "" then
        return ""
    end
    if string.match(s, "^%d+$") then
        return "rbxassetid://" .. s
    end
    return s
end

-- ไอคอนวาดด้วย Frame (ไม่พึ่ง asset) คืนฟังก์ชันเปลี่ยนสี
local function Icon(parent, kind, x, y)
    local box = New("Frame", {
        Size = UDim2.fromOffset(18, 18),
        Position = UDim2.fromOffset(x, y),
        BackgroundTransparency = 1,
    }, parent)
    local parts = {}
    local function rect(px, py, w, h, r, rot)
        local f = New("Frame", {
            Size = UDim2.fromOffset(w, h),
            Position = UDim2.fromOffset(px, py),
            BorderSizePixel = 0,
            Rotation = rot or 0,
        }, box)
        Corner(f, r or 1)
        parts[#parts + 1] = { f = f }
        return f
    end
    local function ring(px, py, s, r, th)
        local f = New("Frame", {
            Size = UDim2.fromOffset(s, s),
            Position = UDim2.fromOffset(px, py),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, box)
        Corner(f, r)
        parts[#parts + 1] = { stroke = Stroke(f, Color3.new(1, 1, 1), th or 2, 0) }
    end
    if kind == "grid" then
        rect(1, 1, 7, 7, 3)
        rect(10, 1, 7, 7, 3)
        rect(1, 10, 7, 7, 3)
        rect(10, 10, 7, 7, 3)
    elseif kind == "sliders" then
        rect(1, 2, 16, 2, 1)
        rect(1, 8, 11, 2, 1)
        rect(1, 14, 14, 2, 1)
    elseif kind == "close" then
        rect(1, 8, 16, 2, 1, 45)
        rect(1, 8, 16, 2, 1, -45)
    elseif kind == "max" then
        ring(3, 3, 12, 3)
    elseif kind == "dots" then
        rect(1, 1, 8, 8, 4)
        rect(9, 3, 8, 8, 4)
        rect(4, 9, 9, 9, 4)
    elseif kind == "save" then
        ring(2, 2, 14, 3)
        rect(5, 2, 8, 5, 1)
        rect(5, 11, 8, 4, 1)
    else -- ring (settings)
        ring(1, 1, 16, 8)
        rect(7, 7, 4, 4, 2)
    end
    return function(c)
        for _, p in ipairs(parts) do
            if p.stroke then
                p.stroke.Color = c
            else
                p.f.BackgroundColor3 = c
            end
        end
    end
end

-- ดอกซากุระวาดด้วย Frame (ใช้เป็นโลโก้ / ปุ่มลอย)
local function Flower(parent, size)
    local holder = New("Frame", {
        Size = UDim2.fromOffset(size, size),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundTransparency = 1,
    }, parent)
    local pr = size * 0.2
    local dist = size * 0.27
    for i = 0, 4 do
        local a = math.rad(i * 72 - 90)
        local p = New("Frame", {
            Size = UDim2.fromOffset(pr * 2, pr * 2),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, math.cos(a) * dist, 0.5, math.sin(a) * dist),
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.04,
        }, holder)
        Corner(p, 999)
    end
    local c = New("Frame", {
        Size = UDim2.fromOffset(size * 0.22, size * 0.22),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BorderSizePixel = 0,
    }, holder)
    Corner(c, 999)
    Bind(c, "BackgroundColor3", "Accent")
    return holder
end

--==================================================
-- ROOT GUI
--==================================================
pcall(function()
    for _, root in ipairs({ PlayerGui, GuiParent }) do
        for _, v in ipairs(root:GetChildren()) do
            if v.Name == "SAKURA_UI" or v.Name == "SAKURA_Floating" or v.Name == "SAKURA_Stats" then
                v:Destroy()
            end
        end
    end
end)

local Screen = New("ScreenGui", {
    Name = "SAKURA_UI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999998,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, GuiParent)

-- เก็บ connection ไว้ ตัดทิ้งตอน UI ถูกทำลาย (รันซ้ำได้ไม่ค้าง)
local Conns = {}
local function Track(c)
    Conns[#Conns + 1] = c
    return c
end
Screen.Destroying:Connect(function()
    for _, c in ipairs(Conns) do
        pcall(function()
            c:Disconnect()
        end)
    end
end)

local BW, BH = 780, 560 -- ขนาดออกแบบ (ปรับตามจอผ่าน UIScale)
local SW = 176 -- ความกว้าง sidebar

local function ViewSize()
    local s = Screen.AbsoluteSize
    if s.X > 0 and s.Y > 0 then
        return s
    end
    return workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
end

local function TargetScale()
    local v = ViewSize()
    local fit = math.min(v.X * 0.97 / BW, v.Y * 0.95 / BH)
    local base = math.min(fit * (Config.Maximized and 1 or 0.92), Config.Maximized and 1.4 or 1.1)
    local s = base * (Config.UIScalePercent / 100)
    return math.clamp(s, 0.3, math.max(0.3, fit))
end

local Main = New("CanvasGroup", {
    Name = "Main",
    Size = UDim2.fromOffset(BW, BH),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(Config.WindowX, Config.WindowY),
    BorderSizePixel = 0,
    GroupTransparency = 1,
    Active = true,
    Visible = false,
}, Screen)
Bind(Main, "BackgroundColor3", "Bg")
Corner(Main, 22)

--==================================================
-- ANIMATED BACKGROUND
--==================================================
local RefreshBackgroundImages, RefreshPetalCount
local MAX_PETALS = 40
do
-- 1) ไล่เฉดสีพื้นหลังนุ่มๆ
local Wash = New("Frame", {
    Size = UDim2.fromScale(1, 1),
    BorderSizePixel = 0,
    BackgroundColor3 = Color3.new(1, 1, 1),
}, Main)
local WashGrad = New("UIGradient", { Rotation = 60 }, Wash)
OnTheme(function()
    WashGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.Accent2:Lerp(Theme.Bg, Theme.Dark and 0.8 or 0.55)),
        ColorSequenceKeypoint.new(0.5, Theme.Bg),
        ColorSequenceKeypoint.new(1, Theme.Accent:Lerp(Theme.Bg, Theme.Dark and 0.8 or 0.6)),
    })
end)
TweenService:Create(
    WashGrad,
    TweenInfo.new(18, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    { Rotation = 130 }
):Play()

-- 2) ภาพพื้นหลังของคุณ (ใส่ใน ตั้งค่า > พื้นหลัง) + ซูมช้าๆ
local BgHolder = New("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
}, Main)
local BgImage = New("ImageLabel", {
    Size = UDim2.fromScale(1.12, 1.12),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    BackgroundTransparency = 1,
    ScaleType = Enum.ScaleType.Crop,
    ImageTransparency = 0.78,
    Visible = false,
}, BgHolder)
TweenService:Create(
    BgImage,
    TweenInfo.new(20, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    { Position = UDim2.fromScale(0.47, 0.52), Size = UDim2.fromScale(1.2, 1.2) }
):Play()

-- 3) แสงลอย (orb)
local OrbLayer = New("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
}, Main)
local OrbDefs = {
    { size = 340, x = 0.08, y = 0.12, x2 = 0.22, y2 = 0.3, key = "Accent2", t = 11 },
    { size = 400, x = 0.92, y = 0.85, x2 = 0.75, y2 = 0.65, key = "Accent", t = 14 },
    { size = 260, x = 0.6, y = 0.1, x2 = 0.45, y2 = 0.25, key = "Accent2", t = 9 },
}
for _, d in ipairs(OrbDefs) do
    local o = New("Frame", {
        Size = UDim2.fromOffset(d.size, d.size),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(d.x, d.y),
        BorderSizePixel = 0,
        BackgroundTransparency = 0.86,
    }, OrbLayer)
    Corner(o, 999)
    Bind(o, "BackgroundColor3", d.key)
    TweenService:Create(
        o,
        TweenInfo.new(d.t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Position = UDim2.fromScale(d.x2, d.y2), BackgroundTransparency = 0.92 }
    ):Play()
end

-- 4) รูปตัวละครของคุณ (มุมขวาล่าง ลอยขึ้นลงเบาๆ)
local ArtImage = New("ImageLabel", {
    Size = UDim2.fromOffset(330, 470),
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -6, 1, -6),
    BackgroundTransparency = 1,
    ScaleType = Enum.ScaleType.Fit,
    Visible = false,
}, Main)
TweenService:Create(
    ArtImage,
    TweenInfo.new(3.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    { Position = UDim2.new(1, -6, 1, -14) }
):Play()

RefreshBackgroundImages = function()
    local bg = AssetUrl(Config.BgImageId)
    BgImage.Image = bg
    BgImage.Visible = bg ~= ""
    local art = AssetUrl(Config.ArtImageId)
    ArtImage.Image = art
    ArtImage.Visible = art ~= ""
    ArtImage.ImageTransparency = 1 - math.clamp(Config.ArtOpacity / 100, 0, 1)
    OrbLayer.Visible = Config.AnimBackground
end

-- 5) กลีบซากุระร่วง
local PetalLayer = New("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
}, Main)

local Petals = {}
for i = 1, MAX_PETALS do
    local w = math.random(8, 14)
    local f = New("Frame", {
        Size = UDim2.fromOffset(w, math.floor(w * 0.66)),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BorderSizePixel = 0,
        BackgroundTransparency = 0.1 + math.random() * 0.3,
    }, PetalLayer)
    Corner(f, 99)
    local pet = {
        f = f,
        x = math.random(),
        y = math.random() * 1.2 - 0.1,
        sp = 0.05 + math.random() * 0.07, -- ความเร็วตก (สัดส่วนจอ/วินาที)
        amp = 0.015 + math.random() * 0.03, -- แกว่งซ้าย-ขวา
        fr = 0.8 + math.random() * 1.4,
        ph = math.random() * 6.28,
        rot = (math.random() - 0.5) * 140,
        r = math.random() * 360,
        mix = math.random() * 0.55,
    }
    Petals[i] = pet
    OnTheme(function()
        f.BackgroundColor3 = Theme.Accent2:Lerp(Color3.new(1, 1, 1), pet.mix)
    end)
end

RefreshPetalCount = function()
    for i, p in ipairs(Petals) do
        p.f.Visible = Config.AnimBackground and i <= Config.PetalCount
    end
end

Track(RunService.Heartbeat:Connect(function(dt)
    if not Main.Visible or not Config.AnimBackground then
        return
    end
    dt = math.min(dt, 0.1) * (Config.AnimSpeed / 100)
    for i = 1, math.min(Config.PetalCount, MAX_PETALS) do
        local p = Petals[i]
        p.y = p.y + p.sp * dt
        p.ph = p.ph + p.fr * dt
        p.r = p.r + p.rot * dt
        if p.y > 1.08 then
            p.y = -0.08
            p.x = math.random()
        end
        p.f.Position = UDim2.fromScale(p.x + math.sin(p.ph) * p.amp, p.y)
        p.f.Rotation = p.r
    end
end))

-- 6) ประกายระยิบ
for i = 1, 9 do
    local s = New("Frame", {
        Size = UDim2.fromOffset(4, 4),
        Position = UDim2.fromScale(math.random(), math.random()),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Rotation = 45,
    }, OrbLayer)
    Bind(s, "BackgroundColor3", (i % 2 == 0) and "Accent" or "Accent2")
    TweenService:Create(
        s,
        TweenInfo.new(1.4 + math.random() * 1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, math.random() * 3),
        { BackgroundTransparency = 0.1, Size = UDim2.fromOffset(7, 7) }
    ):Play()
end

end

-- ขอบหน้าต่างไล่สีหมุน
local MainStroke = Stroke(Main, Color3.new(1, 1, 1), 1.6, 0)
local MainGrad = New("UIGradient", { Rotation = 0 }, MainStroke)
OnTheme(function()
    MainGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.Stroke),
        ColorSequenceKeypoint.new(0.35, Theme.Accent),
        ColorSequenceKeypoint.new(0.65, Theme.Accent2),
        ColorSequenceKeypoint.new(1, Theme.Stroke),
    })
end)
TweenService:Create(
    MainGrad,
    TweenInfo.new(7, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
    { Rotation = 360 }
):Play()
local MainScale = New("UIScale", { Scale = TargetScale() }, Main)

do
-- เงาใต้หน้าต่าง
local Shadow = New("Frame", {
    Size = UDim2.fromOffset(BW, BH),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    ZIndex = 0,
    Visible = false,
}, Screen)
local ShadowScale = New("UIScale", { Scale = 1 }, Shadow)
local ShadowLayers = {}
for i, g in ipairs({ 8, 20, 36 }) do
    local l = New("Frame", {
        Size = UDim2.new(1, g * 2, 1, g * 2),
        Position = UDim2.fromOffset(-g, -g + 10),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(80, 40, 30),
    }, Shadow)
    Corner(l, 22 + g)
    ShadowLayers[i] = { f = l, base = 0.88 + i * 0.03 }
end

Track(RunService.RenderStepped:Connect(function()
    local vis = Main.Visible
    Shadow.Visible = vis
    if not vis then
        return
    end
    Shadow.Position = Main.Position
    Shadow.Size = Main.Size
    ShadowScale.Scale = MainScale.Scale
    local a = Main.GroupTransparency
    for _, l in ipairs(ShadowLayers) do
        l.f.BackgroundTransparency = 1 - (1 - l.base) * (1 - a)
    end
end))

end

local Opening = false

local function ApplyScale(animate)
    if Opening then
        return
    end
    if animate and Main.Visible then
        Tween(MainScale, 0.25, { Scale = TargetScale() }, Enum.EasingStyle.Quint)
    else
        MainScale.Scale = TargetScale()
    end
end

Track(Screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    ApplyScale(false)
end))

--==================================================
-- SOUND / FX
--==================================================
local function PlayToggleSound(on, big)
    if not Config.SoundEnabled then
        return
    end
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = on and SOUND_ON or SOUND_OFF
        s.Volume = big and 0.6 or 0.5
        s.PlaybackSpeed = (on and 1.2 or 0.88) * (big and 0.9 or 1)
        s.Parent = SoundService
        s:Play()
        Debris:AddItem(s, 2.5)
    end)
end

local function FloatCenter()
    local s = Screen.AbsoluteSize
    return s.X * Config.FloatX, s.Y * Config.FloatY
end

local function FxRing(cx, cy, size, thick, dur, color)
    local r = New("Frame", {
        Size = UDim2.fromOffset(6, 6),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(cx, cy),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 60,
    }, Screen)
    Corner(r, 9999)
    local st = Stroke(r, color or Theme.Accent2, thick, 0.05)
    Tween(r, dur, { Size = UDim2.fromOffset(size, size) }, Enum.EasingStyle.Quint)
    Tween(st, dur, { Transparency = 1, Thickness = 0.5 })
    Debris:AddItem(r, dur + 0.15)
end

-- กลีบซากุระพุ่งออก
local function FxPetals(cx, cy, count, dist)
    for i = 1, count do
        local ang = math.random() * math.pi * 2
        local d = dist * (0.5 + math.random() * 0.9)
        local w = math.random(7, 13)
        local p = New("Frame", {
            Size = UDim2.fromOffset(w, math.floor(w * 0.66)),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(cx, cy),
            BorderSizePixel = 0,
            BackgroundColor3 = (i % 3 == 0) and Color3.new(1, 1, 1)
                or Theme.Accent2:Lerp(Color3.new(1, 1, 1), math.random() * 0.5),
            Rotation = math.random(0, 360),
            ZIndex = 61,
        }, Screen)
        Corner(p, 99)
        local dur = 0.6 + math.random() * 0.6
        Tween(p, dur, {
            Position = UDim2.fromOffset(cx + math.cos(ang) * d, cy + math.sin(ang) * d * 0.85 + 22),
            BackgroundTransparency = 1,
            Rotation = p.Rotation + math.random(-220, 220),
        }, Enum.EasingStyle.Quint)
        Debris:AddItem(p, dur + 0.15)
    end
end

local AnimToken = 0

-- เปิด: บินออกจากปุ่มดอกไม้ แล้วขยายเป็นหน้าต่าง
local function PlayOpen()
    AnimToken = AnimToken + 1
    local token = AnimToken
    Opening = true
    local t = TargetScale()
    local fx, fy = FloatCenter()

    MainStroke.Thickness = 1.6
    Main.Size = UDim2.fromOffset(BW, BH)
    Main.Position = UDim2.fromOffset(fx, fy)
    Main.GroupTransparency = 1
    MainScale.Scale = t * 0.1
    Main.Visible = true

    PlayToggleSound(true, true)
    FxRing(fx, fy, 120, 3, 0.55)
    FxPetals(fx, fy, 14, 80)

    Tween(Main, 0.3, { GroupTransparency = 0 })
    Tween(Main, 0.6, { Position = UDim2.fromScale(Config.WindowX, Config.WindowY) }, Enum.EasingStyle.Quint)
    Tween(MainScale, 0.65, { Scale = t }, Enum.EasingStyle.Back)

    task.delay(0.68, function()
        if token == AnimToken then
            Opening = false
        end
    end)
end

-- ปิด: หดกลับเข้าปุ่มดอกไม้ พร้อมกลีบพุ่งออก
local function PlayClose()
    AnimToken = AnimToken + 1
    local token = AnimToken
    Opening = true
    PlayToggleSound(false, true)

    local s0 = MainScale.Scale
    local fx, fy = FloatCenter()
    local ap, asz = Main.AbsolutePosition, Main.AbsoluteSize
    FxPetals(ap.X + asz.X / 2, ap.Y + asz.Y / 2, 18, 170 * math.max(s0, 0.6))

    Tween(Main, 0.45, { Position = UDim2.fromOffset(fx, fy) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    Tween(MainScale, 0.45, { Scale = s0 * 0.08 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    Tween(Main, 0.4, { GroupTransparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)

    task.delay(0.47, function()
        if token ~= AnimToken then
            return
        end
        Main.Visible = false
        Main.Position = UDim2.fromScale(Config.WindowX, Config.WindowY)
        MainScale.Scale = s0
        FxRing(fx, fy, 100, 3, 0.5)
        FxPetals(fx, fy, 8, 50)
        Opening = false
    end)
end

local function SetWindow(visible)
    SetConfig("WindowVisible", visible)
    if visible then
        PlayOpen()
    else
        PlayClose()
    end
end

-- ลากหน้าต่าง/ปุ่ม/วิดเจ็ต แล้วเซฟตำแหน่งเป็นสัดส่วนหน้าจอ
local function SavePosition(target, kx, ky)
    local s = Screen.AbsoluteSize
    if s.X <= 0 or s.Y <= 0 then
        return
    end
    local c = target.AbsolutePosition + target.AbsoluteSize / 2
    local fx = math.clamp(c.X / s.X, 0.02, 0.98)
    local fy = math.clamp(c.Y / s.Y, 0.02, 0.98)
    target.Position = UDim2.fromScale(fx, fy)
    SetConfig(kx, math.floor(fx * 10000) / 10000)
    SetConfig(ky, math.floor(fy * 10000) / 10000)
end

local function MakeDraggable(handle, target, kx, ky, onClick)
    local dragging, dragInput, startPos, startCenter, moved = false, nil, nil, nil, false

    handle.InputBegan:Connect(function(input)
        if IsPointer(input) then
            dragging = true
            moved = false
            dragInput = input
            startPos = input.Position
            startCenter = target.AbsolutePosition + target.AbsoluteSize / 2
        end
    end)

    Track(UIS.InputChanged:Connect(function(input)
        if not dragging or not IsMove(input) then
            return
        end
        if input.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then
            return
        end
        local d = input.Position - startPos
        if d.Magnitude > 8 then
            moved = true
        end
        if moved then
            local s = Screen.AbsoluteSize
            target.Position = UDim2.fromOffset(
                math.clamp(startCenter.X + d.X, 0, s.X),
                math.clamp(startCenter.Y + d.Y, 0, s.Y)
            )
        end
    end))

    Track(UIS.InputEnded:Connect(function(input)
        if dragging and IsPointer(input) then
            if input.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then
                return
            end
            dragging = false
            if moved then
                SavePosition(target, kx, ky)
            elseif onClick then
                onClick()
            end
        end
    end))
end

-- แจ้งเตือนเล็กๆ ด้านล่างจอ (Toast)
local ActiveToast
local function Toast(text, on)
    if ActiveToast then
        ActiveToast:Destroy()
        ActiveToast = nil
    end
    local t = New("TextLabel", {
        Size = UDim2.fromOffset(0, 38),
        AutomaticSize = Enum.AutomaticSize.X,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, 48),
        BorderSizePixel = 0,
        Text = text,
        TextSize = 13,
        BackgroundColor3 = Theme.Surface,
        TextColor3 = Theme.Text,
        ZIndex = 300,
    }, Screen)
    SetFont(t, FNT.M)
    Corner(t, 19)
    Stroke(t, Theme.Accent, 1.2, 0.3)
    Pad(t, 38, 18, 0, 0)
    local dot = New("Frame", {
        Size = UDim2.fromOffset(9, 9),
        Position = UDim2.new(0, -24, 0.5, -4),
        BorderSizePixel = 0,
        BackgroundColor3 = (on == true) and Theme.Good or (on == false and Theme.Muted or Theme.Accent2),
    }, t)
    Corner(dot, 5)
    ActiveToast = t
    Tween(t, 0.35, { Position = UDim2.new(0.5, 0, 1, -26) }, Enum.EasingStyle.Back)
    task.delay(1.8, function()
        if ActiveToast == t then
            Tween(t, 0.25, { Position = UDim2.new(0.5, 0, 1, 48) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            task.delay(0.3, function()
                t:Destroy()
                if ActiveToast == t then
                    ActiveToast = nil
                end
            end)
        end
    end)
end

--==================================================
-- STATUS: save pill + status dot
--==================================================
local SaveStates = {
    idle = { "Auto Save", nil },
    saving = { "กำลังบันทึก...", "Warn" },
    saved = { "บันทึกแล้ว", "Good" },
    failed = { "บันทึกไม่ได้", "Bad" },
    unsupported = { "ไม่รองรับไฟล์", "Bad" },
}

local function StatusPill(parent, width)
    local pill = New("Frame", { Size = UDim2.fromOffset(width or 112, 28), BorderSizePixel = 0 }, parent)
    Bind(pill, "BackgroundColor3", "Surface2")
    Corner(pill, 14)
    Bind(Stroke(pill, Theme.Stroke, 1, 0.3), "Color", "Stroke")

    local dot = New("Frame", {
        Size = UDim2.fromOffset(8, 8),
        Position = UDim2.new(0, 12, 0.5, -4),
        BorderSizePixel = 0,
    }, pill)
    Corner(dot, 4)

    local label = Text(pill, "", 11, FNT.M, "Sub")
    label.Position = UDim2.fromOffset(27, 0)
    label.Size = UDim2.new(1, -31, 1, 0)

    local current = "idle"
    local function render()
        local s = SaveStates[current]
        label.Text = s[1]
        dot.BackgroundColor3 = s[2] and Theme[s[2]] or Theme.Accent
    end
    OnTheme(render)

    SaveHooks[#SaveHooks + 1] = function(state)
        current = state
        render()
    end
    return pill
end

--==================================================
-- FPS / MS WIDGET (เล็ก ลากได้)
--==================================================
local StatsGui = New("ScreenGui", {
    Name = "SAKURA_Stats",
    ResetOnSpawn = false,
    DisplayOrder = 999999,
    IgnoreGuiInset = true,
    Enabled = Config.StatsVisible,
}, GuiParent)

local StatsBox = New("Frame", {
    Size = UDim2.fromOffset(158, 32),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(Config.StatsX, Config.StatsY),
    BorderSizePixel = 0,
    BackgroundTransparency = 0.08,
    Active = true,
}, StatsGui)
Bind(StatsBox, "BackgroundColor3", "Surface")
Corner(StatsBox, 16)
Bind(Stroke(StatsBox, Theme.Stroke, 1.2, 0.1), "Color", "Accent")

local FpsLabel = Text(StatsBox, "", 12, FNT.M, "Sub", Enum.TextXAlignment.Center)
FpsLabel.RichText = true
FpsLabel.Size = UDim2.new(0.5, -1, 1, 0)

local MsLabel = Text(StatsBox, "", 12, FNT.M, "Sub", Enum.TextXAlignment.Center)
MsLabel.RichText = true
MsLabel.Position = UDim2.new(0.5, 1, 0, 0)
MsLabel.Size = UDim2.new(0.5, -1, 1, 0)

local StatsDivider = New("Frame", {
    Size = UDim2.fromOffset(1, 14),
    Position = UDim2.new(0.5, 0, 0.5, -7),
    BorderSizePixel = 0,
}, StatsBox)
Bind(StatsDivider, "BackgroundColor3", "Stroke")

MakeDraggable(StatsBox, StatsBox, "StatsX", "StatsY")

local Metrics = { fps = 60, ping = 0 }

do
    local frames, acc = 0, 0
    Track(RunService.RenderStepped:Connect(function(dt)
        frames = frames + 1
        acc = acc + dt
        if acc >= 0.5 then
            Metrics.fps = math.floor(frames / acc + 0.5)
            frames, acc = 0, 0
        end
    end))
end

local function GetPing()
    local ok, v = pcall(function()
        return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return (ok and type(v) == "number") and math.floor(v + 0.5) or 0
end

local function Level(value, good, mid, higherIsBetter)
    if higherIsBetter then
        return value >= good and Theme.Good or (value >= mid and Theme.Warn or Theme.Bad)
    end
    return value <= good and Theme.Good or (value <= mid and Theme.Warn or Theme.Bad)
end

local function RefreshStats()
    Metrics.ping = GetPing()
    local fc = Level(Metrics.fps, 50, 30, true)
    local mc = Level(Metrics.ping, 80, 160, false)
    local muted = "#" .. Theme.Muted:ToHex()
    FpsLabel.Text = string.format(
        '<font color="#%s"><b>%d</b></font> <font color="%s">FPS</font>',
        fc:ToHex(), Metrics.fps, muted
    )
    MsLabel.Text = string.format(
        '<font color="#%s"><b>%d</b></font> <font color="%s">MS</font>',
        mc:ToHex(), Metrics.ping, muted
    )
end

--==================================================
-- TOP BAR
--==================================================
local BrandSub
do
local Top = New("Frame", {
    Size = UDim2.new(1, 0, 0, 62),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
}, Main)

local TopLine = New("Frame", {
    Size = UDim2.new(1, -28, 0, 1),
    Position = UDim2.new(0, 14, 1, -1),
    BorderSizePixel = 0,
    BackgroundColor3 = Color3.new(1, 1, 1),
}, Top)
do
    local g = AccentGrad(TopLine, 0)
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.9),
        NumberSequenceKeypoint.new(0.5, 0.2),
        NumberSequenceKeypoint.new(1, 0.9),
    })
end

local Badge = New("Frame", {
    Size = UDim2.fromOffset(38, 38),
    Position = UDim2.fromOffset(16, 12),
    BorderSizePixel = 0,
    BackgroundColor3 = Color3.new(1, 1, 1),
}, Top)
AccentGrad(Badge, 45)
Corner(Badge, 19)
Bind(Stroke(Badge, Theme.Accent, 1.5, 0.5), "Color", "Accent")
local BadgeFlower = Flower(Badge, 30)
TweenService:Create(
    BadgeFlower,
    TweenInfo.new(12, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
    { Rotation = 360 }
):Play()

local Brand = Text(Top, "", 17, FNT.X, "Text")
Brand.RichText = true
OnTheme(function()
    Brand.Text = 'SAKURA <font color="#' .. Theme.Accent:ToHex() .. '">HUB</font>'
end)
Brand.Position = UDim2.fromOffset(64, 9)
Brand.Size = UDim2.new(1, -330, 0, 24)

BrandSub = Text(Top, tostring(game.Name or ""), 11, FNT.R, "Muted")
BrandSub.Position = UDim2.fromOffset(64, 33)
BrandSub.Size = UDim2.new(1, -330, 0, 16)

local TopPill = StatusPill(Top, 116)
TopPill.AnchorPoint = Vector2.new(1, 0.5)
TopPill.Position = UDim2.new(1, -96, 0.5, 0)

local function WindowButton(kind, xOffset, danger)
    local b = New("TextButton", {
        Size = UDim2.fromOffset(32, 32),
        Position = UDim2.new(1, xOffset, 0.5, -16),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, Top)
    Corner(b, 16)
    Bind(b, "BackgroundColor3", "Surface2")
    local paint = Icon(b, kind, 7, 7)
    OnTheme(function()
        paint(Theme.Sub)
    end)
    b.MouseEnter:Connect(function()
        Tween(b, 0.12, { BackgroundColor3 = danger and Theme.Bad or Theme.Button })
        paint(danger and Color3.new(1, 1, 1) or Theme.Text)
    end)
    b.MouseLeave:Connect(function()
        Tween(b, 0.12, { BackgroundColor3 = Theme.Surface2 })
        paint(Theme.Sub)
    end)
    return b
end

local MaxBtn = WindowButton("max", -78, false)
local CloseBtn = WindowButton("close", -42, true)
CloseBtn.MouseButton1Click:Connect(function()
    SetWindow(false)
end)

MakeDraggable(Top, Main, "WindowX", "WindowY")

MaxBtn.MouseButton1Click:Connect(function()
    SetConfig("Maximized", not Config.Maximized)
    SetConfig("WindowX", 0.5)
    SetConfig("WindowY", 0.5)
    Tween(Main, 0.3, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Quint)
    ApplyScale(true)
end)

end

--==================================================
-- SIDEBAR
--==================================================
local Rail = New("Frame", {
    Size = UDim2.new(0, SW, 1, -82),
    Position = UDim2.fromOffset(12, 70),
    BorderSizePixel = 0,
}, Main)
OnTheme(function()
    Rail.BackgroundColor3 = Theme.Surface
    Rail.BackgroundTransparency = math.clamp(PanelAlpha() + 0.05, 0, 0.75)
end)
Corner(Rail, 16)
Bind(Stroke(Rail, Theme.Stroke, 1, 0.35), "Color", "Stroke")

local CatList = New("ScrollingFrame", {
    Size = UDim2.new(1, -16, 1, -84),
    Position = UDim2.fromOffset(8, 10),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    ScrollBarImageTransparency = 0.3,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    ElasticBehavior = Enum.ElasticBehavior.Never,
}, Rail)
Bind(CatList, "ScrollBarImageColor3", "Accent")
List(CatList, 4)
Pad(CatList, 0, 4, 1, 1)

local UserBox = New("Frame", {
    Size = UDim2.new(1, -16, 0, 54),
    Position = UDim2.new(0, 8, 1, -62),
    BorderSizePixel = 0,
}, Rail)
Bind(UserBox, "BackgroundColor3", "Surface2")
Corner(UserBox, 14)

local Avatar = New("ImageLabel", {
    Size = UDim2.fromOffset(36, 36),
    Position = UDim2.new(0, 9, 0.5, -18),
    BorderSizePixel = 0,
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=60&h=60",
}, UserBox)
Corner(Avatar, 18)
Bind(Avatar, "BackgroundColor3", "Button")
Bind(Stroke(Avatar, Theme.Accent, 2, 0.1), "Color", "Accent")
Bind(Stroke(UserBox, Theme.Stroke, 1, 0.5), "Color", "Stroke")
local Online = New("Frame", {
    Size = UDim2.fromOffset(11, 11),
    Position = UDim2.new(0, 38, 0.5, 8),
    BorderSizePixel = 0,
    ZIndex = 3,
}, UserBox)
Corner(Online, 6)
Bind(Online, "BackgroundColor3", "Good")
Bind(Stroke(Online, Theme.Surface2, 2, 0), "Color", "Surface2")

local UName = Text(UserBox, LocalPlayer.DisplayName, 13, FNT.B, "Text")
UName.Position = UDim2.fromOffset(54, 10)
UName.Size = UDim2.new(1, -60, 0, 18)
local UTag = Text(UserBox, "@" .. LocalPlayer.Name, 11, FNT.R, "Muted")
UTag.Position = UDim2.fromOffset(54, 28)
UTag.Size = UDim2.new(1, -60, 0, 14)

local Pages = {}
local TabList = {}

local function CatGroup(name)
    local l = Text(CatList, name, 11, FNT.B, "Muted")
    l.Size = UDim2.new(1, 0, 0, 26)
    l.LayoutOrder = Next(CatList)
    Pad(l, 10, 0, 6, 0)
    return l
end

local CurrentTab = nil
local function SelectTab(id)
    if not Pages[id] then
        id = "Home"
    end
    SetConfig("LastTab", id)
    local changed = id ~= CurrentTab
    CurrentTab = id
    for pid, page in pairs(Pages) do
        page.Visible = (pid == id)
    end
    if changed then
        local p = Pages[id]
        p.Position = UDim2.fromOffset(0, 16)
        Tween(p, 0.32, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quint)
    end
    for _, t in ipairs(TabList) do
        t.active = (t.id == id)
        t.paint()
    end
end

local function Category(name, id, iconKind)
    local b = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = Next(CatList),
    }, CatList)
    Corner(b, 21)
    local bst = Stroke(b, Theme.Accent, 1, 1)

    local ind = New("Frame", {
        Size = UDim2.fromOffset(3, 8),
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 5, 0.5, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, b)
    Corner(ind, 2)

    local setIcon = Icon(b, iconKind, 17, 12)

    local lbl = Text(b, name, 14, FNT.M)
    lbl.Position = UDim2.fromOffset(46, 0)
    lbl.Size = UDim2.new(1, -50, 1, 0)
    lbl.TextColor3 = Theme.Sub

    local tab = { id = id, active = false, hover = false }
    function tab.paint()
        Tween(b, 0.15, {
            BackgroundColor3 = tab.active and Theme.Accent or Theme.Button,
            BackgroundTransparency = tab.active and 0.78 or (tab.hover and 0.5 or 1),
        })
        Tween(bst, 0.15, { Color = Theme.Accent, Transparency = tab.active and 0.4 or 1 })
        Tween(lbl, 0.15, { TextColor3 = tab.active and Theme.Text or Theme.Sub })
        Tween(ind, 0.15, {
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = tab.active and 0 or 1,
            Size = tab.active and UDim2.fromOffset(3, 22) or UDim2.fromOffset(3, 8),
        })
        setIcon(tab.active and Theme.Accent or Theme.Sub)
    end
    TabList[#TabList + 1] = tab
    OnTheme(tab.paint)

    b.MouseEnter:Connect(function()
        tab.hover = true
        tab.paint()
    end)
    b.MouseLeave:Connect(function()
        tab.hover = false
        tab.paint()
    end)
    b.MouseButton1Click:Connect(function()
        SelectTab(id)
    end)
    return b
end

--==================================================
-- PAGES
--==================================================
local Body = New("Frame", {
    Size = UDim2.new(1, -(SW + 38), 1, -82),
    Position = UDim2.fromOffset(SW + 26, 70),
    BackgroundTransparency = 1,
}, Main)

local function MakePage(id, title, subtitle)
    local page = New("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = false,
    }, Body)
    Bind(page, "ScrollBarImageColor3", "Accent")
    List(page, 8)
    Pad(page, 0, 8, 0, 14)

    local head = New("Frame", {
        Size = UDim2.new(1, 0, 0, 62),
        BackgroundTransparency = 1,
        LayoutOrder = Next(page),
    }, page)
    local t = Text(head, title, 24, FNT.X, "Text")
    t.Size = UDim2.new(1, 0, 0, 30)
    local s = Text(head, subtitle or "", 12, FNT.R, "Muted")
    s.Position = UDim2.fromOffset(0, 31)
    s.Size = UDim2.new(1, 0, 0, 18)
    local hb = New("Frame", {
        Size = UDim2.fromOffset(44, 4),
        Position = UDim2.fromOffset(0, 54),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, head)
    Corner(hb, 2)
    AccentGrad(hb, 0)

    Pages[id] = page
    return page
end

-- Section แบบพับ/ขยายได้ (จำสถานะใน Config)
local Collapsed = {}
for id in string.gmatch(Config.CollapsedSections, "[^|]+") do
    Collapsed[id] = true
end
local function SaveCollapsed()
    local t = {}
    for id, v in pairs(Collapsed) do
        if v then
            t[#t + 1] = id
        end
    end
    table.sort(t)
    SetConfig("CollapsedSections", table.concat(t, "|"))
end

local SectionsByPage = {}
local CurrentSection = nil

local function Section(page, title)
    local hdr = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = Next(page),
    }, page)

    local bar = New("Frame", {
        Size = UDim2.fromOffset(4, 16),
        Position = UDim2.new(0, 2, 0.5, -8),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, hdr)
    Corner(bar, 2)
    AccentGrad(bar, 90)

    local hl = New("Frame", {
        Size = UDim2.new(1, -4, 0, 1),
        Position = UDim2.new(0, 2, 1, -1),
        BorderSizePixel = 0,
    }, hdr)
    Bind(hl, "BackgroundColor3", "Stroke")
    New("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, hl)

    local label = Text(hdr, title, 14, FNT.B, "Text")
    label.Position = UDim2.fromOffset(16, 0)
    label.Size = UDim2.new(1, -46, 1, 0)

    local chev = New("Frame", {
        Size = UDim2.fromOffset(14, 14),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(1, -18, 0.5, 0),
        BackgroundTransparency = 1,
    }, hdr)
    local c1 = New("Frame", {
        Size = UDim2.fromOffset(8, 2), Position = UDim2.fromOffset(1, 6), Rotation = 45, BorderSizePixel = 0,
    }, chev)
    local c2 = New("Frame", {
        Size = UDim2.fromOffset(8, 2), Position = UDim2.fromOffset(6, 6), Rotation = -45, BorderSizePixel = 0,
    }, chev)
    Corner(c1, 1)
    Corner(c2, 1)
    OnTheme(function()
        c1.BackgroundColor3 = Theme.Muted
        c2.BackgroundColor3 = Theme.Muted
    end)

    local sec = { label = hdr, items = {}, collapsed = Collapsed[title] == true }
    function sec.refresh(animate)
        for _, it in ipairs(sec.items) do
            it.frame.Visible = not sec.collapsed
        end
        local rot = sec.collapsed and -90 or 0
        if animate then
            Tween(chev, 0.18, { Rotation = rot })
        else
            chev.Rotation = rot
        end
    end
    sec.refresh(false)

    hdr.MouseButton1Click:Connect(function()
        sec.collapsed = not sec.collapsed
        Collapsed[title] = sec.collapsed
        SaveCollapsed()
        sec.refresh(true)
    end)

    CurrentSection = sec
    SectionsByPage[page] = SectionsByPage[page] or {}
    table.insert(SectionsByPage[page], sec)
    return sec
end

local function Register(row)
    local sec = CurrentSection
    if sec then
        table.insert(sec.items, { frame = row })
        sec.refresh(false)
    end
end

local Refreshers = {}

--==================================================
-- COMPONENTS
--==================================================
local UpdateSummary = function() end

-- ---------- Toggle ----------
local function Toggle(page, opts)
    local row = Panel(page, UDim2.new(1, 0, 0, 66), "TextButton")
    HoverRow(row)
    Register(row)
    local rowStroke = row:FindFirstChildOfClass("UIStroke")

    local title = Text(row, opts.title, 14, FNT.B, "Text")
    title.Position = UDim2.fromOffset(20, 12)
    title.Size = UDim2.new(1, -100, 0, 20)

    local desc = Text(row, opts.desc or "", 12, FNT.R, "Muted")
    desc.Position = UDim2.fromOffset(20, 34)
    desc.Size = UDim2.new(1, -100, 0, 18)

    local strip = New("Frame", {
        Size = UDim2.fromOffset(4, 28),
        Position = UDim2.new(0, 4, 0.5, -14),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
    }, row)
    Corner(strip, 2)
    AccentGrad(strip, 90)

    local glow = New("Frame", {
        Size = UDim2.fromOffset(66, 42),
        Position = UDim2.new(1, -75, 0.5, -21),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
    }, row)
    Corner(glow, 21)
    AccentGrad(glow, 0)

    local track = New("Frame", {
        Size = UDim2.fromOffset(50, 28),
        Position = UDim2.new(1, -67, 0.5, -14),
        BorderSizePixel = 0,
    }, row)
    Corner(track, 14)
    local tStroke = Stroke(track, Theme.Stroke, 1, 0.2)

    local fill = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
    }, track)
    Corner(fill, 14)
    AccentGrad(fill, 0)

    local knob = New("Frame", {
        Size = UDim2.fromOffset(22, 22),
        Position = UDim2.fromOffset(3, 3),
        BorderSizePixel = 0,
    }, track)
    Corner(knob, 11)

    local state = Config[opts.key] == true

    local function render(animate)
        Apply(track, animate, { BackgroundColor3 = Theme.Button })
        Apply(fill, animate, { BackgroundTransparency = state and 0 or 1 })
        Apply(glow, animate, { BackgroundTransparency = state and 0.8 or 1 })
        Apply(knob, animate, {
            Position = state and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3),
            BackgroundColor3 = state and Color3.new(1, 1, 1) or Theme.Muted,
        })
        Apply(strip, animate, { BackgroundTransparency = state and 0 or 1 })
        Apply(tStroke, animate, { Color = state and Theme.Accent or Theme.Stroke })
        if rowStroke then
            Apply(rowStroke, animate, {
                Color = state and Theme.Accent or Theme.Stroke,
                Transparency = state and 0.4 or 0.35,
            })
        end
        UpdateSummary()
    end
    OnTheme(function()
        render(false)
    end)

    local function set(v, fire)
        state = v
        SetConfig(opts.key, v)
        render(true)
        if fire then
            PlayToggleSound(v)
            if opts.callback then
                task.spawn(opts.callback, v)
            end
        end
    end

    row.MouseButton1Click:Connect(function()
        set(not state, true)
    end)

    Refreshers[#Refreshers + 1] = function()
        state = Config[opts.key] == true
        render(false)
        if opts.callback then
            task.spawn(opts.callback, state)
        end
    end

    if opts.callback then
        task.defer(opts.callback, state)
    end

    return {
        Get = function()
            return state
        end,
        Set = function(v)
            set(v, true)
        end,
    }
end

-- ---------- Slider ----------
local function Slider(page, opts)
    local min, max, step = opts.min, opts.max, opts.step or 1
    local row = Panel(page, UDim2.new(1, 0, 0, 80))
    Register(row)

    local title = Text(row, opts.title, 14, FNT.B, "Text")
    title.Position = UDim2.fromOffset(18, 10)
    title.Size = UDim2.new(1, -120, 0, 20)

    local desc = Text(row, opts.desc or "", 12, FNT.R, "Muted")
    desc.Position = UDim2.fromOffset(18, 31)
    desc.Size = UDim2.new(1, -120, 0, 16)

    local pill = New("Frame", {
        Size = UDim2.fromOffset(84, 24),
        Position = UDim2.new(1, -100, 0, 10),
        BorderSizePixel = 0,
    }, row)
    Corner(pill, 12)
    Bind(pill, "BackgroundColor3", "Surface2")
    Bind(Stroke(pill, Theme.Accent, 1, 0.5), "Color", "Accent")
    local val = Text(row, "", 13, FNT.B, "Accent", Enum.TextXAlignment.Center)
    val.Position = UDim2.new(1, -100, 0, 10)
    val.Size = UDim2.fromOffset(84, 24)

    local bar = New("Frame", {
        Size = UDim2.new(1, -36, 0, 8),
        Position = UDim2.fromOffset(18, 62),
        BorderSizePixel = 0,
    }, row)
    Corner(bar, 4)
    Bind(bar, "BackgroundColor3", "Button")

    local fill = New("Frame", {
        Size = UDim2.fromScale(0, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, bar)
    Corner(fill, 4)
    AccentGrad(fill, 0)

    local knob = New("Frame", {
        Size = UDim2.fromOffset(18, 18),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, bar)
    Corner(knob, 9)
    Bind(Stroke(knob, Theme.Accent, 3, 0), "Color", "Accent")

    local hit = New("TextButton", {
        Size = UDim2.new(1, -36, 0, 30),
        Position = UDim2.fromOffset(18, 50),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, row)

    local value = math.clamp(Config[opts.key], min, max)

    local function show()
        local a = (value - min) / (max - min)
        fill.Size = UDim2.fromScale(a, 1)
        knob.Position = UDim2.fromScale(a, 0.5)
        val.Text = string.format("%g", value) .. (opts.suffix or "")
    end

    local function setValue(v, fire)
        v = math.clamp(math.floor((v - min) / step + 0.5) * step + min, min, max)
        if v == value and fire then
            return
        end
        value = v
        show()
        if fire then
            SetConfig(opts.key, v)
            if opts.callback then
                task.spawn(opts.callback, v)
            end
        end
    end

    local dragging = false
    local function fromX(x)
        local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
        setValue(min + (max - min) * a, true)
    end

    hit.InputBegan:Connect(function(input)
        if IsPointer(input) then
            dragging = true
            page.ScrollingEnabled = false
            Tween(knob, 0.12, { Size = UDim2.fromOffset(23, 23) })
            fromX(input.Position.X)
        end
    end)
    Track(UIS.InputChanged:Connect(function(input)
        if dragging and IsMove(input) then
            fromX(input.Position.X)
        end
    end))
    Track(UIS.InputEnded:Connect(function(input)
        if dragging and IsPointer(input) then
            dragging = false
            page.ScrollingEnabled = true
            Tween(knob, 0.12, { Size = UDim2.fromOffset(18, 18) })
        end
    end))

    show()

    Refreshers[#Refreshers + 1] = function()
        value = math.clamp(Config[opts.key], min, max)
        show()
        if opts.callback then
            task.spawn(opts.callback, value)
        end
    end

    if opts.callback then
        task.defer(opts.callback, value)
    end
end

-- ---------- Dropdown (เดี่ยว / หลายตัวเลือก) ----------
local function Split(s)
    local t = {}
    for v in string.gmatch(s or "", "[^|]+") do
        t[#t + 1] = v
    end
    return t
end

local function Dropdown(page, opts)
    local HEAD, ITEM = 62, 34
    local options = opts.options
    local multi = opts.multi == true
    local row = Panel(page, UDim2.new(1, 0, 0, HEAD))
    row.ClipsDescendants = true
    Register(row)

    local head = New("TextButton", {
        Size = UDim2.new(1, 0, 0, HEAD),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, row)

    local title = Text(head, opts.title, 14, FNT.B, "Text")
    title.Position = UDim2.fromOffset(20, 12)
    title.Size = UDim2.new(1, -200, 0, 20)
    local desc = Text(head, opts.desc or "", 12, FNT.R, "Muted")
    desc.Position = UDim2.fromOffset(20, 33)
    desc.Size = UDim2.new(1, -200, 0, 18)

    local pill = New("Frame", {
        Size = UDim2.fromOffset(150, 32),
        Position = UDim2.new(1, -166, 0.5, -16),
        BorderSizePixel = 0,
    }, head)
    Corner(pill, 16)
    Bind(pill, "BackgroundColor3", "Surface2")
    Bind(Stroke(pill, Theme.Accent, 1, 0.5), "Color", "Accent")
    local vlabel = Text(pill, "", 12, FNT.B, "Accent", Enum.TextXAlignment.Center)
    vlabel.Position = UDim2.fromOffset(10, 0)
    vlabel.Size = UDim2.new(1, -34, 1, 0)

    local arrow = New("Frame", {
        Size = UDim2.fromOffset(12, 12),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0),
        BackgroundTransparency = 1,
    }, pill)
    local a1 = New("Frame", { Size = UDim2.fromOffset(7, 2), Position = UDim2.fromOffset(0, 5), Rotation = 45, BorderSizePixel = 0 }, arrow)
    local a2 = New("Frame", { Size = UDim2.fromOffset(7, 2), Position = UDim2.fromOffset(5, 5), Rotation = -45, BorderSizePixel = 0 }, arrow)
    Corner(a1, 1)
    Corner(a2, 1)
    OnTheme(function()
        a1.BackgroundColor3 = Theme.Accent
        a2.BackgroundColor3 = Theme.Accent
    end)

    local list = New("Frame", {
        Size = UDim2.new(1, -24, 0, #options * ITEM),
        Position = UDim2.fromOffset(12, HEAD),
        BackgroundTransparency = 1,
    }, row)
    List(list, 0)

    local selected = {} -- set
    local function readSelected()
        selected = {}
        if multi then
            for _, v in ipairs(Split(Config[opts.key])) do
                selected[v] = true
            end
        else
            selected[Config[opts.key]] = true
        end
    end
    readSelected()

    local optionButtons = {}
    local function renderValue()
        if multi then
            local n = 0
            local names = {}
            for _, o in ipairs(options) do
                if selected[o] then
                    n = n + 1
                    names[#names + 1] = o
                end
            end
            vlabel.Text = n == 0 and "ไม่เลือก" or (n <= 2 and table.concat(names, ", ") or (n .. " รายการ"))
        else
            vlabel.Text = tostring(Config[opts.key])
        end
    end

    local function renderOptions(animate)
        for o, b in pairs(optionButtons) do
            local on = selected[o] == true
            Apply(b.bg, animate, {
                BackgroundColor3 = Theme.Accent,
                BackgroundTransparency = on and 0.8 or 1,
            })
            Apply(b.dot, animate, { BackgroundTransparency = on and 0 or 0.7 })
            b.lbl.TextColor3 = on and Theme.Text or Theme.Sub
        end
        renderValue()
    end

    for i, o in ipairs(options) do
        local b = New("TextButton", {
            Size = UDim2.new(1, 0, 0, ITEM),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = i,
        }, list)
        local bg = New("Frame", {
            Size = UDim2.new(1, 0, 1, -4),
            Position = UDim2.fromOffset(0, 2),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
        }, b)
        Corner(bg, 10)
        local dot = New("Frame", {
            Size = UDim2.fromOffset(10, 10),
            Position = UDim2.new(0, 12, 0.5, -5),
            BorderSizePixel = 0,
        }, bg)
        Corner(dot, multi and 3 or 5)
        Bind(dot, "BackgroundColor3", "Accent")
        local lbl = Text(bg, o, 13, FNT.M)
        lbl.Position = UDim2.fromOffset(32, 0)
        lbl.Size = UDim2.new(1, -40, 1, 0)
        optionButtons[o] = { bg = bg, dot = dot, lbl = lbl }

        b.MouseButton1Click:Connect(function()
            if multi then
                selected[o] = not selected[o]
                local t = {}
                for _, name in ipairs(options) do
                    if selected[name] then
                        t[#t + 1] = name
                    end
                end
                SetConfig(opts.key, table.concat(t, "|"))
            else
                selected = { [o] = true }
                SetConfig(opts.key, o)
            end
            renderOptions(true)
            PlayToggleSound(true)
            if opts.callback then
                task.spawn(opts.callback, multi and Split(Config[opts.key]) or o)
            end
        end)
    end
    OnTheme(function()
        renderOptions(false)
    end)

    local open = false
    local function setOpen(v)
        open = v
        Tween(row, 0.24, {
            Size = UDim2.new(1, 0, 0, open and (HEAD + #options * ITEM + 10) or HEAD),
        }, Enum.EasingStyle.Quint)
        Tween(arrow, 0.2, { Rotation = open and 180 or 0 })
    end
    head.MouseButton1Click:Connect(function()
        setOpen(not open)
    end)

    Refreshers[#Refreshers + 1] = function()
        readSelected()
        renderOptions(false)
        if opts.callback then
            task.spawn(opts.callback, multi and Split(Config[opts.key]) or Config[opts.key])
        end
    end

    if opts.callback then
        task.defer(opts.callback, multi and Split(Config[opts.key]) or Config[opts.key])
    end
end

-- ---------- Button (มีริปเปิลตอนกด) ----------
local function Button(page, opts)
    local row = Panel(page, UDim2.new(1, 0, 0, 62))
    Register(row)

    local title = Text(row, opts.title, 14, FNT.B, "Text")
    title.Position = UDim2.fromOffset(20, 11)
    title.Size = UDim2.new(1, -160, 0, 20)
    local desc = Text(row, opts.desc or "", 12, FNT.R, "Muted")
    desc.Position = UDim2.fromOffset(20, 33)
    desc.Size = UDim2.new(1, -160, 0, 18)

    local btn = New("TextButton", {
        Size = UDim2.fromOffset(118, 36),
        Position = UDim2.new(1, -134, 0.5, -18),
        BorderSizePixel = 0,
        Text = opts.text or "กด",
        TextSize = 13,
        AutoButtonColor = false,
        ClipsDescendants = true,
    }, row)
    SetFont(btn, FNT.B)
    Corner(btn, 18)
    local danger = opts.danger == true
    if danger then
        Bind(btn, "BackgroundColor3", "Bad")
        btn.TextColor3 = Color3.new(1, 1, 1)
    else
        btn.BackgroundColor3 = Color3.new(1, 1, 1)
        AccentGrad(btn, 0)
        Bind(btn, "TextColor3", "OnAccent")
    end

    local sc = New("UIScale", { Scale = 1 }, btn)
    btn.MouseEnter:Connect(function()
        Tween(sc, 0.12, { Scale = 1.04 })
    end)
    btn.MouseLeave:Connect(function()
        Tween(sc, 0.12, { Scale = 1 })
    end)
    btn.MouseButton1Down:Connect(function(x, y)
        Tween(sc, 0.08, { Scale = 0.95 })
        pcall(function()
            local rel = (Vector2.new(x, y) - btn.AbsolutePosition) / math.max(0.1, MainScale.Scale)
            local rip = New("Frame", {
                Size = UDim2.fromOffset(4, 4),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromOffset(rel.X, rel.Y),
                BorderSizePixel = 0,
                BackgroundColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 0.4,
            }, btn)
            Corner(rip, 999)
            Tween(rip, 0.5, { Size = UDim2.fromOffset(190, 190), BackgroundTransparency = 1 }, Enum.EasingStyle.Quint)
            Debris:AddItem(rip, 0.6)
        end)
    end)
    btn.MouseButton1Up:Connect(function()
        Tween(sc, 0.18, { Scale = 1.04 }, Enum.EasingStyle.Back)
    end)
    btn.MouseButton1Click:Connect(function()
        PlayToggleSound(true)
        if opts.callback then
            task.spawn(opts.callback)
        end
    end)
    return { Button = btn }
end

-- ---------- TextBox ----------
local function Input(page, opts)
    local row = Panel(page, UDim2.new(1, 0, 0, 62))
    Register(row)

    local title = Text(row, opts.title, 14, FNT.B, "Text")
    title.Position = UDim2.fromOffset(20, 11)
    title.Size = UDim2.new(1, -240, 0, 20)
    local desc = Text(row, opts.desc or "", 12, FNT.R, "Muted")
    desc.Position = UDim2.fromOffset(20, 33)
    desc.Size = UDim2.new(1, -240, 0, 18)

    local box = New("TextBox", {
        Size = UDim2.fromOffset(200, 34),
        Position = UDim2.new(1, -216, 0.5, -17),
        BorderSizePixel = 0,
        Text = tostring(Config[opts.key] or ""),
        PlaceholderText = opts.placeholder or "พิมพ์ที่นี่...",
        ClearTextOnFocus = false,
        TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)
    SetFont(box, FNT.M)
    Corner(box, 17)
    Pad(box, 14, 14, 0, 0)
    local bst = Stroke(box, Theme.Stroke, 1, 0.3)
    OnTheme(function()
        box.BackgroundColor3 = Theme.Surface2
        box.TextColor3 = Theme.Text
        box.PlaceholderColor3 = Theme.Muted
        bst.Color = Theme.Stroke
    end)
    box.Focused:Connect(function()
        Tween(bst, 0.15, { Color = Theme.Accent, Transparency = 0 })
    end)
    box.FocusLost:Connect(function(enter)
        Tween(bst, 0.15, { Color = Theme.Stroke, Transparency = 0.3 })
        SetConfig(opts.key, box.Text)
        if opts.callback then
            task.spawn(opts.callback, box.Text, enter)
        end
    end)
    Refreshers[#Refreshers + 1] = function()
        box.Text = tostring(Config[opts.key] or "")
        if opts.callback then
            task.spawn(opts.callback, box.Text, false)
        end
    end
    return box
end

-- ---------- Keybind ----------
local Listening = nil
local function Keybind(page, opts)
    local row = Panel(page, UDim2.new(1, 0, 0, 62))
    Register(row)
    local title = Text(row, opts.title, 14, FNT.B, "Text")
    title.Position = UDim2.fromOffset(20, 11)
    title.Size = UDim2.new(1, -170, 0, 20)
    local desc = Text(row, opts.desc or "", 12, FNT.R, "Muted")
    desc.Position = UDim2.fromOffset(20, 33)
    desc.Size = UDim2.new(1, -170, 0, 18)

    local btn = New("TextButton", {
        Size = UDim2.fromOffset(130, 34),
        Position = UDim2.new(1, -146, 0.5, -17),
        BorderSizePixel = 0,
        Text = "",
        TextSize = 13,
        AutoButtonColor = false,
    }, row)
    SetFont(btn, FNT.B)
    Corner(btn, 17)
    local bst = Stroke(btn, Theme.Accent, 1, 0.4)
    local waiting = false
    local function render()
        btn.BackgroundColor3 = Theme.Surface2
        btn.TextColor3 = waiting and Theme.Accent2 or Theme.Accent
        btn.Text = waiting and "กดปุ่มที่ต้องการ..." or tostring(Config[opts.key])
        bst.Color = waiting and Theme.Accent2 or Theme.Accent
    end
    OnTheme(render)
    btn.MouseButton1Click:Connect(function()
        waiting = true
        Listening = function(name)
            waiting = false
            Listening = nil
            if name ~= "Escape" then
                SetConfig(opts.key, name)
                Toast("ตั้งปุ่มเป็น " .. name, true)
            end
            render()
        end
        render()
    end)
    Refreshers[#Refreshers + 1] = render
end

Track(UIS.InputBegan:Connect(function(input, processed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end
    if Listening then
        Listening(input.KeyCode.Name)
        return
    end
    if processed then
        return
    end
    if input.KeyCode.Name == Config.ToggleKey then
        SetWindow(not Config.WindowVisible)
    end
end))

-- ---------- Status (จุดสี + ข้อความ) ----------
local StatusColors = { idle = "Muted", ok = "Good", warn = "Warn", bad = "Bad", busy = "Accent2" }

local function StatusRow(page, opts)
    local row = Panel(page, UDim2.new(1, 0, 0, 54))
    Register(row)

    local dot = New("Frame", {
        Size = UDim2.fromOffset(12, 12),
        Position = UDim2.fromOffset(20, 21),
        BorderSizePixel = 0,
    }, row)
    Corner(dot, 6)
    local halo = New("Frame", {
        Size = UDim2.fromOffset(12, 12),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BorderSizePixel = 0,
        BackgroundTransparency = 0.6,
    }, dot)
    Corner(halo, 999)

    local title = Text(row, opts.title, 14, FNT.B, "Text")
    title.Position = UDim2.fromOffset(44, 8)
    title.Size = UDim2.new(1, -170, 0, 20)
    local sub = Text(row, opts.desc or "", 12, FNT.R, "Muted")
    sub.Position = UDim2.fromOffset(44, 28)
    sub.Size = UDim2.new(1, -170, 0, 18)

    local tag = New("TextLabel", {
        Size = UDim2.fromOffset(100, 26),
        Position = UDim2.new(1, -116, 0.5, -13),
        BorderSizePixel = 0,
        Text = "",
        TextSize = 12,
    }, row)
    SetFont(tag, FNT.B)
    Corner(tag, 13)

    local state, label = opts.state or "idle", opts.label or "ว่าง"
    local pulse
    local function render()
        local c = Theme[StatusColors[state] or "Muted"]
        dot.BackgroundColor3 = c
        halo.BackgroundColor3 = c
        tag.BackgroundColor3 = c:Lerp(Theme.Bg, 0.82)
        tag.TextColor3 = c:Lerp(Theme.Text, Theme.Dark and 0.1 or 0.35)
        tag.Text = label
    end
    OnTheme(render)

    local function startPulse()
        if pulse then
            pulse:Cancel()
            pulse = nil
        end
        halo.Size = UDim2.fromOffset(12, 12)
        halo.BackgroundTransparency = 0.6
        if state == "ok" or state == "busy" then
            pulse = TweenService:Create(
                halo,
                TweenInfo.new(state == "busy" and 0.8 or 1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1),
                { Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1 }
            )
            pulse:Play()
        end
    end
    startPulse()

    return {
        Set = function(newState, newLabel)
            state = newState or state
            label = newLabel or label
            render()
            startPulse()
        end,
    }
end

-- ============================================================
--  COLOR PICKER  (สี่เหลี่ยมเฉด + แถบ Hue + HEX + พรีเซ็ต)
-- ============================================================
local PaletteColors = {
    "FFF6EA", "F7E4CF", "FFD9E2", "F4A0B5", "EFA53A", "E07A5F", "B5838D", "8D6E63",
    "81B29A", "A8DADC", "9DB4FF", "C3B1E1", "2B2D42", "1B1B2F", "FFFFFF", "000000",
}

local ActiveOverlay, ActivePopup
local PaletteConns = {}

local function ClosePalette()
    for _, c in ipairs(PaletteConns) do
        pcall(function()
            c:Disconnect()
        end)
    end
    PaletteConns = {}
    if ActiveOverlay then
        ActiveOverlay:Destroy()
        ActiveOverlay = nil
    end
    if ActivePopup then
        ActivePopup:Destroy()
        ActivePopup = nil
    end
end

local themePending = false
local function QueueTheme()
    if themePending then
        return
    end
    themePending = true
    task.defer(function()
        themePending = false
        ApplyTheme()
    end)
end

local function OpenPalette(title, key, onPick)
    ClosePalette()

    ActiveOverlay = New("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 150,
    }, Screen)
    Tween(ActiveOverlay, 0.2, { BackgroundTransparency = 0.5 })
    ActiveOverlay.MouseButton1Click:Connect(ClosePalette)

    local PW, PH = 240, 304
    local pop = New("CanvasGroup", {
        Size = UDim2.fromOffset(PW, PH),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundColor3 = Theme.Bg,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        ZIndex = 160,
        Active = true,
    }, Screen)
    Corner(pop, 18)
    Stroke(pop, Theme.Accent, 1.5, 0.3)
    local vs = ViewSize()
    New("UIScale", { Scale = math.clamp((vs.Y - 24) / PH, 0.5, 1) }, pop)
    ActivePopup = pop
    Tween(pop, 0.2, { GroupTransparency = 0 })

    local okc, c0 = pcall(Color3.fromHex, Config[key])
    if not okc then
        c0 = Color3.new(1, 1, 1)
    end
    local H, S, V = c0:ToHSV()

    local ttl = Text(pop, title or "เลือกสี", 14, FNT.B, Theme.Text)
    ttl.Position = UDim2.fromOffset(14, 10)
    ttl.Size = UDim2.new(1, -130, 0, 20)

    local prev = New("Frame", {
        Size = UDim2.fromOffset(36, 18),
        Position = UDim2.fromOffset(PW - 82, 11),
        BorderSizePixel = 0,
    }, pop)
    Corner(prev, 9)
    Stroke(prev, Theme.Stroke, 1, 0.3)

    local closeB = New("TextButton", {
        Size = UDim2.fromOffset(24, 24),
        Position = UDim2.fromOffset(PW - 38, 8),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        Text = "×",
        TextSize = 18,
        TextColor3 = Theme.Sub,
        AutoButtonColor = false,
    }, pop)
    SetFont(closeB, FNT.B)
    Corner(closeB, 12)
    closeB.MouseButton1Click:Connect(ClosePalette)

    local sv = New("Frame", {
        Size = UDim2.fromOffset(PW - 28, 124),
        Position = UDim2.fromOffset(14, 40),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromHSV(H, 1, 1),
    }, pop)
    Corner(sv, 10)
    local wf = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, sv)
    Corner(wf, 10)
    New("UIGradient", { Transparency = NumberSequence.new(0, 1) }, wf)
    local bf = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(0, 0, 0),
    }, sv)
    Corner(bf, 10)
    New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }, bf)
    local svCur = New("Frame", {
        Size = UDim2.fromOffset(16, 16),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, sv)
    Corner(svCur, 8)
    Stroke(svCur, Color3.new(1, 1, 1), 2.5, 0)
    local svHit = New("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, sv)

    local hue = New("Frame", {
        Size = UDim2.fromOffset(PW - 28, 14),
        Position = UDim2.fromOffset(14, 176),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, pop)
    Corner(hue, 7)
    New("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
        }),
    }, hue)
    local hueCur = New("Frame", {
        Size = UDim2.fromOffset(18, 18),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BorderSizePixel = 0,
    }, hue)
    Corner(hueCur, 9)
    Stroke(hueCur, Color3.new(1, 1, 1), 2.5, 0)
    local hueHit = New("TextButton", {
        Size = UDim2.new(1, 0, 1, 12),
        Position = UDim2.fromOffset(0, -6),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, hue)

    local box = New("TextBox", {
        Size = UDim2.fromOffset(PW - 28, 30),
        Position = UDim2.fromOffset(14, 202),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = "#RRGGBB",
        ClearTextOnFocus = false,
        TextSize = 12,
        TextColor3 = Theme.Text,
        PlaceholderColor3 = Theme.Muted,
    }, pop)
    SetFont(box, FNT.M)
    Corner(box, 15)
    Stroke(box, Theme.Stroke, 1, 0.3)

    local function render(fromBox)
        local c = Color3.fromHSV(H, S, V)
        sv.BackgroundColor3 = Color3.fromHSV(H, 1, 1)
        svCur.Position = UDim2.fromScale(S, 1 - V)
        hueCur.Position = UDim2.fromScale(H, 0.5)
        hueCur.BackgroundColor3 = Color3.fromHSV(H, 1, 1)
        prev.BackgroundColor3 = c
        if not fromBox then
            box.Text = "#" .. string.upper(c:ToHex())
        end
        return c
    end
    local function commit(fromBox)
        onPick(render(fromBox))
    end
    render(false)

    local function bindDrag(hit, onMove)
        local dragging, dInput = false, nil
        local off = Vector2.zero
        hit.InputBegan:Connect(function(input)
            if not IsPointer(input) then
                return
            end
            local p = Vector2.new(input.Position.X, input.Position.Y)
            local a, sz = hit.AbsolutePosition, hit.AbsoluteSize
            local inset = GuiService:GetGuiInset()
            local q = p + inset
            local inside = q.X >= a.X and q.X <= a.X + sz.X and q.Y >= a.Y and q.Y <= a.Y + sz.Y
            off = inside and inset or Vector2.zero
            dragging = true
            dInput = input
            onMove(p + off)
        end)
        PaletteConns[#PaletteConns + 1] = UIS.InputChanged:Connect(function(input)
            if dragging and IsMove(input) then
                if input.UserInputType == Enum.UserInputType.Touch and input ~= dInput then
                    return
                end
                onMove(Vector2.new(input.Position.X, input.Position.Y) + off)
            end
        end)
        PaletteConns[#PaletteConns + 1] = UIS.InputEnded:Connect(function(input)
            if dragging and IsPointer(input) then
                if input.UserInputType == Enum.UserInputType.Touch and input ~= dInput then
                    return
                end
                dragging = false
            end
        end)
    end

    bindDrag(svHit, function(pos)
        S = math.clamp((pos.X - sv.AbsolutePosition.X) / math.max(1, sv.AbsoluteSize.X), 0, 1)
        V = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / math.max(1, sv.AbsoluteSize.Y), 0, 1)
        commit(false)
    end)
    bindDrag(hueHit, function(pos)
        H = math.clamp((pos.X - hue.AbsolutePosition.X) / math.max(1, hue.AbsoluteSize.X), 0, 1)
        commit(false)
    end)

    box.FocusLost:Connect(function()
        local h = string.match(box.Text, "^%s*#?(%x%x%x%x%x%x)%s*$")
        if h then
            H, S, V = Color3.fromHex(h):ToHSV()
            commit(false)
        else
            box.TextColor3 = Theme.Bad
            task.delay(0.8, function()
                if box.Parent then
                    box.TextColor3 = Theme.Text
                    render(false)
                end
            end)
        end
    end)

    for i, hexv in ipairs(PaletteColors) do
        local c = Color3.fromHex(hexv)
        local sw = New("TextButton", {
            Size = UDim2.fromOffset(22, 22),
            Position = UDim2.fromOffset(14 + ((i - 1) % 8) * 27, 244 + math.floor((i - 1) / 8) * 28),
            BackgroundColor3 = c,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
        }, pop)
        Corner(sw, 11)
        Stroke(sw, Theme.Stroke, 1, 0.3)
        sw.MouseButton1Click:Connect(function()
            H, S, V = c:ToHSV()
            commit(false)
        end)
    end
end

local ColorRefreshers = {}

local function ColorRow(page, title, key)
    local row = Panel(page, UDim2.new(1, 0, 0, 52), "TextButton")
    HoverRow(row)
    Register(row)

    local t = Text(row, title, 13, FNT.B, "Text")
    t.Position = UDim2.fromOffset(20, 0)
    t.Size = UDim2.new(1, -180, 1, 0)

    local hexLabel = Text(row, "", 11, FNT.M, "Muted", Enum.TextXAlignment.Right)
    hexLabel.Position = UDim2.new(1, -158, 0, 0)
    hexLabel.Size = UDim2.fromOffset(84, 52)

    local swatch = New("Frame", {
        Size = UDim2.fromOffset(44, 26),
        Position = UDim2.new(1, -62, 0.5, -13),
        BorderSizePixel = 0,
    }, row)
    Corner(swatch, 13)
    Bind(Stroke(swatch, Theme.Stroke, 1.2, 0.2), "Color", "Stroke")

    local function refresh()
        swatch.BackgroundColor3 = Hex(key, RGB(200, 200, 200))
        hexLabel.Text = string.upper(tostring(Config[key]))
    end
    refresh()
    Refreshers[#Refreshers + 1] = refresh
    ColorRefreshers[#ColorRefreshers + 1] = refresh

    row.MouseButton1Click:Connect(function()
        OpenPalette(title, key, function(c)
            SetConfig(key, "#" .. string.upper(c:ToHex()))
            refresh()
            QueueTheme()
        end)
    end)
end

-- ธีมสำเร็จรูป (แตะครั้งเดียวเปลี่ยนทั้ง UI)
local ThemePresets = {
    { "Honey", "#EFA53A", "#F4A0B5", "#FFF6EA", "#F7E4CF" },
    { "Sakura", "#F26D9A", "#FFB7C9", "#FFF0F4", "#FBD9E3" },
    { "Mint", "#3DB59A", "#A8E0CF", "#F0FBF7", "#D5F0E6" },
    { "Sky", "#5B8DEF", "#9ED0F5", "#F1F7FF", "#DCE9FB" },
    { "Moonlit", "#C3A2FF", "#F2A6C8", "#17141F", "#2A2438" },
    { "Cocoa", "#E9A76B", "#F0B8C4", "#1E1714", "#33261F" },
}

local function ThemeGrid(page)
    local holder = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = Next(page),
    }, page)
    New("UIGridLayout", {
        CellSize = UDim2.new(1 / 3, -7, 0, 58),
        CellPadding = UDim2.fromOffset(10, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, holder)
    Register(holder)

    for _, p in ipairs(ThemePresets) do
        local card = Panel(holder, nil, "TextButton")
        HoverRow(card)

        local function dot(hex, x)
            local d = New("Frame", {
                Size = UDim2.fromOffset(22, 22),
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, x, 0.5, 0),
                BorderSizePixel = 0,
                BackgroundColor3 = Color3.fromHex(hex),
            }, card)
            Corner(d, 11)
            Stroke(d, Color3.new(0, 0, 0), 1, 0.85)
        end
        dot(p[4], 12)
        dot(p[3], 26)
        dot(p[2], 40)

        local n = Text(card, p[1], 13, FNT.B, "Text")
        n.Position = UDim2.fromOffset(72, 0)
        n.Size = UDim2.new(1, -78, 1, 0)

        card.MouseButton1Click:Connect(function()
            SetConfig("UIAccentColor", p[2])
            SetConfig("UIAccent2Color", p[3])
            SetConfig("UIBackgroundColor", p[4])
            SetConfig("UIButtonColor", p[5])
            for _, fn in ipairs(ColorRefreshers) do
                pcall(fn)
            end
            QueueTheme()
            Toast("ใช้ธีม " .. p[1])
        end)
    end
end

--==================================================
-- HOME
--==================================================
local ActiveCountGetters = {}
local RefreshHome
do
local Home = MakePage("Home", "หน้าหลัก", "ภาพรวมและข้อมูลเซิร์ฟเวอร์")

local Hero = Panel(Home, UDim2.new(1, 0, 0, 92))
Tint(Hero)
local HeroSub = Text(Hero, "", 12, FNT.M, "Muted")
HeroSub.Position = UDim2.fromOffset(22, 14)
HeroSub.Size = UDim2.new(0.6, 0, 0, 16)
local HeroName = Text(Hero, LocalPlayer.DisplayName, 26, FNT.X, Color3.new(1, 1, 1))
HeroName.Position = UDim2.fromOffset(22, 34)
HeroName.Size = UDim2.new(0.6, 0, 0, 42)
AccentGrad(HeroName, 0)
local HeroClock = Text(Hero, "", 28, FNT.X, "Text", Enum.TextXAlignment.Right)
HeroClock.Position = UDim2.new(0.5, 0, 0, 16)
HeroClock.Size = UDim2.new(0.5, -22, 0, 36)
local HeroDate = Text(Hero, "", 11, FNT.M, "Muted", Enum.TextXAlignment.Right)
HeroDate.Position = UDim2.new(0.5, 0, 0, 56)
HeroDate.Size = UDim2.new(0.5, -22, 0, 16)

local MapImageUrl = "rbxthumb://type=GameIcon&id=" .. tostring(game.GameId) .. "&w=150&h=150"

local MapCard = Panel(Home, UDim2.new(1, 0, 0, 118))
MapCard.ClipsDescendants = true
local MapBG = New("ImageLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Image = MapImageUrl,
    ScaleType = Enum.ScaleType.Crop,
    ImageTransparency = 0.88,
}, MapCard)
Corner(MapBG, 14)
Tint(MapCard)

local MapIcon = New("ImageLabel", {
    Size = UDim2.fromOffset(86, 86),
    Position = UDim2.fromOffset(16, 16),
    BorderSizePixel = 0,
    Image = MapImageUrl,
    ScaleType = Enum.ScaleType.Crop,
}, MapCard)
Corner(MapIcon, 20)
Bind(MapIcon, "BackgroundColor3", "Button")
Bind(Stroke(MapIcon, Theme.Accent, 2, 0.2), "Color", "Accent")

local MapName = Text(MapCard, tostring(game.Name or "Unknown"), 18, FNT.X, "Text")
MapName.Position = UDim2.fromOffset(114, 16)
MapName.Size = UDim2.new(1, -130, 0, 26)
local MapBy = Text(MapCard, "กำลังโหลดข้อมูลแมพ...", 12, FNT.R, "Muted")
MapBy.Position = UDim2.fromOffset(114, 44)
MapBy.Size = UDim2.new(1, -130, 0, 16)

local Chips = New("Frame", {
    Size = UDim2.new(1, -130, 0, 26),
    Position = UDim2.fromOffset(114, 74),
    BackgroundTransparency = 1,
}, MapCard)
New("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, Chips)

local function Chip(text)
    local c = New("TextLabel", {
        Size = UDim2.fromOffset(0, 26),
        AutomaticSize = Enum.AutomaticSize.X,
        BorderSizePixel = 0,
        Text = text,
        TextSize = 11,
        LayoutOrder = Next(Chips),
    }, Chips)
    SetFont(c, FNT.M)
    Bind(c, "BackgroundColor3", "Surface2")
    Bind(c, "TextColor3", "Sub")
    Corner(c, 13)
    Pad(c, 11, 11, 0, 0)
    return c
end

Chip("ID " .. tostring(game.PlaceId))
local ChipPlayers = Chip("ผู้เล่น -/-")

task.spawn(function()
    pcall(function()
        local info = MarketplaceService:GetProductInfo(game.PlaceId)
        if info then
            if info.Name and info.Name ~= "" then
                MapName.Text = tostring(info.Name)
                BrandSub.Text = tostring(info.Name)
            end
            if info.Creator and info.Creator.Name then
                MapBy.Text = "โดย " .. tostring(info.Creator.Name)
            else
                MapBy.Text = ""
            end
        end
    end)
end)

local function Stat(parent, label)
    local c = Panel(parent)
    local bar = New("Frame", {
        Size = UDim2.fromOffset(4, 20),
        Position = UDim2.fromOffset(0, 12),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, c)
    Corner(bar, 2)
    AccentGrad(bar, 90)
    local l = Text(c, label, 11, FNT.M, "Muted")
    l.Position = UDim2.fromOffset(18, 11)
    l.Size = UDim2.new(1, -30, 0, 14)
    local v = Text(c, "-", 16, FNT.X, "Text")
    v.Position = UDim2.fromOffset(18, 30)
    v.Size = UDim2.new(1, -30, 0, 24)
    return v
end

local Grid = New("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    LayoutOrder = Next(Home),
}, Home)
New("UIGridLayout", {
    CellSize = UDim2.new(0.5, -5, 0, 66),
    CellPadding = UDim2.fromOffset(10, 10),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, Grid)

local StatPlayer = Stat(Grid, "ผู้เล่น")
local StatTime = Stat(Grid, "เวลาในเซิร์ฟ")
local StatFps = Stat(Grid, "FPS")
local StatPing = Stat(Grid, "Ping")

-- สรุปฟังก์ชันที่เปิดอยู่
local SummaryCard = Panel(Home, UDim2.new(1, 0, 0, 58))
local SummaryDot = New("Frame", {
    Size = UDim2.fromOffset(12, 12),
    Position = UDim2.fromOffset(20, 23),
    BorderSizePixel = 0,
}, SummaryCard)
Corner(SummaryDot, 6)
local SummaryText = Text(SummaryCard, "", 14, FNT.B, "Text")
SummaryText.Position = UDim2.fromOffset(44, 0)
SummaryText.Size = UDim2.new(1, -60, 1, 0)

local PerfCard = Panel(Home, UDim2.new(1, 0, 0, 124))
Tint(PerfCard)
local PerfTitle = Text(PerfCard, "ประสิทธิภาพ (FPS)", 13, FNT.B, "Text")
PerfTitle.Position = UDim2.fromOffset(18, 12)
PerfTitle.Size = UDim2.new(0.5, 0, 0, 18)
local PerfAvg = Text(PerfCard, "", 12, FNT.M, "Sub", Enum.TextXAlignment.Right)
PerfAvg.Position = UDim2.new(0.5, 0, 0, 12)
PerfAvg.Size = UDim2.new(0.5, -18, 0, 18)
local PerfBars = New("Frame", {
    Size = UDim2.new(1, -36, 0, 70),
    Position = UDim2.fromOffset(18, 42),
    BackgroundTransparency = 1,
}, PerfCard)

local PERF_N = 36
local PerfBar, PerfHist = {}, {}
for i = 1, PERF_N do
    local b = New("Frame", {
        Size = UDim2.new(1 / PERF_N, -2, 0, 2),
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new((i - 1) / PERF_N, 1, 1, 0),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
    }, PerfBars)
    Corner(b, 3)
    PerfBar[i] = b
    PerfHist[i] = 0
end

local function PerfUpdate()
    table.remove(PerfHist, 1)
    PerfHist[#PerfHist + 1] = Metrics.fps
    local peak, sum, cnt = 60, 0, 0
    for _, v in ipairs(PerfHist) do
        if v > peak then
            peak = v
        end
        if v > 0 then
            sum = sum + v
            cnt = cnt + 1
        end
    end
    for i, v in ipairs(PerfHist) do
        local b = PerfBar[i]
        b.Size = UDim2.new(1 / PERF_N, -2, math.clamp(v / peak, 0.04, 1), 0)
        b.BackgroundColor3 = Level(v, 50, 30, true)
        b.BackgroundTransparency = v == 0 and 1 or 0.08
    end
    PerfAvg.Text = "เฉลี่ย " .. tostring(cnt > 0 and math.floor(sum / cnt + 0.5) or 0) .. " FPS"
end

local sessionStart = os.time()

UpdateSummary = function()
    local n = 0
    for _, g in ipairs(ActiveCountGetters) do
        if g() then
            n = n + 1
        end
    end
    SummaryText.Text = n == 0 and "ยังไม่มีฟังก์ชันที่เปิดอยู่" or ("เปิดใช้งานอยู่ " .. n .. " ฟังก์ชัน")
    SummaryDot.BackgroundColor3 = n == 0 and Theme.Muted or Theme.Good
end

RefreshHome = function()
    local hr = tonumber(os.date("%H")) or 12
    HeroSub.Text = (hr >= 5 and hr < 12 and "อรุณสวัสดิ์")
        or (hr >= 12 and hr < 17 and "สวัสดีตอนบ่าย")
        or (hr >= 17 and hr < 21 and "สวัสดีตอนเย็น")
        or "ราตรีสวัสดิ์"
    HeroClock.Text = os.date("%H:%M")
    HeroDate.Text = os.date("%d / %m / %Y")
    local sec = math.max(0, os.time() - sessionStart)
    StatPlayer.Text = LocalPlayer.DisplayName
    StatTime.Text = string.format("%02d:%02d:%02d", math.floor(sec / 3600), math.floor((sec % 3600) / 60), sec % 60)
    StatFps.Text = tostring(Metrics.fps)
    StatFps.TextColor3 = Level(Metrics.fps, 50, 30, true)
    StatPing.Text = tostring(Metrics.ping) .. " ms"
    StatPing.TextColor3 = Level(Metrics.ping, 80, 160, false)
    ChipPlayers.Text = string.format("ผู้เล่น %d/%d", #Players:GetPlayers(), Players.MaxPlayers)
    PerfUpdate()
end

task.spawn(function()
    while Screen.Parent do
        RefreshStats()
        RefreshHome()
        task.wait(0.5)
    end
end)

end


--==================================================
-- SHOP  (ร้านค้าอัตโนมัติ: ซื้อจำนวนสูงสุดทันที)
-- อยู่ในฟังก์ชันเดียว เพื่อไม่ให้ชนลิมิต local ของ UI
--==================================================
;(function()
    local RS = game:GetService("ReplicatedStorage")

    local LOBBY_PLACE_ID = 117949143041402
    local IN_LOBBY = (game.PlaceId == LOBBY_PLACE_ID)
    local Remotes = RS:WaitForChild("Remotes")

    local function alive()
        return Screen.Parent ~= nil
    end

    local function Reg(t)
        ActiveCountGetters[#ActiveCountGetters + 1] = t.Get
        return t
    end

    local function fmt(n)
        local s = tostring(math.floor(tonumber(n) or 0))
        while true do
            local r, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
            s = r
            if k == 0 then
                break
            end
        end
        return s
    end

    local function attr(name)
        return tonumber(LocalPlayer:GetAttribute(name)) or 0
    end

    local function pickSet(str)
        local set = {}
        for _, v in ipairs(Split(str)) do
            set[v] = true
        end
        return set
    end

    ------------------------------------------------------------------
    -- SHOP CONFIG (ดึงจากเกม ถ้าไม่ได้ใช้ค่าสำรองจากดัมพ์ล่าสุด)
    ------------------------------------------------------------------
    local ShopCfg
    do
        local ok, cfg = pcall(function()
            return require(RS.Modules.ShopModule.ShopConfig)
        end)
        if ok and type(cfg) == "table" and cfg.GoldShopItems and cfg.GemsShopItems then
            ShopCfg = cfg
        else
            ShopCfg = {
                GoldShopItems = {
                    { ID = "Fruit_1", Price = 150, MaxStock = 10 },
                    { ID = "Fruit_2", Price = 350, MaxStock = 5 },
                    { ID = "RareShard", Price = 500, MaxStock = 25 },
                    { ID = "EpicShard", Price = 1000, MaxStock = 20 },
                    { ID = "LegendShard", Price = 2500, MaxStock = 20 },
                    { ID = "MythicShard", Price = 5000, MaxStock = 20 },
                    { ID = "MysteriousShard", Price = 65000, MaxStock = 10 },
                    { ID = "Trait", Price = 3000, MaxStock = 10 },
                    { ID = "StatRerollAll", Price = 500, MaxStock = 10 },
                    { ID = "StatReroll", Price = 1200, MaxStock = 10 },
                    { ID = "MysteryCapsule", Price = 3000, MaxStock = 50 },
                    { ID = "BingoCoin", Price = 2000, MaxStock = 10 },
                },
                GemsShopItems = {
                    { ID = "Fruit_1", Price = 10, MaxStock = 10 },
                    { ID = "Fruit_2", Price = 25, MaxStock = 5 },
                    { ID = "RareShard", Price = 35, MaxStock = 25 },
                    { ID = "EpicShard", Price = 75, MaxStock = 20 },
                    { ID = "LegendShard", Price = 180, MaxStock = 20 },
                    { ID = "MythicShard", Price = 350, MaxStock = 20 },
                    { ID = "MysteriousShard", Price = 10000, MaxStock = 10 },
                    { ID = "Trait", Price = 200, MaxStock = 10 },
                    { ID = "StatRerollAll", Price = 35, MaxStock = 10 },
                    { ID = "StatReroll", Price = 80, MaxStock = 10 },
                    { ID = "MysteryCapsule", Price = 750, MaxStock = 50 },
                    { ID = "BingoCoin", Price = 1000, MaxStock = 10 },
                },
            }
        end
    end

    -- รายการสินค้าทั้งหมด (รวมของใหม่อัตโนมัติ ไม่ต้องแก้สคริปต์เมื่อเกมเพิ่มของ)
    local SHOP_IDS = {}
    do
        local seen = {}
        for _, list in ipairs({ ShopCfg.GoldShopItems, ShopCfg.GemsShopItems }) do
            for _, it in ipairs(list) do
                if not seen[it.ID] then
                    seen[it.ID] = true
                    SHOP_IDS[#SHOP_IDS + 1] = it.ID
                end
            end
        end
    end

    local function shopList(cur)
        return (cur == "Coins") and ShopCfg.GoldShopItems or ShopCfg.GemsShopItems
    end

    local function shopWantedIds(cur)
        local all = (cur == "Coins") and Config.ShopCoinsAll or Config.ShopGemsAll
        local set = pickSet((cur == "Coins") and Config.ShopCoinsPick or Config.ShopGemsPick)
        local out = {}
        for _, it in ipairs(shopList(cur)) do
            if all or set[it.ID] then
                out[it.ID] = true
            end
        end
        return out
    end

    local function shopWanted()
        for _, cur in ipairs({ "Coins", "Gems" }) do
            if next(shopWantedIds(cur)) then
                return true
            end
        end
        return false
    end

    ------------------------------------------------------------------
    -- STATUS ROWS
    ------------------------------------------------------------------
    local MainStatus, MoneyStatus
    local doShopNow

    local Shop = MakePage("Shop", "ร้านค้า", "ซื้อของอัตโนมัติ  •  ซื้อจำนวนสูงสุดทันที")

    Section(Shop, "สถานะ")
    MainStatus = StatusRow(Shop, { title = "สถานะบอท", desc = "กำลังทำอะไรอยู่", state = "idle", label = "เริ่มทำงาน" })
    MoneyStatus = StatusRow(Shop, { title = "ทรัพยากร", desc = "Coins / Gems", state = "ok", label = "-" })

    local function setStatus(t, state)
        MainStatus.Set(state or "busy", t)
    end

    ------------------------------------------------------------------
    -- CODES  (อ่านรายชื่อโค้ดสดจากในเกม + ใส่ทั้งหมดด้วยปุ่มเดียว)
    ------------------------------------------------------------------
    local CodeStatus
    local redeeming = false

    -- อ่านจาก RedeemConfig ของเกมทุกครั้ง: เกมอัปเดตโค้ดใหม่ก็เห็นเอง ไม่ต้องดัมใหม่
    local function getCodes()
        local list = {}
        local ok, cfg = pcall(function()
            return require(RS.Modules.RedeemCodeModule.RedeemConfig)
        end)
        if ok and type(cfg) == "table" and type(cfg.Codes) == "table" then
            for name, info in pairs(cfg.Codes) do
                if type(name) == "string" and type(info) == "table" and info.Active ~= false then
                    list[#list + 1] = name
                end
            end
            table.sort(list)
        end
        return list, ok
    end

    local function markRedeemed(code)
        local set = pickSet(Config.RedeemedCodes)
        if not set[code] then
            set[code] = true
            local t = {}
            for k in pairs(set) do
                t[#t + 1] = k
            end
            table.sort(t)
            SetConfig("RedeemedCodes", table.concat(t, "|"))
        end
    end

    local function pendingCodes()
        local all = getCodes()
        local done = pickSet(Config.RedeemedCodes)
        local out = {}
        for _, c in ipairs(all) do
            if not done[c] then
                out[#out + 1] = c
            end
        end
        return out, #all
    end

    local function redeemAll()
        if redeeming then
            return
        end
        local remote = Remotes:FindFirstChild("RedeemCode")
        if not remote then
            Toast("ไม่พบระบบโค้ดในแมพนี้ (ลองใน Lobby)", false)
            return
        end
        local list = pendingCodes()
        if #list == 0 then
            Toast("ไม่มีโค้ดใหม่ให้ใส่", true)
            return
        end
        redeeming = true
        local okN, failN = 0, 0
        for i, code in ipairs(list) do
            if not alive() then
                break
            end
            setStatus(string.format("ใส่โค้ด %s (%d/%d)", code, i, #list))
            local called, ok, msg = pcall(function()
                return remote:InvokeServer(code)
            end)
            local text = tostring(msg or "")
            if called and ok then
                okN += 1
                markRedeemed(code)
            elseif text:find("must join our group") then
                Toast("ต้องเข้ากลุ่มเกมแล้ว REJOIN ก่อนถึงจะใส่โค้ดได้", false)
                break
            else
                failN += 1
                local low = text:lower()
                -- ใส่ไปแล้ว / หมดอายุ -> จำไว้ ไม่ลองซ้ำ
                if low:find("already") or low:find("redeemed") or low:find("expired") or low:find("invalid") then
                    markRedeemed(code)
                end
            end
            task.wait(1.2)
        end
        redeeming = false
        setStatus(string.format("ใส่โค้ดเสร็จ สำเร็จ %d / ไม่ผ่าน %d", okN, failN), "ok")
        Toast(string.format("ใส่โค้ด: สำเร็จ %d  ไม่ผ่าน %d", okN, failN), okN > 0)
    end

    Section(Shop, "โค้ด")
    CodeStatus = StatusRow(Shop, { title = "โค้ดในเกม", desc = "อ่านสดจากเกม อัปเดตเองทุกวินาที", state = "idle", label = "-" })
    Button(Shop, {
        title = "ใส่โค้ดทั้งหมด",
        desc = "ใส่ทุกโค้ดที่เปิดใช้งานและยังไม่เคยใส่ ในปุ่มเดียว",
        text = "ใส่โค้ด",
        callback = function()
            redeemAll()
        end,
    })

    ------------------------------------------------------------------
    -- PAGE: SHOP
    ------------------------------------------------------------------
    Section(Shop, "ตั้งค่า")
    Reg(Toggle(Shop, {
        key = "AutoShop",
        title = "Auto ซื้อของร้านค้า",
        desc = "เปิดแล้วซื้อจำนวนสูงสุดทันที (ตอนอยู่ใน Lobby)",
    }))
    Button(Shop, {
        title = "ซื้อของร้านค้าตอนนี้",
        desc = "ซื้อตามรายการที่เลือกไว้ ด้วยจำนวนสูงสุด",
        text = "ซื้อ",
        callback = function()
            doShopNow()
        end,
    })
    Section(Shop, "ร้าน Coins")
    Toggle(Shop, { key = "ShopCoinsAll", title = "ซื้อทุกอย่างในร้าน Coins", desc = "ข้ามรายการที่เลือกด้านล่าง" })
    Dropdown(Shop, {
        key = "ShopCoinsPick",
        title = "สินค้าร้าน Coins",
        desc = "เลือกได้หลายอย่าง (" .. #ShopCfg.GoldShopItems .. " รายการ)",
        multi = true,
        options = SHOP_IDS,
    })
    Section(Shop, "ร้าน Gems")
    Toggle(Shop, { key = "ShopGemsAll", title = "ซื้อทุกอย่างในร้าน Gems", desc = "ข้ามรายการที่เลือกด้านล่าง" })
    Dropdown(Shop, {
        key = "ShopGemsPick",
        title = "สินค้าร้าน Gems",
        desc = "เลือกได้หลายอย่าง (" .. #ShopCfg.GemsShopItems .. " รายการ)",
        multi = true,
        options = SHOP_IDS,
    })

    ------------------------------------------------------------------
    -- BUY: ซื้อจำนวนสูงสุดทันที (min ของสต็อกเต็ม กับ ที่เงินพอ)
    ------------------------------------------------------------------
    local buying = false

    local function buyShop()
        if buying then
            return 0
        end
        buying = true
        local bought = 0
        setStatus("กำลังซื้อของร้านค้า...")
        for _, cur in ipairs({ "Coins", "Gems" }) do
            local want = shopWantedIds(cur)
            local bal = attr(cur)
            for _, it in ipairs(shopList(cur)) do
                if want[it.ID] then
                    local n = math.min(it.MaxStock, math.floor(bal / it.Price))
                    while n >= 1 do
                        if not alive() then
                            buying = false
                            return bought
                        end
                        local ok, res = pcall(function()
                            return Remotes.BuyItem:InvokeServer(it.ID, n, cur)
                        end)
                        if ok and res then
                            bought += n
                            bal -= n * it.Price
                            setStatus(string.format("ซื้อ %s x%d (%s) รวม %d ชิ้น", it.ID, n, cur, bought))
                            task.wait(0.2)
                            break
                        end
                        -- ถ้าสต็อกเหลือไม่ถึงจำนวนสูงสุด ลดลงครึ่งหนึ่งแล้วลองใหม่
                        n = math.floor(n / 2)
                        task.wait(0.15)
                    end
                end
            end
        end
        buying = false
        setStatus(string.format("ซื้อของเสร็จ %d ชิ้น", bought), "ok")
        return bought
    end

    doShopNow = function()
        if not IN_LOBBY then
            Toast("ใช้ได้เฉพาะตอนอยู่ใน Lobby", false)
            return
        end
        if not shopWanted() then
            Toast("ยังไม่ได้เลือกสินค้า", false)
            return
        end
        buyShop()
    end

    ------------------------------------------------------------------
    -- STATUS REFRESH + START
    ------------------------------------------------------------------
    local function refreshInfo()
        MoneyStatus.Set("ok", string.format("Coins %s  Gems %s", fmt(attr("Coins")), fmt(attr("Gems"))))
        local pend, total = pendingCodes()
        if total == 0 then
            CodeStatus.Set("idle", "ไม่พบรายชื่อโค้ด")
        elseif #pend == 0 then
            CodeStatus.Set("ok", string.format("ใส่ครบแล้ว (%d โค้ด)", total))
        else
            CodeStatus.Set("busy", string.format("โค้ดใหม่ %d / ทั้งหมด %d", #pend, total))
        end
    end

    task.defer(function()
        task.spawn(function()
            while alive() do
                refreshInfo()
                task.wait(1)
            end
        end)

        if not IN_LOBBY then
            setStatus("อยู่นอก Lobby (ร้านค้าใช้ได้เฉพาะใน Lobby)", "idle")
            return
        end

        task.spawn(function()
            local t0 = os.clock()
            while LocalPlayer:GetAttribute("Coins") == nil and os.clock() - t0 < 25 do
                task.wait(0.5)
            end
            task.wait(2)

            -- ซื้อทันทีเมื่อเปิด Auto (รวมตอนโหลดสคริปต์ที่เปิดค้างไว้) ไม่มีระบบรอรีสต็อก
            local wasOn = false
            while alive() do
                local on = Config.AutoShop == true
                if on and not wasOn and shopWanted() then
                    buyShop()
                end
                wasOn = on
                task.wait(1)
            end
        end)
    end)
end)()

--==================================================
-- APPEARANCE  (ธีม + พื้นหลังขยับ + ภาพของคุณ)
--==================================================
local Look = MakePage("Look", "ธีมและพื้นหลัง", "ปรับหน้าตา • เปลี่ยนแล้วเห็นผลทันที")

Section(Look, "ธีมสำเร็จรูป")
ThemeGrid(Look)

Section(Look, "พื้นหลังขยับ")

local function ApplyBackground()
    RefreshBackgroundImages()
    RefreshPetalCount()
    QueueTheme()
end

Toggle(Look, {
    key = "AnimBackground",
    title = "พื้นหลังขยับ",
    desc = "กลีบซากุระร่วง แสงลอย และประกายระยิบ",
    callback = function()
        ApplyBackground()
    end,
})

Slider(Look, {
    key = "PetalCount",
    title = "จำนวนกลีบซากุระ",
    desc = "ลดลงถ้าเครื่องหน่วง",
    min = 0,
    max = MAX_PETALS,
    step = 1,
    callback = function()
        RefreshPetalCount()
    end,
})

Slider(Look, {
    key = "AnimSpeed",
    title = "ความเร็วแอนิเมชัน",
    desc = "ความเร็วกลีบที่ร่วง",
    min = 30,
    max = 200,
    step = 10,
    suffix = "%",
})

Slider(Look, {
    key = "PanelAlpha",
    title = "ความโปร่งใสของการ์ด",
    desc = "เพิ่มเพื่อให้เห็นพื้นหลังชัดขึ้น",
    min = 0,
    max = 60,
    step = 2,
    suffix = "%",
    callback = function()
        QueueTheme()
    end,
})

Section(Look, "ภาพของคุณ (Roblox Asset ID)")

Input(Look, {
    key = "BgImageId",
    title = "ภาพพื้นหลัง",
    desc = "ใส่เลข ID หรือ rbxassetid://...",
    placeholder = "เช่น 1234567890",
    callback = function()
        RefreshBackgroundImages()
    end,
})

Input(Look, {
    key = "ArtImageId",
    title = "รูปตัวละคร (มุมขวาล่าง)",
    desc = "ควรเป็น PNG พื้นหลังโปร่งใส",
    placeholder = "เช่น 1234567890",
    callback = function()
        RefreshBackgroundImages()
    end,
})

Slider(Look, {
    key = "ArtOpacity",
    title = "ความชัดของรูปตัวละคร",
    desc = "100% = เห็นชัดเต็มที่",
    min = 10,
    max = 100,
    step = 5,
    suffix = "%",
    callback = function()
        RefreshBackgroundImages()
    end,
})

Section(Look, "สี UI")
ColorRow(Look, "สีหลัก (Accent)", "UIAccentColor")
ColorRow(Look, "สีรอง (ชมพู / ไล่เฉด)", "UIAccent2Color")
ColorRow(Look, "สีพื้นหลัง", "UIBackgroundColor")
ColorRow(Look, "สีปุ่ม", "UIButtonColor")

--==================================================
-- CONFIG  (ระบบ + สล็อตเซฟ + Export / Import)
--==================================================
local Settings = MakePage("Settings", "ตั้งค่า", "ระบบ • คอนฟิก • สล็อตเซฟ")

Section(Settings, "ระบบ")

Toggle(Settings, {
    key = "SoundEnabled",
    title = "เสียงเปิด / ปิด",
    desc = "เล่นเสียงสั้นๆ ตอนกดสวิตช์",
})

Toggle(Settings, {
    key = "StatsVisible",
    title = "แสดง FPS / MS",
    desc = "กล่องเล็กลากย้ายตำแหน่งได้",
    callback = function(v)
        StatsGui.Enabled = v
    end,
})

Slider(Settings, {
    key = "UIScalePercent",
    title = "ขนาดหน้าต่าง",
    desc = "ปรับเพิ่มจากขนาดอัตโนมัติตามหน้าจอ",
    min = 60,
    max = 120,
    step = 5,
    suffix = "%",
    callback = function()
        ApplyScale(true)
    end,
})

Keybind(Settings, {
    key = "ToggleKey",
    title = "ปุ่มลัดเปิด / ปิด UI",
    desc = "กดปุ่มนี้เพื่อซ่อน/แสดงหน้าต่าง",
})

Section(Settings, "คอนฟิก")

local CfgCard = Panel(Settings, UDim2.new(1, 0, 0, 66))
Register(CfgCard)
local CfgTitle = Text(CfgCard, "บันทึกอัตโนมัติ", 14, FNT.B, "Text")
CfgTitle.Position = UDim2.fromOffset(20, 12)
CfgTitle.Size = UDim2.new(1, -160, 0, 20)
local CfgDesc = Text(
    CfgCard,
    writefile and CONFIG_FILE or "executor นี้ไม่รองรับการเขียนไฟล์",
    11,
    FNT.R,
    "Muted"
)
CfgDesc.Position = UDim2.fromOffset(20, 34)
CfgDesc.Size = UDim2.new(1, -160, 0, 18)
local CfgPill = StatusPill(CfgCard, 122)
CfgPill.AnchorPoint = Vector2.new(1, 0.5)
CfgPill.Position = UDim2.new(1, -16, 0.5, 0)

Section(Settings, "สล็อตเซฟ")

local SlotNames = { "Slot 1", "Slot 2", "Slot 3", "Slot 4", "Slot 5" }
local SlotStatus

local function SlotPath(name)
    return PROFILE_DIR .. "/" .. string.gsub(name, "%s+", "") .. ".json"
end

local function SlotExists(name)
    if not (isfile and readfile) then
        return false
    end
    local ok, e = pcall(isfile, SlotPath(name))
    return ok and e == true
end

local function RefreshSlotStatus()
    if not SlotStatus then
        return
    end
    if not writefile then
        SlotStatus.Set("bad", "ไม่รองรับ")
    elseif SlotExists(Config.ProfileSlot) then
        SlotStatus.Set("ok", "มีข้อมูล")
    else
        SlotStatus.Set("idle", "ว่าง")
    end
end

local function SnapshotConfig()
    local data = {}
    for k, v in pairs(Config) do
        if Defaults[k] ~= nil and not ProfileExclude[k] then
            data[k] = v
        end
    end
    return data
end

local ApplyAll

local function ApplySnapshot(data)
    local n = 0
    for k, v in pairs(Defaults) do
        if not ProfileExclude[k] and type(data[k]) == type(v) then
            Config[k] = data[k]
            n = n + 1
        end
    end
    ApplyAll()
    return n
end

Dropdown(Settings, {
    key = "ProfileSlot",
    title = "เลือกสล็อต",
    desc = "เก็บคอนฟิกแยกได้ 5 ชุด",
    options = SlotNames,
    callback = function()
        RefreshSlotStatus()
    end,
})

SlotStatus = StatusRow(Settings, {
    title = "สถานะสล็อต",
    desc = "ดูว่าสล็อตที่เลือกมีข้อมูลหรือยัง",
    state = "idle",
    label = "ว่าง",
})

Button(Settings, {
    title = "บันทึกลงสล็อต",
    desc = "เซฟค่าปัจจุบันทั้งหมดลงสล็อตที่เลือก",
    text = "บันทึก",
    callback = function()
        if not writefile then
            Toast("executor ไม่รองรับการเขียนไฟล์", false)
            return
        end
        local ok = pcall(function()
            if makefolder and isfolder and not isfolder(PROFILE_DIR) then
                makefolder(PROFILE_DIR)
            end
            writefile(SlotPath(Config.ProfileSlot), HttpService:JSONEncode(SnapshotConfig()))
        end)
        Toast(ok and ("บันทึกลง " .. Config.ProfileSlot .. " แล้ว") or "บันทึกไม่สำเร็จ", ok)
        RefreshSlotStatus()
    end,
})

Button(Settings, {
    title = "โหลดจากสล็อต",
    desc = "นำค่าจากสล็อตที่เลือกมาใช้ทันที",
    text = "โหลด",
    callback = function()
        if not SlotExists(Config.ProfileSlot) then
            Toast("สล็อตนี้ยังว่างอยู่", false)
            return
        end
        local ok, n = pcall(function()
            return ApplySnapshot(HttpService:JSONDecode(readfile(SlotPath(Config.ProfileSlot))))
        end)
        Toast(ok and ("โหลด " .. Config.ProfileSlot .. " แล้ว (" .. tostring(n) .. " ค่า)") or "ไฟล์เสียหาย", ok)
    end,
})

Button(Settings, {
    title = "ลบสล็อต",
    desc = "ลบข้อมูลในสล็อตที่เลือก",
    text = "ลบ",
    danger = true,
    callback = function()
        if not SlotExists(Config.ProfileSlot) then
            Toast("สล็อตนี้ว่างอยู่แล้ว", false)
            return
        end
        local ok = pcall(function()
            if delfile then
                delfile(SlotPath(Config.ProfileSlot))
            else
                writefile(SlotPath(Config.ProfileSlot), "{}")
            end
        end)
        Toast(ok and "ลบสล็อตแล้ว" or "ลบไม่สำเร็จ", ok)
        RefreshSlotStatus()
    end,
})

Section(Settings, "Export / Import")

Button(Settings, {
    title = "คัดลอกคอนฟิก (Export)",
    desc = "คัดลอกเป็นข้อความ JSON ไปแชร์เพื่อน",
    text = "คัดลอก",
    callback = function()
        local copy = (type(setclipboard) == "function" and setclipboard)
            or (type(toclipboard) == "function" and toclipboard)
        if not copy then
            Toast("executor ไม่รองรับคลิปบอร์ด", false)
            return
        end
        local ok = pcall(copy, HttpService:JSONEncode(SnapshotConfig()))
        Toast(ok and "คัดลอกคอนฟิกแล้ว" or "คัดลอกไม่สำเร็จ", ok)
    end,
})

Input(Settings, {
    key = "ImportText",
    title = "วางคอนฟิก (Import)",
    desc = "วางข้อความ JSON แล้วกดปุ่มด้านล่าง",
    placeholder = "{ ... }",
})

Button(Settings, {
    title = "นำเข้าคอนฟิก",
    desc = "ใช้ค่าจากข้อความที่วางไว้",
    text = "นำเข้า",
    callback = function()
        local ok, n = pcall(function()
            return ApplySnapshot(HttpService:JSONDecode(Config.ImportText))
        end)
        if ok and n and n > 0 then
            SetConfig("ImportText", "")
            Toast("นำเข้า " .. n .. " ค่าแล้ว", true)
        else
            Toast("ข้อความ JSON ไม่ถูกต้อง", false)
        end
    end,
})

local FloatApplyPosition
local ResetRow = Panel(Settings, UDim2.new(1, 0, 0, 52), "TextButton")
HoverRow(ResetRow)
Register(ResetRow)
local ResetLabel = Text(ResetRow, "รีเซ็ตการตั้งค่าทั้งหมด", 13, FNT.B, Theme.Bad)
OnTheme(function()
    ResetLabel.TextColor3 = Theme.Bad
end)
ResetLabel.Position = UDim2.fromOffset(20, 0)
ResetLabel.Size = UDim2.new(1, -40, 1, 0)

local resetArmed = false
ResetRow.MouseButton1Click:Connect(function()
    if not resetArmed then
        resetArmed = true
        ResetLabel.Text = "กดอีกครั้งเพื่อยืนยันการรีเซ็ต"
        task.delay(3, function()
            resetArmed = false
            ResetLabel.Text = "รีเซ็ตการตั้งค่าทั้งหมด"
        end)
        return
    end
    resetArmed = false
    ResetLabel.Text = "รีเซ็ตการตั้งค่าทั้งหมด"
    for k, v in pairs(Defaults) do
        Config[k] = v
    end
    Collapsed = {}
    for _, secs in pairs(SectionsByPage) do
        for _, sec in ipairs(secs) do
            sec.collapsed = false
            sec.refresh(true)
        end
    end
    ApplyAll()
    Tween(Main, 0.3, { Position = UDim2.fromScale(Config.WindowX, Config.WindowY) }, Enum.EasingStyle.Quint)
    if FloatApplyPosition then
        FloatApplyPosition()
    end
    StatsBox.Position = UDim2.fromScale(Config.StatsX, Config.StatsY)
    SelectTab(Config.LastTab)
    SaveConfig(true)
    Toast("รีเซ็ตการตั้งค่าแล้ว")
end)

-- ใช้ค่า Config ปัจจุบันกับทุกส่วนของ UI (ใช้ตอนโหลดสล็อต / import / reset)
ApplyAll = function()
    ApplyTheme()
    for _, fn in ipairs(ColorRefreshers) do
        pcall(fn)
    end
    for _, fn in ipairs(Refreshers) do
        pcall(fn)
    end
    RefreshBackgroundImages()
    RefreshPetalCount()
    StatsGui.Enabled = Config.StatsVisible
    ApplyScale(true)
    SaveConfig()
end

--==================================================
-- SIDEBAR CATEGORIES
--==================================================
CatGroup("เมนูหลัก")
Category("หน้าหลัก", "Home", "grid")
Category("ร้านค้า", "Shop", "sliders")
CatGroup("ปรับแต่ง")
Category("ธีมและพื้นหลัง", "Look", "dots")
Category("ตั้งค่า", "Settings", "ring")

--==================================================
-- FLOATING FLOWER BUTTON  (ปุ่มลอยรูปดอกซากุระ ลากได้)
--==================================================
local ToggleGui = New("ScreenGui", {
    Name = "SAKURA_Floating",
    ResetOnSpawn = false,
    DisplayOrder = 999999,
    IgnoreGuiInset = true,
}, GuiParent)

local Float = New("Frame", {
    Size = UDim2.fromOffset(54, 54),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(Config.FloatX, Config.FloatY),
    BackgroundTransparency = 1,
    Active = true,
}, ToggleGui)

local Glow = New("Frame", {
    Size = UDim2.new(1, 10, 1, 10),
    Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
}, Float)
Corner(Glow, 999)
local GlowStroke = Stroke(Glow, Theme.Accent2, 3, 0.2)
OnTheme(function()
    GlowStroke.Color = Theme.Accent2
end)
TweenService:Create(
    GlowStroke,
    TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    { Transparency = 0.7 }
):Play()

local FloatBtn = New("TextButton", {
    Size = UDim2.fromScale(1, 1),
    Text = "",
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Active = true,
    BackgroundColor3 = Color3.new(1, 1, 1),
}, Float)
Corner(FloatBtn, 999)
AccentGrad(FloatBtn, 45)
Stroke(FloatBtn, Color3.new(1, 1, 1), 2, 0.2)
local FloatFlower = Flower(FloatBtn, 38)
FloatFlower.Active = false
TweenService:Create(
    FloatFlower,
    TweenInfo.new(10, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
    { Rotation = 360 }
):Play()

FloatApplyPosition = function()
    Float.Position = UDim2.fromScale(Config.FloatX, Config.FloatY)
end

MakeDraggable(FloatBtn, Float, "FloatX", "FloatY", function()
    SetWindow(not Config.WindowVisible)
end)

--==================================================
-- START
--==================================================
SelectTab(Config.LastTab)
RefreshBackgroundImages()
RefreshPetalCount()
RefreshStats()
RefreshHome()
UpdateSummary()
RefreshSlotStatus()

if Config.WindowVisible then
    PlayOpen()
end

if not LoadedFromFile then
    SaveConfig(true) -- สร้างไฟล์ Config ครั้งแรก
end

print("[SAKURA] UI Loaded" .. (LoadedFromFile and " (Config loaded)" or " (new Config)"))
