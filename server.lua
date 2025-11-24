ESX = exports['es_extended']:getSharedObject()

-- Safezones (casino par défaut pour spawn)
local safezones = {
	casino = vector3(883.7473, -41.2722, 78.1572),      -- Casino (SAFEZONE1)
	hopital = vector3(-1528.9363, -435.9113, 35.4374),  -- Hôpital (SAFEZONE2)
	sandy = vector3(1730.3627, 3314.2917, 41.2235),     -- Sandy (SAFEZONE3)
	paleto = vector3(1457.2135, 6552.5176, 14.5812)      -- Paleto (SAFEZONE4)
}

-- Fonction pour trouver la safezone la plus proche
function GetClosestSafezone(coords)
	local closestZone = safezones.casino
	local closestDistance = #(coords - safezones.casino)
	
	for name, zoneCoords in pairs(safezones) do
		local distance = #(coords - zoneCoords)
		if distance < closestDistance then
			closestDistance = distance
			closestZone = zoneCoords
		end
	end
	
	return closestZone
end

RegisterServerEvent('revive:resetInventory')
AddEventHandler('revive:resetInventory', function()
	local source = source
	local xPlayer = ESX.GetPlayerFromId(source)
	
	if not xPlayer then return end
	
	Player(source).state:set('invOpen', false, true)
	Player(source).state:set('invBusy', false, true)
	Player(source).state:set('dead', false, true)
	
	Wait(100)
	
	TriggerClientEvent('ox_inventory:closeInventory', source)
end)

-- Event pour forcer le refresh de l'inventaire après respawn
RegisterServerEvent('ox_inventory:refreshInventory')
AddEventHandler('ox_inventory:refreshInventory', function()
	local source = source
	local xPlayer = ESX.GetPlayerFromId(source)
	
	if not xPlayer then return end
	
	-- Forcer la synchronisation de l'inventaire via ESX
	Wait(200)
	xPlayer.syncInventory()
end)

-- Event pour demander la safezone la plus proche
RegisterServerEvent('revive:getClosestSafezone')
AddEventHandler('revive:getClosestSafezone', function(playerCoords)
	local source = source
	
	-- NOTIFIER TOUS LES CLIENTS que ce joueur respawn (éviter faux kills)
	TriggerClientEvent('sd-redzones:client:globalPlayerRevived', -1, source)
	-- Notifier le serveur aussi
	TriggerEvent('sd-redzones:server:playerRevived', source)
	
	local closestSafezone = GetClosestSafezone(playerCoords)
	TriggerClientEvent('revive:teleportToSafezone', source, closestSafezone)
end)

-- Event pour réanimer un autre joueur
RegisterNetEvent('revive:reviveOtherPlayer')
AddEventHandler('revive:reviveOtherPlayer', function(targetId)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
	local xTarget = ESX.GetPlayerFromId(targetId)
	
	if not xPlayer or not xTarget then return end
	
	-- Vérifier la distance
	local playerCoords = GetEntityCoords(GetPlayerPed(src))
	local targetCoords = GetEntityCoords(GetPlayerPed(targetId))
	local distance = #(playerCoords - targetCoords)
	
	if distance > 3.0 then
		return
	end
	
	-- NOTIFIER TOUS LES CLIENTS que ce joueur est réanimé (éviter faux kills)
	TriggerClientEvent('sd-redzones:client:globalPlayerRevived', -1, targetId)
	-- Notifier le serveur aussi
	TriggerEvent('sd-redzones:server:playerRevived', targetId)
	
	-- Réanimer le joueur à sa position actuelle
	TriggerClientEvent('revive:revivePlayer', targetId, true)
	
	-- Log webhook
	if exports['discord_logs'] then
		exports['discord_logs']:LogRevive(
			xPlayer.getName(),
			xTarget.getName(),
			"Réanimé par joueur",
			string.format("Position: %.2f, %.2f, %.2f", targetCoords.x, targetCoords.y, targetCoords.z)
		)
	end
end)

RegisterCommand('revive', function(source, args, rawCommand)
	local xPlayer = ESX.GetPlayerFromId(source)
	
	if source == 0 then
		return
	end
	
	-- VÉRIFICATION ADMIN
	if xPlayer.getGroup() ~= 'admin' and xPlayer.getGroup() ~= 'superadmin' then
		return
	end

	if args[1] then
		local targetId = tonumber(args[1])
		local xTarget = ESX.GetPlayerFromId(targetId)
		
		if xTarget then
			-- NOTIFIER TOUS LES CLIENTS que ce joueur est réanimé (éviter faux kills)
			TriggerClientEvent('sd-redzones:client:globalPlayerRevived', -1, targetId)
			-- Notifier le serveur aussi
			TriggerEvent('sd-redzones:server:playerRevived', targetId)
			
			TriggerClientEvent('revive:revivePlayer', targetId, false)
			
			if exports['discord_logs'] then
				exports['discord_logs']:LogRevive(
					xPlayer.getName(),
					xTarget.getName(),
					"Revive ADMIN",
					"Commande admin"
				)
			end
		end
	else
		-- NOTIFIER TOUS LES CLIENTS que ce joueur est réanimé (éviter faux kills)
		TriggerClientEvent('sd-redzones:client:globalPlayerRevived', -1, source)
		-- Notifier le serveur aussi
		TriggerEvent('sd-redzones:server:playerRevived', source)
		
		TriggerClientEvent('revive:revivePlayer', source, false)
		
		if exports['discord_logs'] then
			exports['discord_logs']:LogRevive(
				xPlayer.getName(),
				xPlayer.getName(),
				"Auto-revive ADMIN",
				"Commande admin self"
			)
		end
	end
end, false)

RegisterCommand('heal', function(source, args, rawCommand)
	local xPlayer = ESX.GetPlayerFromId(source)
	
	if source == 0 then
		return
	end
	
	-- VÉRIFICATION ADMIN
	if xPlayer.getGroup() ~= 'admin' and xPlayer.getGroup() ~= 'superadmin' then
		return
	end

	if args[1] then
		local targetId = tonumber(args[1])
		local xTarget = ESX.GetPlayerFromId(targetId)
		
		if xTarget then
			TriggerClientEvent('revive:healPlayer', targetId)
			
			if exports['discord_logs'] then
				exports['discord_logs']:LogRevive(
					xPlayer.getName(),
					xTarget.getName(),
					"Heal ADMIN",
					"Commande admin heal"
				)
			end
		end
	else
		TriggerClientEvent('revive:healPlayer', source)
	end
end, false)
