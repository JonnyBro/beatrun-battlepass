BRBP = BRBP or {}

local root = "battlepass/"

local function includeFile(fileName)
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

includeFile("sh_config.lua")
includeFile("sh_shared.lua")
includeFile("sv_core.lua")
includeFile("sv_protect.lua")
includeFile("sv_ulx.lua")
includeFile("cl_cosmetics.lua")
includeFile("cl_ui.lua")
