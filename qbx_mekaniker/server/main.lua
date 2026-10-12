-- Tabel til fakturalog
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mechanic_invoices` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `sender_citizenid` VARCHAR(50) NOT NULL,
            `target_citizenid` VARCHAR(50) NOT NULL,
            `amount` INT NOT NULL,
            `reason` VARCHAR(255) NOT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mechanic_vehicle_tuning` (
            `plate` VARCHAR(16) NOT NULL PRIMARY KEY,
            `properties` LONGTEXT NOT NULL,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]])
end)

local function notify(src, description, type)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Mekaniker',
        description = description,
        type = type or 'inform',
    })
end

local function getPlayer(src)
    return exports.qbx_core:GetPlayer(src)
end

local function isMechanic(player)
    return player and player.PlayerData.job.name == Config.Job
end

local function isBoss(player)
    return isMechanic(player) and player.PlayerData.job.isboss == true
end

local function getDistance(a, b)
    return #(GetEntityCoords(GetPlayerPed(a)) - GetEntityCoords(GetPlayerPed(b)))
end

local function getGrades()
    local job = exports.qbx_core:GetJobs()[Config.Job]
    local list = {}
    if not job then return list end
    for grade, data in pairs(job.grades) do
        list[#list + 1] = { value = tostring(grade), label = ('%s (%s)'):format(data.name, grade), grade = tonumber(grade) }
    end
    table.sort(list, function(x, y) return x.grade < y.grade end)
    return list
end

local function validGrade(grade)
    for _, g in ipairs(getGrades()) do
        if g.grade == grade then return true end
    end
    return false
end

-- Karakterer (grader) til menuer
lib.callback.register('mk_mekaniker:getGrades', function(src)
    if not isBoss(getPlayer(src)) then return {} end
    return getGrades()
end)

-- Medarbejderliste
lib.callback.register('mk_mekaniker:getEmployees', function(src)
    if not isBoss(getPlayer(src)) then return {} end

    local rows = MySQL.query.await([[
        SELECT pg.citizenid, pg.grade, p.charinfo
        FROM player_groups pg
        JOIN players p ON p.citizenid = pg.citizenid
        WHERE pg.`group` = ? AND pg.`type` = 'job'
    ]], { Config.Job })

    local employees = {}
    for _, row in ipairs(rows or {}) do
        local info = json.decode(row.charinfo) or {}
        employees[#employees + 1] = {
            citizenid = row.citizenid,
            grade = tonumber(row.grade),
            name = ('%s %s'):format(info.firstname or '?', info.lastname or '?'),
        }
    end
    return employees
end)

-- Data til mekanikertabletten
lib.callback.register('mk_mekaniker:getTabletData', function(src)
    local player = getPlayer(src)
    if not isMechanic(player) then return nil end

    local boss = isBoss(player)
    local citizenid = player.PlayerData.citizenid
    local job = exports.qbx_core:GetJobs()[Config.Job]
    local rank = job and job.grades[player.PlayerData.job.grade.level]
    local whereClause = boss and '' or 'WHERE sender_citizenid = ?'
    local params = boss and {} or { citizenid }

    local totals = MySQL.single.await(([[
        SELECT COUNT(*) AS count, COALESCE(SUM(amount), 0) AS amount
        FROM mechanic_invoices %s
    ]]):format(whereClause), params) or { count = 0, amount = 0 }
    local invoices = MySQL.query.await(([[
        SELECT id, sender_citizenid, target_citizenid, amount, reason, created_at
        FROM mechanic_invoices %s
        ORDER BY id DESC LIMIT 8
    ]]):format(whereClause), params) or {}

    for _, invoice in ipairs(invoices) do
        invoice.amount = tonumber(invoice.amount) or 0
        invoice.created_at = tostring(invoice.created_at or '')
    end

    local grades = getGrades()
    local gradeNames = {}
    for _, grade in ipairs(grades) do
        gradeNames[grade.grade] = grade.label
        grade.grade = nil
    end

    local employees = {}
    if boss then
        local rows = MySQL.query.await([[
            SELECT pg.citizenid, pg.grade, p.charinfo
            FROM player_groups pg
            JOIN players p ON p.citizenid = pg.citizenid
            WHERE pg.`group` = ? AND pg.`type` = 'job'
        ]], { Config.Job }) or {}

        for _, row in ipairs(rows) do
            local info = json.decode(row.charinfo) or {}
            local grade = tonumber(row.grade) or 0
            employees[#employees + 1] = {
                citizenid = row.citizenid,
                grade = grade,
                rank = gradeNames[grade] or ('Rank %s'):format(grade),
                name = ('%s %s'):format(info.firstname or '?', info.lastname or '?'),
            }
        end
    end

    return {
        name = ('%s %s'):format(player.PlayerData.charinfo.firstname or '', player.PlayerData.charinfo.lastname or ''),
        rank = rank and rank.name or 'Mekaniker',
        isBoss = boss,
        onDuty = player.PlayerData.job.onduty == true,
        grades = grades,
        employees = employees,
        stats = { invoices = tonumber(totals.count) or 0, revenue = tonumber(totals.amount) or 0 },
        invoiceHistory = invoices,
    }
end)

-- Ansæt
lib.callback.register('mk_mekaniker:hire', function(src, targetId, grade)
    local boss = getPlayer(src)
    if not isBoss(boss) then return false, 'Du er ikke chef.' end

    targetId, grade = tonumber(targetId), tonumber(grade)
    if not targetId or not grade or not validGrade(grade) then return false, 'Ugyldige data.' end

    local target = getPlayer(targetId)
    if not target then return false, 'Spilleren findes ikke.' end
    if targetId == src then return false, 'Du kan ikke ansætte dig selv.' end
    if getDistance(src, targetId) > Config.InteractDistance then return false, 'Spilleren er for langt væk.' end
    if isMechanic(target) then return false, 'Spilleren er allerede ansat.' end

    local citizenid = target.PlayerData.citizenid
    exports.qbx_core:AddPlayerToJob(citizenid, Config.Job, grade)
    exports.qbx_core:SetPlayerPrimaryJob(citizenid, Config.Job)

    notify(targetId, 'Du er blevet ansat som mekaniker!', 'success')
    return true, 'Spilleren er ansat.'
end)

-- Fyr
lib.callback.register('mk_mekaniker:fire', function(src, citizenid)
    local boss = getPlayer(src)
    if not isBoss(boss) then return false, 'Du er ikke chef.' end
    if type(citizenid) ~= 'string' then return false, 'Ugyldige data.' end
    if citizenid == boss.PlayerData.citizenid then return false, 'Du kan ikke fyre dig selv.' end
    local employed = MySQL.scalar.await('SELECT 1 FROM player_groups WHERE citizenid = ? AND `group` = ? AND `type` = \'job\' LIMIT 1', { citizenid, Config.Job })
    if not employed then return false, 'Medarbejderen findes ikke.' end

    exports.qbx_core:RemovePlayerFromJob(citizenid, Config.Job)

    local target = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if target then notify(target.PlayerData.source, 'Du er blevet fyret fra mekanikeren.', 'error') end
    return true, 'Medarbejderen er fyret.'
end)

-- Skift rank
lib.callback.register('mk_mekaniker:setGrade', function(src, citizenid, grade)
    local boss = getPlayer(src)
    if not isBoss(boss) then return false, 'Du er ikke chef.' end

    grade = tonumber(grade)
    if type(citizenid) ~= 'string' or not grade or not validGrade(grade) then return false, 'Ugyldige data.' end
    local employed = MySQL.scalar.await('SELECT 1 FROM player_groups WHERE citizenid = ? AND `group` = ? AND `type` = \'job\' LIMIT 1', { citizenid, Config.Job })
    if not employed then return false, 'Medarbejderen findes ikke.' end

    exports.qbx_core:AddPlayerToJob(citizenid, Config.Job, grade)

    local target = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if target then notify(target.PlayerData.source, 'Din rank er blevet ændret.', 'inform') end
    return true, 'Rank opdateret.'
end)

-- Faktura
local pendingInvoice = {}

lib.callback.register('mk_mekaniker:invoice', function(src, targetId, amount, reason)
    local sender = getPlayer(src)
    if not isMechanic(sender) then return false, 'Du er ikke mekaniker.' end
    if not Config.EmployeesCanInvoice and not isBoss(sender) then return false, 'Kun chefen kan fakturere.' end
    if Config.Invoice.requireOnDuty and not sender.PlayerData.job.onduty then return false, 'Du er ikke på arbejde.' end

    targetId, amount = tonumber(targetId), math.floor(tonumber(amount) or 0)
    reason = type(reason) == 'string' and reason:sub(1, 200) or ''

    if not targetId or targetId == src then return false, 'Ugyldig modtager.' end
    if amount < Config.Invoice.minAmount or amount > Config.Invoice.maxAmount then
        return false, ('Beløb skal være mellem %s og %s kr.'):format(Config.Invoice.minAmount, Config.Invoice.maxAmount)
    end
    if reason == '' then return false, 'Skriv en beskrivelse.' end

    local target = getPlayer(targetId)
    if not target then return false, 'Spilleren findes ikke.' end
    if getDistance(src, targetId) > Config.InteractDistance then return false, 'Spilleren er for langt væk.' end
    if pendingInvoice[targetId] then return false, 'Spilleren har allerede en ventende faktura.' end

    pendingInvoice[targetId] = true
    local senderName = ('%s %s'):format(sender.PlayerData.charinfo.firstname, sender.PlayerData.charinfo.lastname)
    local accepted = lib.callback.await('mk_mekaniker:confirmInvoice', targetId, senderName, amount, reason)
    pendingInvoice[targetId] = nil

    if not accepted then
        notify(src, 'Kunden afviste fakturaen.', 'error')
        return false, 'Fakturaen blev afvist.'
    end

    -- Tjek igen efter svar (spilleren kan være logget af)
    target, sender = getPlayer(targetId), getPlayer(src)
    if not target or not sender then return false, 'Spilleren er ikke længere online.' end

    if not target.Functions.RemoveMoney('bank', amount, 'mechanic-invoice') then
        notify(targetId, 'Du har ikke penge nok i banken.', 'error')
        return false, 'Kunden har ikke penge nok.'
    end

    local share = math.floor(amount * Config.Invoice.commissionPercent / 100)
    local rest = amount - share

    sender.Functions.AddMoney('bank', share, 'mechanic-invoice-commission')

    if rest > 0 and Config.Invoice.useSocietyFunds and GetResourceState('qbx_management') == 'started' then
        pcall(function() exports.qbx_management:AddMoney(Config.Job, rest) end)
    end

    MySQL.insert('INSERT INTO mechanic_invoices (sender_citizenid, target_citizenid, amount, reason) VALUES (?, ?, ?, ?)', {
        sender.PlayerData.citizenid, target.PlayerData.citizenid, amount, reason,
    })

    notify(targetId, ('Du har betalt %s kr.'):format(amount), 'success')
    return true, ('Faktura betalt. Du fik %s kr.'):format(share)
end)

local function nearWorkshop(src, vehicle)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local playerCoords = GetEntityCoords(ped)
    local atShop = false
    for _, coords in ipairs(Config.Workshop.locations) do
        if #(playerCoords - coords) <= Config.Workshop.radius then
            atShop = true
            break
        end
    end
    if not atShop then return false end

    if vehicle then
        if not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return false end
        if GetPedInVehicleSeat(vehicle, -1) ~= ped then return false end
        if #(GetEntityCoords(vehicle) - playerCoords) > Config.Workshop.maxVehicleDistance then return false end
    end
    return true
end

local function getVehicleByNetId(src, netId)
    netId = tonumber(netId)
    if not netId or netId < 1 then return nil end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not nearWorkshop(src, vehicle) then return nil end
    return vehicle
end

local function getPlate(vehicle)
    return (GetVehicleNumberPlateText(vehicle) or ''):gsub('^%s*(.-)%s*$', '%1')
end

lib.callback.register('mk_mekaniker:getVehicleTuning', function(src, netId)
    netId = tonumber(netId)
    if not netId or netId < 1 then return nil end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local ped = GetPlayerPed(src)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return nil end
    if not ped or ped == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then return nil end
    local plate = getPlate(vehicle)
    if plate == '' then return nil end
    local row = MySQL.single.await('SELECT properties FROM mechanic_vehicle_tuning WHERE plate = ?', { plate })
    if not row then return {} end
    local ok, properties = pcall(json.decode, row.properties)
    return ok and type(properties) == 'table' and properties or {}
end)

lib.callback.register('mk_mekaniker:buyVehicleTune', function(src, netId, category, value)
    local vehicle = getVehicleByNetId(src, netId)
    if not vehicle then return false, 'Du skal sidde i bilen ved værkstedet.' end
    if type(category) ~= 'string' then return false, 'Ugyldig tuning.' end
    value = tonumber(value)
    if not value or value % 1 ~= 0 then return false, 'Ugyldigt valg.' end

    local config = Config.Workshop.modCategories[category]
    local isColor = category == 'primaryColor' or category == 'secondaryColor'
    local price
    if isColor then
        local validColor = false
        for _, color in ipairs(Config.Workshop.colors) do
            if color.value == value then validColor = true break end
        end
        if not validColor then return false, 'Ugyldig farve.' end
        price = Config.Workshop.paintPrice
    elseif config then
        if config.toggle then
            if value ~= 0 and value ~= 1 then return false, 'Ugyldigt valg.' end
        elseif value < -1 or value > config.maxLevel then
            return false, 'Dette tuningniveau er ikke tilladt.'
        end
        if (config.toggle and value == 0) or value == -1 then
            price = 0
        else
            price = config.price
        end
    else
        return false, 'Denne opgradering findes ikke.'
    end

    local player = getPlayer(src)
    if not player then return false, 'Spilleren findes ikke.' end
    if price > 0 and not player.Functions.RemoveMoney(Config.Workshop.paymentAccount, price, 'mechanic-vehicle-tuning') then
        return false, 'Du har ikke penge nok.'
    end

    local plate = getPlate(vehicle)
    if plate == '' then
        if price > 0 then player.Functions.AddMoney(Config.Workshop.paymentAccount, price, 'mechanic-tuning-refund') end
        return false, 'Bilen mangler en nummerplade.'
    end
    local row = MySQL.single.await('SELECT properties FROM mechanic_vehicle_tuning WHERE plate = ?', { plate })
    local properties = {}
    if row then
        local ok, decoded = pcall(json.decode, row.properties)
        if ok and type(decoded) == 'table' then properties = decoded end
    end
    if isColor then
        properties[category] = value
    else
        properties.mods = properties.mods or {}
        properties.mods[category] = value
    end
    MySQL.update.await('INSERT INTO mechanic_vehicle_tuning (plate, properties) VALUES (?, ?) ON DUPLICATE KEY UPDATE properties = VALUES(properties)', {
        plate, json.encode(properties),
    })
    return true, ('Opgradering købt for %s kr.'):format(price), properties
end)

lib.callback.register('mk_mekaniker:buyShopProduct', function(src, productKey)
    if type(productKey) ~= 'string' or not nearWorkshop(src) then return false, 'Du skal være ved værkstedets butik.' end
    local product = Config.ShopProducts[productKey]
    if not product then return false, 'Denne vare findes ikke.' end
    if GetResourceState('ox_inventory') ~= 'started' then return false, 'Butikken kræver ox_inventory.' end

    local player = getPlayer(src)
    if not player then return false, 'Spilleren findes ikke.' end
    local inventory = exports.ox_inventory
    if not inventory:CanCarryItem(src, product.item, 1) then return false, 'Du har ikke plads i dit inventar.' end
    if not player.Functions.RemoveMoney(Config.Workshop.paymentAccount, product.price, 'mechanic-shop-purchase') then
        return false, 'Du har ikke penge nok.'
    end

    local added = inventory:AddItem(src, product.item, 1)
    if not added then
        player.Functions.AddMoney(Config.Workshop.paymentAccount, product.price, 'mechanic-shop-refund')
        return false, 'Varen kunne ikke lægges i dit inventar. Pengene er tilbagebetalt.'
    end
    return true, ('Du købte %s for %s kr.'):format(product.label, product.price)
end)

local function getNearbyItemVehicle(src, netId)
    netId = tonumber(netId)
    if not netId or netId < 1 then return nil end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local ped = GetPlayerPed(src)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return nil end
    if not ped or ped == 0 or #(GetEntityCoords(vehicle) - GetEntityCoords(ped)) > Config.Workshop.itemUseDistance then return nil end
    return vehicle
end

lib.callback.register('mk_mekaniker:canUseShopItem', function(src, itemKey, netId)
    if type(itemKey) ~= 'string' or not Config.ShopProducts[itemKey] then return false, 'Ugyldigt værkstedsitem.' end
    if GetResourceState('ox_inventory') ~= 'started' then return false, 'ox_inventory er ikke startet.' end
    if not getNearbyItemVehicle(src, netId) then return false, 'Gå tættere på bilen, du vil bruge itemet på.' end
    local product = Config.ShopProducts[itemKey]
    local count = exports.ox_inventory:Search(src, 'count', product.item)
    if (tonumber(count) or 0) < 1 then return false, 'Du har ikke dette item.' end
    return true
end)

lib.callback.register('mk_mekaniker:validateShopItemTarget', function(src, netId)
    return getNearbyItemVehicle(src, netId) ~= nil
end)
