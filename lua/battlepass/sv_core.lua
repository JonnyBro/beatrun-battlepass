if not SERVER then return end

BRBP = BRBP or {}
BRBP.Players = BRBP.Players or {}

util.AddNetworkString("BRBP_State")
util.AddNetworkString("BRBP_Progress")
util.AddNetworkString("BRBP_Toast")
util.AddNetworkString("BRBP_Parkour")
util.AddNetworkString("BRBP_Equip")
util.AddNetworkString("BRBP_BuyPremium")
util.AddNetworkString("BRBP_Open")
util.AddNetworkString("BRBP_Request")
util.AddNetworkString("BRBP_Claim")
util.AddNetworkString("BRBP_Welcome")

local DATA_DIR = "beatrun_battlepass"
file.CreateDir(DATA_DIR)

local function sid(ply)
	return ply:SteamID64() or ply:SteamID()
end

local function pathFor(ply)
	return DATA_DIR .. "/" .. sid(ply) .. ".json"
end

local function emptyEquip()
	return {
		trail = "",
		title = "",
		footstep = "",
		jump = "",
	}
end

local function defaultQuestState(kind, ply, exclude)
	local key = (kind == "daily") and BRBP.DayKey() or BRBP.WeekKey()
	local picked = BRBP.PickQuests(kind, sid(ply), key, exclude)
	local items = {}
	for i = 1, #picked do
		items[i] = {
			id = picked[i].id,
			progress = 0,
			done = false,
		}
	end
	return {key = key, items = items}
end

local function defaultData(ply)
	local weekly = defaultQuestState("weekly", ply)
	return {
		season = BRBP.Config.Season,
		xp = 0,
		grantedTier = 0,
		premium = false,
		premiumGranted = 0,
		unlocked = {},
		equipped = emptyEquip(),
		weekly = weekly,
		daily = defaultQuestState("daily", ply, BRBP.BlockedEventsFromWeekly(weekly)),
		boostUntil = 0,
		seen = false,
		gen = BRBP.Config.SaveGen or 1,
	}
end

local function rotateQuests(data, ply)
	local weekChanged = data.weekly.key ~= BRBP.WeekKey()
	local dayChanged = data.daily.key ~= BRBP.DayKey()
	if weekChanged then
		data.weekly = defaultQuestState("weekly", ply)
	end
	if dayChanged or weekChanged then
		data.daily = defaultQuestState("daily", ply, BRBP.BlockedEventsFromWeekly(data.weekly))
	end
end

local function resetSeason(data, ply)
	if data.season == BRBP.Config.Season then return data end
	local fresh = defaultData(ply)
	if istable(data.unlocked) then fresh.unlocked = data.unlocked end
	if istable(data.equipped) then fresh.equipped = data.equipped end
	return fresh
end

function BRBP.Load(ply)
	if not IsValid(ply) or ply:IsBot() then return end

	local raw = file.Read(pathFor(ply), "DATA")
	local data = raw and util.JSONToTable(raw) or nil
	if not istable(data) or (data.gen or 0) ~= (BRBP.Config.SaveGen or 1) then
		data = defaultData(ply)
	else
		data = resetSeason(data, ply)
		data.unlocked = data.unlocked or {}
		data.equipped = data.equipped or emptyEquip()
		data.weekly = data.weekly or defaultQuestState("weekly", ply)
		data.daily = data.daily or defaultQuestState("daily", ply, BRBP.BlockedEventsFromWeekly(data.weekly))
		rotateQuests(data, ply)
	end

	if BRBP.HasPremiumAccess(ply, data) then
		data.premium = true
	end

	BRBP.Players[sid(ply)] = data
	return data
end

function BRBP.Get(ply)
	if not IsValid(ply) then return nil end
	return BRBP.Players[sid(ply)] or BRBP.Load(ply)
end

function BRBP.Save(ply)
	local data = BRBP.Get(ply)
	if not data then return end
	file.Write(pathFor(ply), util.TableToJSON(data, false))
end

local function unlockCosmetic(data, id)
	if data.unlocked[id] then return false end
	data.unlocked[id] = true
	return true
end

local function grantReward(ply, data, reward)
	local kind = reward[1]
	if kind == "xp" then
		if ply.AddXP then ply:AddXP(reward[2]) end
	elseif kind == "boost" then
		local now = os.time()
		local start = math.max(data.boostUntil or 0, now)
		data.boostUntil = start + reward[2]
		ply:SetNW2Int("BRBP_BoostUntil", data.boostUntil)
	elseif kind == "cosmetic" then
		unlockCosmetic(data, reward[2])
	end
end

local function grantTrack(ply, data, track)
	if not istable(track) then return end
	for i = 1, #track do
		grantReward(ply, data, track[i])
	end
end

local function grantTiers(ply, data)
	return false
end

function BRBP.ClaimTier(ply, tier)
	local data = BRBP.Get(ply)
	if not data then return false end

	tier = math.floor(tonumber(tier) or 0)
	if tier < 1 or tier > BRBP.TrackEnd() then return false end
	if BRBP.GetTierForXP(data.xp) < tier then return false end
	if (data.grantedTier or 0) + 1 ~= tier then return false end

	data.grantedTier = tier
	local def = BRBP.Tiers[tier]
	if def then
		grantTrack(ply, data, def.free)
		if data.premium then
			if not BRBP.IsBonusTier(tier) then
				grantTrack(ply, data, def.premium)
			end
			data.premiumGranted = tier
		end
	end

	BRBP.Save(ply)
	BRBP.Sync(ply)
	return true
end

local function grantMissedPremium(ply, data)
	if not data.premium then return end
	data.premiumGranted = data.premiumGranted or 0
	for t = data.premiumGranted + 1, data.grantedTier do
		if not BRBP.IsBonusTier(t) then
			local def = BRBP.Tiers[t]
			if def then
				grantTrack(ply, data, def.premium)
			end
		end
	end
	data.premiumGranted = data.grantedTier
end

function BRBP.GivePremium(ply)
	local data = BRBP.Get(ply)
	if not data then return end
	data.premium = true
	grantMissedPremium(ply, data)
	BRBP.Save(ply)
	BRBP.Sync(ply)
end

local function applyEquipped(ply, data)
	local eq = data.equipped or emptyEquip()
	ply:SetNW2String("BRBP_Trail", eq.trail or "")
	ply:SetNW2String("BRBP_Title", eq.title or "")
	ply:SetNW2String("BRBP_Footstep", eq.footstep or "")
	ply:SetNW2String("BRBP_Jump", eq.jump or "")
	ply:SetNW2Int("BRBP_BoostUntil", data.boostUntil or 0)
	ply:SetNW2Int("BRBP_XP", data.xp or 0)
	ply:SetNW2Int("BRBP_Tier", BRBP.GetTierForXP(data.xp))
	ply:SetNW2Bool("BRBP_Premium", data.premium and true or false)
end

local function serializeQuests(state, kind)
	local out = {}
	for i = 1, #(state.items or {}) do
		local item = state.items[i]
		local def = BRBP.FindQuest(kind, item.id)
		out[i] = {
			id = item.id,
			progress = item.progress or 0,
			goal = def and def.goal or 1,
			xp = def and def.xp or 0,
			done = item.done and true or false,
			icon = def and def.icon or "icons/group.png",
		}
	end
	return out
end

function BRBP.Sync(ply)
	local data = BRBP.Get(ply)
	if not data then return end
	applyEquipped(ply, data)

	local payload = {
		xp = data.xp,
		premium = data.premium and true or false,
		season = data.season,
		seasonName = BRBP.Config.SeasonName,
		seasonEnds = BRBP.Config.SeasonEnds,
		grantedTier = data.grantedTier,
		unlocked = data.unlocked,
		equipped = data.equipped,
		daily = serializeQuests(data.daily, "daily"),
		weekly = serializeQuests(data.weekly, "weekly"),
		boostUntil = data.boostUntil,
		premiumCost = BRBP.Config.PremiumXPCost,
		beatrunXP = ply.GetXP and ply:GetXP() or 0,
	}

	local compressed = util.Compress(util.TableToJSON(payload) or "{}")
	net.Start("BRBP_State")
	net.WriteUInt(#compressed, 16)
	net.WriteData(compressed, #compressed)
	net.Send(ply)
end

function BRBP.AddXP(ply, amount)
	local data = BRBP.Get(ply)
	if not data or amount <= 0 then return end
	local before = BRBP.GetTierForXP(data.xp)
	data.xp = math.min(data.xp + math.floor(amount), BRBP.Config.TierXP * BRBP.TrackEnd())
	local after = BRBP.GetTierForXP(data.xp)
	ply:SetNW2Int("BRBP_XP", data.xp)
	ply:SetNW2Int("BRBP_Tier", after)
	if after > before then
		applyEquipped(ply, data)
		net.Start("BRBP_Toast")
		net.WriteUInt(2, 2)
		net.WriteUInt(after, 8)
		net.WriteUInt(0, 16)
		net.Send(ply)
		BRBP.Sync(ply)
	end
end

local function bumpQuestList(ply, data, kind, event, amount)
	local state = data[kind]
	if not state then return false end
	local changed = false
	for i = 1, #(state.items or {}) do
		local item = state.items[i]
		if not item.done then
			local def = BRBP.FindQuest(kind, item.id)
			if def and BRBP.EventMatchesQuest(event, def.event) then
				item.progress = math.min((item.progress or 0) + amount, def.goal)
				if item.progress >= def.goal then
					item.done = true
					item.progress = def.goal
					BRBP.AddXP(ply, def.xp)
					net.Start("BRBP_Toast")
					net.WriteUInt(0, 2)
					net.WriteUInt(0, 8)
					net.WriteUInt(def.xp, 16)
					net.Send(ply)
				end
				changed = true
			end
		end
	end
	return changed
end

function BRBP.Progress(ply, event, amount)
	if not IsValid(ply) or ply:IsBot() then return end
	amount = amount or 1
	local data = BRBP.Get(ply)
	if not data then return end

	rotateQuests(data, ply)

	local d = bumpQuestList(ply, data, "daily", event, amount)
	local w = bumpQuestList(ply, data, "weekly", event, amount)
	if not d and not w then return end

	BRBP.Save(ply)
	BRBP.Sync(ply)
end

local lastParkour = {}
local parkourWindow = {}
local diveState = {}
local vaultState = {}

local VAULT_EVENTS = {
	vault = true,
	vaultover = true,
	vaultkong = true,
}
local DIVE_EVENTS = {
	divestart = true,
	diveidle = true,
}

local function acceptParkour(ply, event, trusted)
	if not IsValid(ply) or ply:IsBot() then return end
	if not ply:Alive() then return end
	if ply:GetMoveType() == MOVETYPE_NOCLIP then return end
	if not isstring(event) or not BRBP.Config.ParkourBPXP[event] then return end
	if not trusted and BRBP.ParkourRefuse and BRBP.ParkourRefuse(ply, event) then return end

	local id = sid(ply)
	local now = CurTime()
	lastParkour[id] = lastParkour[id] or {}

	local groupKey = VAULT_EVENTS[event] and "_vault" or (DIVE_EVENTS[event] and "_dive" or event)
	if now - (lastParkour[id][groupKey] or 0) < BRBP.Config.ParkourEventCooldown then return end
	lastParkour[id][groupKey] = now
	lastParkour[id][event] = now

	if not trusted then
		parkourWindow[id] = parkourWindow[id] or {t = now, n = 0}
		if now - parkourWindow[id].t >= 1 then
			parkourWindow[id] = {t = now, n = 0}
		end
		parkourWindow[id].n = parkourWindow[id].n + 1
		if parkourWindow[id].n > BRBP.Config.MaxParkourEventsPerSec then return end
	end

	local data = BRBP.Get(ply)
	if not data then return end

	local beforeTier = data.grantedTier
	local bp = BRBP.Config.ParkourBPXP[event] or 0
	if bp > 0 then
		BRBP.AddXP(ply, bp)
	end

	rotateQuests(data, ply)
	local d = bumpQuestList(ply, data, "daily", event, 1)
	local w = bumpQuestList(ply, data, "weekly", event, 1)
	local p = bumpQuestList(ply, data, "weekly", "parkour", 1)
	local p2 = bumpQuestList(ply, data, "daily", "parkour", 1)

	applyEquipped(ply, data)
	BRBP.Save(ply)
	if d or w or p or p2 or data.grantedTier > beforeTier then
		BRBP.Sync(ply)
	end
end

net.Receive("BRBP_Parkour", function(_, ply)
	local event = net.ReadString()
	if not isstring(event) or #event > 32 then return end
	acceptParkour(ply, event, VAULT_EVENTS[event] or DIVE_EVENTS[event])
end)

hook.Add("OnParkour", "BRBP_ServerParkour", function(event, ply)
	if not IsValid(ply) then return end
	if not VAULT_EVENTS[event] and not DIVE_EVENTS[event] then return end
	acceptParkour(ply, event, true)
end)

hook.Add("Think", "BRBP_DetectDiveVault", function()
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and not ply:IsBot() then
			local id = sid(ply)
			if ply:Alive() and ply:GetMoveType() ~= MOVETYPE_NOCLIP then
				local diving = ply.GetDive and ply:GetDive()
				if diving and not diveState[id] then
					acceptParkour(ply, "divestart", true)
				end
				diveState[id] = diving and true or false

				local mantle = ply.GetMantle and ply:GetMantle() or 0
				local vaulting = mantle == 2 or mantle == 3
				if vaulting and not vaultState[id] then
					acceptParkour(ply, mantle == 3 and "vaultkong" or "vault", true)
				end
				vaultState[id] = vaulting
			else
				diveState[id] = false
				vaultState[id] = false
			end
		end
	end
end)

net.Receive("BRBP_Equip", function(_, ply)
	if BRBP.TooFast and BRBP.TooFast(ply, "eq", 0.12) then return end
	local slot = net.ReadString()
	local id = net.ReadString()
	if not isstring(slot) or not isstring(id) then return end
	if #slot > 16 or #id > 40 then return end
	local data = BRBP.Get(ply)
	if not data then return end

	local allowed = {
		trail = true,
		title = true,
		footstep = true,
		jump = true,
	}
	if not allowed[slot] then return end

	if id ~= "" then
		local item = BRBP.Cosmetics[id]
		if not item or item.type ~= slot then return end
		if not data.unlocked[id] then return end
	end

	data.equipped[slot] = id
	applyEquipped(ply, data)
	BRBP.Save(ply)
	BRBP.Sync(ply)
end)

net.Receive("BRBP_BuyPremium", function(_, ply)
	if BRBP.TooFast and BRBP.TooFast(ply, "buy", 1.5) then return end
	local data = BRBP.Get(ply)
	if not data or data.premium then return end

	local have = ply.GetXP and ply:GetXP() or 0
	local cost = BRBP.Config.PremiumXPCost
	if have < cost then
		ply:ChatPrint(BRBP.L("need_xp"))
		return
	end

	if ply.AddXP then ply:AddXP(-cost) end
	BRBP.RecalcBeatrunLevel(ply)
	BRBP.GivePremium(ply)
end)

net.Receive("BRBP_Claim", function(_, ply)
	if not IsValid(ply) then return end
	BRBP.ClaimTier(ply, net.ReadUInt(8))
end)

net.Receive("BRBP_Request", function(_, ply)
	if BRBP.TooFast and BRBP.TooFast(ply, "sync", 0.4) then return end
	BRBP.Sync(ply)
end)

local function initPlayer(ply)
	local data = BRBP.Load(ply)
	if not data then return end
	if data.premium or BRBP.HasPremiumAccess(ply, data) then
		BRBP.GivePremium(ply)
	else
		applyEquipped(ply, data)
		BRBP.Sync(ply)
	end
	if not data.seen then
		data.seen = true
		BRBP.Save(ply)
		net.Start("BRBP_Welcome")
		net.Send(ply)
	end
end

hook.Add("PlayerInitialSpawn", "BRBP_Join", function(ply)
	timer.Simple(2, function()
		if not IsValid(ply) then return end
		initPlayer(ply)
	end)
end)

timer.Create("BRBP_SeasonWatch", 30, 0, function()
	local n = BRBP.SeasonAt()
	if n == BRBP.Config.Season then return end

	local online = {}
	for _, ply in ipairs(player.GetHumans()) do
		if BRBP.Players[sid(ply)] then
			BRBP.Save(ply)
			online[#online + 1] = ply
		end
	end

	BRBP.ApplySeason(n)
	BRBP.Players = {}
	for i = 1, #online do
		if IsValid(online[i]) then initPlayer(online[i]) end
	end
end)

hook.Add("PlayerDisconnected", "BRBP_Leave", function(ply)
	local id = sid(ply)
	BRBP.Save(ply)
	BRBP.Players[id] = nil
	lastParkour[id] = nil
	parkourWindow[id] = nil
	diveState[id] = nil
	vaultState[id] = nil
end)

hook.Add("ShutDown", "BRBP_Shutdown", function()
	for _, ply in ipairs(player.GetAll()) do
		BRBP.Save(ply)
	end
end)

hook.Add("PlayerSay", "BRBP_Chat", function(ply, text)
	local cmd = string.lower(string.Trim(text or ""))
	if BRBP.Config.ChatCommands[cmd] then
		net.Start("BRBP_Open")
		net.Send(ply)
		BRBP.Sync(ply)
		return ""
	end
end)

local lastPos = {}
local lastAng = {}
local afkTime = {}
local playAccum = {}
local distAccum = {}
local grappleAccum = {}

timer.Create("BRBP_Tick", 1, 0, function()
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and not ply:IsBot() and ply:Alive() and ply:GetMoveType() ~= MOVETYPE_NOCLIP then
			local data = BRBP.Get(ply)
			if data then
				local ang = ply:EyeAngles()
				local prevAng = lastAng[ply] or ang
				lastAng[ply] = ang
				if math.abs(math.NormalizeAngle(ang.y - prevAng.y)) < 0.4 and math.abs(ang.p - prevAng.p) < 0.4 then
					afkTime[ply] = (afkTime[ply] or 0) + 1
				else
					afkTime[ply] = 0
				end

				if (afkTime[ply] or 0) < 90 then
					playAccum[ply] = (playAccum[ply] or 0) + 1
					if playAccum[ply] >= 5 then
						BRBP.Progress(ply, "playtime", playAccum[ply])
						playAccum[ply] = 0
					end
				end

				local pos = ply:GetPos()
				local prev = lastPos[ply]
				lastPos[ply] = pos
				if prev then
					local dist = pos:Distance(prev)
					if dist > 8 and dist < 1200 then
						local meters = dist / 52.49
						distAccum[ply] = (distAccum[ply] or 0) + meters
						if distAccum[ply] >= 25 then
							BRBP.Progress(ply, "distance", math.floor(distAccum[ply]))
							distAccum[ply] = distAccum[ply] - math.floor(distAccum[ply])
						end
						if ply.GetGrappling and ply:GetGrappling() then
							grappleAccum[ply] = (grappleAccum[ply] or 0) + meters
							if grappleAccum[ply] >= 25 then
								BRBP.Progress(ply, "grapple", math.floor(grappleAccum[ply]))
								grappleAccum[ply] = grappleAccum[ply] - math.floor(grappleAccum[ply])
							end
						end
					end
				end
			end
		end
	end
end)

hook.Add("PlayerSpawn", "BRBP_SpawnCosmetics", function(ply)
	timer.Simple(0.2, function()
		if not IsValid(ply) then return end
		local data = BRBP.Get(ply)
		if data then applyEquipped(ply, data) end
	end)
end)

local courseWrapped = false
local function wrapFinishCourse()
	if courseWrapped or not isfunction(FinishCourse) then return end
	local old = FinishCourse
	FinishCourse = function(ply)
		old(ply)
		if IsValid(ply) then
			BRBP.Progress(ply, "course", 1)
		end
	end
	courseWrapped = true
end

hook.Add("InitPostEntity", "BRBP_WrapCourse", function()
	wrapFinishCourse()
	timer.Simple(2, wrapFinishCourse)
end)

local function xpForLevel(level)
	if isfunction(CalcXPForNextLevel) then
		return CalcXPForNextLevel(level)
	end
	return math.Round(0.25 * level ^ 3 + 0.8 * level ^ 2 + 2 * level)
end

function BRBP.RecalcBeatrunLevel(ply)
	if not IsValid(ply) or ply:IsBot() then return end
	if not BEATRUN_PLAYERS_XP then return end

	local steamID = ply:SteamID()
	local info = BEATRUN_PLAYERS_XP[steamID]
	if not info then return end

	info.xp = math.max(0, math.Round(tonumber(info.xp) or 0))

	local level = math.max(1, math.floor(tonumber(info.level) or 1))
	while level > 1 do
		if info.xp >= xpForLevel(level - 1) then break end
		level = level - 1
	end
	while true do
		local lo = xpForLevel(level - 1)
		local hi = xpForLevel(level)
		if hi == lo then break end
		if (info.xp - lo) / (hi - lo) < 1 then break end
		level = level + 1
		if level > 10000 then break end
	end

	info.level = level
	ply:SetNW2Int("Beatrun_XP", info.xp)
	ply:SetNW2Int("Beatrun_Level", info.level)

	pcall(function()
		net.Start("Beatrun_XPUpdate")
		net.Send(ply)
	end)

	file.CreateDir("beatrun/server")
	file.Write("beatrun/server/xp.json", util.TableToJSON(BEATRUN_PLAYERS_XP))
end

hook.Add("InitPostEntity", "BRBP_WrapAddXP", function()
	local meta = FindMetaTable("Player")
	if not meta or meta.BRBP_AddXPWrapped then return end
	local old = meta.AddXP
	if not isfunction(old) then return end

	function meta:AddXP(xp)
		local data = BRBP.Players[sid(self)]
		if data and data.boostUntil and os.time() < data.boostUntil and (xp or 0) > 0 then
			xp = math.Round(xp * (BRBP.Config.BoostMult or 1.25))
		end
		local result = old(self, xp)
		if (xp or 0) < 0 then
			BRBP.RecalcBeatrunLevel(self)
		end
		return result
	end

	meta.BRBP_AddXPWrapped = true
end)

concommand.Add("brbp_give", function(ply, _, args)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	local target = ply
	local xp = tonumber(args[#args]) or 750
	if args[1] and not tonumber(args[1]) then
		for _, v in ipairs(player.GetAll()) do
			if string.find(string.lower(v:Nick()), string.lower(args[1]), 1, true) then
				target = v
				break
			end
		end
	end
	if not IsValid(target) then return end
	BRBP.AddXP(target, xp)
	BRBP.Save(target)
	BRBP.Sync(target)
end)

concommand.Add("brbp_premium", function(ply, _, args)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	local target = ply
	if args[1] and args[1] ~= "" then
		for _, v in ipairs(player.GetAll()) do
			if string.find(string.lower(v:Nick()), string.lower(args[1]), 1, true) then
				target = v
				break
			end
		end
	end
	if not IsValid(target) then return end
	BRBP.GivePremium(target)
end)
