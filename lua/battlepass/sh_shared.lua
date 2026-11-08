BRBP = BRBP or {}

function BRBP.QuestLabel(id, goal)
	local shown = goal

	if id == "d_play" or id == "w_play" then
		shown = math.floor(goal / 60)
	end

	return string.format(language.GetPhrase("beatrun_battlepass.quest." .. id), shown)
end

function BRBP.TrackEnd()
	return (BRBP.Config.MaxTier or 30) + (BRBP.Config.BonusTiers or 0)
end

function BRBP.IsBonusTier(tier)
	return (tier or 0) > (BRBP.Config.MaxTier or 30)
end

function BRBP.TierCost(tier)
	local cfg = BRBP.Config

	if tier > cfg.MaxTier then return cfg.BonusTierXP end

	return cfg.TierBaseXP + cfg.TierStepXP * (tier - 1)
end

-- total XP needed to reach the tier
function BRBP.XPForTier(tier)
	local cfg = BRBP.Config
	local main = math.min(tier, cfg.MaxTier)
	local total = main * cfg.TierBaseXP + cfg.TierStepXP * main * (main - 1) / 2

	return total + math.max(tier - cfg.MaxTier, 0) * cfg.BonusTierXP
end

function BRBP.MaxXP()
	return BRBP.XPForTier(BRBP.TrackEnd())
end

function BRBP.GetTierForXP(xp)
	xp = xp or 0
	local tier = 0

	while tier < BRBP.TrackEnd() and xp >= BRBP.XPForTier(tier + 1) do
		tier = tier + 1
	end

	return tier
end

-- XP gathered inside the current tier and the cost of the next one
function BRBP.XPIntoTier(xp)
	local tier = BRBP.GetTierForXP(xp)

	if tier >= BRBP.TrackEnd() then
		local cost = BRBP.TierCost(tier)

		return cost, cost
	end

	return (xp or 0) - BRBP.XPForTier(tier), BRBP.TierCost(tier + 1)
end

function BRBP.SeasonAt(now)
	now = now or os.time()
	local best, first

	for n, season in pairs(BRBP.Seasons or {}) do
		if not first or n < first then first = n end
		if (season.starts or 0) <= now and (not best or n > best) then best = n end
	end

	return best or first
end

function BRBP.ApplySeason(n)
	local season = BRBP.Seasons and BRBP.Seasons[n]

	if not season then return false end

	BRBP.Config.Season = n
	BRBP.Config.SeasonName = season.name
	BRBP.Config.SeasonEnds = season.ends
	BRBP.Config.WeekEpoch = season.starts
	BRBP.Tiers = season.tiers

	return true
end

function BRBP.DayKey(now)
	return os.date("!%Y-%m-%d", now or os.time())
end

function BRBP.WeekKey(now)
	now = now or os.time()
	local origin = BRBP.Config.WeekEpoch or 0

	return tostring(math.floor(math.max(0, now - origin) / 604800))
end

function BRBP.SecondsUntilNextDay(now)
	now = now or os.time()
	local utc = os.date("!*t", now)
	local elapsed = (utc.hour or 0) * 3600 + (utc.min or 0) * 60 + (utc.sec or 0)

	return 86400 - elapsed
end

function BRBP.SecondsUntilNextWeek(now)
	now = now or os.time()
	local origin = BRBP.Config.WeekEpoch or 0

	return 604800 - (math.max(0, now - origin) % 604800)
end

function BRBP.FormatCountdown(sec)
	sec = math.max(0, math.floor(tonumber(sec) or 0))
	local h = math.floor(sec / 3600)
	local m = math.floor((sec % 3600) / 60)
	local s = sec % 60

	return string.format("%02d:%02d:%02d", h, m, s)
end

function BRBP.EventMatchesQuest(incoming, questEvent)
	if incoming == questEvent then return true end

	local groups = BRBP.Config.QuestEventGroups
	local group = groups and groups[questEvent]

	return group and group[incoming] == true
end

function BRBP.FindQuest(kind, id)
	local pool = BRBP.QuestPool[kind]

	if not pool then return nil end

	for i = 1, #pool do
		if pool[i].id == id then return pool[i] end
	end
end

local function Lcg(seed)
	seed = (seed * 1103515245 + 12345) % 2147483648

	return seed
end

function BRBP.BlockedEventsFromWeekly(weekly)
	local blocked = {}

	if not istable(weekly) or not istable(weekly.items) then return blocked end

	for i = 1, #(weekly.items or {}) do
		local item = weekly.items[i]

		if istable(item) and not item.done then
			local def = BRBP.FindQuest("weekly", item.id)

			if def and def.event then
				blocked[def.event] = true
			end
		end
	end

	return blocked
end

function BRBP.PickQuests(kind, steamid, key, excludeEvents)
	local pool = table.Copy(BRBP.QuestPool[kind] or {})
	local count = (kind == "daily") and BRBP.Config.DailyCount or BRBP.Config.WeeklyCount
	count = math.min(count, #pool)

	local seed = tonumber(util.CRC((steamid or "") .. key .. tostring(BRBP.Config.Season))) or 1

	for i = #pool, 2, -1 do
		seed = Lcg(seed)
		local j = (seed % i) + 1
		pool[i], pool[j] = pool[j], pool[i]
	end

	local picked = {}
	local used = {}
	local function take(q)
		if used[q.id] then return end

		used[q.id] = true
		picked[#picked + 1] = q
	end

	for i = 1, #pool do
		local q = pool[i]

		if not (kind == "daily" and excludeEvents and excludeEvents[q.event]) then
			take(q)
			if #picked >= count then return picked end
		end
	end

	for i = 1, #pool do
		take(pool[i])
		if #picked >= count then break end
	end

	return picked
end

function BRBP.HasPremiumAccess(ply, data)
	if data and data.premium then return true end
	if not IsValid(ply) then return false end

	local group = ply:GetUserGroup() or "user"

	return BRBP.Config.PremiumGroups[group] == true
end

function BRBP.RewardText(reward)
	local kind = reward[1]

	if kind == "xp" then
		return string.format(language.GetPhrase("beatrun_battlepass.reward_xp"), reward[2])
	elseif kind == "boost" then
		local hours = string.format(language.GetPhrase("beatrun_battlepass.hours"), math.floor(reward[2] / 3600))

		return string.format(language.GetPhrase("beatrun_battlepass.reward_boost"), hours)
	elseif kind == "cosmetic" then
		local item = BRBP.Cosmetics[reward[2]]

		if not item then return reward[2] end

		local typeKey = ({
			title = "reward_title",
			trail = "trail",
			footstep = "footstep",
			jump = "jump"
		})[item.type] or "reward_title"
		local name = item.short or item.text or item.name

		return language.GetPhrase("beatrun_battlepass." .. typeKey) .. " " .. name
	end

	return tostring(kind)
end

function BRBP.TitleColor(def)
	if not def then return Color(255, 255, 255) end

	local fx = def.fx or "static"
	local base = def.color or Color(255, 255, 255)

	if fx == "rainbow" then
		return HSVToColor((CurTime() * 90) % 360, 0.75, 1)
	elseif fx == "hsv" then
		local h, s, _ = ColorToHSV(base)

		return HSVToColor((h + CurTime() * 70) % 360, math.max(s, 0.65), 1)
	elseif fx == "pulse" then
		local t = (math.sin(CurTime() * 3.2) + 1) * 0.5

		return Color(
			Lerp(t, 255, base.r),
			Lerp(t, 255, base.g),
			Lerp(t, 255, base.b)
		)
	end

	return base
end

function BRBP.TitleTag(def)
	if not def then return "" end

	return "[" .. (def.text or def.name or "TITLE") .. "]"
end

function BRBP.TitleMarkup(def)
	local tag = BRBP.TitleTag(def)
	local fx = def.fx or "static"

	if fx == "rainbow" or fx == "hsv" then
		return "<hsv=t()*300>" .. tag .. "<stop>"
	end

	local c = def.color or Color(255, 255, 255)

	return string.format("<c=%02x%02x%02x>%s<stop>", c.r, c.g, c.b, tag)
end

function BRBP.TitleHUDMarkup(id, def)
	if not def then return "" end

	return "<brbp=" .. tostring(id) .. ">" .. BRBP.TitleTag(def) .. " <stop>"
end

BRBP.ApplySeason(BRBP.SeasonAt())
