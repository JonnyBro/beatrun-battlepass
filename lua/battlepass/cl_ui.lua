if not CLIENT then return end

BRBP = BRBP or {}
BRBP.State = BRBP.State or {
	xp = 0,
	premium = false,
	unlocked = {},
	equipped = {},
	daily = {},
	weekly = {},
	seasonEnds = 0,
	premiumCost = 10000,
	beatrunXP = 0,
	grantedTier = 0
}

-- the engine only reads .properties at startup and on language change, so a file that was just downloaded
-- from the server (not mounted from Workshop) would show raw keys until restart; read it ourselves as well
local PHRASES = "resource/localization/%s/beatrun_battlepass.properties"

local function AddPhrases(lang)
	local raw = file.Read(string.format(PHRASES, lang), "GAME")

	if not raw then return end

	for line in string.gmatch(raw, "[^\r\n]+") do
		local key, value = string.match(line, "^%s*([%w_%.]+)%s*=(.*)$")

		if key then language.Add(key, string.Replace(value, "\\n", "\n")) end
	end
end

local function LoadPhrases(lang)
	AddPhrases("en")
	if lang and lang ~= "en" then AddPhrases(lang) end
end

LoadPhrases(GetConVar("gmod_language"):GetString())
cvars.AddChangeCallback("gmod_language", function(_, _, lang)
	LoadPhrases(lang)
end, "BRBP_Phrases")

-- BeatrunUI, CurrentTheme and the BeatrunUI*/AEUI* fonts come from the gamemode, which loads after autorun,
-- so they are only touched inside functions, never at file scope
local function S(px)
	return BeatrunUI.S(px)
end

local function Theme()
	return CurrentTheme()
end

local menu
local tab = "pass"
local content

local SND_CLICK = "brbp_sounds/battlepass_clicksound.ogg"
local SND_CLOSE_BTN = "brbp_sounds/battlepass_button_close_click.wav"
local SND_OPEN = "brbp_sounds/battlepass_opened.mp3"
local SND_CLOSE = "brbp_sounds/battlepass_closed.mp3"

local uiChan
local function PlayUI(path)
	if not isstring(path) or path == "" then return end

	sound.PlayFile("sound/" .. path, "noplay", function(chan)
		if not IsValid(chan) then
			surface.PlaySound(path)

			return
		end

		if path == SND_OPEN or path == SND_CLOSE then
			if IsValid(uiChan) then uiChan:Stop() end
			uiChan = chan
		end

		chan:SetVolume(1)
		chan:Play()
	end)
end

local col = {
	gold = Color(255, 220, 40),
	green = Color(94, 255, 110)
}

local mats = {
	star = Material("icons/group.png")
}

local iconCache = {}
local function Icon(path)
	if not path then return mats.star end
	if iconCache[path] then return iconCache[path] end

	iconCache[path] = Material(path, "smooth")

	return iconCache[path]
end

local function State()
	return BRBP.State
end

local function IsUnlocked(id)
	return State().unlocked and State().unlocked[id]
end

local function Equipped(slot)
	local eq = State().equipped or {}

	return eq[slot] or ""
end

local function Equip(slot, id)
	net.Start("BRBP_Equip")
		net.WriteString(slot)
		net.WriteString(id or "")
	net.SendToServer()
end

local function LiveXP()
	return LocalPlayer():GetNW2Int("BRBP_XP", State().xp or 0)
end

local function SeasonLine()
	local st = State()
	local ends = st.seasonEnds or BRBP.Config.SeasonEnds or 0
	local endsText = ""

	if ends > 0 then
		endsText = ends > os.time() and string.format(language.GetPhrase("beatrun_battlepass.ends"), os.date("%d.%m.%Y", ends)) or language.GetPhrase("beatrun_battlepass.season_over")
	end

	return string.format(language.GetPhrase("beatrun_battlepass.players"), BRBP.Config.Season or "") .. "  -  " .. (st.seasonName or BRBP.Config.SeasonName or ""), endsText
end

local function DrawBar(x, y, w, h, frac, fill)
	local th = Theme()
	surface.SetDrawColor(th.panels.secondary)
	surface.DrawRect(x, y, w, h)
	surface.SetDrawColor(fill or th.accent)
	surface.DrawRect(x, y, math.floor(w * math.Clamp(frac, 0, 1)), h)
end

local function RewardLines(rewards)
	local lines = {}

	if not rewards then return lines end

	for i = 1, #rewards do
		local r = rewards[i]
		local item = r[1] == "cosmetic" and BRBP.Cosmetics[r[2]] or nil

		if item then
			lines[#lines + 1] = language.GetPhrase("beatrun_battlepass.reward_" .. item.type)
			lines[#lines + 1] = item.short or item.text or item.name
		else
			lines[#lines + 1] = BRBP.RewardText(r)
		end
	end

	return lines
end

local function SplitWrapTokens(text)
	local tokens = {}

	for word in string.gmatch(text or "", "%S+") do
		local start = 1

		while start <= #word do
			local i = word:find("[-_]", start)

			if not i then
				tokens[#tokens + 1] = word:sub(start)
				break
			end

			tokens[#tokens + 1] = word:sub(start, i)
			start = i + 1
		end
	end

	if #tokens == 0 then tokens[1] = text or "" end

	return tokens
end

local function WrapFitLines(text, maxW, font)
	surface.SetFont(font)
	text = text or ""
	if surface.GetTextSize(text) <= maxW then
		return { text }
	end

	local words = SplitWrapTokens(text)
	local lines = {}
	local cur = ""

	for i = 1, #words do
		local try = (cur == "") and words[i] or (cur .. ((string.find(cur, "[-_]$") and "") or " ") .. words[i])

		if cur ~= "" and surface.GetTextSize(try) > maxW then
			lines[#lines + 1] = cur
			cur = words[i]
		else
			cur = try
		end
	end

	if cur ~= "" then lines[#lines + 1] = cur end
	if #lines == 0 then lines[1] = text end

	return lines
end

local CARD_FONT = "AEUISmall"

local function DrawFitText(text, cx, y, maxW, color)
	local lines = WrapFitLines(text, maxW, CARD_FONT)
	local lh = draw.GetFontHeight(CARD_FONT)

	for i = 1, #lines do
		draw.SimpleText(lines[i], CARD_FONT, cx, y + (i - 1) * lh, color, TEXT_ALIGN_CENTER)
	end

	return #lines * lh
end

local function DrawPremiumHeader(w, y)
	local label = language.GetPhrase("beatrun_battlepass.premium")
	surface.SetFont("BeatrunUISmall")
	local tw, th = surface.GetTextSize(label)
	local star = math.floor(th * 0.8)
	local gap = S(4)
	local x = w / 2 - (star + gap + tw) / 2
	surface.SetDrawColor(col.gold)
	surface.SetMaterial(mats.star)
	surface.DrawTexturedRect(x, y + (th - star) / 2, star, star)
	draw.SimpleText(label, "BeatrunUISmall", x + star + gap, y, col.gold, TEXT_ALIGN_LEFT)
end

local function HideScrollerButtons(scroller)
	local function wipe(btn)
		if not IsValid(btn) then return end

		btn:SetVisible(false)
		btn:SetSize(0, 0)
		btn:SetText("")
		btn.Paint = function() end
	end

	wipe(scroller.btnLeft)
	wipe(scroller.btnRight)
	local old = scroller.PerformLayout
	scroller.PerformLayout = function(self, w, h)
		wipe(self.btnLeft)
		wipe(self.btnRight)
		if old then old(self, w, h) end
		wipe(self.btnLeft)
		wipe(self.btnRight)
	end
end

local function HookPassDrag(scroller)
	local drag = { active = false, moved = false, startX = 0, startOff = 0 }

	local function maxOff()
		local canvas = scroller.pnlCanvas

		if not IsValid(canvas) then return 0 end

		return math.max(0, canvas:GetWide() - scroller:GetWide())
	end

	local function stopDrag()
		if not drag.active then return end

		drag.active = false
		scroller:MouseCapture(false)
		scroller:SetCursor("arrow")
	end

	local function startDrag()
		drag.active = true
		drag.moved = false
		drag.startX = gui.MouseX()
		drag.startOff = scroller.OffsetX or 0
	end

	local function bindPress(pnl)
		if not IsValid(pnl) then return end

		pnl:SetMouseInputEnabled(true)
		local prev = pnl.OnMousePressed
		pnl.OnMousePressed = function(self, code)
			if code == MOUSE_LEFT then startDrag() end
			if prev then return prev(self, code) end
		end

		if isfunction(pnl.DoClick) then
			local click = pnl.DoClick
			pnl.DoClick = function(self, ...)
				if drag.moved then return end

				return click(self, ...)
			end
		end
	end

	bindPress(scroller)
	bindPress(scroller.pnlCanvas)
	for _, pnl in ipairs(scroller.Panels or {}) do
		bindPress(pnl)
		for _, child in ipairs(pnl:GetChildren()) do
			bindPress(child)
		end
	end

	local oldThink = scroller.Think
	scroller.Think = function(self)
		if oldThink then oldThink(self) end
		if not drag.active then return end

		if not input.IsMouseDown(MOUSE_LEFT) then
			stopDrag()

			return
		end

		local dx = gui.MouseX() - drag.startX

		if math.abs(dx) >= 6 then
			drag.moved = true
			self:MouseCapture(true)
			self:SetCursor("sizewe")
		end

		if drag.moved then
			self.OffsetX = math.Clamp(drag.startOff - dx, 0, maxOff())
			self:InvalidateLayout(true)
		end
	end

	scroller.OnMouseReleased = function(_, code)
		if code == MOUSE_LEFT then stopDrag() end
	end
end

local function BuildPassHeader(parent)
	local header = parent:Add("DPanel")
	header:Dock(TOP)
	header:SetTall(S(76))
	header:DockMargin(0, 0, 0, S(12))
	header:DockPadding(S(20), S(16), S(16), S(16))
	header.Paint = function(_, w, h)
		local th = Theme()
		BeatrunUI.PaintPanel(w, h, th.panels.primary, true)

		local xp = LiveXP()
		local tier = math.min(BRBP.GetTierForXP(xp), BRBP.TrackEnd())
		local into, need = BRBP.XPIntoTier(xp)
		local x = S(20)
		local level = string.format(language.GetPhrase("beatrun_battlepass.level"), tier)
		draw.SimpleText(level, "BeatrunUILarge", x, h / 2, th.text.primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetFont("BeatrunUILarge")
		local bx = x + surface.GetTextSize(level) + S(28)
		draw.SimpleText(string.format(language.GetPhrase("beatrun_battlepass.xp"), into, need), "AEUIDefault", bx, S(14), th.text.muted)
		DrawBar(bx, h - S(24), math.max(math.min(w - bx - S(380), S(520)), S(80)), S(6), into / need)
	end

	local buy = BeatrunUI.MakeButton(header, "", "primary", "BeatrunUISmall")
	buy:Dock(RIGHT)
	buy:SetWide(S(340))
	buy.Think = function(self)
		local cur = State()
		local text = cur.premium and language.GetPhrase("beatrun_battlepass.premium_owned") or string.format(language.GetPhrase("beatrun_battlepass.buy_premium"), cur.premiumCost or BRBP.Config.PremiumXPCost)

		if self:GetText() ~= text then self:SetText(text) end
		self:SetCursor(cur.premium and "arrow" or "hand")
	end

	buy.Paint = function(self, w, h)
		if State().premium then
			BeatrunUI.PaintPanel(w, h, Theme().panels.secondary)
			surface.SetDrawColor(col.gold)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			self:SetTextColor(col.gold)

			return
		end

		ApplyButtonTheme(self, w, h, "primary")
	end

	buy.DoClick = function()
		if State().premium then return end

		PlayUI(SND_CLICK)
		net.Start("BRBP_BuyPremium")
		net.SendToServer()
	end
end

local function TierCard(i)
	local def = BRBP.Tiers[i]
	local card = vgui.Create("DPanel")
	card:SetWide(S(124))

	card.Paint = function(_, w, h)
		local th = Theme()
		local granted = State().grantedTier or 0
		local reached = BRBP.GetTierForXP(LiveXP()) >= i
		local claimed = granted >= i
		local canClaim = reached and granted == i - 1
		local textCol = (claimed or canClaim) and th.text.primary or th.text.dark

		BeatrunUI.PaintPanel(w, h, claimed and th.panels.secondary or th.panels.primary)
		if canClaim then
			local pulse = (math.sin(CurTime() * 4) + 1) * 0.5
			surface.SetDrawColor(ColorAlpha(th.accent, 120 + 135 * pulse))
			surface.DrawOutlinedRect(0, 0, w, h, S(2))
		end

		local pad = S(8)

		if BRBP.IsBonusTier(i) then
			draw.SimpleText(language.GetPhrase("beatrun_battlepass.bonus"), "BeatrunUISmall", w / 2, pad, col.gold, TEXT_ALIGN_CENTER)
		else
			DrawPremiumHeader(w, pad)
		end

		local y = pad + draw.GetFontHeight("BeatrunUISmall") + S(6)
		local prem = RewardLines(def and def.premium)

		for k = 1, math.min(#prem, 4) do
			y = y + DrawFitText(prem[k], w / 2, y, w - S(12), textCol)
		end

		local mid = math.floor(h * 0.5)
		local numH = draw.GetFontHeight("BeatrunUILarge")
		surface.SetDrawColor(reached and th.text.primary or th.border)
		surface.DrawRect(S(12), mid - numH / 2 - S(4), w - S(24), 1)
		surface.DrawRect(S(12), mid + numH / 2 + S(4), w - S(24), 1)
		draw.SimpleText(tostring(i), "BeatrunUILarge", w / 2, mid, claimed and col.green or textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		y = mid + numH / 2 + S(12)
		draw.SimpleText(language.GetPhrase("beatrun_battlepass.free"), "BeatrunUISmall", w / 2, y, th.text.muted, TEXT_ALIGN_CENTER)
		y = y + draw.GetFontHeight("BeatrunUISmall") + S(6)
		local free = RewardLines(def and def.free)

		for k = 1, math.min(#free, 4) do
			y = y + DrawFitText(free[k], w / 2, y, w - S(12), textCol)
		end
	end

	local claim = BeatrunUI.MakeButton(card, language.GetPhrase("beatrun_battlepass.claim"), "primary")
	claim:Dock(BOTTOM)
	claim:DockMargin(S(8), 0, S(8), S(8))
	claim:SetVisible(false)
	card.Think = function()
		local can = BRBP.GetTierForXP(LiveXP()) >= i and (State().grantedTier or 0) == i - 1

		if claim:IsVisible() ~= can then claim:SetVisible(can) end
	end

	claim.DoClick = function(self)
		if (State().grantedTier or 0) ~= i - 1 then return end

		self:SetVisible(false)
		PlayUI(SND_CLICK)
		State().grantedTier = i
		net.Start("BRBP_Claim")
			net.WriteUInt(i, 8)
		net.SendToServer()
	end

	return card
end

local function BuildPass(parent)
	BuildPassHeader(parent)

	local scroller = parent:Add("DHorizontalScroller")
	scroller:Dock(FILL)
	scroller:SetOverlap(-S(8))
	HideScrollerButtons(scroller)

	for i = 1, BRBP.TrackEnd() do
		scroller:AddPanel(TierCard(i))
	end

	local live = math.Clamp(BRBP.GetTierForXP(LiveXP()), 1, BRBP.TrackEnd())
	local granted = State().grantedTier or 0
	local focus = (granted + 1 <= live) and (granted + 1) or live
	local cardW = S(124)
	local step = cardW + S(8)

	-- DHorizontalScroller has no width until the first layout; hide the canvas so it doesn't flash at offset 0
	if IsValid(scroller.pnlCanvas) then
		scroller.pnlCanvas:SetVisible(false)
	end

	local placed = false
	local prevLayout = scroller.PerformLayout
	scroller.PerformLayout = function(self, w, h)
		if not placed and w > 8 then
			self.OffsetX = math.max(0, (focus - 1) * step + cardW * 0.5 - w * 0.5)
			placed = true
			if IsValid(self.pnlCanvas) then
				self.pnlCanvas:SetVisible(true)
			end
		end

		if prevLayout then prevLayout(self, w, h) end
	end

	HookPassDrag(scroller)
end

local function QuestRow(parent, kind, index)
	local row = parent:Add("DPanel")
	row:Dock(TOP)
	row:SetTall(S(64))
	row:DockMargin(0, 0, 0, S(6))
	row.Paint = function(_, w, h)
		local item = ((State()[kind]) or {})[index]

		if not item then return end

		local th = Theme()
		BeatrunUI.PaintPanel(w, h, th.panels.primary, item.done)
		if item.done then
			surface.SetDrawColor(col.green)
			surface.DrawRect(0, 0, S(4), h)
		end

		local slot = h
		local custom = isstring(item.icon) and item.icon:find("beatrun_bp_icons", 1, true)
		-- the custom icons have a lot of transparent padding, so they are drawn bigger than the row
		local iconSize = custom and math.floor(h * 1.3) or S(32)
		surface.SetDrawColor(item.done and col.green or th.text.primary)
		surface.SetMaterial(Icon(item.icon))
		surface.DrawTexturedRect(S(8) + (slot - iconSize) / 2, (h - iconSize) / 2, iconSize, iconSize)

		local textX = S(8) + slot + S(8)
		local right = w - S(14)
		local statCol = item.done and col.green or th.text.muted
		draw.SimpleText(BRBP.QuestLabel(item.id, item.goal), "BeatrunUISmall", textX, S(10), th.text.primary)
		draw.SimpleText("+" .. item.xp .. " XP", "AEUIDefault", right, S(10), statCol, TEXT_ALIGN_RIGHT)

		local pct = (item.progress or 0) / math.max(item.goal or 1, 1)
		DrawBar(textX, h - S(18), right - textX - S(110), S(6), pct, item.done and col.green or nil)
		draw.SimpleText((item.progress or 0) .. " / " .. (item.goal or 0), "AEUIDefault", right, h - S(15), statCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
end

local function QuestColumn(parent, kind)
	local column = parent:Add("DPanel")
	column.Paint = nil

	local head = column:Add("DPanel")
	head:Dock(TOP)
	head:SetTall(draw.GetFontHeight("BeatrunUI") + S(12))
	head.Paint = function(_, w, h)
		local th = Theme()
		local name = "// " .. language.GetPhrase("beatrun_battlepass." .. (kind == "daily" and "daily" or "weekly"))
		draw.SimpleText(name, "BeatrunUI", 0, 0, kind == "weekly" and col.gold or th.text.primary)
		local left = (kind == "daily") and BRBP.SecondsUntilNextDay() or BRBP.SecondsUntilNextWeek()
		draw.SimpleText(string.format(language.GetPhrase("beatrun_battlepass.reset_in"), BRBP.FormatCountdown(left)), "AEUIDefault", w, 0, th.text.muted, TEXT_ALIGN_RIGHT)
	end

	local scroll = BeatrunUI.MakeScroll(column)

	for i = 1, #(State()[kind] or {}) do
		QuestRow(scroll, kind, i)
	end

	if kind == "daily" then
		local cap = scroll:Add("DPanel")
		cap:Dock(TOP)
		cap:SetTall(S(36))
		cap:DockMargin(0, S(6), 0, 0)
		cap.Paint = function(_, w, h)
			local th = Theme()
			local st = State()
			local got, max = st.parkourXP or 0, st.parkourCap or BRBP.Config.ParkourDailyCap
			local text = string.format(language.GetPhrase("beatrun_battlepass.parkour_today"), got, max)

			draw.SimpleText(text, "AEUIDefault", 0, 0, got >= max and col.green or th.text.muted)
			DrawBar(0, h - S(8), w, S(4), got / math.max(max, 1), got >= max and col.green or nil)
		end
	end

	return column
end

local function BuildQuests(parent)
	local left = QuestColumn(parent, "daily")
	left:Dock(LEFT)
	local right = QuestColumn(parent, "weekly")
	right:Dock(FILL)
	right:DockMargin(S(16), 0, 0, 0)

	local prev = parent.PerformLayout
	parent.PerformLayout = function(self, w, h)
		left:SetWide(math.floor((w - S(16)) / 2))
		if prev then prev(self, w, h) end
	end

	parent:InvalidateLayout()
end

local typeOrder = { "trail", "title", "footstep", "jump" }
local typeLang = {
	trail = "trail",
	title = "title_type",
	footstep = "footstep",
	jump = "jump"
}

local function CosmeticRow(scroll, typ, id)
	local def = BRBP.Cosmetics[id]
	local row = scroll:Add("DButton")
	row:Dock(TOP)
	row:SetTall(S(40))
	row:DockMargin(0, 0, 0, S(4))
	row:SetText("")
	row:SetCursor("hand")
	row.Paint = function(self, w, h)
		local th = Theme()
		local onNow = Equipped(typ) == id
		BeatrunUI.PaintPanel(w, h, self:IsHovered() and th.panels.secondary or th.panels.primary, onNow)

		local sw = S(16)
		local swatch = def.type == "title" and BRBP.TitleColor(def) or def.color

		if swatch then
			surface.SetDrawColor(swatch)
			surface.DrawRect(S(16), (h - sw) / 2, sw, sw)
		end

		local label = def.type == "title" and BRBP.TitleTag(def) or def.name
		draw.SimpleText(label, "BeatrunUISmall", S(16) + sw + S(12), h / 2, th.text.primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		local status = onNow and language.GetPhrase("beatrun_battlepass.equipped") or language.GetPhrase("beatrun_battlepass.equip")
		local statusCol = onNow and th.accent or (self:IsHovered() and th.text.primary or th.text.muted)
		draw.SimpleText(status, "BeatrunUISmall", w - S(16), h / 2, statusCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	row.DoClick = function()
		PlayUI(SND_CLICK)
		Equip(typ, Equipped(typ) == id and "" or id)
	end
end

local function BuildCosmetics(parent)
	local scroll = BeatrunUI.MakeScroll(parent)

	local any = false

	for _, typ in ipairs(typeOrder) do
		local ids = {}

		for id, def in pairs(BRBP.Cosmetics) do
			if def.type == typ and IsUnlocked(id) then
				ids[#ids + 1] = id
			end
		end

		table.sort(ids)
		if #ids > 0 then
			local title = BeatrunUI.MakeTitle(scroll, "#beatrun_battlepass." .. typeLang[typ])

			if any then title:DockMargin(0, S(14), 0, S(10)) end
			any = true
			for i = 1, #ids do
				CosmeticRow(scroll, typ, ids[i])
			end
		end
	end

	if not any then
		local empty = scroll:Add("DPanel")
		empty:Dock(TOP)
		empty:SetTall(S(80))
		empty.Paint = function(_, w, h)
			draw.SimpleText(language.GetPhrase("beatrun_battlepass.empty_cosmetics"), "BeatrunUI", w / 2, h / 2, Theme().text.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
end

local function FillContent()
	if not IsValid(content) then return end

	content:Clear()
	content.PerformLayout = nil
	if tab == "pass" then
		BuildPass(content)
	elseif tab == "quests" then
		BuildQuests(content)
	else
		BuildCosmetics(content)
	end
end

local function CloseMenu()
	if not IsValid(menu) then return end

	menu:Close()
end

function BRBP.OpenMenu(keepTab)
	if not keepTab then tab = "pass" end

	if IsValid(menu) then
		menu.tabs:Select(tab)

		return
	end

	menu = BeatrunUI.MakeWindow("#beatrun_battlepass.title", math.min(ScrW() * 0.9, S(1320)), math.min(ScrH() * 0.88, S(780)))
	menu:SetAlpha(0)
	menu:AlphaTo(255, 0.1)
	menu:SetKeyboardInputEnabled(true)
	menu.OnClose = function(self)
		if menu == self then menu = nil end
		PlayUI(SND_CLOSE)
	end
	-- the open bind is handled only by PlayerButtonDown: closing here too made the same press reopen the menu
	menu.OnKeyCodePressed = function(_, key)
		if key == KEY_ESCAPE then CloseMenu() end
	end

	local info = menu:Add("DPanel")
	info:Dock(TOP)
	info:SetTall(S(36))
	info:DockMargin(0, 0, 0, S(4))
	info.Paint = function(_, w, h)
		local th = Theme()
		local season, ends = SeasonLine()
		surface.SetFont("BeatrunUI")
		local sw = surface.GetTextSize(season)
		draw.SimpleText(season, "BeatrunUI", 0, h / 2, th.text.primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(ends, "AEUIDefault", sw + S(16), h / 2, th.text.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end


	local tabs = BeatrunUI.MakeTabBar(menu, 40)
	tabs:DockMargin(0, 0, 0, S(12))
	menu.tabs = tabs

	content = menu:Add("DPanel")
	content:Dock(FILL)
	content.Paint = nil

	for _, key in ipairs({ "pass", "quests", "cosmetics" }) do
		local btn = tabs:AddTab(key, "#beatrun_battlepass.tab_" .. key, function()
			tab = key
			FillContent()
		end)
		local click = btn.DoClick
		btn.DoClick = function(self)
			if tabs.active ~= key then PlayUI(SND_CLICK) end
			click(self)
		end
	end

	menu:InvalidateLayout(true)
	tabs:Select(tab)
	if not keepTab then
		PlayUI(SND_OPEN)
	end
end

net.Receive("BRBP_State", function()
	local len = net.ReadUInt(16)
	local raw = util.Decompress(net.ReadData(len))

	if not raw then return end

	local data = util.JSONToTable(raw)

	if not istable(data) then return end
	-- client clock can disagree with the server near a season boundary; the server's season wins
	if data.season and data.season ~= BRBP.Config.Season then
		BRBP.ApplySeason(data.season)
	end

	BRBP.State = data
end)

hook.Add("BRBP_ClientToast", "BRBP_RefreshMenu", function(kind)
	if not IsValid(menu) then return end
	if tab == "pass" and kind ~= 0 then return end

	FillContent()
end)

net.Receive("BRBP_Open", function()
	BRBP.OpenMenu()
end)

local lastToggle = 0
hook.Add("PlayerButtonDown", "BRBP_Toggle", function(ply, btn)
	if ply ~= LocalPlayer() then return end
	if btn ~= (BRBP.Config.OpenBind or KEY_F8) then return end
	if CurTime() - lastToggle < 0.25 then return end

	lastToggle = CurTime()
	if IsValid(menu) then
		CloseMenu()
	else
		net.Start("BRBP_Request")
		net.SendToServer()
		BRBP.OpenMenu()
	end
end)

concommand.Add("battlepass", function()
	net.Start("BRBP_Request")
	net.SendToServer()
	BRBP.OpenMenu()
end)

local logchange
local logoMat

local function BeatrunLogo()
	if logoMat and not logoMat:IsError() then return logoMat end

	local paths = {
		"../gamemodes/beatrun/logo.png",
		"gamemodes/beatrun/logo.png",
		"beatrun/logo.png"
	}
	for i = 1, #paths do
		local mat = Material(paths[i], "smooth")

		if mat and not mat:IsError() then
			logoMat = mat

			return logoMat
		end
	end
end

local function ParseMarks(text)
	local segs = {}
	local i = 1
	local n = #text

	while i <= n do
		local s, e, inner = string.find(text, "{(.-)}", i)

		if not s then
			segs[#segs + 1] = { string.sub(text, i), false }
			break
		end

		if s > i then
			segs[#segs + 1] = { string.sub(text, i, s - 1), false }
		end

		segs[#segs + 1] = { inner, true }
		i = e + 1
	end

	return segs
end

local function DrawMarked(text, cx, y, font)
	local th = Theme()
	surface.SetFont(font)
	local segs = ParseMarks(text)
	local total = 0

	for i = 1, #segs do
		total = total + surface.GetTextSize(segs[i][1])
	end

	local x = cx - total / 2

	for i = 1, #segs do
		local str, hi = segs[i][1], segs[i][2]
		draw.SimpleText(str, font, x, y, hi and th.accent or th.text.primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		x = x + surface.GetTextSize(str)
	end
end

local function CloseLogchange()
	if not IsValid(logchange) then return end

	PlayUI(SND_CLOSE)
	logchange:AlphaTo(0, 0.1, 0, function(_, pnl)
		if IsValid(pnl) then pnl:Remove() end
	end)
	logchange = nil
end

local function DrawLogo(x, y, w, h)
	local mat = BeatrunLogo()

	if not mat then return end

	local tw, th = mat:Width(), mat:Height()
	local tex = mat:GetTexture("$basetexture")

	if tex and tex.GetMappingWidth then
		local mw, mh = tex:GetMappingWidth(), tex:GetMappingHeight()

		if mw > 0 and mh > 0 then
			tw, th = mw, mh
		end
	end

	if tw < 8 then tw = 512 end
	if th < 8 then th = 128 end
	local scale = math.min(w / tw, h / th)
	local dw, dh = tw * scale, th * scale
	surface.SetMaterial(mat)
	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawTexturedRect(x + (w - dw) / 2, y + (h - dh) / 2, dw, dh)
end

local function WelcomeLines()
	return string.Explode("\n", language.GetPhrase("beatrun_battlepass.season" .. BRBP.Config.Season .. ".welcome"))
end

function BRBP.OpenLogchange()
	if IsValid(logchange) then
		logchange:Remove()
		logchange = nil
	end

	local BODY_FONT = "BeatrunUISmall"

	local function layout()
		local m = {}
		m.w = S(720)
		m.pad = S(24)
		m.logoH = S(90)
		m.headH = draw.GetFontHeight("BeatrunUILarge")
		m.lineH = draw.GetFontHeight(BODY_FONT) + S(4)
		m.blankH = S(10)
		m.keyH = S(44)
		m.okH = S(36)
		local body = 0

		for _, line in ipairs(WelcomeLines()) do
			body = body + (line == "" and m.blankH or m.lineH)
		end

		m.body = body
		m.h = math.min(m.pad + m.logoH + S(16) + m.headH + S(16) + body + S(20) + m.lineH + m.keyH + S(8) + m.lineH + S(20) + m.okH + m.pad, ScrH() - S(40))
		m.x = math.floor((ScrW() - m.w) / 2)
		m.y = math.floor((ScrH() - m.h) / 2)

		return m
	end

	logchange = vgui.Create("DFrame")
	logchange:SetSize(ScrW(), ScrH())
	logchange:SetTitle("")
	logchange:ShowCloseButton(false)
	logchange:SetDraggable(false)
	logchange:MakePopup()
	logchange:SetKeyboardInputEnabled(true)
	logchange:SetAlpha(0)
	logchange:AlphaTo(255, 0.12)

	logchange.Paint = function(self, w, h)
		local th = Theme()
		BeatrunUI.DrawPanelBlur(self)
		surface.SetDrawColor(0, 0, 0, 150)
		surface.DrawRect(0, 0, w, h)

		local m = layout()
		local cx = w / 2
		draw.RoundedBox(S(th.radius), m.x, m.y, m.w, m.h, th.bg)
		if th.outline then
			surface.SetDrawColor(th.border)
			surface.DrawOutlinedRect(m.x, m.y, m.w, m.h, 1)
		end

		surface.SetDrawColor(th.accent)
		surface.DrawRect(m.x, m.y, m.w, S(3))

		local y = m.y + m.pad
		DrawLogo(m.x, y, m.w, m.logoH)
		y = y + m.logoH + S(16)

		draw.SimpleText(language.GetPhrase("beatrun_battlepass.logchange"), "BeatrunUILarge", cx, y, th.text.primary, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		y = y + m.headH + S(16)

		for _, line in ipairs(WelcomeLines()) do
			if line == "" then
				y = y + m.blankH
			else
				DrawMarked(line, cx, y, BODY_FONT)
				y = y + m.lineH
			end
		end

		y = y + S(20)

		draw.SimpleText(language.GetPhrase("beatrun_battlepass.welcome_press"), BODY_FONT, cx, y, th.text.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		y = y + m.lineH

		local pulse = (math.sin(CurTime() * 4) + 1) * 0.5
		local keyW = S(120)
		draw.RoundedBox(S(th.radius), cx - keyW / 2, y, keyW, m.keyH, th.panels.primary)
		surface.SetDrawColor(ColorAlpha(th.accent, 120 + 135 * pulse))
		surface.DrawOutlinedRect(cx - keyW / 2, y, keyW, m.keyH, S(2))
		draw.SimpleText(input.GetKeyName(BRBP.Config.OpenBind or KEY_F8) or "F8", "BeatrunUI", cx, y + m.keyH / 2, th.text.primary, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		y = y + m.keyH + S(8)

		DrawMarked(language.GetPhrase("beatrun_battlepass.welcome_or"), cx, y, BODY_FONT)
	end

	logchange.OnKeyCodePressed = function(_, key)
		if key == KEY_ESCAPE or key == KEY_SPACE or key == KEY_ENTER then
			CloseLogchange()
		end
	end

	local ok = BeatrunUI.MakeButton(logchange, language.GetPhrase("beatrun_battlepass.welcome_ok"), "primary", "BeatrunUI")
	ok:SetSize(S(220), S(36))
	ok.DoClick = function()
		PlayUI(SND_CLOSE_BTN)
		CloseLogchange()
	end

	logchange.PerformLayout = function()
		local m = layout()
		ok:SetPos(m.x + (m.w - ok:GetWide()) / 2, m.y + m.h - m.pad - ok:GetTall())
	end
end

net.Receive("BRBP_Welcome", function()
	timer.Simple(0.4, function()
		BRBP.OpenLogchange()
	end)
end)

concommand.Add("brbp_logchange", function()
	BRBP.OpenLogchange()
end)
