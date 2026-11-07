BRBP = BRBP or {}
BRBP.Config = BRBP.Config or {}

-- Season, SeasonName, SeasonEnds, WeekEpoch and BRBP.Tiers are filled from BRBP.Seasons by BRBP.ApplySeason (sh_shared).
-- Bumping SaveGen wipes ALL player data including cosmetics; a new season does not need it.
BRBP.Config.SaveGen = 1
BRBP.Config.TierXP = 750
BRBP.Config.MaxTier = 30
BRBP.Config.BonusTiers = 10
BRBP.Config.PremiumXPCost = 10000
BRBP.Config.BoostMult = 1.25
BRBP.Config.PremiumGroups = {
	vip = true,
	admin = true,
	superadmin = true
}

BRBP.Config.ParkourBPXP = {
	roll = 2,
	sidestep = 1,
	slide = 1,
	vault = 2,
	climb = 3,
	vaultontohigh = 3,
	vaultonto = 2,
	vaulthigh = 3,
	climbheave = 3,
	climbhard = 3,
	climbhard2 = 3,
	wallrunh = 2,
	springboard = 2,
	wallrunv = 2,
	coil = 1,
	swingbar = 3,
	step = 1,
	divestart = 2,
	diveidle = 2,
	vaultover = 2,
	vaultkong = 2
}

BRBP.Config.QuestEventGroups = {
	vault = {
		vault = true,
		vaultover = true,
		vaultkong = true
	},
	divestart = {
		divestart = true,
		diveidle = true
	}
}

BRBP.Config.ParkourEventCooldown = 0.45
BRBP.Config.MaxParkourEventsPerSec = 6
BRBP.Config.OpenBind = KEY_F8

BRBP.Config.ChatCommands = {
	["!bp"] = true,
	["!battlepass"] = true,
	["!pass"] = true,
	["/bp"] = true,
	["/battlepass"] = true
}

BRBP.Cosmetics = {
	trail_white = {
		type = "trail",
		name = "WHITE LINE",
		short = "WHITE",
		mat = "trails/smoke",
		color = Color(255, 255, 255),
		width = 14
	},
	trail_cyan = {
		type = "trail",
		name = "CYAN WAKE",
		short = "CYAN",
		mat = "trails/plasma",
		color = Color(0, 230, 255),
		width = 16
	},
	trail_gold = {
		type = "trail",
		name = "GOLD RUSH",
		short = "GOLD",
		mat = "trails/physbeam",
		color = Color(255, 210, 70),
		width = 18
	},
	trail_red = {
		type = "trail",
		name = "REDLINE",
		mat = "trails/laser",
		color = Color(255, 70, 70),
		width = 16
	},
	trail_green = {
		type = "trail",
		name = "TRACE",
		mat = "trails/plasma",
		color = Color(94, 255, 110),
		width = 16
	},
	trail_magenta = {
		type = "trail",
		name = "OVERDRIVE",
		mat = "trails/laser",
		color = Color(255, 70, 200),
		width = 16
	},
	trail_fire = {
		type = "trail",
		name = "HEAT",
		mat = "trails/plasma",
		color = Color(255, 120, 40),
		width = 18
	},
	trail_rainbow = {
		type = "trail",
		name = "PRISM",
		mat = "trails/physbeam",
		color = Color(255, 255, 255),
		width = 20,
		rainbow = true
	},

	title_rookie = { type = "title", name = "ROOKIE", text = "ROOKIE", color = Color(0, 230, 255), fx = "static" },
	title_runner = { type = "title", name = "RUNNER", text = "RUNNER", color = Color(255, 255, 255), fx = "pulse" },
	title_freerunner = { type = "title", name = "FREERUNNER", text = "FREERUN", color = Color(94, 255, 110), fx = "pulse" },
	title_traceur = { type = "title", name = "KICK-GLITCHER", text = "KICK-GLITCHER", color = Color(150, 70, 255), fx = "pulse" },
	title_veteran = { type = "title", name = "NO BRAKES", text = "NO BRAKES", color = Color(255, 70, 130), fx = "pulse" },
	title_legend = { type = "title", name = "FIRST TRY", text = "FIRST TRY", color = Color(255, 50, 200), fx = "pulse" },
	title_season = { type = "title", name = "S1", text = "S1", color = Color(218, 206, 45), fx = "rainbow" },
	title_premium = { type = "title", name = "PREMIUM", text = "PREMIUM", color = Color(255, 220, 40), fx = "pulse" },
	title_overdrive = { type = "title", name = "OVERDRIVE", text = "OVERDRIVE", color = Color(255, 40, 40), fx = "pulse" },
	title_elite = { type = "title", name = "GM_OUA ENJOYER", text = "GM_OUA ENJOYER", color = Color(255, 140, 0), fx = "pulse" },
	title_ghost = { type = "title", name = "TRYHARD", text = "TRYHARD", color = Color(180, 220, 255), fx = "pulse" },

	fx_dust = { type = "footstep", name = "ECHO STEPS", short = "ECHO" },
	fx_spark = { type = "footstep", name = "SPARK STEPS", short = "SPARK" },
	fx_jump = { type = "jump", name = "JUMP FLASH", short = "JUMP" },

	-- SEASON 2: SECOND WIND
	trail_s2_undertow = { type = "trail", name = "UNDERTOW", mat = "trails/laser", color = Color(0, 210, 170), width = 16 },
	trail_s2_night = { type = "trail", name = "NIGHT SHIFT", mat = "trails/plasma", color = Color(150, 80, 255), width = 16 },
	trail_s2_ember = { type = "trail", name = "EMBER", mat = "trails/plasma", color = Color(255, 170, 40), color2 = Color(255, 40, 20), width = 18 },
	trail_s2_livewire = { type = "trail", name = "LIVE WIRE", mat = "trails/electric", color = Color(120, 200, 255), width = 18 },
	trail_s2_leaf = { type = "trail", name = "LEAF FALL", mat = "trails/smoke", color = Color(230, 140, 40), color2 = Color(200, 60, 30), width = 16 },
	trail_s2_toxic = { type = "trail", name = "TOXIC", mat = "trails/laser", color = Color(170, 255, 40), width = 16 },
	trail_s2_sunset = { type = "trail", name = "SUNSET", mat = "trails/physbeam", color = Color(255, 150, 40), color2 = Color(255, 40, 170), width = 20 },
	trail_s2_tailwind = { type = "trail", name = "TAILWIND", mat = "trails/physbeam", color = Color(255, 255, 255), color2 = Color(0, 230, 255), width = 20 },

	title_s2_afterburner = { type = "title", name = "AFTERBURNER", text = "AFTERBURNER", color = Color(255, 120, 30), fx = "pulse" },
	title_s2_rooftop = { type = "title", name = "ROOFTOP RAT", text = "ROOFTOP RAT", color = Color(0, 210, 170), fx = "static" },
	title_s2_onemore = { type = "title", name = "ONE MORE RUN", text = "ONE MORE RUN", color = Color(255, 255, 255), fx = "pulse" },
	title_s2_grapple = { type = "title", name = "GRAPPLE ADDICT", text = "GRAPPLE ADDICT", color = Color(120, 200, 255), fx = "pulse" },
	title_s2_coyote = { type = "title", name = "COYOTE TIME", text = "COYOTE TIME", color = Color(230, 170, 90), fx = "pulse" },
	title_s2_pb = { type = "title", name = "PB HUNTER", text = "PB HUNTER", color = Color(255, 210, 70), fx = "pulse" },
	title_s2_momentum = { type = "title", name = "MOMENTUM", text = "MOMENTUM", color = Color(150, 80, 255), fx = "hsv" },
	title_s2_frame = { type = "title", name = "FRAME PERFECT", text = "FRAME PERFECT", color = Color(94, 255, 110), fx = "pulse" },
	title_s2_wind = { type = "title", name = "SECOND WIND", text = "SECOND WIND", color = Color(0, 230, 255), fx = "pulse" },
	title_s2_skill = { type = "title", name = "SKILL ISSUE", text = "SKILL ISSUE", color = Color(255, 60, 60), fx = "pulse" },
	title_s2_season = { type = "title", name = "S2", text = "S2", color = Color(255, 140, 40), fx = "rainbow" },

	fx_ember = { type = "footstep", name = "EMBER STEPS", short = "EMBER" },
	fx_jump_ember = { type = "jump", name = "EMBER BURST", short = "EMBER" },

	-- SEASON 3: WHITEOUT
	trail_s3_frost = { type = "trail", name = "FROST", mat = "trails/plasma", color = Color(170, 230, 255), width = 16 },
	trail_s3_blackice = { type = "trail", name = "BLACK ICE", mat = "trails/laser", color = Color(50, 110, 255), width = 16 },
	trail_s3_candy = { type = "trail", name = "CANDY CANE", mat = "trails/laser", color = Color(255, 40, 40), colors = { Color(255, 40, 40), Color(255, 255, 255) }, blink = 2, width = 16 },
	trail_s3_aurora = { type = "trail", name = "AURORA", mat = "trails/physbeam", color = Color(60, 255, 140), color2 = Color(170, 70, 255), width = 20 },
	trail_s3_pine = { type = "trail", name = "EVERGREEN", mat = "trails/plasma", color = Color(40, 200, 90), width = 16 },
	trail_s3_tinsel = { type = "trail", name = "TINSEL", mat = "trails/physbeam", color = Color(255, 210, 70), colors = { Color(255, 210, 70), Color(220, 230, 255) }, blink = 6, width = 18 },
	trail_s3_garland = { type = "trail", name = "GARLAND", mat = "trails/laser", color = Color(255, 40, 40), colors = { Color(255, 40, 40), Color(60, 255, 90), Color(255, 210, 50), Color(60, 140, 255) }, blink = 3, width = 18 },

	title_s3_frostbite = { type = "title", name = "FROSTBITE", text = "FROSTBITE", color = Color(120, 210, 255), fx = "pulse" },
	title_s3_snowball = { type = "title", name = "SNOWBALL", text = "SNOWBALL", color = Color(230, 240, 255), fx = "static" },
	title_s3_coldstart = { type = "title", name = "COLD START", text = "COLD START", color = Color(170, 230, 255), fx = "pulse" },
	title_s3_blizzard = { type = "title", name = "BLIZZARD", text = "BLIZZARD", color = Color(200, 220, 255), fx = "pulse" },
	title_s3_icebreaker = { type = "title", name = "ICEBREAKER", text = "ICEBREAKER", color = Color(50, 110, 255), fx = "pulse" },
	title_s3_cocoa = { type = "title", name = "HOT COCOA", text = "HOT COCOA", color = Color(200, 120, 60), fx = "pulse" },
	title_s3_krampus = { type = "title", name = "KRAMPUS", text = "KRAMPUS", color = Color(220, 30, 30), fx = "pulse" },
	title_s3_angel = { type = "title", name = "SNOW ANGEL", text = "SNOW ANGEL", color = Color(255, 255, 255), fx = "pulse" },
	title_s3_whiteout = { type = "title", name = "WHITEOUT", text = "WHITEOUT", color = Color(220, 240, 255), fx = "hsv" },
	title_s3_newyear = { type = "title", name = "HAPPY 2027", text = "HAPPY 2027", color = Color(255, 210, 50), fx = "hsv" },
	title_s3_season = { type = "title", name = "S3", text = "S3", color = Color(170, 230, 255), fx = "rainbow" },

	fx_snow = { type = "footstep", name = "SNOW STEPS", short = "SNOW" },
	fx_confetti = { type = "footstep", name = "CONFETTI STEPS", short = "CONFETTI" },
	fx_jump_frost = { type = "jump", name = "FROST BURST", short = "FROST" },
	fx_jump_firework = { type = "jump", name = "FIREWORK", short = "FIREWORK" }
}

local function T(free, premium)
	return { free = free, premium = premium }
end

-- Seasons switch automatically by server time (UTC). The latest season with starts <= now is active.
-- Welcome text of season N is beatrun_battlepass.seasonN.welcome in resource/localization/*/beatrun_battlepass.properties.
-- Cosmetics from previous seasons stay unlocked; XP, tiers, quests and premium reset.
BRBP.Seasons = {
	[2] = {
		name = "SECOND WIND",
		starts = 1794009600, -- 2026-11-07 00:00 UTC
		ends = 1796083200, -- 2026-12-01 00:00 UTC
		tiers = {
			T({ { "xp", 50 } }, { { "xp", 150 }, { "cosmetic", "title_s2_afterburner" } }), -- 1
			T({ { "cosmetic", "title_s2_rooftop" } }, { { "xp", 200 } }), -- 2
			T({ { "xp", 75 } }, { { "cosmetic", "trail_s2_night" } }), -- 3
			T({ { "cosmetic", "trail_s2_undertow" } }, { { "xp", 200 } }), -- 4
			T({ { "xp", 100 } }, { { "boost", 3600 } }), -- 5
			T({ { "cosmetic", "title_s2_onemore" } }, { { "cosmetic", "title_s2_grapple" } }), -- 6
			T({ { "xp", 125 } }, { { "xp", 250 } }), -- 7
			T({ { "cosmetic", "fx_ember" } }, { { "cosmetic", "fx_jump_ember" } }), -- 8
			T({ { "xp", 150 } }, { { "xp", 250 } }), -- 9
			T({ { "cosmetic", "trail_s2_ember" }, { "xp", 200 } }, { { "cosmetic", "title_s2_coyote" }, { "xp", 400 } }), -- 10
			T({ { "cosmetic", "title_s2_pb" } }, { { "boost", 3600 } }), -- 11
			T({ { "xp", 175 } }, { { "xp", 300 } }), -- 12
			T({ { "xp", 200 } }, { { "cosmetic", "trail_s2_livewire" } }), -- 13
			T({ { "xp", 200 } }, { { "xp", 300 } }), -- 14
			T({ { "xp", 250 } }, { { "cosmetic", "title_s2_momentum" } }), -- 15
			T({ { "xp", 250 } }, { { "boost", 7200 } }), -- 16
			T({ { "cosmetic", "title_s2_frame" } }, { { "xp", 400 } }), -- 17
			T({ { "xp", 300 } }, { { "xp", 400 } }), -- 18
			T({ { "cosmetic", "trail_s2_leaf" } }, { { "xp", 450 } }), -- 19
			T({ { "cosmetic", "title_s2_wind" }, { "xp", 400 } }, { { "xp", 600 } }), -- 20
			T({ { "xp", 350 } }, { { "boost", 3600 } }), -- 21
			T({ { "xp", 350 } }, { { "xp", 400 } }), -- 22
			T({ { "cosmetic", "trail_s2_toxic" } }, { { "xp", 450 } }), -- 23
			T({ { "xp", 400 } }, { { "xp", 500 } }), -- 24
			T({ { "cosmetic", "title_s2_skill" } }, { { "xp", 600 } }), -- 25
			T({ { "xp", 500 } }, { { "boost", 7200 } }), -- 26
			T({ { "xp", 500 } }, { { "cosmetic", "trail_s2_sunset" } }), -- 27
			T({ { "xp", 600 } }, { { "xp", 700 } }), -- 28
			T({ { "cosmetic", "title_s2_season" } }, { { "xp", 800 } }), -- 29
			T({ { "cosmetic", "trail_s2_tailwind" }, { "xp", 1000 } }, { { "xp", 1500 }, { "boost", 14400 } }) -- 30
		}
	},
	[3] = {
		name = "WHITEOUT",
		starts = 1796083200, -- 2026-12-01 00:00 UTC
		ends = 1798761600, -- 2027-01-01 00:00 UTC
		tiers = {
			T({ { "xp", 50 } }, { { "xp", 150 }, { "cosmetic", "title_s3_frostbite" } }), -- 1
			T({ { "cosmetic", "title_s3_snowball" } }, { { "xp", 200 } }), -- 2
			T({ { "xp", 75 } }, { { "cosmetic", "trail_s3_blackice" } }), -- 3
			T({ { "cosmetic", "trail_s3_frost" } }, { { "xp", 200 } }), -- 4
			T({ { "xp", 100 } }, { { "boost", 3600 } }), -- 5
			T({ { "cosmetic", "title_s3_coldstart" } }, { { "cosmetic", "title_s3_blizzard" } }), -- 6
			T({ { "xp", 125 } }, { { "xp", 250 } }), -- 7
			T({ { "cosmetic", "fx_snow" } }, { { "cosmetic", "fx_jump_frost" } }), -- 8
			T({ { "xp", 150 } }, { { "xp", 250 } }), -- 9
			T({ { "cosmetic", "trail_s3_candy" }, { "xp", 200 } }, { { "cosmetic", "title_s3_icebreaker" }, { "xp", 400 } }), -- 10
			T({ { "cosmetic", "title_s3_cocoa" } }, { { "boost", 3600 } }), -- 11
			T({ { "xp", 175 } }, { { "xp", 300 } }), -- 12
			T({ { "xp", 200 } }, { { "cosmetic", "trail_s3_aurora" } }), -- 13
			T({ { "xp", 200 } }, { { "xp", 300 } }), -- 14
			T({ { "xp", 250 } }, { { "cosmetic", "title_s3_krampus" } }), -- 15
			T({ { "xp", 250 } }, { { "boost", 7200 } }), -- 16
			T({ { "cosmetic", "title_s3_angel" } }, { { "xp", 400 } }), -- 17
			T({ { "xp", 300 } }, { { "xp", 400 } }), -- 18
			T({ { "cosmetic", "trail_s3_pine" } }, { { "xp", 450 } }), -- 19
			T({ { "cosmetic", "title_s3_whiteout" }, { "xp", 400 } }, { { "xp", 600 } }), -- 20
			T({ { "xp", 350 } }, { { "boost", 3600 } }), -- 21
			T({ { "xp", 350 } }, { { "xp", 400 } }), -- 22
			T({ { "cosmetic", "trail_s3_tinsel" } }, { { "xp", 450 } }), -- 23
			T({ { "xp", 400 } }, { { "xp", 500 } }), -- 24
			T({ { "cosmetic", "title_s3_newyear" } }, { { "xp", 600 } }), -- 25
			T({ { "xp", 500 } }, { { "boost", 7200 } }), -- 26
			T({ { "xp", 500 } }, { { "cosmetic", "trail_s3_garland" } }), -- 27
			T({ { "xp", 600 } }, { { "xp", 700 } }), -- 28
			T({ { "cosmetic", "title_s3_season" } }, { { "xp", 800 } }), -- 29
			T({ { "cosmetic", "fx_jump_firework" }, { "xp", 1000 } }, { { "cosmetic", "fx_confetti" }, { "xp", 1500 }, { "boost", 14400 } }) -- 30
		}
	}
}

for _, season in pairs(BRBP.Seasons) do
	for n = 1, BRBP.Config.BonusTiers do
		season.tiers[BRBP.Config.MaxTier + n] = T({ { "xp", 200 } }, { { "xp", 200 } })
	end
end

BRBP.QuestPool = {
	daily = {
		{ id = "d_vault", event = "vault", goal = 40, xp = 350, icon = "beatrun_bp_icons/bp_vault.png" },
		{ id = "d_wallh", event = "wallrunh", goal = 25, xp = 350, icon = "beatrun_bp_icons/bp_wallrun.png" },
		{ id = "d_wallv", event = "wallrunv", goal = 15, xp = 400, icon = "beatrun_bp_icons/bp_wallrunvertical.png" },
		{ id = "d_slide", event = "slide", goal = 35, xp = 300, icon = "beatrun_bp_icons/bp_slide.png" },
		{ id = "d_roll", event = "roll", goal = 15, xp = 350, icon = "beatrun_bp_icons/bp_safetyroll.png" },
		{ id = "d_coil", event = "coil", goal = 20, xp = 300, icon = "beatrun_bp_icons/bp_coil.png" },
		{ id = "d_play", event = "playtime", goal = 900, xp = 400, icon = "beatrun_bp_icons/bp_playtime.png" },
		{ id = "d_dist", event = "distance", goal = 4000, xp = 400, icon = "beatrun_bp_icons/bp_distance.png" },
		{ id = "d_grapple", event = "grapple", goal = 600, xp = 400, icon = "beatrun_bp_icons/bp_grapple.png" },
		{ id = "d_dive", event = "divestart", goal = 20, xp = 400, icon = "beatrun_bp_icons/bp_dive.png" }
	},
	weekly = {
		{ id = "w_parkour", event = "parkour", goal = 400, xp = 1400, icon = "icons/group.png" },
		{ id = "w_slide", event = "slide", goal = 160, xp = 1400, icon = "beatrun_bp_icons/bp_slide.png" },
		{ id = "w_play", event = "playtime", goal = 5400, xp = 1400, icon = "beatrun_bp_icons/bp_playtime.png" },
		{ id = "w_dist", event = "distance", goal = 25000, xp = 1500, icon = "beatrun_bp_icons/bp_distance.png" },
		{ id = "w_vault", event = "vault", goal = 180, xp = 1300, icon = "beatrun_bp_icons/bp_vault.png" },
		{ id = "w_wall", event = "wallrunh", goal = 120, xp = 1300, icon = "beatrun_bp_icons/bp_wallrun.png" },
		{ id = "w_grapple", event = "grapple", goal = 3500, xp = 1400, icon = "beatrun_bp_icons/bp_grapple.png" },
		{ id = "w_dive", event = "divestart", goal = 90, xp = 1300, icon = "beatrun_bp_icons/bp_dive.png" }
	}
}

BRBP.Config.DailyCount = 4
BRBP.Config.WeeklyCount = 4
