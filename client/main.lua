ESX = exports["es_extended"]:getSharedObject()

Citizen.CreateThread(function()
	Citizen.CreateThread(function()
		while not NetworkIsSessionStarted() do
			Citizen.Wait(0)
		end

		exports.spawnmanager:setAutoSpawn(false)

		while GetResourceState('esx_menu_default') ~= 'started' do
			Citizen.Wait(0)
		end

		DoScreenFadeOut(0)
		TriggerEvent("esx_multicharacter:SetupCharacters")
	end)

	local canRelog, cam, cam2, spawned = false, nil, nil, nil
	local selectedSlot, maxSlots = nil, Config.Slots or 4
	local Characters = {}
	local isChoosing = false
	local uiReady = false
	local hidePlayers = false
	local hideLoopRunning = false

	local function SerializeCharactersForNui(characters, slots)
		local serialized = {}
		for i = 1, slots do
			if characters[i] then
				serialized[i] = characters[i]
			end
		end
		return serialized
	end

	local function SetupSkyCamera()
		local sky = Config.SkyCam
		cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", sky.x, sky.y, sky.z, 300.0, 0.0, 0.0, sky.w, false, 0)
		SetCamActive(cam, true)
		RenderScriptCams(true, false, 1, true, true)
	end

	local function DestroyCameras()
		if cam then
			SetCamActive(cam, false)
			DestroyCam(cam, true)
			cam = nil
		end
		if cam2 then
			SetCamActive(cam2, false)
			DestroyCam(cam2, true)
			cam2 = nil
		end
		RenderScriptCams(false, true, 500, true, true)
	end

	local function ToCoords(vec)
		return {
			x = vec.x,
			y = vec.y,
			z = vec.z,
			heading = vec.w,
			w = vec.w
		}
	end

	local function SetPlayerAt(vec)
		local playerPed = PlayerPedId()
		SetEntityCoordsNoOffset(playerPed, vec.x, vec.y, vec.z, false, false, false, true)
		SetEntityHeading(playerPed, vec.w)
	end

	local function SetupSkinCreatorCamera()
		local creator = Config.SkinCreator
		local playerPed = PlayerPedId()
		local offset = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 1.2, 0.6)

		if cam then
			SetCamActive(cam, false)
			DestroyCam(cam, true)
			cam = nil
		end

		cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", offset.x, offset.y, offset.z, 0.0, 0.0, 0.0, 50.0, false, 0)
		PointCamAtCoord(cam, creator.x, creator.y, creator.z + 0.6)
		SetCamActive(cam, true)
		RenderScriptCams(true, false, 1, true, true)
	end

	local function WaitForWorldAtCoords(x, y, z)
		local playerPed = PlayerPedId()
		RequestCollisionAtCoord(x, y, z)
		SetFocusPosAndVel(x, y, z, 0.0, 0.0, 0.0)

		local timeout = GetGameTimer() + 15000
		while not HasCollisionLoadedAroundEntity(playerPed) and GetGameTimer() < timeout do
			RequestCollisionAtCoord(x, y, z)
			Citizen.Wait(0)
		end

		NewLoadSceneStart(x, y, z, x, y, z, 80.0, 0)
		timeout = GetGameTimer() + 10000
		while IsNetworkLoadingScene() and GetGameTimer() < timeout do
			Citizen.Wait(0)
		end
		NewLoadSceneStop()

		SetEntityCoordsNoOffset(playerPed, x, y, z, false, false, false, true)
		Citizen.Wait(500)
	end

	local function RestorePlayerState()
		hidePlayers = false

		local playerId = PlayerId()
		local playerPed = PlayerPedId()

		MumbleSetVolumeOverride(playerId, -1.0)
		SetEntityVisible(playerPed, true, false)
		SetPlayerInvincible(playerId, false)
		SetEntityInvincible(playerPed, false)
		SetEntityCollision(playerPed, true, true)
		SetPedCanRagdoll(playerPed, true)
		FreezeEntityPosition(playerPed, false)
		SetPlayerControl(playerId, true, 0)
		ClearFocus()

		for _, player in ipairs(GetActivePlayers()) do
			if player ~= playerId then
				NetworkConcealPlayer(player, false, false)
			end
		end
	end

	local function PlaySpawnCamera(spawn)
		local pos = {
			x = spawn.x or spawn[1] or Config.Spawn.x,
			y = spawn.y or spawn[2] or Config.Spawn.y,
			z = spawn.z or spawn[3] or Config.Spawn.z
		}
		local heading = spawn.heading or spawn.w or Config.Spawn.w
		local playerPed = PlayerPedId()

		RestorePlayerState()
		playerPed = PlayerPedId()
		SetEntityVisible(playerPed, true, false)
		FreezeEntityPosition(playerPed, true)
		SetEntityCoordsNoOffset(playerPed, pos.x, pos.y, pos.z, false, false, false, true)
		SetEntityHeading(playerPed, heading)

		WaitForWorldAtCoords(pos.x, pos.y, pos.z)
		SetEntityCollision(playerPed, true, true)

		DestroyCameras()
		SetupSkyCamera()
		RenderScriptCams(true, false, 0, true, true)

		DoScreenFadeIn(500)
		Citizen.Wait(500)

		local sky = Config.SkyCam
		cam2 = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", sky.x, sky.y, sky.z, 300.0, 0.0, 0.0, sky.w, false, 0)
		PointCamAtCoord(cam2, pos.x, pos.y, pos.z + 200.0)
		SetCamActiveWithInterp(cam2, cam, 900, true, true)
		Citizen.Wait(900)

		cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", pos.x, pos.y, pos.z + 200.0, 300.0, 0.0, 0.0, sky.w, false, 0)
		PointCamAtCoord(cam, pos.x, pos.y, pos.z + 2.0)
		SetCamActiveWithInterp(cam, cam2, 3700, true, true)
		Citizen.Wait(3700)

		PlaySoundFrontend(-1, "Zoom_Out", "DLC_HEIST_PLANNING_BOARD_SOUNDS", 1)
		RenderScriptCams(false, true, 500, true, true)
		PlaySoundFrontend(-1, "CAR_BIKE_WHOOSH", "MP_LOBBY_SOUNDS", 1)

		Citizen.Wait(500)

		if cam2 then
			DestroyCam(cam2, true)
			cam2 = nil
		end
		if cam then
			SetCamActive(cam, false)
			DestroyCam(cam, true)
			cam = nil
		end
	end

	local function ShowCharacterUI()
		if uiReady then
			return
		end

		uiReady = true
		SetNuiFocus(true, true)
		SendNUIMessage({
			action = "setupui",
			characters = SerializeCharactersForNui(Characters, maxSlots),
			slots = maxSlots,
			canDelete = Config.CanDelete,
			show = true
		})
	end

	Citizen.CreateThread(function()
		while true do
			if isChoosing then
				DisplayHud(false)
				DisplayRadar(false)
			end
			Citizen.Wait(0)
		end
	end)

	RegisterNetEvent('esx_multicharacter:SetupCharacters')
	AddEventHandler('esx_multicharacter:SetupCharacters', function()
		ESX.PlayerLoaded = false
		ESX.PlayerData = {}
		spawned = false
		canRelog = false
		isChoosing = true
		uiReady = false

		DoScreenFadeOut(0)
		while not IsScreenFadedOut() do
			Citizen.Wait(10)
		end

		SetNuiFocus(false, false)
		SendNUIMessage({ action = "closeui" })

		ClearTimecycleModifier()
		SetTimecycleModifier('hud_def_blur')

		local playerPed = PlayerPedId()
		FreezeEntityPosition(playerPed, true)
		SetEntityCollision(playerPed, false, false)
		SetEntityInvincible(playerPed, true)
		SetPedCanRagdoll(playerPed, false)
		SetEntityVisible(playerPed, false, false)
		SetEntityCoords(playerPed, Config.HiddenCoords.x, Config.HiddenCoords.y, Config.HiddenCoords.z, false, false, false, false)

		DestroyCameras()
		SetupSkyCamera()

		ESX.UI.Menu.CloseAll()
		hidePlayers = false
		hideLoopRunning = false
		Citizen.Wait(100)
		StartLoop()
		TriggerServerEvent("esx_multicharacter:SetupCharacters")
	end)

	StartLoop = function()
		if hideLoopRunning then
			return
		end

		hideLoopRunning = true
		hidePlayers = true
		MumbleSetVolumeOverride(PlayerId(), 0.0)
		Citizen.CreateThread(function()
			local keys = {18, 19, 21, 27, 61, 131, 172, 173, 155, 174, 175, 176, 177, 187, 188, 191, 201, 209, 254, 340, 352, 108, 109}
			while hidePlayers do
				DisableAllControlActions(0)
				for i = 1, #keys do
					EnableControlAction(0, keys[i], true)
				end
				SetEntityVisible(PlayerPedId(), false, false)
				SetLocalPlayerVisibleLocally(1)
				SetPlayerInvincible(PlayerId(), 1)
				ThefeedHideThisFrame()
				HideHudComponentThisFrame(11)
				HideHudComponentThisFrame(12)
				HideHudComponentThisFrame(21)
				HideHudAndRadarThisFrame()
				Citizen.Wait(0)
				local vehicles = GetGamePool('CVehicle')
				for i = 1, #vehicles do
					SetEntityLocallyInvisible(vehicles[i])
				end
			end
			hideLoopRunning = false
		end)
		Citizen.CreateThread(function()
			while hidePlayers do
				local playerId = PlayerId()
				for _, player in ipairs(GetActivePlayers()) do
					if player ~= playerId then
						NetworkConcealPlayer(player, true, true)
					end
				end
				Citizen.Wait(0)
			end
		end)
	end

	RegisterNetEvent('esx_multicharacter:SetupUI')
	AddEventHandler('esx_multicharacter:SetupUI', function(data, slots)
		Characters = data or {}
		maxSlots = math.max(tonumber(slots) or Config.Slots or 4, Config.Slots or 4)
		spawned = false
		uiReady = false

		for _, v in pairs(Characters) do
			if not v.model and v.skin then
				if v.skin.model then
					v.model = v.skin.model
				elseif v.skin.sex == 1 then
					v.model = `mp_f_freemode_01`
				else
					v.model = `mp_m_freemode_01`
				end
			end
		end

		Citizen.CreateThread(function()
			local sky = Config.SkyCam

			if not cam or not IsCamActive(cam) then
				DestroyCameras()
				SetupSkyCamera()
			end

			WaitForWorldAtCoords(sky.x, sky.y, sky.z)

			ClearTimecycleModifier()
			SetTimecycleModifier('hud_def_blur')

			ShutdownLoadingScreen()
			ShutdownLoadingScreenNui()
			TriggerEvent('esx:loadingScreenOff')

			DoScreenFadeIn(800)
			while not IsScreenFadedIn() do
				Citizen.Wait(10)
			end

			Citizen.Wait(400)
			ShowCharacterUI()
		end)
	end)

	RegisterNUICallback('selectCharacter', function(data, cb)
		local slot = tonumber(data.slot)
		if not slot or slot < 1 or slot > maxSlots then
			return cb({})
		end
		selectedSlot = slot
		cb({})
	end)

	RegisterNUICallback('playCharacter', function(data, cb)
		local slot = tonumber(data.slot) or selectedSlot
		if not slot or not Characters[slot] then
			return cb({})
		end
		if Characters[slot].disabled then
			return cb({})
		end

		selectedSlot = slot
		spawned = slot
		SetNuiFocus(false, false)
		SendNUIMessage({ action = "closeui" })

		DoScreenFadeOut(500)
		while not IsScreenFadedOut() do
			Citizen.Wait(10)
		end

		TriggerServerEvent('esx_multicharacter:CharacterChosen', slot, false)
		cb({})
	end)

	RegisterNUICallback('createCharacter', function(data, cb)
		local slot = tonumber(data.slot) or selectedSlot
		if not slot or Characters[slot] then
			return cb({})
		end

		selectedSlot = slot
		spawned = slot
		SetNuiFocus(false, false)
		SendNUIMessage({ action = "closeui" })

		DoScreenFadeOut(500)
		while not IsScreenFadedOut() do
			Citizen.Wait(10)
		end

		TriggerServerEvent('esx_multicharacter:CharacterChosen', slot, true)
		DoScreenFadeIn(500)
		Citizen.Wait(300)
		TriggerEvent('esx_identity:showRegisterIdentity')
		cb({})
	end)

	RegisterNUICallback('deleteCharacter', function(data, cb)
		local slot = tonumber(data.slot) or selectedSlot
		if not Config.CanDelete or not slot or not Characters[slot] then
			return cb('error')
		end

		selectedSlot = slot
		Characters[slot] = nil
		TriggerServerEvent('esx_multicharacter:DeleteCharacter', slot)
		cb('ok')
	end)

	RegisterNetEvent('esx:playerLoaded')
	AddEventHandler('esx:playerLoaded', function(playerData, isNew, skin)
		ClearTimecycleModifier()
		SetTimecycleModifier('default')

		if isNew or not skin or (type(skin) == 'table' and not next(skin)) then
			local sex = skin and skin.sex or 0
			local model = sex == 0 and `mp_m_freemode_01` or `mp_f_freemode_01`
			RequestModel(model)
			while not HasModelLoaded(model) do
				Citizen.Wait(0)
			end
			SetPlayerModel(PlayerId(), model)
			SetModelAsNoLongerNeeded(model)
			skin = Config.Default
			skin.sex = sex
		end

		local playerPed = PlayerPedId()
		FreezeEntityPosition(playerPed, true)
		SetEntityVisible(playerPed, true, false)

		if isNew then
			DoScreenFadeIn(500)
			Citizen.Wait(300)

			SetPlayerAt(Config.SkinCreator)
			TriggerEvent('skinchanger:loadSkin', skin)
			SetupSkinCreatorCamera()

			local finished = false
			TriggerEvent('skinchanger:loadSkin', skin, function()
				SetPedAoBlobRendering(PlayerPedId(), true)
				ResetEntityAlpha(PlayerPedId())
				TriggerEvent('esx_skin:openSaveableMenu', function()
					finished = true
				end, function()
					finished = true
				end)
			end)
			repeat Citizen.Wait(200) until finished

			DoScreenFadeOut(500)
			while not IsScreenFadedOut() do
				Citizen.Wait(10)
			end

			PlaySpawnCamera(ToCoords(Config.Spawn))
		else
			local spawn = playerData.coords or ToCoords(Config.Spawn)
			if type(spawn) == 'string' then
				spawn = json.decode(spawn) or ToCoords(Config.Spawn)
			end
			if not spawn.x and not spawn[1] then
				spawn = ToCoords(Config.Spawn)
			end

			local selectedCharacterSkin = spawned and Characters[spawned] and Characters[spawned].skin or nil
			TriggerEvent('skinchanger:loadSkin', skin or selectedCharacterSkin)
			playerPed = PlayerPedId()

			DoScreenFadeOut(500)
			while not IsScreenFadedOut() do
				Citizen.Wait(10)
			end

			PlaySpawnCamera(spawn)
		end

		isChoosing = false
		DisplayHud(true)
		DisplayRadar(true)
		RestorePlayerState()

		TriggerServerEvent('esx:onPlayerSpawn')
		TriggerEvent('esx:onPlayerSpawn')
		TriggerEvent('playerSpawned')
		TriggerEvent('esx:restoreLoadout')
		SetNuiFocus(false, false)
		SendNUIMessage({ action = "closeui" })
		Characters = {}
		canRelog = true
		uiReady = false
	end)

	RegisterNetEvent('esx:onPlayerLogout')
	AddEventHandler('esx:onPlayerLogout', function()
		DoScreenFadeOut(10)
		while not IsScreenFadedOut() do
			Citizen.Wait(10)
		end
		spawned = false
		canRelog = false
		hideLoopRunning = false
		RestorePlayerState()
		TriggerEvent("esx_multicharacter:SetupCharacters")
		TriggerEvent('esx_skin:resetFirstSpawn')
	end)

	RegisterCommand('relog', function()
		if not canRelog then
			return ESX.ShowNotification('Bitte warte einen Moment...')
		end

		canRelog = false
		TriggerServerEvent('esx_multicharacter:relog')
		SetTimeout(5000, function()
			canRelog = true
		end)
	end, false)

	TriggerEvent('chat:addSuggestion', '/relog', 'Zurück zur Charakterauswahl wechseln')
end)
