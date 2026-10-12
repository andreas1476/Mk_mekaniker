local function notify(description, type)
    lib.notify({ title = 'Mekaniker', description = description, type = type or 'inform' })
end

local function getClosestServerId()
    local playerId = lib.getClosestPlayer(GetEntityCoords(cache.ped), Config.InteractDistance, false)
    return playerId and GetPlayerServerId(playerId) or nil
end

local function result(ok, msg)
    notify(msg, ok and 'success' or 'error')
end

local function getPlayerJob()
    local ok, playerData = pcall(function()
        return exports.qbx_core:GetPlayerData()
    end)
    if not ok or type(playerData) ~= 'table' then return nil end
    return playerData and playerData.job
end

local function isBossClient()
    local job = getPlayerJob()
    return job and job.name == Config.Job and job.isboss
end

-- Kunden accepterer / afviser faktura
lib.callback.register('mk_mekaniker:confirmInvoice', function(senderName, amount, reason)
    local choice = lib.alertDialog({
        header = 'Faktura fra mekaniker',
        content = ('**Fra:** %s  \n**Beløb:** %s kr.  \n**Beskrivelse:** %s'):format(senderName, amount, reason),
        centered = true,
        cancel = true,
        labels = { confirm = 'Betal', cancel = 'Afvis' },
    })
    return choice == 'confirm'
end)

-- Lav faktura
local function createInvoice()
    local target = getClosestServerId()
    if not target then return notify('Ingen spiller i nærheden.', 'error') end

    local input = lib.inputDialog('Ny faktura', {
        { type = 'number', label = 'Beløb (kr.)', required = true, min = Config.Invoice.minAmount, max = Config.Invoice.maxAmount },
        { type = 'input', label = 'Beskrivelse', required = true, max = 200 },
    })
    if not input then return end

    local ok, msg = lib.callback.await('mk_mekaniker:invoice', false, target, input[1], input[2])
    result(ok, msg)
end

local function tabletCallback(name, ...)
    local ok, data = pcall(lib.callback.await, name, false, ...)
    if not ok then
        notify('Kunne ikke hente tabletdata.', 'error')
        return nil
    end
    return data
end

local function openTablet()
    local job = getPlayerJob()
    if not job or job.name ~= Config.Job then return notify('Du er ikke mekaniker.', 'error') end

    local data = tabletCallback('mk_mekaniker:getTabletData')
    if not data then return end

    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end

local function closeTablet()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb)
    closeTablet()
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    local data = tabletCallback('mk_mekaniker:getTabletData')
    cb({ ok = data ~= nil, data = data })
end)

RegisterNUICallback('hire', function(payload, cb)
    local target = getClosestServerId()
    if not target then
        cb({ ok = false, message = 'Ingen spiller i nærheden.' })
        return
    end
    local ok, message = lib.callback.await('mk_mekaniker:hire', false, target, payload.grade)
    cb({ ok = ok, message = message })
end)

RegisterNUICallback('setGrade', function(payload, cb)
    local ok, message = lib.callback.await('mk_mekaniker:setGrade', false, payload.citizenid, payload.grade)
    cb({ ok = ok, message = message })
end)

RegisterNUICallback('fire', function(payload, cb)
    local ok, message = lib.callback.await('mk_mekaniker:fire', false, payload.citizenid)
    cb({ ok = ok, message = message })
end)

RegisterNUICallback('invoice', function(payload, cb)
    local target = getClosestServerId()
    if not target then
        cb({ ok = false, message = 'Ingen kunde i nærheden.' })
        return
    end
    local ok, message = lib.callback.await('mk_mekaniker:invoice', false, target, payload.amount, payload.reason)
    cb({ ok = ok, message = message })
end)

RegisterNUICallback('notify', function(payload, cb)
    notify(payload.message or '', payload.type or 'inform')
    cb({ ok = true })
end)

-- Chef-menu
local function openBossMenu()
    if not isBossClient() then return notify('Kun chefen har adgang.', 'error') end
    openTablet()
end

-- Target-zone til chef-menu
CreateThread(function()
    exports.ox_target:addSphereZone({
        coords = Config.BossMenu.coords,
        radius = Config.BossMenu.radius,
        debug = false,
        options = {
            {
                name = 'mechanic_boss_menu',
                icon = 'fa-solid fa-briefcase',
                label = 'Åbn mekanikertablet',
                groups = Config.Job,
                canInteract = isBossClient,
                onSelect = openBossMenu,
            },
        },
    })
end)

-- Faktura-kommando / tast for alle mekanikere
RegisterCommand('faktura', function()
    local job = getPlayerJob()
    if not job or job.name ~= Config.Job then return notify('Du er ikke mekaniker.', 'error') end
    createInvoice()
end, false)

RegisterKeyMapping('faktura', 'Mekaniker: lav faktura', 'keyboard', 'F7')

RegisterCommand('mekanikertablet', openTablet, false)
RegisterKeyMapping('mekanikertablet', 'Mekaniker: åbn tablet', 'keyboard', 'F6')

local function applySavedTuning(vehicle, properties)
    if not DoesEntityExist(vehicle) or type(properties) ~= 'table' then return end
    SetVehicleModKit(vehicle, 0)
    for category, value in pairs(properties.mods or {}) do
        local config = Config.Workshop.modCategories[category]
        if config and type(value) == 'number' then
            if config.toggle then
                ToggleVehicleMod(vehicle, config.slot, value == 1)
            else
                SetVehicleMod(vehicle, config.slot, value, false)
            end
        end
    end
    local primary, secondary = GetVehicleColours(vehicle)
    if type(properties.primaryColor) == 'number' then primary = properties.primaryColor end
    if type(properties.secondaryColor) == 'number' then secondary = properties.secondaryColor end
    SetVehicleColours(vehicle, primary, secondary)
end

local function getTuneCatalog(vehicle)
    SetVehicleModKit(vehicle, 0)
    local catalog = {}
    for key, config in pairs(Config.Workshop.modCategories) do
        local options = {}
        if config.toggle then
            options = {
                { value = 0, label = 'Deaktiveret' },
                { value = 1, label = 'Aktiveret' },
            }
        else
            local count = GetNumVehicleMods(vehicle, config.slot)
            local maxLevel = math.min(count - 1, config.maxLevel)
            if maxLevel >= 0 then
                options[#options + 1] = { value = -1, label = 'Standard' }
                for level = 0, maxLevel do
                    options[#options + 1] = { value = level, label = ('Niveau %s'):format(level + 1) }
                end
            end
        end
        if #options > 0 then
            catalog[#catalog + 1] = { key = key, label = config.label, price = config.price, options = options }
        end
    end
    local primary, secondary = GetVehicleColours(vehicle)
    for _, colorType in ipairs({
        { key = 'primaryColor', label = 'Primærfarve', current = primary },
        { key = 'secondaryColor', label = 'Sekundærfarve', current = secondary },
    }) do
        local options = {}
        for _, color in ipairs(Config.Workshop.colors) do
            options[#options + 1] = { value = color.value, label = color.label }
        end
        catalog[#catalog + 1] = { key = colorType.key, label = colorType.label, price = Config.Workshop.paintPrice, options = options, current = colorType.current }
    end
    table.sort(catalog, function(a, b) return a.label < b.label end)
    return catalog
end

local function openWorkshopShop()
    local coords = GetEntityCoords(cache.ped)
    local closeToShop = false
    for _, location in ipairs(Config.Workshop.locations) do
        if #(coords - location) <= Config.Workshop.radius then closeToShop = true break end
    end
    if not closeToShop then return notify('Du skal være ved værkstedets butik.', 'error') end

    local vehicle = GetVehiclePedIsIn(cache.ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= cache.ped then vehicle = nil end
    local vehicleNetId, catalog = nil, {}
    if vehicle then
        vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
        local properties = lib.callback.await('mk_mekaniker:getVehicleTuning', false, vehicleNetId) or {}
        applySavedTuning(vehicle, properties)
        catalog = getTuneCatalog(vehicle)
    end
    local products = {}
    for key, product in pairs(Config.ShopProducts) do
        products[#products + 1] = { key = key, label = product.label, price = product.price, description = product.description }
    end
    table.sort(products, function(a, b) return a.label < b.label end)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'shopOpen',
        data = {
            vehicle = vehicle and GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)) or 'Butik — vælg en bil for at tune',
            hasVehicle = vehicle ~= nil,
            netId = vehicleNetId,
            catalog = catalog,
            products = products,
        },
    })
end

RegisterNUICallback('closeShop', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'shopClose' })
    cb({ ok = true })
end)

RegisterNUICallback('buyTune', function(payload, cb)
    local vehicle = GetVehiclePedIsIn(cache.ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= cache.ped then
        cb({ ok = false, message = 'Du skal sidde i førersædet.' })
        return
    end
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local ok, message, properties = lib.callback.await('mk_mekaniker:buyVehicleTune', false, netId, payload.category, payload.value)
    if ok then
        applySavedTuning(vehicle, properties)
        SendNUIMessage({ action = 'tunePurchased', category = payload.category, value = tonumber(payload.value) })
    end
    cb({ ok = ok, message = message })
end)

RegisterNUICallback('buyProduct', function(payload, cb)
    local ok, message = lib.callback.await('mk_mekaniker:buyShopProduct', false, payload.key)
    cb({ ok = ok, message = message })
end)

local function getVehicleForItem()
    local vehicle = GetVehiclePedIsIn(cache.ped, false)
    if vehicle == 0 then
        local coords = GetEntityCoords(cache.ped)
        vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, Config.Workshop.itemUseDistance, 0, 70)
    end
    if vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
    if #(GetEntityCoords(vehicle) - GetEntityCoords(cache.ped)) > Config.Workshop.itemUseDistance then return nil end
    return vehicle
end

local function requestVehicleControl(vehicle)
    local timeout = GetGameTimer() + 1500
    NetworkRequestControlOfEntity(vehicle)
    while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < timeout do
        Wait(0)
        NetworkRequestControlOfEntity(vehicle)
    end
    return NetworkHasControlOfEntity(vehicle)
end

local function useShopVehicleItem(itemKey, itemData)
    local vehicle = getVehicleForItem()
    if not vehicle then return notify('Gå tæt på den bil, du vil bruge itemet på.', 'error') end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local allowed, message = lib.callback.await('mk_mekaniker:canUseShopItem', false, itemKey, netId)
    if not allowed then return notify(message or 'Du kan ikke bruge dette item her.', 'error') end
    if not requestVehicleControl(vehicle) then return notify('Du kan ikke få adgang til bilen lige nu.', 'error') end

    exports.ox_inventory:useItem(itemData, function(usedItem)
        if not usedItem then return end
        local targetStillValid = lib.callback.await('mk_mekaniker:validateShopItemTarget', false, netId)
        if not targetStillValid or not DoesEntityExist(vehicle) then
            notify('Bilen kom for langt væk. Itemet blev brugt, men bilen blev ikke ændret.', 'error')
            return
        end

        if itemKey == 'repairkit' then
            SetVehicleEngineHealth(vehicle, math.max(GetVehicleEngineHealth(vehicle), 650.0))
            SetVehicleBodyHealth(vehicle, math.max(GetVehicleBodyHealth(vehicle), 700.0))
            SetVehicleDeformationFixed(vehicle)
        elseif itemKey == 'advancedrepairkit' then
            SetVehicleFixed(vehicle)
            SetVehicleDeformationFixed(vehicle)
            SetVehicleUndriveable(vehicle, false)
            for tyre = 0, 7 do SetVehicleTyreFixed(vehicle, tyre) end
        elseif itemKey == 'cleaningkit' then
            SetVehicleDirtLevel(vehicle, 0.0)
            WashDecalsFromVehicle(vehicle, 1.0)
        elseif itemKey == 'engine_oil' then
            local engineHealth = GetVehicleEngineHealth(vehicle)
            SetVehicleEngineHealth(vehicle, math.min(1000.0, math.max(0.0, engineHealth) + 300.0))
        elseif itemKey == 'tirekit' then
            for tyre = 0, 7 do SetVehicleTyreFixed(vehicle, tyre) end
        elseif itemKey == 'nitrous' then
            SetVehicleEnginePowerMultiplier(vehicle, 35.0)
            SetTimeout(15000, function()
                if DoesEntityExist(vehicle) then SetVehicleEnginePowerMultiplier(vehicle, 0.0) end
            end)
        end

        notify(('Brugte %s på bilen.'):format(Config.ShopProducts[itemKey].label), 'success')
    end)
end

exports('useRepairkit', function(data) useShopVehicleItem('repairkit', data) end)
exports('useAdvancedrepairkit', function(data) useShopVehicleItem('advancedrepairkit', data) end)
exports('useCleaningkit', function(data) useShopVehicleItem('cleaningkit', data) end)
exports('useEngineOil', function(data) useShopVehicleItem('engine_oil', data) end)
exports('useTirekit', function(data) useShopVehicleItem('tirekit', data) end)
exports('useNitrous', function(data) useShopVehicleItem('nitrous', data) end)

RegisterCommand('bilshop', openWorkshopShop, false)

CreateThread(function()
    for index, coords in ipairs(Config.Workshop.locations) do
        exports.ox_target:addSphereZone({
            coords = coords,
            radius = Config.Workshop.radius,
            debug = false,
            options = {
                {
                    name = ('mechanic_vehicle_shop_%s'):format(index),
                    icon = 'fa-solid fa-screwdriver-wrench',
                    label = 'Tune bil / åbn bilbutik',
                    onSelect = openWorkshopShop,
                },
            },
        })
    end
end)

-- Indlæs købte opgraderinger, når ejeren sætter sig ind i bilen.
CreateThread(function()
    local lastVehicle = 0
    while true do
        local vehicle = GetVehiclePedIsIn(cache.ped, false)
        if vehicle ~= 0 and vehicle ~= lastVehicle and GetPedInVehicleSeat(vehicle, -1) == cache.ped then
            lastVehicle = vehicle
            local properties = lib.callback.await('mk_mekaniker:getVehicleTuning', false, NetworkGetNetworkIdFromEntity(vehicle))
            if properties then applySavedTuning(vehicle, properties) end
        elseif vehicle == 0 then
            lastVehicle = 0
        end
        Wait(vehicle == 0 and 1000 or 1500)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        closeTablet()
        SetNuiFocus(false, false)
    end
end)
