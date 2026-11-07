local CATEGORY_NAME = "Beatrun Battlepass"

function ulx.brbpgive(calling_ply, target_plys, amount)
	if not SERVER then return end
	amount = tonumber(amount) or 750
	for i = 1, #target_plys do
		local ply = target_plys[i]
		if IsValid(ply) and BRBP and BRBP.AddXP then
			BRBP.AddXP(ply, amount)
			BRBP.Save(ply)
			BRBP.Sync(ply)
		end
	end
	ulx.fancyLogAdmin(calling_ply, "#A gave #T #s battle pass XP", target_plys, tostring(amount))
end

local give = ulx.command(CATEGORY_NAME, "ulx brbpgive", ulx.brbpgive, "!brbpgive")
give:addParam{type = ULib.cmds.PlayersArg}
give:addParam{type = ULib.cmds.NumArg, min = 1, max = 30000, default = 750, hint = "xp", ULib.cmds.optional}
give:defaultAccess(ULib.ACCESS_SUPERADMIN)
give:help("Give battle pass XP.")

function ulx.brbppremium(calling_ply, target_plys)
	if not SERVER then return end
	for i = 1, #target_plys do
		local ply = target_plys[i]
		if IsValid(ply) and BRBP and BRBP.GivePremium then
			BRBP.GivePremium(ply)
		end
	end
	ulx.fancyLogAdmin(calling_ply, "#A unlocked premium battle pass for #T", target_plys)
end

local prem = ulx.command(CATEGORY_NAME, "ulx brbppremium", ulx.brbppremium, "!brbppremium")
prem:addParam{type = ULib.cmds.PlayersArg}
prem:defaultAccess(ULib.ACCESS_SUPERADMIN)
prem:help("Unlock premium battle pass track.")
