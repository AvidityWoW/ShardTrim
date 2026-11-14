-- Avidity Shard Trim: while you're over your limit, any key press or click deletes
-- one Soul Shard. DeleteCursorItem needs a real hardware event and allows one item
-- per event, so the trim piggybacks on your own input.

local ITEM = 6265
local ICON = "Interface\\Icons\\INV_Misc_Gem_Amethyst_02"
local NAME = "|cff8f3fdaShard Trim:|r "
local SOUL_BAG = 0x4 -- Soul Shards bag family bit (Soul Pouch, Felcloth Bag, ...)
local LAST_BAG = Enum.BagIndex and Enum.BagIndex.ReagentBag or 4 -- includes the reagent bag slot where there is one
local DEFAULTS = {
	enabled = true, threshold = 8, method = "auto", banner = "above", minimap = true,
	layout = "icon", iconSize = 18, countPos = "auto", style = "tooltip", fontSize = 12, background = true, opacity = 90, rounding = 0,
	indicator = "always", tooltip = true,
}
local NO_BACKGROUND = { height = 20, padding = 2, inset = 0 } -- sizes when Background is off
local LAYOUTS = {
	{ "icon", "Icon", "The shard icon with your count. Set how big the icon is with Icon Size." },
	{ "text", "Label", "Just text: \"Soul Shards\" and your count, no icon." },
}
local FOOTER_MIN_SIZE = 32 -- Automatic puts the count on icons at least this big, beside smaller ones
local COUNT_POSITIONS = {
	{ "auto", "Automatic", "On the icon when it's big enough to fit (Icon Size 32 or more), to its right when smaller, and below the text for Label." },
	{ "right", "Right" },
	{ "left", "Left" },
	{ "above", "Above" },
	{ "below", "Below" },
	{ "footer", "On the icon", "In a dark strip along the bottom of the icon. The Label layout puts it below instead." },
}
ShardTrimDB = ShardTrimDB or {}
local busy, loaded, previewing, category, Update
local settings = {} -- key -> Settings object, so changes made elsewhere show in the panel too

-- Returns the shard count, the limit (never below your shard bags' slots) and the first shard's { bag, slot }.
local function Scan()
	local total, capacity, first = 0, 0
	for bag = 0, LAST_BAG do
		local _, family = C_Container.GetContainerNumFreeSlots(bag)
		local shardBag = bit.band(family or 0, SOUL_BAG) ~= 0
		if bag <= 4 or shardBag then -- the reagent slot only counts when it holds a shard bag
			local slots = C_Container.GetContainerNumSlots(bag)
			if shardBag then capacity = capacity + slots end
			for slot = 1, slots do
				if C_Container.GetContainerItemID(bag, slot) == ITEM then
					total = total + 1
					first = first or { bag, slot }
				end
			end
		end
	end
	return total, math.max(ShardTrimDB.threshold or DEFAULTS.threshold, capacity), first, capacity
end

local function Trim()
	if not ShardTrimDB.enabled or busy or GetCursorInfo() or GetCurrentKeyBoardFocus() then return end
	local total, limit, shard = Scan()
	if total <= limit then return end

	busy = true
	C_Timer.After(1, function() busy = false end) -- until bags report the new count
	C_Container.PickupContainerItem(shard[1], shard[2])
	local kind, id = GetCursorInfo()
	-- Put it back if the bags shifted and we picked up something else
	if not (kind == "item" and id == ITEM and pcall(DeleteCursorItem)) then ClearCursor() end
end

-- Writes through the Settings object when the panel exists, so it stays in sync.
local function Set(key, value)
	if settings[key] then
		settings[key]:SetValue(value)
	else
		ShardTrimDB[key] = value
		if Update then Update() end
	end
end

local function SetEnabled(on)
	Set("enabled", on)
	print(NAME .. (on and "|cff20ff20on|r" or "|cffff2020off|r") .. ".")
end

function ShardTrim_Toggle()
	SetEnabled(not ShardTrimDB.enabled)
end

local function OpenOptions()
	if category then Settings.OpenToCategory(category:GetID()) end
end

local function FillTooltip(tt, hints)
	local total, limit, _, capacity = Scan()
	local on = ShardTrimDB.enabled
	tt:AddLine("|cff8f3fdaAvidity|r Shard Trim")
	tt:AddDoubleLine("Soul Shards", ("%d / %d"):format(total, limit), 1, 0.82, 0, 1, 1, 1)
	if capacity > ShardTrimDB.threshold then -- explain why the limit is above Shards to Keep
		tt:AddDoubleLine("Shards to Keep", ("%d (shard bags hold %d)"):format(ShardTrimDB.threshold, capacity), 1, 0.82, 0, 0.6, 0.6, 0.6)
	end
	if on then
		tt:AddDoubleLine("Trimming", "On", 1, 0.82, 0, 0.1, 1, 0.1)
	else
		tt:AddDoubleLine("Trimming", "Off", 1, 0.82, 0, 1, 0.1, 0.1)
	end
	tt:AddLine(" ")
	for _, hint in ipairs(hints) do tt:AddLine(hint, 0.1, 1, 0.1) end
end

-- Banner: top of the screen until you drag it; left-click trims, right-click locks or
-- unlocks dragging. The game remembers where you drop it (named, user-placed frame),
-- and a drag isn't a click. Its look comes from the selected skin (see the API below).
local bar = CreateFrame("Button", "ShardTrimButton", UIParent, "BackdropTemplate")
bar:SetPoint("TOP", 0, -60)
bar:SetAlpha(0)
bar:SetFrameStrata("MEDIUM")
local icon = bar:CreateTexture(nil, "ARTWORK")
icon:SetTexture(ICON)
local label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
label:SetText("Soul Shards")
local count = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
local highlight = bar:CreateTexture(nil, "HIGHLIGHT") -- shows on mouseover by itself, like an action button's
highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
highlight:SetBlendMode("ADD")
highlight:SetAllPoints(icon)
-- On/off badge: a ready-check tick or cross on the icon's corner (the Label layout has none).
local status = bar:CreateTexture(nil, "OVERLAY", nil, 7)
local STATUS_ON, STATUS_OFF = "Interface\\RaidFrame\\ReadyCheck-Ready", "Interface\\RaidFrame\\ReadyCheck-NotReady"
-- Strip along the bottom of the icon when the count goes on it; the count sits centered on it.
local footer = bar:CreateTexture(nil, "ARTWORK", nil, 1)
footer:SetColorTexture(0, 0, 0, 0.65)
bar.Icon, bar.Label, bar.Count, bar.Highlight, bar.Status, bar.Footer = icon, label, count, highlight, status, footer

--[[ Skinning API, for UI packs and skin addons:

	ShardTrim.banner              the banner Button ("ShardTrimButton", BackdropTemplate),
	                              with .Icon, .Highlight, .Status and .Footer (Textures; Status is the
	                              on/off badge, Footer the strip under the count when it sits on the icon),
	                              .Label and .Count (FontStrings)
	ShardTrimDB.layout            the player's layout: "icon" or "text" (label)
	ShardTrimDB.iconSize          the icon's size in pixels
	ShardTrimDB.fontSize          the label's and count's font size (on the icon, the count is 2 smaller
	                              and shrinks to fit the icon's width);
	                              skins that change fonts in apply should keep this size
	ShardTrimDB.countPos          where the count goes: "auto", "right", "left", "above", "below"
	                              or "footer" (on the icon)

	ShardTrim:RegisterSkin(key, skin)
	                              adds a choice to Options > Shard Trim > Banner > Style. If the player's saved
	                              style is this key, it's applied right away. skin fields, all optional:
	    label      name shown in the dropdown (default: key)
	    backdrop   a backdrop table; nil for no background
	    bg         { r, g, b } background color; the alpha comes from the Background slider
	    border     { r, g, b[, a] } border color
	    hover      { r, g, b[, a] } border color while the mouse is over the banner
	    height     banner height (default 30)
	    padding    left and right padding (default 10)
	    inset      space around the icon when nothing sits beside it (default 4)
	    (a backdrop whose bgFile and edgeFile are both Interface\\Buttons\\WHITE8X8 gets the Corner
	    Rounding option: the addon draws it with rounded corners instead of as a backdrop)
	    apply      function(banner, db) run after the above, for anything else (fonts, extra textures);
	               when db.background is false the player turned the background off, so skip yours
	    remove     function(banner) to undo apply's extras when the player picks another skin

	ShardTrim:SetStyle(key)       switch skins (saved, like picking it in options)
	ShardTrim:Refresh()           reapply the current skin and redraw

	ShardTrim.RegisterCallback(you, event, method) with CallbackHandler events:
	    "BannerStyled"(event, banner, key, layout)                   after a skin or layout is applied
	    "BannerUpdate"(event, banner, total, limit, over, enabled)   after each redraw, to restyle colors
]]
ShardTrim = { banner = bar }
local callbacks = LibStub("CallbackHandler-1.0"):New(ShardTrim)
local skins, skinOrder, current = {}, {}, nil

-- Where the count goes: "right", "left", "above", "below" or "footer" (on the icon; never for the Label layout).
local function CountPosition()
	local db = ShardTrimDB
	if db.layout == "text" and (db.countPos == "auto" or db.countPos == "footer") then return "below" end -- nothing to sit on
	if db.countPos == "auto" then return db.iconSize >= FOOTER_MIN_SIZE and "footer" or "right" end
	return db.countPos
end

-- Rounded corners. Backdrops can't round, so for skins built from solid color (a WHITE8X8 background
-- and border) we draw it ourselves when Corner Rounding is above 0: a border-colored rounded rectangle,
-- with a fill-colored one inset by the border's width on top. Each is three strips plus four
-- quarter circles cut from the game's round portrait mask.
local SOLID = "Interface\\Buttons\\WHITE8X8"
local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local CORNERS = { -- point, texcoords, x and y direction inward
	{ "TOPLEFT", 0, 0.5, 0, 0.5, 1, -1 }, { "TOPRIGHT", 0.5, 1, 0, 0.5, -1, -1 },
	{ "BOTTOMLEFT", 0, 0.5, 0.5, 1, 1, 1 }, { "BOTTOMRIGHT", 0.5, 1, 0.5, 1, -1, 1 },
}
local rounded -- true while the current skin is drawn with rounded corners

local function NewShape(sublevel)
	local shape = {}
	for i = 1, 7 do
		local t = bar:CreateTexture(nil, "BACKGROUND", nil, sublevel)
		t:SetTexture(i <= 4 and CIRCLE or SOLID)
		if i <= 4 then t:SetTexCoord(unpack(CORNERS[i], 2, 5)) end
		shape[i] = t
	end
	return shape
end
local roundBorder, roundFill = NewShape(-8), NewShape(-7)

local function ShowShape(shape, shown)
	for _, t in ipairs(shape) do t:SetShown(shown) end
end

local function ColorShape(shape, color, alpha)
	for _, t in ipairs(shape) do t:SetVertexColor(color[1], color[2], color[3], alpha or color[4] or 1) end
end

local function PlaceShape(shape, inset, radius)
	for i, c in ipairs(CORNERS) do
		local t = shape[i]
		t:ClearAllPoints()
		t:SetSize(math.max(radius, 1), math.max(radius, 1))
		t:SetPoint(c[1], bar, c[1], c[6] * inset, c[7] * inset)
		t:SetShown(radius > 0)
	end
	local middle, left, right = shape[5], shape[6], shape[7]
	local edge = inset + radius
	middle:ClearAllPoints()
	middle:SetPoint("TOPLEFT", bar, "TOPLEFT", edge, -inset)
	middle:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -edge, inset)
	left:ClearAllPoints()
	left:SetPoint("TOPLEFT", bar, "TOPLEFT", inset, -edge)
	left:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", edge, edge)
	right:ClearAllPoints()
	right:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -inset, -edge)
	right:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", -edge, edge)
	left:SetShown(radius > 0)
	right:SetShown(radius > 0)
end

local function CanRound(skin)
	local b = skin.backdrop
	return b and b.bgFile == SOLID and b.edgeFile == SOLID
end

local function SetFontSize(fontString, size)
	local path, _, flags = fontString:GetFont()
	fontString:SetFont(path, size, flags)
end

local function Layout()
	local skin, mode = ShardTrimDB.background and current or NO_BACKGROUND, ShardTrimDB.layout
	local pos = CountPosition()
	icon:ClearAllPoints()
	label:ClearAllPoints()
	count:ClearAllPoints()
	status:ClearAllPoints()
	footer:ClearAllPoints()
	local badge = ShardTrimDB.indicator
	status:SetShown(mode ~= "text" and (badge == "always" or badge == "off" and not ShardTrimDB.enabled)) -- no badge on the Label layout
	icon:SetShown(mode ~= "text")
	label:SetShown(mode == "text")
	highlight:SetShown(mode == "icon")
	footer:SetShown(pos == "footer")

	local pad = skin.padding or 10
	local inset = skin.inset or 4
	-- The count is placed around an anchor: the icon, or the "Soul Shards" label in the Label layout.
	local anchor, anchorW, anchorH = icon
	if mode == "text" then
		anchor, anchorW, anchorH = label, label:GetStringWidth(), label:GetStringHeight()
	else
		local size = ShardTrimDB.iconSize
		icon:SetSize(size, size)
		anchorW, anchorH = size, size
		local badgeSize = math.floor(math.min(math.max(size * 0.45, 10), 20))
		status:SetSize(badgeSize, badgeSize)
		status:SetPoint("TOPLEFT", icon, -math.floor(badgeSize / 4), math.floor(badgeSize / 4))
	end

	-- The text next to the icon: the count, unless it's on the icon
	local parts = {}
	if pos == "footer" then
		footer:SetPoint("BOTTOMLEFT", icon)
		footer:SetPoint("BOTTOMRIGHT", icon)
		-- A little smaller than Font Size, and shrunk further until it fits across the icon
		local fontSize = math.max(ShardTrimDB.fontSize - 2, 6)
		SetFontSize(count, fontSize)
		while fontSize > 6 and count:GetStringWidth() > anchorW - 4 do
			fontSize = fontSize - 1
			SetFontSize(count, fontSize)
		end
		footer:SetHeight(math.ceil(count:GetStringHeight()) + 3)
		count:SetPoint("CENTER", footer)
	else
		parts[#parts + 1] = count
	end
	local textWidth, textHeight = 0, 0
	for i, part in ipairs(parts) do
		textWidth = textWidth + part:GetStringWidth() + (i > 1 and 6 or 0)
		textHeight = math.max(textHeight, part:GetStringHeight())
	end

	-- Everything is placed from the banner's top-left corner, x right and y down.
	local width, height, iconX, iconY, textX, textY
	if pos == "above" or pos == "below" then
		local margin = inset + 2
		width = math.max(anchorW, textWidth) + 2 * margin
		height = 2 * margin + anchorH + 2 + textHeight
		iconX, textX = (width - anchorW) / 2, (width - textWidth) / 2
		if pos == "below" then
			iconY, textY = margin, margin + anchorH + 2
		else
			textY, iconY = margin, margin + textHeight + 2
		end
	else -- beside the anchor, or on the icon
		local margin = #parts > 0 and pad or inset
		height = math.max(#parts > 0 and skin.height or 0, anchorH + 2 * inset) -- square around a lone icon
		width = 2 * margin + anchorW + (#parts > 0 and 6 + textWidth or 0)
		iconY, textY = (height - anchorH) / 2, (height - textHeight) / 2
		if pos == "left" then
			textX, iconX = margin, margin + textWidth + 6
		else
			iconX, textX = margin, margin + anchorW + 6
		end
	end

	local function Place(region, x, y) region:SetPoint("TOPLEFT", bar, "TOPLEFT", math.floor(x + 0.5), -math.floor(y + 0.5)) end
	Place(anchor, iconX, iconY)
	for _, part in ipairs(parts) do
		Place(part, textX, textY + (textHeight - part:GetStringHeight()) / 2)
		textX = textX + part:GetStringWidth() + 6
	end
	bar:SetSize(math.floor(width + 0.5), math.floor(height + 0.5))

	if rounded then
		local edge = current.backdrop.edgeSize or 1
		local radius = math.min(ShardTrimDB.rounding, math.floor(math.min(width, height) / 2))
		PlaceShape(roundBorder, 0, radius)
		PlaceShape(roundFill, edge, math.max(radius - edge, 0))
	end
end

local function ApplyStyle()
	local db = ShardTrimDB
	local skin = skins[db.style] or skins[DEFAULTS.style] -- a skin addon that isn't loaded falls back, keeping the choice saved
	if current and current ~= skin and current.remove then current.remove(bar) end
	current = skin

	bar:ClearBackdrop()
	rounded = skin.backdrop and db.background and db.rounding > 0 and CanRound(skin)
	ShowShape(roundBorder, rounded)
	ShowShape(roundFill, rounded)
	local bg, border = skin.bg or { 0, 0, 0 }, skin.border or { 1, 1, 1 }
	if rounded then
		ColorShape(roundBorder, border)
		ColorShape(roundFill, bg, db.opacity / 100)
	elseif skin.backdrop and db.background then
		bar:SetBackdrop(skin.backdrop)
		bar:SetBackdropColor(bg[1], bg[2], bg[3], db.opacity / 100)
		bar:SetBackdropBorderColor(unpack(border))
	end
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim the icon's built-in border
	label:SetFontObject(GameFontNormal)
	count:SetFontObject(GameFontHighlight)
	SetFontSize(label, db.fontSize)
	SetFontSize(count, db.fontSize) -- Layout shrinks it to fit when it sits on the icon
	Layout()
	if skin.apply then skin.apply(bar, db) end
	callbacks:Fire("BannerStyled", bar, db.style, db.layout)
end

function ShardTrim:RegisterSkin(key, skin)
	assert(type(key) == "string" and type(skin) == "table", "Usage: ShardTrim:RegisterSkin(key, skinTable)")
	if not skins[key] then skinOrder[#skinOrder + 1] = key end
	skins[key] = skin
	if loaded and (ShardTrimDB.style == key or current == nil) then
		ApplyStyle()
		Update()
	end
end

function ShardTrim:SetStyle(key)
	Set("style", key)
end

function ShardTrim:Refresh()
	if not loaded then return end
	ApplyStyle()
	Update()
end

-- Built-in skins
local TOOLTIP_BG = TOOLTIP_DEFAULT_BACKGROUND_COLOR or { r = 0.09, g = 0.09, b = 0.19 }
ShardTrim:RegisterSkin("tooltip", {
	label = "Tooltip",
	backdrop = {
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	},
	bg = { TOOLTIP_BG.r, TOOLTIP_BG.g, TOOLTIP_BG.b },
	border = { 0.6, 0.6, 0.6 },
	hover = { 1, 0.82, 0 },
})
ShardTrim:RegisterSkin("dialog", {
	label = "Dialog",
	backdrop = {
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	},
	bg = { 1, 1, 1 },
	border = { 1, 1, 1 },
	hover = { 1, 0.82, 0 },
	height = 32,
})
ShardTrim:RegisterSkin("flat", {
	label = "Flat",
	backdrop = {
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
	},
	bg = { 0.06, 0.06, 0.06 },
	border = { 0, 0, 0 },
	hover = { 0.56, 0.25, 0.85 },
	height = 24,
	padding = 6,
	inset = 2,
})

-- Flat-style skins share this 1px border backdrop
local THIN = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }
ShardTrim:RegisterSkin("gold", {
	label = "Gold",
	backdrop = {
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
		tile = true, tileSize = 32, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	},
	bg = { 1, 1, 1 },
	border = { 1, 1, 1 },
	hover = { 1, 0.9, 0.5 },
	height = 32,
})
ShardTrim:RegisterSkin("toast", {
	label = "Toast",
	backdrop = {
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\FriendsFrame\\UI-Toast-Border",
		tile = true, tileSize = 12, edgeSize = 12,
		insets = { left = 5, right = 5, top = 5, bottom = 5 },
	},
	bg = { 0, 0, 0 },
	border = { 1, 1, 1 },
	hover = { 1, 0.82, 0 },
	inset = 5,
})
ShardTrim:RegisterSkin("shadow", {
	label = "Shadow",
	backdrop = THIN,
	bg = { 0.08, 0.02, 0.12 },
	border = { 0.56, 0.25, 0.85 },
	hover = { 0.8, 0.55, 1 },
	height = 24,
	padding = 6,
	inset = 2,
})
ShardTrim:RegisterSkin("fel", {
	label = "Fel",
	backdrop = THIN,
	bg = { 0.02, 0.08, 0.02 },
	border = { 0.35, 0.8, 0.15 },
	hover = { 0.6, 1, 0.3 },
	height = 24,
	padding = 6,
	inset = 2,
})
ShardTrim:RegisterSkin("glass", {
	label = "Glass",
	backdrop = THIN,
	bg = { 0, 0, 0 },
	border = { 1, 1, 1, 0.12 },
	hover = { 1, 1, 1, 0.45 },
	height = 24,
	padding = 6,
	inset = 2,
})
ShardTrim:RegisterSkin("void", {
	label = "Void",
	backdrop = THIN,
	bg = { 0.02, 0.02, 0.05 },
	border = { 0.25, 0.2, 0.6 },
	hover = { 0.5, 0.4, 1 },
	height = 24,
	padding = 6,
	inset = 2,
})
ShardTrim:RegisterSkin("ember", {
	label = "Ember",
	backdrop = THIN,
	bg = { 0.12, 0.04, 0.02 },
	border = { 0.9, 0.4, 0.1 },
	hover = { 1, 0.65, 0.2 },
	height = 24,
	padding = 6,
	inset = 2,
})
ShardTrim:RegisterSkin("frost", {
	label = "Frost",
	backdrop = THIN,
	bg = { 0.02, 0.06, 0.1 },
	border = { 0.4, 0.7, 1 },
	hover = { 0.7, 0.9, 1 },
	height = 24,
	padding = 6,
	inset = 2,
})
ShardTrim:RegisterSkin("outline", {
	label = "Outline",
	backdrop = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 },
	bg = { 0.1, 0.1, 0.1 },
	border = { 0, 0, 0 },
	hover = { 1, 0.82, 0 },
	height = 26,
	padding = 7,
	inset = 3,
})
ShardTrim:RegisterSkin("stone", {
	label = "Stone",
	backdrop = {
		bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 128, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	},
	bg = { 1, 1, 1 },
	border = { 0.5, 0.5, 0.5 },
	hover = { 1, 0.82, 0 },
})

local function ShowBarTooltip(self)
	if not ShardTrimDB.tooltip then return end
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
	FillTooltip(GameTooltip, {
		"Left-click: delete one extra shard",
		"Middle-click: turn trimming " .. (ShardTrimDB.enabled and "off" or "on"),
		"Mouse wheel: shards to keep up or down (shift for 5)",
		ShardTrimDB.locked and "Right-click: unlock to move" or "Drag to move, right-click to lock",
	})
	GameTooltip:Show()
end

local function SetBorder(color)
	if not color then return end
	if rounded then
		ColorShape(roundBorder, color)
	elseif bar:GetBackdrop() then
		bar:SetBackdropBorderColor(unpack(color))
	end
end

bar:RegisterForClicks("LeftButtonUp", "MiddleButtonUp", "RightButtonUp")
bar:SetScript("OnClick", function(self, button)
	if button == "MiddleButton" then return ShardTrim_Toggle() end -- Update redraws the tooltip
	if button ~= "RightButton" then return Trim() end
	ShardTrimDB.locked = not ShardTrimDB.locked
	print(NAME .. "banner " .. (ShardTrimDB.locked and "locked." or "unlocked - drag to move."))
	ShowBarTooltip(self)
end)
-- Mouse wheel over the banner changes Shards to Keep, by 5 with shift held
bar:SetScript("OnMouseWheel", function(_, delta)
	local step = IsShiftKeyDown() and 5 or 1
	Set("threshold", math.min(math.max(ShardTrimDB.threshold + delta * step, 0), 100))
end)
bar:SetScript("OnEnter", function(self)
	SetBorder(current and current.hover)
	ShowBarTooltip(self)
end)
bar:SetScript("OnLeave", function()
	SetBorder(current and current.border)
	if GameTooltip:IsOwned(bar) then GameTooltip:Hide() end
end)
bar:SetMovable(true)
bar:SetClampedToScreen(true)
bar:RegisterForDrag("LeftButton")
bar:SetScript("OnDragStart", function(self)
	if not ShardTrimDB.locked then
		GameTooltip:Hide()
		self:StartMoving()
	end
end)
bar:SetScript("OnDragStop", bar.StopMovingOrSizing)

-- Data broker (shows in Titan Panel, ChocolateBar, Bazooka, ...) and minimap button.
local broker = LibStub("LibDataBroker-1.1"):NewDataObject("ShardTrim", {
	type = "data source",
	label = "Soul Shards",
	icon = ICON,
	text = "",
	OnClick = function(_, button)
		if button == "RightButton" then
			OpenOptions()
		elseif IsShiftKeyDown() then
			Trim()
		else
			ShardTrim_Toggle()
		end
	end,
	OnTooltipShow = function(tt)
		FillTooltip(tt, {
			"Left-click: turn trimming " .. (ShardTrimDB.enabled and "off" or "on"),
			"Shift-click: delete one extra shard",
			"Right-click: options",
		})
	end,
})
local LDBIcon = LibStub("LibDBIcon-1.0")
local minimapStatus -- tick or cross over the minimap button's icon

local function UpdateMinimap()
	ShardTrimDB.minimapIcon.hide = not ShardTrimDB.minimap
	if ShardTrimDB.minimap then LDBIcon:Show("ShardTrim") else LDBIcon:Hide("ShardTrim") end
end

-- Takes keyboard input only while over the limit in auto mode; every key still passes through.
local keys = CreateFrame("Frame")
keys:SetPropagateKeyboardInput(true)
keys:SetScript("OnKeyDown", Trim)
WorldFrame:HookScript("OnMouseDown", function()
	if ShardTrimDB.method == "auto" then Trim() end
end)

function Update()
	local total, limit = Scan()
	local on, banner = ShardTrimDB.enabled, ShardTrimDB.banner
	local over = total > limit
	-- "above" stays up while trimming is off, so you can turn it back on; and the banner shows
	-- while the Options window is open, to preview changes
	local visible = banner ~= "never" and (banner == "always" or over or previewing)
	keys:EnableKeyboard(on and over and ShardTrimDB.method == "auto")
	bar:SetAlpha(visible and 1 or 0) -- hidden by alpha, not Hide(), so /click ShardTrimButton always works
	bar:EnableMouse(visible)
	bar:EnableMouseWheel(visible)

	icon:SetDesaturated(not on)
	status:SetTexture(on and STATUS_ON or STATUS_OFF)
	if on then label:SetTextColor(1, 0.82, 0) else label:SetTextColor(0.5, 0.5, 0.5) end
	if CountPosition() == "footer" then
		count:SetFormattedText("%d|cffa0a0a0/%d|r", total, limit) -- the count in its usual color, the target in grey
	else
		count:SetFormattedText("%d / %d", total, limit)
	end
	if not on then
		count:SetTextColor(0.5, 0.5, 0.5)
	elseif over then
		count:SetTextColor(1, 0.25, 0.25)
	else
		count:SetTextColor(1, 1, 1)
	end
	Layout()
	if GameTooltip:IsOwned(bar) then ShowBarTooltip(bar) end
	callbacks:Fire("BannerUpdate", bar, total, limit, over, on)

	local color = not on and "808080" or over and "ff4040" or "ffffff"
	-- Broker bars only take one icon, so the tick or cross goes inline before the count; the
	-- minimap button gets it over its icon instead.
	broker.text = ("|T%s:0|t |cff%s%d / %d|r"):format(on and STATUS_ON or STATUS_OFF, color, total, limit)
	local dim = on and 1 or 0.4 -- greys out the minimap button's icon while off
	if broker.iconR ~= dim then broker.iconR, broker.iconG, broker.iconB = dim, dim, dim end
	if minimapStatus then minimapStatus:SetTexture(on and STATUS_ON or STATUS_OFF) end
end

-- Settings panel (Esc > Options > AddOns > Avidity Shard Trim, with a Banner page under it)
local function BuildOptions()
	category = Settings.RegisterVerticalLayoutCategory("Avidity Shard Trim")
	local bannerPage, bannerLayout = Settings.RegisterVerticalLayoutSubcategory(category, "Banner")
	-- A key can have a control on both pages: both read and write the same saved value, and each
	-- page reads it fresh when shown. The first one registered is the one Set() goes through.
	local function Setting(page, key, label, onChange)
		local default = DEFAULTS[key]
		local variable = "ShardTrim_" .. key .. (settings[key] and "_" .. page:GetID() or "")
		local setting = Settings.RegisterAddOnSetting(page, variable, key, ShardTrimDB, type(default), label, default)
		setting:SetValueChangedCallback(function()
			if onChange then onChange() end
			Update()
		end)
		settings[key] = settings[key] or setting
		return setting
	end
	local function Slider(min, max, step, format)
		local options = Settings.CreateSliderOptions(min, max, step)
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, format)
		return options
	end
	local function Choices(list)
		return function()
			local c = Settings.CreateControlTextContainer()
			for _, choice in ipairs(list) do c:Add(choice[1], choice[2], choice[3]) end
			return c:GetData()
		end
	end
	local function Percent(value) return value .. "%" end
	local Checkbox = Settings.CreateCheckbox or Settings.CreateCheckBox

	-- Main page: what gets trimmed and how
	Checkbox(category, Setting(category, "enabled", "Enable Trimming"),
		"Turn shard deleting on or off. Also by middle-clicking the banner, from the minimap button or a data broker display, with a keybind (Key Bindings > AddOns) or /strim on, off or toggle.")

	Settings.CreateSlider(category, Setting(category, "threshold", "Shards to Keep"), Slider(0, 100, 1),
		"Any shards above this number get deleted. Never goes below the total slots in your equipped shard bags.")

	Settings.CreateDropdown(category, Setting(category, "method", "Delete Method"), Choices({
		{ "auto", "Automatic (any key or click)", "Any key press or click deletes one extra shard. Movement keys still move you." },
		{ "button", "Click the banner", "Click the banner to delete one extra shard." },
		{ "macro", "Macro / keybind", "Use the Delete One Extra Shard keybind (Key Bindings > AddOns) or /click ShardTrimButton in a macro." },
	}), "How extra shards get deleted.")

	local SHOW_BANNER = Choices({
		{ "always", "Always", "Always show your shard count on screen." },
		{ "above", "Above the limit", "Only show the banner while you have more shards than you keep." },
		{ "never", "Never", "Never show the banner. Trimming still works by key, click or macro." },
	})
	local SHOW_BANNER_TIP = "When the shard count banner is shown. Left-click it to delete a shard, middle-click to turn trimming on or off, scroll over it to change Shards to Keep, right-click to lock or unlock it, drag to move it."
	Settings.CreateDropdown(category, Setting(category, "banner", "Show Banner"), SHOW_BANNER,
		SHOW_BANNER_TIP .. " Change its look on the Banner page.")

	Checkbox(category, Setting(category, "minimap", "Show Minimap Button", UpdateMinimap),
		"Show a minimap button. Left-click it to turn trimming on or off, shift-click to delete one extra shard, right-click for these options.")

	-- Banner page: how it looks. The banner stays on screen while this window is open, as a preview.
	Settings.CreateDropdown(bannerPage, Setting(bannerPage, "banner", "Show Banner"), SHOW_BANNER, SHOW_BANNER_TIP)

	Settings.CreateDropdown(bannerPage, Setting(bannerPage, "layout", "Layout", ApplyStyle), Choices(LAYOUTS),
		"What the banner shows.")

	Settings.CreateSlider(bannerPage, Setting(bannerPage, "iconSize", "Icon Size", ApplyStyle), Slider(12, 64, 2),
		"How big the shard icon is. Doesn't apply to the Label layout.")

	Settings.CreateDropdown(bannerPage, Setting(bannerPage, "countPos", "Count Position", ApplyStyle), Choices(COUNT_POSITIONS),
		"Where your shard count goes relative to the icon, or to the \"Soul Shards\" text in the Label layout.")

	Settings.CreateDropdown(bannerPage, Setting(bannerPage, "style", "Style", ApplyStyle), function()
		local c = Settings.CreateControlTextContainer()
		for _, key in ipairs(skinOrder) do c:Add(key, skins[key].label or key) end
		return c:GetData()
	end, "The banner's border and background. Skin addons and UI packs can add their own styles here.")

	Settings.CreateSlider(bannerPage, Setting(bannerPage, "fontSize", "Font Size", ApplyStyle), Slider(8, 24, 1),
		"How big the count and the \"Soul Shards\" text are. When the count sits on the icon it's a little smaller, and shrinks further to fit the icon's width.")

	bannerLayout:AddInitializer(CreateSettingsCheckboxSliderInitializer(
		Setting(bannerPage, "background", "Background", ApplyStyle), "Background",
		"Show the banner's background and border. Turn it off for just the icon and text.",
		Setting(bannerPage, "opacity", "Background Opacity", ApplyStyle), Slider(0, 100, 5, Percent), "Opacity",
		"How solid the background is. The border and text stay solid."))

	Settings.CreateSlider(bannerPage, Setting(bannerPage, "rounding", "Corner Rounding", ApplyStyle), Slider(0, 16, 1),
		"Rounds the banner's corners, in pixels. Works on the plain-color styles (Flat, Shadow, Fel, Glass, Void, Ember, Frost, Outline); the others keep the corners drawn into their border art.")

	Settings.CreateDropdown(bannerPage, Setting(bannerPage, "indicator", "On/Off Badge", ApplyStyle), Choices({
		{ "always", "Always", "A green tick while trimming is on, a red cross while it's off." },
		{ "off", "Only when off", "Just the red cross, while trimming is off." },
		{ "never", "Never", "No badge. The banner still greys out while trimming is off." },
	}), "A tick or cross on the icon showing whether trimming is on. The Label layout has no icon, so it greys out instead.")

	Checkbox(bannerPage, Setting(bannerPage, "tooltip", "Tooltip"),
		"Show your shard count and what clicking does when you mouse over the banner.")

	Settings.RegisterAddOnCategory(category)

	if SettingsPanel then
		SettingsPanel:HookScript("OnShow", function() previewing = true; Update() end)
		SettingsPanel:HookScript("OnHide", function() previewing = false; Update() end)
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		if ShardTrimDB.banner == nil then -- carry over the old "Always Show Banner" checkbox and macro mode's hidden banner
			ShardTrimDB.banner = ShardTrimDB.method == "macro" and "never" or ShardTrimDB.alwaysShow and "always" or nil
		end
		ShardTrimDB.alwaysShow = nil
		if ShardTrimDB.layout == nil and ShardTrimDB.showIcon ~= nil then -- 1.5.0's Show Icon / Show Label checkboxes
			ShardTrimDB.layout = not ShardTrimDB.showIcon and "text" or ShardTrimDB.showLabel == false and "compact" or "full"
		end
		ShardTrimDB.showIcon, ShardTrimDB.showLabel = nil, nil
		if ShardTrimDB.layout == "full" then ShardTrimDB.layout = "compact" end -- the Icon, label and count layout, since removed
		if ShardTrimDB.style == "bronze" then ShardTrimDB.style = "tooltip" end -- 1.14's Forever Bronze style, since removed
		ShardTrimDB.scale = nil -- the banner Scale slider, replaced by Icon Size and Font Size
		if ShardTrimDB.iconSize == nil then -- 1.10's Small icon and Large icon layouts became Icon plus Icon Size
			if ShardTrimDB.layout == "icon" then ShardTrimDB.iconSize = 36 end
			if ShardTrimDB.layout == "compact" then ShardTrimDB.layout = "icon" end
		end
		ShardTrimDB.currency, ShardTrimDB.currencyCollapsed = nil, nil -- 1.7.0's Currency tab option, since removed
		if ShardTrimDB.style == "none" then -- the No background style became the Background checkbox
			ShardTrimDB.style, ShardTrimDB.background = "tooltip", false
		end
		if ShardTrimDB.badge == false then ShardTrimDB.indicator = "never" end -- 1.8's On/Off Badge checkbox
		ShardTrimDB.badge = nil
		for key, value in pairs(DEFAULTS) do
			if ShardTrimDB[key] == nil then ShardTrimDB[key] = value end
		end
		ShardTrimDB.minimapIcon = ShardTrimDB.minimapIcon or {}
		ShardTrimDB.minimapIcon.hide = not ShardTrimDB.minimap
		LDBIcon:Register("ShardTrim", broker, ShardTrimDB.minimapIcon)
		local button = LDBIcon:GetMinimapButton("ShardTrim")
		if button and button.icon then
			minimapStatus = button:CreateTexture(nil, "OVERLAY", nil, 7)
			minimapStatus:SetSize(14, 14)
			minimapStatus:SetPoint("CENTER", button.icon)
		end
		BuildOptions()
		loaded = true
		ApplyStyle()
		self:RegisterEvent("BAG_UPDATE_DELAYED") -- only once the settings above exist
	end
	busy = false
	Update()
end)

-- Key Bindings > AddOns (Bindings.xml)
BINDING_HEADER_SHARDTRIM = "Avidity Shard Trim"
BINDING_NAME_SHARDTRIM_TOGGLE = "Turn Trimming On/Off"
_G["BINDING_NAME_CLICK ShardTrimButton:LeftButton"] = "Delete One Extra Shard"

SLASH_SHARDTRIM1, SLASH_SHARDTRIM2 = "/shardtrim", "/strim"
SlashCmdList.SHARDTRIM = function(msg)
	msg = strtrim(msg:lower())
	local n = tonumber(msg:match("%d+"))
	if n then
		Set("threshold", math.min(n, 100))
	elseif msg == "on" or msg == "off" then
		SetEnabled(msg == "on")
	elseif msg == "toggle" then
		ShardTrim_Toggle()
	else
		OpenOptions()
	end
end
