if not CLIENT then return end

BRBP = BRBP or {}
BRBP.State = BRBP.State or {
	xp = 0,
	premium = false,
	unlocked = {},
	equipped = {},
	daily = {},
	weekly = {},
	seasonName = "FIRST RUN",
	seasonEnds = 0,
	premiumCost = 10000,
	beatrunXP = 0,
	grantedTier = 0,
}

local menu
local tab = "pass"

local function makeFonts()
	surface.CreateFont("BRBP_Title", {
		font = "x14y24pxHeadUpDaisy",
		size = 64,
		weight = 500,
		antialias = false,
		shadow = true,
		scanlines = 2,
		extended = true,
	})
	surface.CreateFont("BRBP_Update", {
		font = "x14y24pxHeadUpDaisy",
		size = 48,
		weight = 500,
		antialias = false,
		shadow = true,
		scanlines = 2,
		extended = true,
	})
	surface.CreateFont("BRBP_Sub", {
		font = "x14y24pxHeadUpDaisy",
		size = 22,
		weight = 500,
		antialias = false,
		shadow = true,
		scanlines = 2,
		extended = true,
	})
	surface.CreateFont("BRBP_Score", {
		font = "x14y24pxHeadUpDaisy",
		size = 18,
		weight = 500,
		extended = true,
	})
	surface.CreateFont("BRBP_Player", {
		font = "x14y24pxHeadUpDaisy",
		size = 16,
		weight = 100,
		extended = true,
	})
	surface.CreateFont("BRBP_Small", {
		font = "x14y24pxHeadUpDaisy",
		size = 14,
		weight = 100,
		extended = true,
	})
	surface.CreateFont("BRBP_Tiny", {
		font = "x14y24pxHeadUpDaisy",
		size = 12,
		weight = 100,
		extended = true,
	})
end
makeFonts()
hook.Add("OnScreenSizeChanged", "BRBP_Fonts", makeFonts)

local SND_CLICK = "brbp_sounds/battlepass_clicksound.ogg"
local SND_CLOSE_BTN = "brbp_sounds/battlepass_button_close_click.wav"
local SND_OPEN = "brbp_sounds/battlepass_opened.mp3"
local SND_CLOSE = "brbp_sounds/battlepass_closed.mp3"

local uiChan
local function playUI(path)
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

CreateClientConVar("brbp_lang", "", true, false)

local col = {
	white = Color(255, 255, 255),
	grey = Color(230, 230, 230, 240),
	hover = Color(120, 120, 120),
	dim = Color(210, 210, 210, 235),
	locked = Color(200, 200, 200, 230),
	dark = Color(15, 15, 15, 50),
	line = Color(255, 255, 255),
	cyan = Color(0, 230, 255),
	gold = Color(255, 220, 40),
	premium = Color(255, 220, 40),
	pulseBlue = Color(80, 210, 255),
	green = Color(94, 255, 110),
	panel = Color(20, 20, 20, 90),
	bar = Color(25, 25, 25, 220),
}

local mats = {
	blur = Material("pp/blurscreen"),
	star = Material("icons/group.png"),
	settings = Material("icons/settings.png"),
	kills = Material("icons/kills.png"),
	ret = Material("icons/return.png"),
}

local iconCache = {}
local function icon(path)
	if not path then return mats.star end
	if iconCache[path] then return iconCache[path] end
	iconCache[path] = Material(path, "smooth")
	return iconCache[path]
end

local function DrawBlurRect(x, y, w, h, amount, density)
	surface.SetDrawColor(255, 255, 255)
	surface.SetMaterial(mats.blur)
	for i = 1, density or 6 do
		mats.blur:SetFloat("$blur", i / 3 * (amount or 6))
		mats.blur:Recompute()
		render.UpdateScreenEffectTexture()
		render.SetScissorRect(x, y, x + w, y + h, true)
		surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
		render.SetScissorRect(0, 0, 0, 0, false)
	end
end

local function LerpColor(t, from, to)
	return Color(
		Lerp(t, from.r, to.r),
		Lerp(t, from.g, to.g),
		Lerp(t, from.b, to.b),
		Lerp(t, from.a, to.a)
	)
end

local function paintBtn(self, w, h, label, active)
	self.Color = self.Color or col.white
	local nextColor = col.white
	if self.Depressed then
		nextColor = col.grey
	elseif self.Hovered then
		nextColor = col.hover
	elseif active then
		nextColor = col.cyan
	end
	self.Color = LerpColor(FrameTime() * 10, self.Color, nextColor)
	draw.SimpleText(label, "BRBP_Score", w / 2, h / 2, self.Color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	if active then
		surface.SetDrawColor(self.Color)
		surface.DrawRect(0, h - 2, w, 2)
	end
end

local function closeMenu()
	if not IsValid(menu) then return end
	playUI(SND_CLOSE)
	menu:AlphaTo(0, 0.1, 0, function(_, pnl)
		if IsValid(pnl) then pnl:Remove() end
	end)
	menu = nil
end

local function state()
	return BRBP.State
end

local function isUnlocked(id)
	return state().unlocked and state().unlocked[id]
end

local function equipped(slot)
	local eq = state().equipped or {}
	return eq[slot] or ""
end

local function equip(slot, id)
	net.Start("BRBP_Equip")
	net.WriteString(slot)
	net.WriteString(id or "")
	net.SendToServer()
end

local cosmeticTypeLang = {
	title = "reward_title",
	trail = "trail",
	footstep = "footstep",
	jump = "jump",
}

local function rewardLines(rewards)
	local lines = {}
	if not rewards then return lines end
	for i = 1, #rewards do
		local r = rewards[i]
		local item = r[1] == "cosmetic" and BRBP.Cosmetics[r[2]] or nil
		if item then
			lines[#lines + 1] = BRBP.L(cosmeticTypeLang[item.type] or "reward_title")
			lines[#lines + 1] = item.short or item.text or item.name
		else
			lines[#lines + 1] = BRBP.RewardText(r)
		end
	end
	return lines
end

local function splitWrapTokens(text)
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

local function wrapFitLines(text, maxW)
	surface.SetFont("BRBP_Small")
	text = text or ""
	if surface.GetTextSize(text) <= maxW then
		return {text}
	end

	local words = splitWrapTokens(text)
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

local function drawFitText(text, cx, y, maxW, color)
	local lines = wrapFitLines(text, maxW)
	for i = 1, #lines do
		draw.SimpleText(lines[i], "BRBP_Small", cx, y + (i - 1) * 14, color, TEXT_ALIGN_CENTER)
	end
	return #lines * 14
end

local function drawPremiumHeader(w, y)
	local label = BRBP.L("premium")
	surface.SetFont("BRBP_Tiny")
	local tw = surface.GetTextSize(label)
	local star = 12
	local gap = 3
	local total = star + gap + tw
	local x = w / 2 - total / 2
	surface.SetDrawColor(col.premium)
	surface.SetMaterial(mats.star)
	surface.DrawTexturedRect(x, y + 1, star, star)
	draw.SimpleText(label, "BRBP_Tiny", x + star + gap, y, col.premium, TEXT_ALIGN_LEFT)
end

local function hideScrollerButtons(scroller)
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

local function hookPassDrag(scroller)
	local drag = {active = false, moved = false, startX = 0, startOff = 0}

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

local content
local function buildPassH(parent)
	local st = state()
	local need = BRBP.Config.TierXP

	local header = parent:Add("DPanel")
	header:Dock(TOP)
	header:SetTall(86)
	header:DockMargin(40, 8, 40, 8)
	header.Paint = function(_, w, h)
		local xp = LocalPlayer():GetNW2Int("BRBP_XP", st.xp or 0)
		local tier = BRBP.GetTierForXP(xp)
		local into = BRBP.XPIntoTier(xp)
		draw.SimpleText(BRBP.L("level", math.min(tier, BRBP.TrackEnd())), "BRBP_Sub", 0, 8, col.white)
		draw.SimpleText(BRBP.L("xp", into, need), "BRBP_Player", 0, 36, col.dim)
		local barW = math.min(w - 340, 520)
		surface.SetDrawColor(col.bar)
		surface.DrawRect(0, 62, barW, 6)
		surface.SetDrawColor(col.white)
		surface.DrawRect(0, 61, barW * math.Clamp(into / need, 0, 1), 7)
	end

	local buy = header:Add("DButton")
	buy:Dock(RIGHT)
	buy:SetWide(320)
	buy:SetText("")
	buy.Color = col.gold
	buy.Paint = function(self, w, h)
		local cur = state()
		local label = cur.premium and BRBP.L("premium_owned") or BRBP.L("buy_premium", cur.premiumCost or BRBP.Config.PremiumXPCost)
		local nextColor = cur.premium and col.gold or col.white
		if self.Hovered and not cur.premium then nextColor = col.hover end
		if self.Depressed and not cur.premium then nextColor = col.grey end
		self.Color = LerpColor(FrameTime() * 10, self.Color, nextColor)
		surface.SetDrawColor(self.Color)
		surface.DrawOutlinedRect(0, 18, w, 48)
		surface.SetDrawColor(self.Color)
		surface.SetMaterial(mats.star)
		surface.DrawTexturedRect(12, 34, 16, 16)
		draw.SimpleText(label, "BRBP_Small", w / 2 + 8, 42, self.Color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	buy.DoClick = function()
		if state().premium then return end
		playUI(SND_CLICK)
		net.Start("BRBP_BuyPremium")
		net.SendToServer()
	end

	local scroller = parent:Add("DHorizontalScroller")
	scroller:Dock(FILL)
	scroller:DockMargin(24, 0, 24, 24)
	scroller:SetOverlap(-10)
	hideScrollerButtons(scroller)

	local cards = {}
	for i = 1, BRBP.TrackEnd() do
		local def = BRBP.Tiers[i]
		local card = vgui.Create("DPanel")
		card:SetWide(108)
		cards[i] = card
		card.Paint = function(pnl, w, h)
			local liveTier = BRBP.GetTierForXP(LocalPlayer():GetNW2Int("BRBP_XP", st.xp or 0))
			local granted = state().grantedTier or 0
			local reached = liveTier >= i
			local claimed = granted >= i
			local canClaim = reached and granted == i - 1
			local reachedCol = claimed and col.white or (canClaim and col.white or Color(160, 160, 160, 210))
			local rewardCol = claimed and col.white or (canClaim and col.white or col.locked)

			surface.SetDrawColor(20, 20, 20, 70)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(reachedCol)
			surface.DrawOutlinedRect(0, 0, w, h)
			if canClaim then
				surface.DrawOutlinedRect(1, 1, w - 2, h - 2)
			end

			if BRBP.IsBonusTier(i) then
				draw.SimpleText(BRBP.L("bonus"), "BRBP_Tiny", w / 2, 10, col.gold, TEXT_ALIGN_CENTER)
			else
				drawPremiumHeader(w, 10)
			end
			local prem = rewardLines(def and def.premium)
			local premY = 28
			for k = 1, math.min(#prem, 4) do
				premY = premY + drawFitText(prem[k], w / 2, premY, w - 12, rewardCol)
			end

			surface.SetDrawColor(reachedCol)
			surface.DrawRect(12, h * 0.46, w - 24, 2)
			local numCol = claimed and col.green or rewardCol
			draw.SimpleText(tostring(i), "BRBP_Sub", w / 2, h * 0.50, numCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			surface.DrawRect(12, h * 0.56, w - 24, 2)

			draw.SimpleText(BRBP.L("free"), "BRBP_Tiny", w / 2, h * 0.60, col.dim, TEXT_ALIGN_CENTER)
			local free = rewardLines(def and def.free)
			local freeY = h * 0.64
			for k = 1, math.min(#free, 4) do
				freeY = freeY + drawFitText(free[k], w / 2, freeY, w - 12, rewardCol)
			end
		end

		local claim = card:Add("DButton")
		claim:Dock(BOTTOM)
		claim:SetTall(26)
		claim:DockMargin(8, 0, 8, 8)
		claim:SetText("")
		claim.Color = col.white
		claim.Think = function(self)
			local liveTier = BRBP.GetTierForXP(LocalPlayer():GetNW2Int("BRBP_XP", 0))
			local granted = state().grantedTier or 0
			self.CanClaim = liveTier >= i and granted == i - 1
			self:SetCursor(self.CanClaim and "hand" or "arrow")
			self:SetMouseInputEnabled(self.CanClaim)
		end
		claim.Paint = function(self, w, h)
			if not self.CanClaim then return end
			local pulse = (math.sin(CurTime() * 4) + 1) * 0.5
			local pulseTo = state().premium and col.premium or col.pulseBlue
			local outline = LerpColor(pulse, col.white, pulseTo)
			if self.Hovered then
				outline = LerpColor(0.35, outline, col.hover)
			end
			surface.SetDrawColor(outline)
			surface.DrawOutlinedRect(0, 0, w, h)
			surface.DrawOutlinedRect(1, 1, w - 2, h - 2)
			draw.SimpleText(BRBP.L("claim"), "BRBP_Tiny", w / 2, h / 2, col.white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		claim.DoClick = function(self)
			if not self.CanClaim then return end
			self.CanClaim = false
			playUI(SND_CLICK)
			if BRBP.State and (BRBP.State.grantedTier or 0) == i - 1 then
				BRBP.State.grantedTier = i
			end
			net.Start("BRBP_Claim")
			net.WriteUInt(i, 8)
			net.SendToServer()
		end

		scroller:AddPanel(card)
	end

	local xp = LocalPlayer():GetNW2Int("BRBP_XP", st.xp or 0)
	local live = math.Clamp(BRBP.GetTierForXP(xp), 1, BRBP.TrackEnd())
	local granted = st.grantedTier or 0
	local focus = live
	if granted + 1 <= live then
		focus = granted + 1
	end

	local overlap = scroller:GetOverlap() or -10
	local cardW = 108
	local step = cardW - overlap
	local viewW = parent:GetWide() - 48
	if viewW < 8 then viewW = ScrW() - 48 end
	scroller.OffsetX = math.max(0, (focus - 1) * step + cardW * 0.5 - viewW * 0.5)

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
	hookPassDrag(scroller)
	parent:InvalidateLayout(true)
	scroller:InvalidateLayout(true)
end

local function questRow(parent, kind, index)
	local row = parent:Add("DPanel")
	row:Dock(TOP)
	row:SetTall(56)
	row:DockMargin(0, 0, 0, 6)
	row.Paint = function(_, w, h)
		local item = ((state()[kind]) or {})[index]
		if not item then return end
		surface.SetDrawColor(20, 20, 20, 80)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(item.done and col.green or Color(255, 255, 255, 40))
		surface.DrawOutlinedRect(0, 0, w, h)

		local custom = isstring(item.icon) and item.icon:find("beatrun_bp_icons", 1, true)
		local bigSize = 78
		local iconSize = custom and bigSize or 32
		local iconX = 6 + math.floor((bigSize - iconSize) / 2)
		local iconPad = math.floor((h - iconSize) / 2)
		surface.SetDrawColor(item.done and col.green or col.white)
		surface.SetMaterial(icon(item.icon))
		surface.DrawTexturedRect(iconX, iconPad, iconSize, iconSize)

		local textX = 6 + bigSize + 10
		local label = BRBP.QuestLabel(item.id, item.goal)
		draw.SimpleText(label, "BRBP_Player", textX, 10, col.white)
		draw.SimpleText("+" .. item.xp .. " XP", "BRBP_Small", w - 12, 10, item.done and col.green or col.dim, TEXT_ALIGN_RIGHT)

		local pct = math.Clamp((item.progress or 0) / math.max(item.goal or 1, 1), 0, 1)
		surface.SetDrawColor(col.bar)
		surface.DrawRect(textX, 36, w - textX - 104, 6)
		surface.SetDrawColor(item.done and col.green or col.white)
		surface.DrawRect(textX, 35, (w - textX - 104) * pct, 7)
		draw.SimpleText((item.progress or 0) .. " / " .. (item.goal or 0), "BRBP_Small", w - 12, 32, item.done and col.green or col.dim, TEXT_ALIGN_RIGHT)
	end
	return row
end

local function questTimer(parent, kind)
	local row = parent:Add("DPanel")
	row:Dock(TOP)
	row:SetTall(22)
	row:DockMargin(0, 4, 0, 0)
	row.Paint = function(_, w, h)
		local left = (kind == "daily") and BRBP.SecondsUntilNextDay() or BRBP.SecondsUntilNextWeek()
		draw.SimpleText(BRBP.L("reset_in", BRBP.FormatCountdown(left)), "BRBP_Small", 0, h / 2, col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

local function buildQuests(parent)
	local st = state()
	local left = parent:Add("DPanel")
	left:Dock(LEFT)
	left:SetWide(ScrW() * 0.5 - 80)
	left:DockMargin(40, 56, 20, 30)
	left.Paint = function(_, w, h)
		draw.SimpleText(BRBP.L("daily"), "BRBP_Sub", 0, 0, col.white)
		surface.SetDrawColor(col.white)
		surface.DrawRect(0, 28, 80, 2)
	end

	local lscroll = left:Add("DScrollPanel")
	lscroll:Dock(FILL)
	lscroll:DockMargin(0, 40, 0, 0)
	lscroll.VBar:SetHideButtons(true)
	lscroll.VBar.Paint = function() end
	lscroll.VBar.btnGrip.Paint = function() end
	for i = 1, #(st.daily or {}) do
		questRow(lscroll, "daily", i)
	end
	questTimer(lscroll, "daily")

	local right = parent:Add("DPanel")
	right:Dock(FILL)
	right:DockMargin(20, 56, 40, 30)
	right.Paint = function(_, w, h)
		draw.SimpleText(BRBP.L("weekly"), "BRBP_Sub", 0, 0, col.gold)
		surface.SetDrawColor(col.gold)
		surface.DrawRect(0, 28, 80, 2)
	end

	local rscroll = right:Add("DScrollPanel")
	rscroll:Dock(FILL)
	rscroll:DockMargin(0, 40, 0, 0)
	rscroll.VBar:SetHideButtons(true)
	rscroll.VBar.Paint = function() end
	rscroll.VBar.btnGrip.Paint = function() end
	for i = 1, #(st.weekly or {}) do
		questRow(rscroll, "weekly", i)
	end
	questTimer(rscroll, "weekly")
end

local typeOrder = {"trail", "title", "footstep", "jump"}
local typeLang = {
	trail = "trail",
	title = "title_type",
	footstep = "footstep",
	jump = "jump",
}

local function buildCosmetics(parent)
	local st = state()
	local scroll = parent:Add("DScrollPanel")
	scroll:Dock(FILL)
	scroll:DockMargin(40, 10, 40, 30)
	scroll.VBar:SetHideButtons(true)
	scroll.VBar.Paint = function() end
	scroll.VBar.btnGrip.Paint = function() end

	local any = false
	for _, typ in ipairs(typeOrder) do
		local ids = {}
		for id, def in pairs(BRBP.Cosmetics) do
			if def.type == typ and isUnlocked(id) then
				ids[#ids + 1] = id
			end
		end
		table.sort(ids)
		if #ids > 0 then
			any = true
			local head = scroll:Add("DPanel")
			head:Dock(TOP)
			head:SetTall(28)
			head:DockMargin(0, 8, 0, 4)
			head.Paint = function(_, w, h)
				draw.SimpleText(BRBP.L(typeLang[typ]), "BRBP_Score", 0, h / 2, col.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				surface.SetDrawColor(col.white)
				surface.DrawRect(0, h - 2, 60, 2)
			end

			for i = 1, #ids do
				local id = ids[i]
				local def = BRBP.Cosmetics[id]
				local row = scroll:Add("DButton")
				row:Dock(TOP)
				row:SetTall(40)
				row:DockMargin(0, 0, 0, 4)
				row:SetText("")
				row.Color = col.white
				row.Paint = function(self, w, h)
					local onNow = equipped(typ) == id
					local nextColor = onNow and col.cyan or col.white
					if self.Hovered then nextColor = col.hover end
					if self.Depressed then nextColor = col.grey end
					self.Color = LerpColor(FrameTime() * 10, self.Color, nextColor)
					surface.SetDrawColor(20, 20, 20, 80)
					surface.DrawRect(0, 0, w, h)
					surface.SetDrawColor(self.Color)
					surface.DrawOutlinedRect(0, 0, w, h)
					if def.color or def.type == "title" then
						local swatch = def.type == "title" and BRBP.TitleColor(def) or def.color
						surface.SetDrawColor(swatch)
						surface.DrawRect(10, 12, 16, 16)
					end
					local label = def.name
					if def.type == "title" then
						label = BRBP.L("reward_title") .. "  " .. BRBP.TitleTag(def)
					end
					draw.SimpleText(label, "BRBP_Player", 36, h / 2, self.Color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					draw.SimpleText(onNow and BRBP.L("equipped") or BRBP.L("equip"), "BRBP_Small", w - 16, h / 2, self.Color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
				end
				row.DoClick = function()
					playUI(SND_CLICK)
					if equipped(typ) == id then
						equip(typ, "")
					else
						equip(typ, id)
					end
				end
			end
		end
	end

	if not any then
		local empty = scroll:Add("DPanel")
		empty:Dock(TOP)
		empty:SetTall(80)
		empty.Paint = function(_, w, h)
			draw.SimpleText(BRBP.L("empty_cosmetics"), "BRBP_Sub", w / 2, h / 2, col.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
end

local function fillContent()
	if not IsValid(content) then return end
	content:Clear()
	if tab == "pass" then
		buildPassH(content)
	elseif tab == "quests" then
		buildQuests(content)
	else
		buildCosmetics(content)
	end
end

function BRBP.OpenMenu(keepTab)
	if IsValid(menu) then
		if not keepTab then tab = "pass" end
		fillContent()
		return
	end

	if not keepTab then tab = "pass" end

	menu = vgui.Create("DFrame")
	menu:SetSize(ScrW(), ScrH())
	menu:SetTitle("")
	menu:ShowCloseButton(false)
	menu:SetDraggable(false)
	menu:MakePopup()
	menu:SetAlpha(0)
	menu:AlphaTo(255, 0.1)
	menu:SetKeyboardInputEnabled(true)

	menu.Paint = function(self, w, h)
		DrawBlurRect(0, 0, w, h, 3, 6)
		surface.SetDrawColor(col.dark)
		surface.DrawRect(0, 0, w, h)

		draw.SimpleText(BRBP.L("title"), "BRBP_Title", w / 2, 72, col.white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		local st = state()
		local ends = (st.seasonEnds and st.seasonEnds > 0) and os.date("%d.%m.%Y", st.seasonEnds) or ""
		draw.SimpleText(BRBP.L("players", st.seasonName or BRBP.Config.SeasonName) .. "   " .. BRBP.L("ends", ends), "BRBP_Sub", w / 2, 118, col.white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		surface.SetDrawColor(col.white)
		surface.DrawRect(w / 2 - 500, 148, 1000, 2)
	end

	menu.OnKeyCodePressed = function(_, key)
		if key == KEY_ESCAPE or key == KEY_F8 then
			closeMenu()
		end
	end

	local tabs = menu:Add("DPanel")
	tabs:SetPos(ScrW() / 2 - 240, 160)
	tabs:SetSize(480, 36)
	tabs.Paint = function() end

	local function tabBtn(id, label, x)
		local b = tabs:Add("DButton")
		b:SetPos(x, 0)
		b:SetSize(160, 36)
		b:SetText("")
		b.Paint = function(self, w, h)
			paintBtn(self, w, h, label, tab == id)
		end
		b.DoClick = function()
			tab = id
			playUI(SND_CLICK)
			fillContent()
		end
	end

	tabBtn("pass", BRBP.L("tab_pass"), 0)
	tabBtn("quests", BRBP.L("tab_quests"), 160)
	tabBtn("cosmetics", BRBP.L("tab_cosmetics"), 320)

	local close = menu:Add("DButton")
	close:SetSize(140, 32)
	close:SetPos(ScrW() - 180, 40)
	close:SetText("")
	close.Color = col.white
	close.Paint = function(self, w, h)
		local nextColor = col.white
		if self.Hovered then nextColor = col.hover end
		if self.Depressed then nextColor = col.grey end
		self.Color = LerpColor(FrameTime() * 10, self.Color, nextColor)
		draw.SimpleText(BRBP.L("close"), "BRBP_Score", w, h / 2, self.Color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
	close.DoClick = function()
		playUI(SND_CLOSE_BTN)
		closeMenu()
	end

	local langBar = menu:Add("DPanel")
	langBar:SetPos(40, 40)
	langBar:SetSize(280, 32)
	langBar.Paint = function() end

	local function langBtn(code, labelKey, x)
		local b = langBar:Add("DButton")
		b:SetPos(x, 0)
		b:SetSize(130, 32)
		b:SetText("")
		b.Paint = function(self, w, h)
			paintBtn(self, w, h, BRBP.L(labelKey), BRBP.GetLang() == code)
		end
		b.DoClick = function()
			if BRBP.GetLang() == code then return end
			playUI(SND_CLICK)
			local cv = GetConVar("brbp_lang")
			if cv then cv:SetString(code) end
			local keep = tab
			menu:Remove()
			menu = nil
			tab = keep
			BRBP.OpenMenu(true)
		end
	end

	langBtn("ru", "lang_ru", 0)
	langBtn("en", "lang_en", 140)

	content = menu:Add("DPanel")
	content:SetPos(0, 200)
	content:SetSize(ScrW(), ScrH() - 200)
	content.Paint = function() end

	fillContent()
	if not keepTab then
		playUI(SND_OPEN)
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
	fillContent()
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
		closeMenu()
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
local logoHtml

local function beatrunLogo()
	if logoMat and not logoMat:IsError() then return logoMat end
	local paths = {
		"../gamemodes/beatrun/logo.png",
		"gamemodes/beatrun/logo.png",
		"beatrun/logo.png",
	}
	for i = 1, #paths do
		local mat = Material(paths[i], "smooth")
		if mat and not mat:IsError() then
			logoMat = mat
			return logoMat
		end
	end
end

local function parseMarks(text)
	local segs = {}
	local i = 1
	local n = #text
	while i <= n do
		local s, e, inner = string.find(text, "{(.-)}", i)
		if not s then
			segs[#segs + 1] = {string.sub(text, i), false}
			break
		end
		if s > i then
			segs[#segs + 1] = {string.sub(text, i, s - 1), false}
		end
		segs[#segs + 1] = {inner, true}
		i = e + 1
	end
	return segs
end

local function drawMarked(text, cx, y, font)
	surface.SetFont(font)
	local segs = parseMarks(text)
	local total = 0
	for i = 1, #segs do
		total = total + surface.GetTextSize(segs[i][1])
	end
	local x = cx - total / 2
	for i = 1, #segs do
		local str, hi = segs[i][1], segs[i][2]
		local w = surface.GetTextSize(str)
		draw.SimpleText(str, font, x, y, hi and col.cyan or col.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		x = x + w
	end
end

local function closeLogchange()
	if not IsValid(logchange) then return end
	playUI(SND_CLOSE)
	logchange:AlphaTo(0, 0.1, 0, function(_, pnl)
		if IsValid(pnl) then pnl:Remove() end
	end)
	logchange = nil
end

function BRBP.OpenLogchange()
	if IsValid(logchange) then
		logchange:Remove()
		logchange = nil
	end

	local function bodyLines()
		return string.Explode("\n", BRBP.L("welcome_body") or "")
	end

	local function bodyHeight()
		local h = 0
		local lines = bodyLines()
		for i = 1, #lines do
			h = h + ((lines[i] == "") and 12 or 22)
		end
		return h
	end

	local cardW = 680
	local logoH = 92
	local f6H = 100
	local function cardHeight()
		return math.min(24 + logoH + 16 + 18 + 58 + bodyHeight() + 12 + f6H + 56, ScrH() - 80)
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

	local logoBox = logchange:Add("DImage")
	logoBox:SetSize(420, logoH)
	logoBox:SetKeepAspect(true)
	logoBox:SetMouseInputEnabled(false)
	local logo = beatrunLogo()
	if logo then
		logoBox:SetMaterial(logo)
	end
	logoBox.Paint = function(self, w, h)
		local mat = beatrunLogo()
		if not mat then return true end
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
		surface.DrawTexturedRect((w - dw) / 2, (h - dh) / 2, dw, dh)
		return true
	end
	logoBox.Think = function(self)
		if not IsValid(logchange) then return end
		self:SetPos(ScrW() / 2 - 210, ScrH() / 2 - cardHeight() / 2 + 22)
	end

	logchange.Paint = function(_, w, h)
		DrawBlurRect(0, 0, w, h, 5, 7)
		surface.SetDrawColor(8, 8, 8, 170)
		surface.DrawRect(0, 0, w, h)

		local cardH = cardHeight()
		local cx, cy = w / 2, h / 2
		local x = cx - cardW / 2
		local y = cy - cardH / 2

		DrawBlurRect(x, y, cardW, cardH, 3, 4)
		surface.SetDrawColor(20, 20, 20, 90)
		surface.DrawRect(x, y, cardW, cardH)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawOutlinedRect(x, y, cardW, cardH)

		local cursor = y + 24 + logoH + 16
		local lineW = 420
		surface.SetDrawColor(col.white)
		surface.DrawRect(cx - lineW / 2, cursor, lineW, 2)

		cursor = cursor + 18
		local heading = BRBP.L("logchange")
		surface.SetFont("BRBP_Update")
		local hw = surface.GetTextSize(heading)
		draw.SimpleText(heading, "BRBP_Update", math.floor(cx - hw / 2) + 10, cursor, col.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		cursor = cursor + 58

		local lines = bodyLines()
		for i = 1, #lines do
			local line = lines[i]
			if line == "" then
				cursor = cursor + 12
			else
				drawMarked(line, cx, cursor, "BRBP_Player")
				cursor = cursor + 22
			end
		end

		cursor = y + cardH - 56 - f6H + 8
		draw.SimpleText(BRBP.L("welcome_press"), "BRBP_Player", cx, cursor, col.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		cursor = cursor + 20

		local pulse = (math.sin(CurTime() * 4) + 1) * 0.5
		local accent = LerpColor(pulse, col.white, col.cyan)
		local boxW, boxH = 132, 42
		surface.SetDrawColor(accent)
		surface.DrawOutlinedRect(cx - boxW / 2, cursor, boxW, boxH)
		surface.DrawOutlinedRect(cx - boxW / 2 + 1, cursor + 1, boxW - 2, boxH - 2)
		draw.SimpleText("F8", "BRBP_Sub", cx, cursor + boxH / 2, accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cursor = cursor + boxH + 8

		local orText = BRBP.L("welcome_or")
		local cmd = "!BP"
		local prefix = orText
		local cut = string.find(orText, "!BP", 1, true)
		if cut then
			prefix = string.sub(orText, 1, cut - 1)
		end
		surface.SetFont("BRBP_Player")
		local preW = surface.GetTextSize(prefix)
		local cmdW = surface.GetTextSize(cmd)
		draw.SimpleText(prefix, "BRBP_Player", cx - (preW + cmdW) / 2, cursor, col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(cmd, "BRBP_Player", cx - (preW + cmdW) / 2 + preW, cursor, col.cyan, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	logchange.OnKeyCodePressed = function(_, key)
		if key == KEY_ESCAPE or key == KEY_SPACE or key == KEY_ENTER then
			closeLogchange()
		end
	end

	local ok

	local langBar = logchange:Add("DPanel")
	langBar:SetPos(40, 40)
	langBar:SetSize(280, 32)
	langBar.Paint = function() end

	local function langBtn(code, labelKey, x)
		local b = langBar:Add("DButton")
		b:SetPos(x, 0)
		b:SetSize(130, 32)
		b:SetText("")
		b.Paint = function(self, w, h)
			paintBtn(self, w, h, BRBP.L(labelKey), BRBP.GetLang() == code)
		end
		b.DoClick = function()
			if BRBP.GetLang() == code then return end
			playUI(SND_CLICK)
			local cv = GetConVar("brbp_lang")
			if cv then cv:SetString(code) end
			if IsValid(ok) then
				ok:SetPos(ScrW() / 2 - 110, ScrH() / 2 + cardHeight() / 2 - 52)
			end
		end
	end

	langBtn("ru", "lang_ru", 0)
	langBtn("en", "lang_en", 140)

	ok = logchange:Add("DButton")
	ok:SetSize(220, 36)
	ok:SetPos(ScrW() / 2 - 110, ScrH() / 2 + cardHeight() / 2 - 52)
	ok:SetText("")
	ok.Color = col.white
	ok.Paint = function(self, w, h)
		local nextColor = col.white
		if self.Hovered then nextColor = col.hover end
		if self.Depressed then nextColor = col.grey end
		self.Color = LerpColor(FrameTime() * 10, self.Color, nextColor)
		surface.SetDrawColor(self.Color)
		surface.DrawOutlinedRect(0, 0, w, h)
		draw.SimpleText(BRBP.L("welcome_ok"), "BRBP_Score", w / 2, h / 2, self.Color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	ok.DoClick = function()
		playUI(SND_CLOSE_BTN)
		closeLogchange()
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
