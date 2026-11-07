if not SERVER then return end

BRBP = BRBP or {}

local lastHit = {}
local burst = {}
local slots = {
	trail = true,
	title = true,
	footstep = true,
	jump = true
}

local function Steam(ply)
	if not IsValid(ply) then return "0" end

	return ply:SteamID64() or ply:SteamID() or "0"
end

function BRBP.TooFast(ply, key, wait)
	if not IsValid(ply) then return true end

	wait = wait or 0.2
	local id = Steam(ply)
	lastHit[id] = lastHit[id] or {}
	local now = CurTime()

	if now < (lastHit[id][key] or 0) then
		return true
	end

	lastHit[id][key] = now + wait

	return false
end

local LANDING_EVENTS = {
	vault = true,
	vaultonto = true,
	vaultontohigh = true,
	vaulthigh = true,
	vaultkong = true,
	vaultover = true,
	divestart = true,
	diveidle = true,
	climb = true,
	climbheave = true,
	climbhard = true,
	climbhard2 = true,
	roll = true,
	step = true,
	stepup = true
}

function BRBP.ParkourRefuse(ply, event)
	if not IsValid(ply) then return true end
	if ply:IsBot() or not ply:Alive() then return true end

	if ply:GetMoveType() == MOVETYPE_NOCLIP or ply:GetMoveType() == MOVETYPE_OBSERVER then
		return true
	end

	if ply:GetObserverMode() ~= OBS_MODE_NONE then return true end
	if ply:IsFrozen() then return true end
	if ply:InVehicle() then return true end

	if ply:WaterLevel() >= 2 and event ~= "divestart" and event ~= "diveidle" then
		return true
	end

	local vel = ply:GetVelocity()

	if ply:OnGround() and vel:Length2D() < 40 and not LANDING_EVENTS[event] then
		return true
	end

	if vel:Length() > 2800 then
		return true
	end

	local id = Steam(ply)
	local now = CurTime()
	local bag = burst[id]

	if not bag or now - bag.started > 8 then
		burst[id] = { started = now, n = 1 }
	else
		bag.n = bag.n + 1
		if bag.n > 22 then
			return true
		end
	end

	return false
end

local function RebuildQuests(kind, ply, key, exclude)
	local picked = BRBP.PickQuests(kind, Steam(ply), key, exclude)
	local items = {}

	for i = 1, #picked do
		items[i] = {
			id = picked[i].id,
			progress = 0,
			done = false
		}
	end

	return { key = key, items = items }
end

local function ValidQuestState(kind, state, count)
	if not istable(state) or not istable(state.items) then return false end
	if #state.items ~= count then return false end

	local seen = {}

	for i = 1, #state.items do
		local id = state.items[i] and state.items[i].id

		if not isstring(id) or seen[id] or not BRBP.FindQuest(kind, id) then
			return false
		end

		seen[id] = true
	end

	return true
end

local function TidyQuests(kind, ply, state, exclude)
	local key = (kind == "daily") and BRBP.DayKey() or BRBP.WeekKey()
	local count = (kind == "daily") and BRBP.Config.DailyCount or BRBP.Config.WeeklyCount

	if not istable(state) or state.key ~= key or not ValidQuestState(kind, state, count) then
		return RebuildQuests(kind, ply, key, exclude)
	end

	for i = 1, #state.items do
		local it = state.items[i]
		local def = BRBP.FindQuest(kind, it.id)

		if def then
			it.progress = math.Clamp(math.floor(tonumber(it.progress) or 0), 0, def.goal)
			if it.progress < def.goal then
				it.done = false
			else
				it.done = it.done and true or false
			end
		else
			it.progress = 0
			it.done = false
		end
	end

	return state
end

local function TidyGear(data)
	local eq = data.equipped

	if not istable(eq) then
		data.equipped = {
			trail = "",
			title = "",
			footstep = "",
			jump = ""
		}

		return
	end

	for slot in pairs(slots) do
		local id = eq[slot]

		if not isstring(id) or id == "" then
			eq[slot] = ""
		elseif not data.unlocked[id] then
			eq[slot] = ""
		else
			local item = BRBP.Cosmetics[id]

			if not item or item.type ~= slot then
				eq[slot] = ""
			end
		end
	end

	for slot in pairs(eq) do
		if not slots[slot] then
			eq[slot] = nil
		end
	end
end

local function Polish(data, ply)
	local cap = BRBP.Config.TierXP * BRBP.TrackEnd()
	data.xp = math.Clamp(math.floor(tonumber(data.xp) or 0), 0, cap)
	data.season = math.floor(tonumber(data.season) or BRBP.Config.Season)

	local reached = BRBP.GetTierForXP(data.xp)
	data.grantedTier = math.Clamp(math.floor(tonumber(data.grantedTier) or 0), 0, math.min(reached, BRBP.TrackEnd()))
	data.premiumGranted = math.Clamp(math.floor(tonumber(data.premiumGranted) or 0), 0, data.grantedTier)

	if data.premium ~= true then
		data.premium = false
	end

	if BRBP.HasPremiumAccess(ply, data) then
		data.premium = true
	end

	local keep = {}

	if istable(data.unlocked) then
		for k, v in pairs(data.unlocked) do
			local id = isstring(k) and k or v

			if isstring(id) and BRBP.Cosmetics[id] and (v == true or v == id) then
				keep[id] = true
			end
		end
	end

	data.unlocked = keep

	local now = os.time()
	data.boostUntil = math.floor(tonumber(data.boostUntil) or 0)
	if data.boostUntil > now + 60 * 60 * 24 * 40 then
		data.boostUntil = now + 60 * 60 * 24 * 14
	end

	if data.boostUntil < 0 then
		data.boostUntil = 0
	end

	data.weekly = TidyQuests("weekly", ply, data.weekly)
	local blocked = BRBP.BlockedEventsFromWeekly(data.weekly)
	local dailyOverlap = false

	if istable(data.daily) and istable(data.daily.items) then
		for i = 1, #data.daily.items do
			local def = BRBP.FindQuest("daily", data.daily.items[i].id)

			if def and blocked[def.event] then
				dailyOverlap = true
				break
			end
		end
	end

	if dailyOverlap then
		data.daily = RebuildQuests("daily", ply, BRBP.DayKey(), blocked)
	else
		data.daily = TidyQuests("daily", ply, data.daily, blocked)
	end

	TidyGear(data)
	data.seen = data.seen and true or false
end

local oldLoad = BRBP.Load
function BRBP.Load(ply)
	local data = oldLoad(ply)

	if data then
		Polish(data, ply)
	end

	return data
end

local oldSave = BRBP.Save
function BRBP.Save(ply)
	local data = BRBP.Players[Steam(ply)]

	if data then
		Polish(data, ply)
	end

	oldSave(ply)
end

local oldAdd = BRBP.AddXP
function BRBP.AddXP(ply, amount)
	if not IsValid(ply) or ply:IsBot() then return end

	amount = math.floor(tonumber(amount) or 0)
	if amount < 1 then return end

	if amount > 30000 then
		amount = 30000
	end

	oldAdd(ply, amount)
end

local oldProgress = BRBP.Progress
function BRBP.Progress(ply, event, amount)
	if not IsValid(ply) or ply:IsBot() then return end
	if not isstring(event) or #event > 32 then return end

	amount = math.floor(tonumber(amount) or 0)
	if amount < 1 then return end

	if event == "playtime" and amount > 8 then
		amount = 8
	elseif event == "distance" and amount > 80 then
		amount = 80
	elseif event == "grapple" and amount > 80 then
		amount = 80
	elseif event == "course" and amount > 1 then
		amount = 1
	elseif amount > 30 then
		amount = 30
	end

	oldProgress(ply, event, amount)
end

local oldClaim = BRBP.ClaimTier
function BRBP.ClaimTier(ply, tier)
	if not IsValid(ply) then return false end

	tier = math.floor(tonumber(tier) or 0)
	if tier < 1 or tier > BRBP.TrackEnd() then return false end

	return oldClaim(ply, tier)
end

hook.Add("PlayerDisconnected", "BRBP_ProtectGone", function(ply)
	local id = Steam(ply)
	lastHit[id] = nil
	burst[id] = nil
end)
