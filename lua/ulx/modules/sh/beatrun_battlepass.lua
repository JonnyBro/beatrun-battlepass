local CATEGORY_NAME = "Beatrun Battlepass"

local function Names(plys)
	local names = {}

	for i = 1, #plys do
		names[i] = plys[i]:Nick()
	end

	return table.concat(names, ", ")
end

function ulx.brbpgive(calling_ply, target_plys, amount)
	if not SERVER then return end

	for i = 1, #target_plys do
		local ply = target_plys[i]

		BRBP.AddXP(ply, amount)
		BRBP.Save(ply)
		BRBP.Sync(ply)
	end

	ulx.fancyLogAdmin(calling_ply, "#A gave #T #i battle pass XP", target_plys, amount)
end

local give = ulx.command(CATEGORY_NAME, "ulx brbpgive", ulx.brbpgive, "!brbpgive")
give:addParam{ type = ULib.cmds.PlayersArg }
give:addParam{ type = ULib.cmds.NumArg, min = 1, max = 30000, default = 750, hint = "xp", ULib.cmds.optional, ULib.cmds.round }
give:defaultAccess(ULib.ACCESS_SUPERADMIN)
give:help("Give battle pass XP.")

function ulx.brbpsetlevel(calling_ply, target_plys, level)
	if not SERVER then return end

	level = math.Clamp(level, 0, BRBP.TrackEnd())

	for i = 1, #target_plys do
		BRBP.SetTier(target_plys[i], level)
	end

	ulx.fancyLogAdmin(calling_ply, "#A set the battle pass level of #T to #i", target_plys, level)
end

local setlevel = ulx.command(CATEGORY_NAME, "ulx brbpsetlevel", ulx.brbpsetlevel, "!brbpsetlevel")
setlevel:addParam{ type = ULib.cmds.PlayersArg }
setlevel:addParam{ type = ULib.cmds.NumArg, min = 0, max = BRBP and BRBP.TrackEnd and BRBP.TrackEnd() or 60, hint = "level", ULib.cmds.round }
setlevel:defaultAccess(ULib.ACCESS_SUPERADMIN)
setlevel:help("Set battle pass level (XP is set to the start of that level).")

function ulx.brbppremium(calling_ply, target_plys, should_revoke)
	if not SERVER then return end

	if not should_revoke then
		for i = 1, #target_plys do
			BRBP.GivePremium(target_plys[i])
		end

		ulx.fancyLogAdmin(calling_ply, "#A unlocked premium battle pass for #T", target_plys)

		return
	end

	local removed, kept = {}, {}

	for i = 1, #target_plys do
		local ply = target_plys[i]

		if BRBP.RemovePremium(ply) then
			removed[#removed + 1] = ply
		else
			kept[#kept + 1] = ply
		end
	end

	if #removed > 0 then
		ulx.fancyLogAdmin(calling_ply, "#A revoked premium battle pass from #T", removed)
	end

	if #kept > 0 then
		ULib.tsayError(calling_ply, Names(kept) .. " keep premium battle pass through their user group (BRBP.Config.PremiumGroups)", true)
	end
end

local prem = ulx.command(CATEGORY_NAME, "ulx brbppremium", ulx.brbppremium, "!brbppremium")
prem:addParam{ type = ULib.cmds.PlayersArg }
prem:addParam{ type = ULib.cmds.BoolArg, invisible = true }
prem:defaultAccess(ULib.ACCESS_SUPERADMIN)
prem:help("Unlock or revoke the premium battle pass track.")
prem:setOpposite("ulx brbpremovepremium", { _, _, true }, "!brbpremovepremium")
