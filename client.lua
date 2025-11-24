-- ══════════════════════════════════════════════════════════
--  INITIALISATION ESX
-- ══════════════════════════════════════════════════════════

ESX = exports['es_extended']:getSharedObject()

-- Variables globales pour le système de blessure
local isDowned = false
local deathTime = 0
local maxDownTime = 60000 -- 60 secondes avant de pouvoir respawn
local canRespawn = false -- Peut respawn après 60 secondes
local forceEnableControls = false -- Force la réactivation des contrôles après respawn
local justRespawned = false -- Protection après respawn pour éviter détection mort immédiate
local autoRespawnDelay = maxDownTime -- Délai avant le respawn automatique (en ms)
local autoRespawnActive = false -- Évite les doublons de demande de respawn

local warzoneCoords = vector3(5366.138, -1110.33875, 354.209473)
local warzoneRadius = 200.0

local function IsInWarzone(coords)
	if not coords then
		return false
	end

	return #(coords - warzoneCoords) <= warzoneRadius
end

local deathUIState = {
        visible = false,
        timeLeft = 0,
        canRespawn = false
}

local function DrawAdvancedText(x, y, scale, text, r, g, b, a, font, center)
        SetTextFont(font or 4)
        SetTextScale(scale, scale)
        SetTextColour(r, g, b, a or 255)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(1, 0, 0, 0, 255)
        SetTextOutline()
        SetTextCentre(center or false)
        SetTextEntry("STRING")
        AddTextComponentString(text)
        DrawText(x, y)
end

local function ShowCustomDeathUI(timeLeft, respawnReady)
        deathUIState.visible = true
        deathUIState.timeLeft = math.max(0, timeLeft or 0)
        deathUIState.canRespawn = respawnReady or false
end

local function HideCustomDeathUI()
        deathUIState.visible = false
end

local function UpdateDeathTimer(timeLeft, respawnReady)
        deathUIState.timeLeft = math.max(0, timeLeft or deathUIState.timeLeft)
        if respawnReady ~= nil then
                deathUIState.canRespawn = respawnReady
        end
end

CreateThread(function()
        while true do
                if deathUIState.visible then
                        Wait(0)

                        local accentR, accentG, accentB = 255, 75, 90
                        local backgroundAlpha = 170

                        DrawRect(0.5, 0.18, 0.26, 0.11, 0, 0, 0, backgroundAlpha)
                        DrawRect(0.5, 0.12, 0.26, 0.005, accentR, accentG, accentB, 210)
                        DrawRect(0.5, 0.24, 0.26, 0.005, 255, 255, 255, 35)

                        DrawAdvancedText(0.5, 0.135, 0.7, "VOUS ÊTES INCONSCIENT", accentR, accentG, accentB, 255, 4, true)

                        local timerText = string.format("Respawn dans %ds", math.floor(deathUIState.timeLeft))
                        if deathUIState.canRespawn then
                                timerText = "Respawn disponible"
                        end
                        DrawAdvancedText(0.5, 0.175, 0.5, timerText, 255, 255, 255, 230, 0, true)

                        local actionText = deathUIState.canRespawn and "Appuyez sur ~r~E~s~ pour revenir en safezone" or "Attendez ou demandez de l'aide"
                        DrawAdvancedText(0.5, 0.215, 0.45, actionText, 210, 210, 210, 255, 0, true)
                else
                        Wait(500)
                end
        end
end)

local function HandleRespawnRequest(coords)
        if autoRespawnActive then
                return
        end

        autoRespawnActive = true

        -- Cacher l'interface de mort
        HideCustomDeathUI()

        -- RÉINITIALISER L'ÉTAT IMMÉDIATEMENT (AVANT TOUT)
        isDowned = false
        canRespawn = false
        justRespawned = true

        -- NOTIFIER LE SCRIPT NO_MELEE QUE LE JOUEUR EST VIVANT
        TriggerEvent('revive:playerRevived')

        -- ACTIVER LE FORÇAGE DES CONTRÔLES
        forceEnableControls = true

        -- Thread pour désactiver le forçage après 10 secondes
        CreateThread(function()
                Wait(10000)
                forceEnableControls = false
        end)

        -- Désactiver la protection après 3 secondes
        CreateThread(function()
                Wait(3000)
                justRespawned = false
        end)

        -- FORCER LA RÉACTIVATION TOTALE DU JOUEUR (CRITIQUE)
        SetPlayerControl(PlayerId(), true, 0)

        -- RÉACTIVER TOUS LES CONTRÔLES IMMÉDIATEMENT
        for i = 0, 350 do
                EnableControlAction(0, i, true)
                EnableControlAction(1, i, true)
                EnableControlAction(2, i, true)
        end

        local playerPed = PlayerPedId()

        -- NETTOYAGE COMPLET
        DetachEntity(playerPed, true, false)
        ClearPedSecondaryTask(playerPed)
        ClearPedTasksImmediately(playerPed)
        FreezeEntityPosition(playerPed, false)
        SetEntityInvincible(playerPed, false)
        SetPlayerInvincible(PlayerId(), false)
        SetEntityCollision(playerPed, true, true)

        -- Notifier le serveur d'arrêter tout carry en cours
        TriggerServerEvent('carry:forceStop')

        -- Demander la téléportation à la safezone
        TriggerServerEvent('revive:getClosestSafezone', coords)
end

RegisterNetEvent('revive:revivePlayer')
AddEventHandler('revive:revivePlayer', function(byOtherPlayer)
	local playerPed = PlayerPedId()
	local coords = GetEntityCoords(playerPed)
	
        -- Cacher l'interface de mort
        HideCustomDeathUI()
	
	-- RÉINITIALISER L'ÉTAT IMMÉDIATEMENT (STOPPE LE THREAD DE CONTRÔLE)
	isDowned = false
	canRespawn = false
	justRespawned = true
	
	-- NOTIFIER LE SCRIPT NO_MELEE QUE LE JOUEUR EST VIVANT
	TriggerEvent('revive:playerRevived')
	
	-- ACTIVER LE FORÇAGE DES CONTRÔLES PENDANT 10 SECONDES
	forceEnableControls = true
	CreateThread(function()
		Wait(10000)
		forceEnableControls = false
	end)
	
	-- Désactiver la protection après 3 secondes
	CreateThread(function()
		Wait(3000)
		justRespawned = false
	end)
	
	-- FORCER LA RÉACTIVATION TOTALE DU JOUEUR (CRITIQUE)
	SetPlayerControl(PlayerId(), true, 0)
	
	-- RÉACTIVER TOUS LES CONTRÔLES IMMÉDIATEMENT (TOUS LES GROUPES)
	for i = 0, 350 do
		EnableControlAction(0, i, true)
		EnableControlAction(1, i, true)
		EnableControlAction(2, i, true)
	end
	
	-- NETTOYER LE CARRY ET TOUT ÉTAT
	DetachEntity(playerPed, true, false)
	ClearPedSecondaryTask(playerPed)
	ClearPedTasksImmediately(playerPed)
	FreezeEntityPosition(playerPed, false)
	SetEntityInvincible(playerPed, false)
	SetPlayerInvincible(PlayerId(), false)
	SetEntityCollision(playerPed, true, true)
	SetEntityVisible(playerPed, true, false)
	
	-- Notifier le serveur d'arrêter le carry
	TriggerServerEvent('carry:forceStop')
	
	-- Notifier la redzone que ce joueur vient d'être réanimé (éviter faux kill)
	TriggerEvent('sd-redzones:client:playerRevived')
	
	-- Si réanimé par un autre joueur, rester sur place
	if byOtherPlayer then
		NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(playerPed), true, false)
		
		Wait(50)
		
		playerPed = PlayerPedId()
		
		-- DOUBLE NETTOYAGE APRÈS RÉSURRECTION
		DetachEntity(playerPed, true, false)
		ClearPedSecondaryTask(playerPed)
		ClearPedTasksImmediately(playerPed)
		FreezeEntityPosition(playerPed, false)
		SetEntityInvincible(playerPed, false)
		SetPlayerInvincible(PlayerId(), false)
		SetEntityCollision(playerPed, true, true)
		SetEntityVisible(playerPed, true, false)
		
		SetEntityHealth(playerPed, 200)
		ClearPedBloodDamage(playerPed)
		
                -- Cacher l'interface de mort une deuxième fois après la résurrection
                HideCustomDeathUI()
		
		-- RÉACTIVER ENCORE UNE FOIS LES CONTRÔLES (TOUS LES GROUPES)
		for i = 0, 350 do
			EnableControlAction(0, i, true)
			EnableControlAction(1, i, true)
			EnableControlAction(2, i, true)
		end
		
		-- Réinitialiser les états d'inventaire pour permettre l'ouverture
		Wait(100)
		exports.ox_inventory:closeInventory()
		LocalPlayer.state:set('invOpen', false, true)
		LocalPlayer.state:set('invBusy', false, true)
		LocalPlayer.state:set('dead', false, true)
		
		TriggerServerEvent('revive:resetInventory')
		TriggerServerEvent('loot:server:removeCorpse')
		
		-- Forcer la synchronisation de l'inventaire après la réanimation
		Wait(300)
		TriggerServerEvent('ox_inventory:refreshInventory')
	else
		-- Commande admin, téléporter à la safezone
		TriggerServerEvent('revive:getClosestSafezone', coords)
	end
end)

-- Event pour recevoir les coordonnées et téléporter
RegisterNetEvent('revive:teleportToSafezone')
AddEventHandler('revive:teleportToSafezone', function(safezoneCoords)
	autoRespawnActive = false
	local playerPed = PlayerPedId()
	
        -- Cacher l'interface de mort
        HideCustomDeathUI()
	
	-- RÉINITIALISER L'ÉTAT TOUT DE SUITE (CRITIQUE)
	isDowned = false
	canRespawn = false
	justRespawned = true
	
	-- NOTIFIER LE SCRIPT NO_MELEE QUE LE JOUEUR EST VIVANT
	TriggerEvent('revive:playerRevived')
	
	-- ACTIVER LE FORÇAGE DES CONTRÔLES PENDANT 10 SECONDES
	forceEnableControls = true
	CreateThread(function()
		Wait(10000)
		forceEnableControls = false
	end)
	
	-- Désactiver la protection après 3 secondes
	CreateThread(function()
		Wait(3000)
		justRespawned = false
	end)
	
	-- FORCER LA RÉACTIVATION TOTALE DU JOUEUR (CRITIQUE)
	SetPlayerControl(PlayerId(), true, 0)
	
	-- RÉACTIVER TOUS LES CONTRÔLES IMMÉDIATEMENT
	for i = 0, 350 do
		EnableControlAction(0, i, true)
		EnableControlAction(1, i, true)
		EnableControlAction(2, i, true)
	end
	
	-- NETTOYAGE TOTAL AVANT RESPAWN
	DetachEntity(playerPed, true, false)
	ClearPedSecondaryTask(playerPed)
	ClearPedTasksImmediately(playerPed)
	FreezeEntityPosition(playerPed, false)
	SetEntityInvincible(playerPed, false)
	SetPlayerInvincible(PlayerId(), false)
	SetEntityCollision(playerPed, true, true)
	
	-- Notifier le serveur d'arrêter le carry
	TriggerServerEvent('carry:forceStop')
	
	-- Fade out
	DoScreenFadeOut(500)
	Wait(500)
	
	-- Téléporter à la safezone
	SetEntityCoordsNoOffset(playerPed, safezoneCoords.x, safezoneCoords.y, safezoneCoords.z, false, false, false)
	NetworkResurrectLocalPlayer(safezoneCoords.x, safezoneCoords.y, safezoneCoords.z, 0.0, true, false)
	
	Wait(200)
	
	playerPed = PlayerPedId()
	
	-- NETTOYAGE COMPLET APRÈS RESPAWN (RÉPÉTÉ PLUSIEURS FOIS)
	for i = 1, 5 do
		DetachEntity(playerPed, true, false)
		ClearPedSecondaryTask(playerPed)
		ClearPedTasksImmediately(playerPed)
		FreezeEntityPosition(playerPed, false)
		SetEntityInvincible(playerPed, false)
		SetPlayerInvincible(PlayerId(), false)
		SetEntityCollision(playerPed, true, true)
		SetEntityVisible(playerPed, true, false)
		
		-- RÉACTIVER TOUS LES CONTRÔLES À CHAQUE ITÉRATION (TOUS LES GROUPES)
		for j = 0, 350 do
			EnableControlAction(0, j, true)
			EnableControlAction(1, j, true)
			EnableControlAction(2, j, true)
		end
		
		Wait(50)
	end
	
	SetEntityHealth(playerPed, 200)
	SetPedArmour(playerPed, 0)
	ClearPedBloodDamage(playerPed)
	
	TriggerEvent('esx_basicneeds:healPlayer')
	
	Wait(500)
	
	TriggerServerEvent('revive:resetInventory')
	TriggerServerEvent('loot:server:removeCorpse')
	
	Wait(100)
	
	exports.ox_inventory:closeInventory()
	
	LocalPlayer.state:set('invOpen', false, true)
	LocalPlayer.state:set('invBusy', false, true)
	LocalPlayer.state:set('dead', false, true)
	
	-- Retirer les armes des mains sans supprimer de l'inventaire
	local playerPed = PlayerPedId()
	SetCurrentPedWeapon(playerPed, GetHashKey("WEAPON_UNARMED"), true)
	
	-- Forcer la synchronisation de l'inventaire après le respawn
	Wait(300)
	TriggerServerEvent('ox_inventory:refreshInventory')
	
	-- Fade in
	DoScreenFadeIn(500)
	
	-- DERNIER NETTOYAGE APRÈS FADE IN
	Wait(500)
	playerPed = PlayerPedId()
	DetachEntity(playerPed, true, false)
	ClearPedTasksImmediately(playerPed)
	FreezeEntityPosition(playerPed, false)
	SetEntityInvincible(playerPed, false)
	SetPlayerInvincible(PlayerId(), false)
	
	-- FORCER LA RÉACTIVATION TOTALE DU JOUEUR (IMPORTANT)
	SetPlayerControl(PlayerId(), true, 0)
	
	-- RÉACTIVER TOUS LES CONTRÔLES UNE DERNIÈRE FOIS (TOUS LES GROUPES)
	for i = 0, 350 do
		EnableControlAction(0, i, true)
		EnableControlAction(1, i, true)
		EnableControlAction(2, i, true)
	end
end)

RegisterNetEvent('revive:healPlayer')
AddEventHandler('revive:healPlayer', function()
	local playerPed = PlayerPedId()
	
	SetEntityHealth(playerPed, 200)
	SetPedArmour(playerPed, 0) -- Pas d'armure au heal (0 au lieu de 100)
	ClearPedBloodDamage(playerPed)
	
	TriggerEvent('esx_basicneeds:healPlayer')
end)

-- ══════════════════════════════════════════════════════════
--  SYSTÈME DE MORT - 0 HP
-- ══════════════════════════════════════════════════════════
--  Le joueur reste vraiment mort (0 HP) jusqu'à ce que :
--  - Un autre joueur le réanime avec /revivep (respawn sur place)
--  - Il appuie sur E après 60 secondes (respawn à la safezone)

-- ══════════════════════════════════════════════════════════
--  COMMANDE POUR RÉANIMER UN JOUEUR PROCHE
-- ══════════════════════════════════════════════════════════

RegisterCommand('revivep', function()
	local playerPed = PlayerPedId()
	local myCoords = GetEntityCoords(playerPed)
	local allPlayers = GetActivePlayers()
	
	local closestPlayer = nil
	local closestDistance = 3.0 -- Maximum 3 mètres
	
	-- Chercher le joueur mort le plus proche
	for _, player in ipairs(allPlayers) do
		if player ~= PlayerId() then
			local targetPed = GetPlayerPed(player)
			local targetCoords = GetEntityCoords(targetPed)
			local distance = #(myCoords - targetCoords)
			
			-- Vérifier si mort (vraiment mort = IsEntityDead ou health très bas)
			local isDead = IsEntityDead(targetPed) or GetEntityHealth(targetPed) <= 105
			
			if isDead and distance < closestDistance then
				closestDistance = distance
				closestPlayer = {
					playerId = player,
					serverId = GetPlayerServerId(player),
					ped = targetPed
				}
			end
		end
	end
	
	if closestPlayer then
		-- Animation de réanimation
		RequestAnimDict("mini@cpr@char_a@cpr_str")
		while not HasAnimDictLoaded("mini@cpr@char_a@cpr_str") do
			Wait(100)
		end
		
		-- Boucle d'animation pendant 10 secondes
		local reviveTime = 0
		local reviveDuration = 10000
		
		while reviveTime < reviveDuration do
			Wait(0)
			reviveTime = reviveTime + 16 -- ~60 FPS
			
			-- Désactiver les contrôles (mouvement + attaques + caméra)
			DisableControlAction(0, 30, true)
			DisableControlAction(0, 31, true)
			DisableControlAction(0, 32, true)
			DisableControlAction(0, 33, true)
			DisableControlAction(0, 34, true)
			DisableControlAction(0, 35, true)
			DisableControlAction(0, 21, true)
			DisableControlAction(0, 22, true)
			DisableControlAction(0, 24, true) -- Attack
			DisableControlAction(0, 25, true) -- Aim
			DisableControlAction(0, 47, true) -- Detonate
			DisableControlAction(0, 58, true) -- Melee Attack
			DisableControlAction(0, 263, true) -- Melee Attack 1
			DisableControlAction(0, 264, true) -- Melee Attack 2
			DisableControlAction(0, 257, true) -- Attack 2
			DisableControlAction(0, 140, true) -- Melee Attack Light
			DisableControlAction(0, 141, true) -- Melee Attack Heavy
			DisableControlAction(0, 142, true) -- Melee Attack Alternate
			DisableControlAction(0, 143, true) -- Melee Block
			DisableControlAction(0, 37, true) -- Weapon Wheel
			DisableControlAction(0, 45, true) -- Reload
			
			-- BLOQUER LA CAMÉRA
			DisableControlAction(0, 1, true) -- Camera LR (souris X)
			DisableControlAction(0, 2, true) -- Camera UD (souris Y)
			DisableControlAction(0, 3, true) -- Camera Zoom In
			DisableControlAction(0, 4, true) -- Camera Zoom Out
			DisableControlAction(0, 5, true) -- Camera Zoom In Secondary
			DisableControlAction(0, 6, true) -- Camera Zoom Out Secondary
			DisableControlAction(1, 1, true) -- Camera LR
			DisableControlAction(1, 2, true) -- Camera UD
			DisableControlAction(2, 1, true) -- Camera LR
			DisableControlAction(2, 2, true) -- Camera UD
			
			-- Maintenir l'animation
			if not IsEntityPlayingAnim(playerPed, "mini@cpr@char_a@cpr_str", "cpr_pumpchest", 3) then
				TaskPlayAnim(playerPed, "mini@cpr@char_a@cpr_str", "cpr_pumpchest", 8.0, -8.0, -1, 1, 0, false, false, false)
			end
			
			-- Afficher la progression
			local percent = math.floor((reviveTime / reviveDuration) * 100)
			
			SetTextFont(4)
			SetTextScale(0.5, 0.5)
			SetTextColour(0, 255, 0, 255)
			SetTextDropshadow(0, 0, 0, 0, 255)
			SetTextEdge(1, 0, 0, 0, 255)
			SetTextOutline()
			SetTextCentre(true)
			SetTextEntry("STRING")
			AddTextComponentString("⚕️ ~r~ Réanimation en cours... ~w~" .. percent .. "%")
			DrawText(0.5, 0.85)
		end
		
		ClearPedTasks(playerPed)
		
		-- Notifier le serveur
		TriggerServerEvent('revive:reviveOtherPlayer', closestPlayer.serverId)
	end
end, false)

-- Suggestion de commande
TriggerEvent('chat:addSuggestion', '/revivep', 'Réanimer le joueur blessé le plus proche (max 3m)')


-- Thread principal de gestion de la mort
CreateThread(function()
	while true do
		Wait(100)
		
		local playerPed = PlayerPedId()
		
		-- Vérifier si le joueur est dans une arena PVP
		local inArena = false
		if GetResourceState('pvp_arenas') == 'started' then
			inArena = exports['pvp_arenas']:IsInArena()
		end
		
		-- NE PAS DÉTECTER LA MORT SI LE JOUEUR VIENT JUSTE DE RESPAWN OU EST DANS UNE ARENA
		if IsEntityDead(playerPed) and not isDowned and not justRespawned and not inArena then
			isDowned = true
			deathTime = GetGameTimer()
			canRespawn = false
			
			-- NOTIFIER LE SCRIPT NO_MELEE QUE LE JOUEUR EST MORT
			TriggerEvent('revive:playerDied')
			
			-- Sauvegarder la position de mort
			local deathCoords = GetEntityCoords(playerPed)
			
			-- Notifier le serveur pour le loot
			TriggerServerEvent('loot:server:registerDeath', deathCoords)
			
                        -- Afficher l'interface de mort modernisée
                        local timeLeft = math.ceil((maxDownTime - (GetGameTimer() - deathTime)) / 1000)
                        print('[REVIVE] Mort détectée, affichage interface personnalisée. TimeLeft:', timeLeft)

                        ShowCustomDeathUI(timeLeft, false)

			if not IsInWarzone(deathCoords) then
				CreateThread(function()
					local expectedDeathTime = deathTime
					Wait(autoRespawnDelay)

					-- Si le joueur est toujours downed et qu'on n'a pas été réanimé entre-temps
					if isDowned and deathTime == expectedDeathTime and not autoRespawnActive then
						HandleRespawnRequest(deathCoords)
					end
				end)
			else
				print('[REVIVE] Mort détectée en zone Warzone - respawn automatique ignoré.')
			end
		end
	end
end)

-- Thread de contrôle (MORT RÉEL - 0 HP) - VERSION OPTIMISÉE
CreateThread(function()
	while true do
		-- SI FORÇAGE ACTIF, TOUJOURS RÉACTIVER LES CONTRÔLES
		if forceEnableControls then
			Wait(0) -- Réactif pendant le forçage
                        -- Cacher l'interface de mort si le joueur vient d'être réanimé
                        if justRespawned then
                                HideCustomDeathUI()
                        end
			for i = 0, 350 do
				EnableControlAction(0, i, true)
				EnableControlAction(1, i, true)
				EnableControlAction(2, i, true)
			end
		elseif isDowned and not justRespawned then
			Wait(0) -- Réactif quand mort pour les contrôles
			
			local playerPed = PlayerPedId()
			
			-- Calculer le temps restant
			local timeLeft = math.ceil((maxDownTime - (GetGameTimer() - deathTime)) / 1000)
			
			-- Vérifier si 60 secondes sont écoulées
			if GetGameTimer() - deathTime >= maxDownTime then
				canRespawn = true
			end
			
			-- DÉSACTIVER TOUS LES CONTRÔLES SAUF E si on peut respawn
			if canRespawn then
				DisableAllControlActions(0)
				EnableControlAction(0, 38, true) -- Activer E
			else
				DisableAllControlActions(0)
			end
			
                        -- Afficher l'interface moderne
                        if not canRespawn then
                                ShowCustomDeathUI(timeLeft, false)
                                UpdateDeathTimer(timeLeft, false)
                        else
                                UpdateDeathTimer(0, true)
                        end
			
			-- Si le joueur peut respawn et appuie sur E
			if canRespawn and IsControlJustPressed(0, 38) then -- E
				local coords = GetEntityCoords(playerPed)
				HandleRespawnRequest(coords)
			end
		else
			-- PAS MORT : Attendre plus longtemps (optimisation)
			Wait(500)
			
			-- Réactiver tous les contrôles si pas mort
			local playerPed = PlayerPedId()
			if not IsEntityDead(playerPed) then
				for i = 0, 350 do
					EnableControlAction(0, i, true)
					EnableControlAction(1, i, true)
					EnableControlAction(2, i, true)
				end
			end
		end
	end
end)
