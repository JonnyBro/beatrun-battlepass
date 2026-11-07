BRBP = BRBP or {}

local root = "battlepass/"

local function IncludeFile(fileName)
	local fullPath = root .. fileName
	local prefix = string.Left(string.lower(fileName), 3)

	if prefix == "sh_" then
		AddCSLuaFile(fullPath)
		include(fullPath)
	elseif prefix == "cl_" then
		AddCSLuaFile(fullPath)
		if CLIENT then include(fullPath) end
	elseif prefix == "sv_" then
		if SERVER then include(fullPath) end
	end
end

IncludeFile("sh_config.lua")
IncludeFile("sh_shared.lua")
IncludeFile("sv_core.lua")
IncludeFile("sv_protect.lua")
IncludeFile("sv_ulx.lua")
IncludeFile("cl_cosmetics.lua")
IncludeFile("cl_ui.lua")
