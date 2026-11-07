if not CLIENT then return end

BRBP = BRBP or {}
BRBP.State = BRBP.State or {
	xp = 0,
	premium = false,
	unlocked = {},
	equipped = {},
	daily = {},
	weekly = {},
}

local trailMats = {}
local TRAIL_MAX = 24
local function trailMat(path)
	if trailMats[path] then return trailMats[path] end
	trailMats[path] = Material(path)
	return trailMats[path]
end
local trails = {}

local function hsv(t)
	local c = HSVToColor((t * 80) % 360, 0.85, 1)
	c.a = 220
	return c
end

local function mixColor(t, a, b)
	return Color(Lerp(t, a.r, b.r), Lerp(t, a.g, b.g), Lerp(t, a.b, b.b))
end

local function pushTrail(ply)
	local sid = ply:SteamID64() or ply:EntIndex()
	trails[sid] = trails[sid] or {}
	local list = trails[sid]
	list[#list + 1] = ply:GetPos() + Vector(0, 0, 8)
	if #list > TRAIL_MAX then
		table.remove(list, 1)
	end
end

timer.Create("BRBP_TrailSample", 0.04, 0, function()
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and ply:Alive() then
			local id = ply:GetNW2String("BRBP_Trail", "")
			if id ~= "" and BRBP.Cosmetics[id] then
				pushTrail(ply)
			else
				trails[ply:SteamID64() or ply:EntIndex()] = nil
			end
		end
	end
end)

hook.Add("PostDrawTranslucentRenderables", "BRBP_Trails", function()
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and ply:Alive() then
			local id = ply:GetNW2String("BRBP_Trail", "")
			local def = BRBP.Cosmetics[id]
			if def and def.type == "trail" then
				local list = trails[ply:SteamID64() or ply:EntIndex()]
				if list and #list >= 2 then
					render.SetMaterial(trailMat(def.mat))
					local trailCol = def.color or color_white
					if def.rainbow then trailCol = hsv(CurTime()) end
					local shift = def.colors and math.floor(CurTime() * (def.blink or 2)) or 0

					for i = 2, #list do
						local a = list[i - 1]
						local b = list[i]
						local frac = i / #list
						local w = (def.width or 14) * frac
						local c = trailCol
						if def.colors then
							c = def.colors[(i + shift) % #def.colors + 1]
						elseif def.color2 then
							c = mixColor(frac, def.color2, trailCol)
						end
						render.DrawBeam(a, b, w, 0, 1, Color(c.r, c.g, c.b, 40 + 180 * frac))
					end
					local last = list[#list]
					local pos = ply:GetPos() + Vector(0, 0, 8)
					local head = def.colors and def.colors[(#list + 1 + shift) % #def.colors + 1] or trailCol
					render.DrawBeam(last, pos, def.width or 14, 0, 1, Color(head.r, head.g, head.b, 220))
				end
			end
		end
	end
end)

local TITLE_DIST = 800
local NICK_DIST = 50000
local titleTrace = {mask = MASK_SOLID}
local enemyColor = Color(255, 0, 0)

local function stableHeadPos(ply)
	return ply:GetPos() + Vector(0, 0, 90)
end

local function canSeeTitle(ply, pos)
	local lp = LocalPlayer()
	titleTrace.start = lp:EyePos()
	titleTrace.endpos = pos
	titleTrace.filter = {lp, ply}
	return not util.TraceLine(titleTrace).Hit
end

local function nickColor(ply)
	if ply == LocalPlayer() then return nil end
	if GetGlobalBool("GM_DATATHEFT") or GetGlobalBool("GM_DEATHMATCH") then return nil end

	local dist = LocalPlayer():GetPos():Distance(ply:GetPos())
	ply.distfromlocal = dist

	local cv = GetConVar("Beatrun_Nametags")
	if cv and not cv:GetBool() then return nil end
	if GetGlobalBool("EM_HideNametags") then return nil end
	if dist >= NICK_DIST then return nil end

	local color = color_white
	if GetGlobalBool("GM_EVENTMODE") and isfunction(GetStatusData) then
		local sdata = GetStatusData(ply:GetNW2String("EPlayerStatus", "Member"))
		if sdata and sdata.color then color = sdata.color end
	end

	if GetGlobalBool("GM_INFECTION") then
		if LocalPlayer():GetNW2Bool("Infected") ~= ply:GetNW2Bool("Infected") then
			color = enemyColor
		else
			return nil
		end
	end

	return color
end

local function disableBeatrunNametags()
	hook.Remove("PostDrawTranslucentRenderables", "BeatrunNametags")
end

hook.Add("InitPostEntity", "BRBP_ReplaceNametags", disableBeatrunNametags)
hook.Add("PlayerInitialSpawn", "BRBP_ReplaceNametags", function()
	timer.Simple(0, disableBeatrunNametags)
end)

hook.Add("PostDrawTranslucentRenderables", "BRBP_Nametags", function(depth, sky)
	if sky then return end
	disableBeatrunNametags()

	local lp = LocalPlayer()
	if not IsValid(lp) then return end

	local font = "BRBP_Player"
	if pcall(surface.SetFont, "BeatrunHUD") then
		font = "BeatrunHUD"
	end

	for _, ply in ipairs(player.GetAll()) do
		if not IsValid(ply) or not ply:Alive() then continue end

		local color = nickColor(ply)
		if not color then continue end

		local dist = ply.distfromlocal or lp:GetPos():Distance(ply:GetPos())
		local pos = stableHeadPos(ply)
		local ang = lp:EyeAngles()
		ang:RotateAroundAxis(ang:Forward(), 90)
		ang:RotateAroundAxis(ang:Right(), 90)
		local nickScale = math.max(2.5 * dist / 2000, 0.5)

		cam.Start3D2D(pos, Angle(0, ang.y, ang.z), nickScale)
			cam.IgnoreZ(true)
			render.DepthRange(0, 0)
			draw.DrawText(ply:Nick(), font, 2, 2, color, TEXT_ALIGN_CENTER)
			render.DepthRange(0, 1)
			cam.IgnoreZ(false)
		cam.End3D2D()

		local titleId = ply:GetNW2String("BRBP_Title", "")
		local def = BRBP.Cosmetics[titleId]
		if def and def.type == "title" and dist <= TITLE_DIST and canSeeTitle(ply, pos) then
			local titleScale = math.max(2.2 * dist / 2000, 0.44)
			local col = BRBP.TitleColor(def)
			cam.Start3D2D(pos, Angle(0, ang.y, ang.z), titleScale)
				draw.SimpleText(BRBP.TitleTag(def), font, 0, -5, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
			cam.End3D2D()
		end
	end
end)

local wrappedHandler
local RANK_CHAT = {
	superadmin = {name = "Super Admin", color = Color(255, 0, 0), rainbow = true},
	admin = {name = "Admin", color = Color(94, 255, 110)},
	vip = {name = "VIP", color = Color(218, 206, 45)},
}

local function hudCustom()
	local cv = GetConVar("easychat_hud_custom")
	return not cv or cv:GetBool()
end

local function registerTitlePart()
	if not EasyChat or not EasyChat.ChatHUD or not EasyChat.ChatHUD.RegisterPart then return false end
	if EasyChat.ChatHUD.Parts and EasyChat.ChatHUD.Parts.brbp then return true end

	EasyChat.ChatHUD:RegisterPart("brbp", {
		CosmeticId = "",
		OkInNicks = false,
		Ctor = function(self, id)
			self.CosmeticId = id or ""
			self.Size = {W = 0, H = 0}
			return self
		end,
		Draw = function(self, ctx)
			local def = BRBP.Cosmetics[self.CosmeticId]
			local col = BRBP.TitleColor(def)
			ctx:UpdateColor(Color(col.r, col.g, col.b, 255))
		end,
	})

	return true
end

local function jsString(s)
	s = tostring(s or "")
	s = string.gsub(s, "\\", "\\\\")
	s = string.gsub(s, "'", "\\'")
	s = string.gsub(s, "\r", "")
	s = string.gsub(s, "\n", "\\n")
	return "'" .. s .. "'"
end

local function ensureChatAnim()
	local rt = EasyChat.GUI and EasyChat.GUI.RichText
	if not IsValid(rt) or not rt.QueueJavascript then return end
	rt:QueueJavascript([[
		(function(){
			if (window.brbpTick) return;
			window.brbpTitles = window.brbpTitles || {};
			window.brbpQueue = function(text, kind, r, g, b) {
				text = (text || '').replace(/^\s+|\s+$/g, '');
				if (!text) return;
				window.brbpTitles[text] = { kind: kind, r: r || 0, g: g || 0, b: b || 0 };
			};
			const lerp = function(a, b, t) { return Math.round(a + (b - a) * t); };
			window.brbpTick = setInterval(function() {
				const root = document.getElementById('main');
				if (!root) return;
				const spans = root.getElementsByTagName('span');
				const h = (Date.now() / 3.5) % 360;
				const rainbow = 'hsl(' + h + ', 90%, 58%)';
				const pulseT = (Math.sin(Date.now() / 320) + 1) * 0.5;
				for (let i = 0; i < spans.length; i++) {
					const el = spans[i];
					const t = (el.textContent || '').replace(/^\s+|\s+$/g, '');
					if (!t) continue;
					const low = t.toLowerCase();
					if (low === '[super admin]') {
						el.style.color = rainbow;
						continue;
					}
					const info = window.brbpTitles[t];
					if (!info) continue;
					if (info.kind === 'rainbow') {
						el.style.color = rainbow;
					} else {
						el.style.color = 'rgb(' + lerp(255, info.r, pulseT) + ',' + lerp(255, info.g, pulseT) + ',' + lerp(255, info.b, pulseT) + ')';
					}
				}
			}, 40);
		})();
	]])
end

local function queueChatAnim(text, kind, col)
	local rt = EasyChat.GUI and EasyChat.GUI.RichText
	if not IsValid(rt) or not rt.QueueJavascript then return end
	ensureChatAnim()
	text = string.Trim(text or "")
	if text == "" then return end
	if kind == "pulse" and col then
		rt:QueueJavascript(string.format(
			"if(window.brbpQueue) window.brbpQueue(%s,'pulse',%d,%d,%d);",
			jsString(text), col.r, col.g, col.b
		))
	else
		rt:QueueJavascript(string.format(
			"if(window.brbpQueue) window.brbpQueue(%s,'rainbow');",
			jsString(text)
		))
	end
end

local function richAppend(col, text)
	local rt = EasyChat.GUI and EasyChat.GUI.RichText
	if not IsValid(rt) then return end
	if rt.InsertColorChange then
		rt:InsertColorChange(col.r, col.g, col.b, 255)
	end
	if rt.AppendText then
		rt:AppendText(text)
	end
end

local function hudAppend(markup)
	if not hudCustom() then return end
	local hud = EasyChat.ChatHUD
	if not hud or not hud.AppendText then return end
	hud:PushPartComponent("stop")
	hud:AppendText(markup)
	hud:PushPartComponent("stop")
end

local function easychatHasRankText(ply)
	local cfg = EasyChat.Config
	if not cfg or not cfg.UserGroups then return false end
	local prefix = cfg.UserGroups[ply:GetUserGroup() or ""]
	return prefix and isstring(prefix.Tag) and #prefix.Tag > 0
end

local function insertPrefix(ply)
	if not IsValid(ply) then return end

	local titleId = ply:GetNW2String("BRBP_Title", "")
	local def = BRBP.Cosmetics[titleId]
	if def and def.type == "title" then
		local col = def.color or Color(255, 220, 40)
		local tag = BRBP.TitleTag(def)
		local fx = def.fx or "static"
		if fx == "rainbow" or fx == "hsv" then
			queueChatAnim(tag, "rainbow")
		else
			queueChatAnim(tag, "pulse", col)
		end
		richAppend(col, tag .. " ")
		hudAppend(BRBP.TitleHUDMarkup(titleId, def))
	end

	if not easychatHasRankText(ply) then
		local rank = RANK_CHAT[ply:GetUserGroup() or ""]
		if rank then
			local tag = "[" .. rank.name .. "]"
			if rank.rainbow then
				queueChatAnim(tag, "rainbow")
				hudAppend("<hsv=t()*300>" .. tag .. " <stop>")
			else
				local c = rank.color
				hudAppend(string.format("<c=%02x%02x%02x>%s <stop>", c.r, c.g, c.b, tag))
			end
			richAppend(rank.color, tag .. " ")
		end
	end
end

local function wrapEasyChatPlayer()
	if not EasyChat or not EasyChat.GetSetAddTextTypeHandle or not EasyChat.SetAddTextTypeHandle then
		return false
	end

	local old = EasyChat.GetSetAddTextTypeHandle("Player")
	if not isfunction(old) then return false end
	if old == wrappedHandler then return true end

	registerTitlePart()
	ensureChatAnim()

	local function handler(ply)
		local ok, err = pcall(insertPrefix, ply)
		if not ok then
			ErrorNoHalt("[BRBP] chat prefix: " .. tostring(err) .. "\n")
		end
		return old(ply)
	end

	EasyChat.SetAddTextTypeHandle("Player", handler)
	wrappedHandler = handler
	return true
end

hook.Add("ECPostInitialized", "BRBP_ChatTitle", function()
	wrappedHandler = nil
	registerTitlePart()
	wrapEasyChatPlayer()
	ensureChatAnim()
end)

hook.Add("InitPostEntity", "BRBP_ChatTitle", function()
	timer.Create("BRBP_ChatTitleRetry", 1, 20, function()
		if wrapEasyChatPlayer() then
			ensureChatAnim()
			timer.Remove("BRBP_ChatTitleRetry")
		end
	end)
end)

hook.Add("StartChat", "BRBP_ChatAnim", function()
	ensureChatAnim()
end)

local spark = Material("effects/spark")
local glow = Material("sprites/light_glow02_add")
local smoke = Material("particle/particle_smokegrenade")
local ringMat = Material("effects/select_ring")
local stepDist = {}
local echoRings = {}

local CYAN = Color(0, 230, 255)
local FROST = Color(170, 230, 255)
local FESTIVE = {
	Color(255, 50, 50),
	Color(60, 255, 90),
	Color(255, 210, 50),
	Color(60, 140, 255),
	Color(255, 80, 220),
	Color(255, 255, 255),
}

local function addRing(pos, col, life, grow)
	echoRings[#echoRings + 1] = {
		pos = pos + Vector(0, 0, 1.5),
		t = CurTime(),
		life = life or 0.42,
		grow = grow or 56,
		col = col or CYAN,
	}
end

local function particle(emitter, mat, pos, o)
	local p = emitter:Add(mat, pos)
	if not p then return end
	p:SetVelocity(o.vel or vector_origin)
	p:SetDieTime(o.life or 0.5)
	p:SetStartAlpha(o.a or 255)
	p:SetEndAlpha(0)
	p:SetStartSize(o.size or 5)
	p:SetEndSize(o.endSize or 0)
	p:SetRoll(math.Rand(0, 360))
	p:SetRollDelta(o.spin or 0)
	p:SetGravity(o.grav or vector_origin)
	p:SetAirResistance(o.drag or 0)
	local c = o.col or color_white
	p:SetColor(c.r, c.g, c.b)
end

local function emit(pos, fn)
	local emitter = ParticleEmitter(pos)
	if not emitter then return end
	fn(emitter)
	emitter:Finish()
end

local function rand2(r)
	return Vector(math.Rand(-r, r), math.Rand(-r, r), 0)
end

local FOOT_FX = {
	fx_dust = function(pos)
		addRing(pos, CYAN)
		emit(pos, function(e)
			particle(e, glow, pos + Vector(0, 0, 6), {life = 0.22, a = 180, size = 28, endSize = 8, col = CYAN})
		end)
	end,
	fx_spark = function(pos)
		emit(pos, function(e)
			for i = 1, 12 do
				particle(e, spark, pos + rand2(10) + Vector(0, 0, 1), {
					vel = Vector(math.Rand(-50, 50), math.Rand(-50, 50), math.Rand(30, 90)),
					life = math.Rand(0.3, 0.55), grav = Vector(0, 0, -280), col = Color(255, 220, 80),
				})
			end
		end)
	end,
	fx_ember = function(pos)
		emit(pos, function(e)
			for i = 1, 5 do
				particle(e, glow, pos + rand2(8) + Vector(0, 0, 2), {
					vel = Vector(math.Rand(-15, 15), math.Rand(-15, 15), math.Rand(20, 50)),
					life = math.Rand(0.6, 1), size = math.Rand(4, 7), grav = Vector(0, 0, 40), drag = 20,
					col = Color(255, math.random(60, 170), 20),
				})
			end
		end)
	end,
	fx_snow = function(pos)
		emit(pos, function(e)
			for i = 1, 3 do
				particle(e, smoke, pos + rand2(6) + Vector(0, 0, 3), {
					vel = rand2(40) + Vector(0, 0, math.Rand(5, 20)),
					life = 0.5, a = 110, size = 6, endSize = 18, drag = 60, col = Color(230, 240, 255),
				})
			end
			for i = 1, 4 do
				particle(e, glow, pos + rand2(10) + Vector(0, 0, 4), {
					vel = rand2(30) + Vector(0, 0, math.Rand(30, 60)),
					life = math.Rand(0.6, 0.9), size = 3, grav = Vector(0, 0, -60), drag = 30, col = color_white,
				})
			end
		end)
	end,
	fx_confetti = function(pos)
		emit(pos, function(e)
			for i = 1, 8 do
				particle(e, spark, pos + rand2(8) + Vector(0, 0, 2), {
					vel = rand2(60) + Vector(0, 0, math.Rand(80, 140)),
					life = math.Rand(0.6, 0.9), size = 4, endSize = 3, spin = math.Rand(-8, 8),
					grav = Vector(0, 0, -300), drag = 40, col = FESTIVE[math.random(#FESTIVE)],
				})
			end
		end)
	end,
}

local JUMP_FX = {
	fx_jump = function(pos)
		emit(pos, function(e)
			for i = 1, 8 do
				particle(e, spark, pos + Vector(0, 0, 20), {
					vel = VectorRand() * 80 + Vector(0, 0, 40), life = 0.4, a = 220, size = 6, col = CYAN,
				})
			end
		end)
	end,
	fx_jump_ember = function(pos)
		emit(pos, function(e)
			particle(e, glow, pos + Vector(0, 0, 20), {life = 0.25, a = 200, size = 60, endSize = 10, col = Color(255, 120, 30)})
			for i = 1, 14 do
				particle(e, spark, pos + Vector(0, 0, 20), {
					vel = VectorRand() * 120 + Vector(0, 0, 60), life = math.Rand(0.4, 0.7), size = 6,
					grav = Vector(0, 0, -200), col = Color(255, math.random(60, 180), 20),
				})
			end
		end)
	end,
	fx_jump_frost = function(pos)
		addRing(pos, FROST, 0.55, 110)
		emit(pos, function(e)
			for i = 1, 14 do
				particle(e, glow, pos + Vector(0, 0, 16), {
					vel = rand2(140) + Vector(0, 0, math.Rand(40, 120)), life = math.Rand(0.8, 1.2), size = 4,
					grav = Vector(0, 0, -80), drag = 50, col = (i % 3 == 0) and FROST or color_white,
				})
			end
		end)
	end,
	fx_jump_firework = function(pos)
		local center = pos + Vector(0, 0, 70)
		emit(center, function(e)
			local a = FESTIVE[math.random(#FESTIVE)]
			local b = FESTIVE[math.random(#FESTIVE)]
			particle(e, glow, center, {life = 0.2, size = 90, endSize = 20, col = a})
			for i = 1, 28 do
				particle(e, (i % 2 == 0) and spark or glow, center, {
					vel = VectorRand():GetNormalized() * math.Rand(140, 200), life = math.Rand(0.8, 1.1),
					size = 5, grav = Vector(0, 0, -150), drag = 60, col = (i % 3 == 0) and b or a,
				})
			end
		end)
	end,
}

local function spawnFootFX(ply, id)
	local fx = FOOT_FX[id]
	if not fx then return end
	local pos = ply:GetPos()
	local vel = ply:GetVelocity()
	vel.z = 0
	if vel:LengthSqr() > 1 then
		pos = pos - vel:GetNormalized() * 10
	end
	fx(pos)
end

hook.Add("PostDrawTranslucentRenderables", "BRBP_EchoSteps", function(depth, sky)
	if sky then return end
	if #echoRings == 0 then return end

	render.SetMaterial(ringMat)
	for i = #echoRings, 1, -1 do
		local ring = echoRings[i]
		local frac = (CurTime() - ring.t) / ring.life
		if frac >= 1 then
			table.remove(echoRings, i)
		else
			local size = 12 + ring.grow * frac
			local c = ring.col
			render.DrawQuadEasy(ring.pos, Vector(0, 0, 1), size, size, Color(c.r, c.g, c.b, 220 * (1 - frac)), 0)
		end
	end
end)

hook.Add("Think", "BRBP_Footstep", function()
	for _, ply in ipairs(player.GetAll()) do
		if not IsValid(ply) or not ply:Alive() then continue end

		local id = ply:GetNW2String("BRBP_Footstep", "")
		if id == "" or not BRBP.Cosmetics[id] then continue end
		local key = ply:EntIndex()
		if ply:GetMoveType() == MOVETYPE_NOCLIP then continue end
		if not ply:OnGround() then
			stepDist[key] = 0
			continue
		end

		local vel = ply:GetVelocity()
		vel.z = 0
		local spd = vel:Length()
		if spd < 90 then continue end

		stepDist[key] = (stepDist[key] or 0) + spd * FrameTime()
		local stride = math.Clamp(spd * 0.38, 55, 110)
		if stepDist[key] >= stride then
			stepDist[key] = 0
			spawnFootFX(ply, id)
		end
	end
end)

hook.Add("OnParkour", "BRBP_JumpFX", function(event)
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	if event ~= "vault" and event ~= "coil" and event ~= "roll" then return end
	local fx = JUMP_FX[ply:GetNW2String("BRBP_Jump", "")]
	if fx then fx(ply:GetPos()) end
end)

local lastSend = {}
local function sendParkour(event)
	if not BRBP.Config.ParkourBPXP[event] then return end
	local now = CurTime()
	if now - (lastSend[event] or 0) < 0.35 then return end
	lastSend[event] = now
	net.Start("BRBP_Parkour")
	net.WriteString(event)
	net.SendToServer()
end

hook.Add("OnParkour", "BRBP_SendEvent", function(event)
	sendParkour(event)
end)

local lastClimb = false
hook.Add("Think", "BRBP_ClimbDetect", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then
		lastClimb = false
		return
	end
	local anim = ply.BodyAnimString or BodyAnimString
	local mantle = ply.GetMantle and ply:GetMantle() or 0
	local active = anim == "vaultontohigh" or mantle == 5
	if active and not lastClimb then
		sendParkour("vaultontohigh")
	end
	lastClimb = active
end)

local lastDive = false
hook.Add("Think", "BRBP_DiveDetect", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then
		lastDive = false
		return
	end
	local anim = ply.BodyAnimString or BodyAnimString
	local diving = (ply.GetDive and ply:GetDive()) or anim == "divestart" or anim == "diveidle"
	if diving and not lastDive then
		sendParkour("divestart")
	end
	lastDive = diving and true or false
end)

local lastVault = false
hook.Add("Think", "BRBP_VaultDetect", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then
		lastVault = false
		return
	end
	local anim = ply.BodyAnimString or BodyAnimString
	local mantle = ply.GetMantle and ply:GetMantle() or 0
	local vaulting = mantle == 2 or mantle == 3 or anim == "vaultover" or anim == "vaultkong"
	if vaulting and not lastVault then
		local event = "vault"
		if mantle == 3 or anim == "vaultkong" then
			event = "vaultkong"
		end
		sendParkour(event)
	end
	lastVault = vaulting
end)

local toasts = {}

net.Receive("BRBP_Toast", function()
	local kind = net.ReadUInt(2)
	local tier = net.ReadUInt(8)
	local xp = net.ReadUInt(16)
	if kind == 2 then return end
	local text
	if kind == 0 then
		text = BRBP.L("toast_quest", xp)
	else
		text = BRBP.L("toast_tier", tier)
	end
	toasts[#toasts + 1] = {kind = kind, xp = xp, text = text, t = CurTime() + 3.5}
	surface.PlaySound("mirrorsedge/ui/ME_UI_hud_select.wav")
	hook.Run("BRBP_ClientToast", kind)
end)

hook.Add("HUDPaint", "BRBP_Toasts", function()
	local y = ScrH() * 0.22
	local cx = ScrW() / 2
	for i = #toasts, 1, -1 do
		local toast = toasts[i]
		local left = toast.t - CurTime()
		if left <= 0 then
			table.remove(toasts, i)
		else
			local a = math.Clamp(left * 400, 0, 255)
			if toast.kind == 0 then
				local prefix = BRBP.L("quest_done")
				local rest = "  +" .. tostring(toast.xp) .. " BP XP"
				surface.SetFont("BRBP_Sub")
				local pw = surface.GetTextSize(prefix)
				local rw = surface.GetTextSize(rest)
				local x = cx - (pw + rw) / 2
				draw.SimpleText(prefix, "BRBP_Sub", x, y, Color(94, 255, 110, a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText(rest, "BRBP_Sub", x + pw, y, Color(255, 255, 255, a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			else
				draw.SimpleText(toast.text, "BRBP_Sub", cx, y, Color(255, 255, 255, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			y = y + 28
		end
	end
end)

local function boostLeft()
	local untilt = 0
	if BRBP.State and tonumber(BRBP.State.boostUntil) then
		untilt = tonumber(BRBP.State.boostUntil)
	end
	local nw = LocalPlayer().GetNW2Int and LocalPlayer():GetNW2Int("BRBP_BoostUntil", 0) or 0
	untilt = math.max(untilt, nw)
	return untilt - os.time()
end

local function boostPercent()
	local mult = (BRBP.Config and BRBP.Config.BoostMult) or 1.25
	return math.Round((mult - 1) * 100)
end

local function boostClock(sec)
	sec = math.max(0, math.floor(sec))
	local h = math.floor(sec / 3600)
	local m = math.floor((sec % 3600) / 60)
	local s = sec % 60
	return string.format("%02d:%02d:%02d", h, m, s)
end

local function boostScaleX(n)
	if SScaleX then return SScaleX(n) end
	return math.ceil(n / (1920 / ScrW()))
end

local function boostScaleY(n)
	if SScaleY then return SScaleY(n) end
	return math.ceil(n / (1080 / ScrH()))
end

local boostBlur = Material("pp/blurscreen")

local function BoostDrawBlurRect(x, y, w, h, a)
	if render.GetDXLevel() < 90 then return end

	surface.SetDrawColor(255, 255, 255, a)
	surface.SetMaterial(boostBlur)

	for i = 1, 2 do
		boostBlur:SetFloat("$blur", i / 3 * 5)
		boostBlur:Recompute()
		render.UpdateScreenEffectTexture()
		render.SetScissorRect(x, y, x + w, y + h, true)
		surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
		render.SetScissorRect(0, 0, 0, 0, false)
	end
end

local function boostHUDWidth(ply, label, clock)
	local nicktext = ply:Nick()
	local xpCvar = GetConVar("Beatrun_HUDXP")
	if (not xpCvar or xpCvar:GetBool()) and ply.GetXP then
		nicktext = ply:Nick() .. " | " .. ply:GetXP() .. "XP"
	end

	local coursename = "#beatrun.hud.freeplay"
	if Course_Name and Course_Name ~= "" then
		coursename = language.GetPhrase("beatrun.hud.course"):format(Course_Name)
	end
	local customname = hook.Run("BeatrunHUDCourse")
	if customname then coursename = customname end

	surface.SetFont("BeatrunHUDSmall")
	local nickw = select(1, surface.GetTextSize(nicktext))
	local clockw = select(1, surface.GetTextSize(clock))
	surface.SetFont("BeatrunHUD")
	local coursew = select(1, surface.GetTextSize(coursename))
	local labelw = select(1, surface.GetTextSize(label))
	local bgpadw = math.max(nickw, coursew, labelw, clockw)
	return bgpadw > 200 and bgpadw + 40 or 200
end

local boostHideAlpha = 0

hook.Add("HUDPaint", "BRBP_Boost", function()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	if BuildMode then return end

	local hidden = GetConVar("Beatrun_HUDHidden")
	if hidden and hidden:GetInt() > 0 then return end
	if hook.Run("BeatrunDrawHUD") == false then return end

	local left = boostLeft()
	if left <= 0 then return end

	local sway = GetConVar("Beatrun_HUDSway")
	local dynamic = GetConVar("Beatrun_HUDDynamic")
	local dynamicOn = dynamic and dynamic:GetBool()
	local vp = ply:GetViewPunchAngles()
	if not sway or not sway:GetBool() then
		vp.x = 0
		vp.z = 0
	end

	if dynamicOn then
		boostHideAlpha = math.Approach(boostHideAlpha, 150 * ply:GetVelocity():Length() / 250, 100 * RealFrameTime())
	else
		boostHideAlpha = 0
	end

	local colStr = ply:GetInfo("Beatrun_HUDTextColor")
	if not colStr or colStr == "" then colStr = "255 255 255 255" end
	local text_color = string.ToColor(colStr) or Color(255, 255, 255, 255)
	text_color.a = dynamicOn and math.max(255 - boostHideAlpha, 2) or text_color.a

	local cornerStr = ply:GetInfo("Beatrun_HUDCornerColor")
	if not cornerStr or cornerStr == "" then cornerStr = "20 20 20 100" end
	local corner_color_c = string.ToColor(cornerStr) or Color(20, 20, 20, 100)
	corner_color_c.a = math.Clamp(corner_color_c.a + 50, 0, 255)
	corner_color_c.a = dynamicOn and math.max(150 - boostHideAlpha, 50) or corner_color_c.a

	local corner_color = string.ToColor(cornerStr) or Color(20, 20, 20, 100)
	corner_color.a = dynamicOn and math.max(100 - boostHideAlpha, 50) or corner_color.a

	local scrw = ScrW()
	local scrh = ScrH()
	local label = BRBP.L("boost_hud", tostring(boostPercent()))
	local clock = boostClock(left)
	local boxw = boostScaleX(boostHUDWidth(ply, label, clock))
	local boxh = boostScaleY(52)
	local boxx = 20 + vp.z
	local boxy = scrh * 0.838 + vp.x

	surface.SetDrawColor(corner_color_c)
	surface.DrawRect(-20 + vp.z, boxy, 40, boxh)
	BoostDrawBlurRect(boxx, boxy, boxw, boxh, math.max(255 - boostHideAlpha, 2))
	surface.SetDrawColor(corner_color)
	surface.DrawOutlinedRect(boxx, boxy, boxw, boxh)

	local star_color = Color(255, 220, 40, text_color.a)
	surface.SetFont("BeatrunHUD")
	surface.SetTextColor(star_color)
	surface.SetTextPos(scrw * 0.002 + vp.z, scrh * 0.845 + vp.x)
	surface.DrawText("★")
	surface.SetTextColor(text_color)
	surface.SetTextPos(scrw * 0.015 + vp.z, scrh * 0.845 + vp.x)
	surface.DrawText(label)

	surface.SetFont("BeatrunHUDSmall")
	surface.SetTextPos(scrw * 0.015 + vp.z, scrh * 0.865 + vp.x)
	surface.DrawText(clock)
end)
