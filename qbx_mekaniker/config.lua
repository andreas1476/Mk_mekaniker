Config = {}

-- Jobnavn (skal matche det du opretter i qbx_core/shared/jobs.lua)
Config.Job = 'mechanic'

-- Chef-menuen (ansæt, fyr, rank, medarbejderliste)
Config.BossMenu = {
    coords = vec3(-347.29, -133.57, 39.01),
    radius = 1.2,
}

-- Hvor langt væk en spiller må være for at kunne ansættes / faktureres
Config.InteractDistance = 4.0

-- Fakturaer
Config.Invoice = {
    minAmount = 50,
    maxAmount = 50000,
    commissionPercent = 60,      -- % af beløbet som mekanikeren selv får i banken
    useSocietyFunds = true,      -- resten går til firmakonto (qbx_management), hvis den er installeret
    requireOnDuty = true,        -- mekanikeren skal være på arbejde
    confirmTimeout = 30000,      -- ms kunden har til at acceptere
}

-- Må almindelige medarbejdere (ikke chef) lave fakturaer?
Config.EmployeesCanInvoice = true

-- Værksted og tuning. Spilleren skal sidde som fører og være ved en af disse lokationer.
Config.Workshop = {
    locations = {
        vec3(-337.4, -136.9, 39.0),
    },
    radius = 4.0,
    maxVehicleDistance = 8.0,
    itemUseDistance = 5.0,
    paymentAccount = 'bank', -- 'cash' eller 'bank'
    modCategories = {
        engine = { label = 'Motor', slot = 11, maxLevel = 4, price = 5000 },
        brakes = { label = 'Bremser', slot = 12, maxLevel = 3, price = 2500 },
        transmission = { label = 'Transmission', slot = 13, maxLevel = 3, price = 3500 },
        suspension = { label = 'Undervogn', slot = 15, maxLevel = 4, price = 2000 },
        armor = { label = 'Panser', slot = 16, maxLevel = 4, price = 3000 },
        turbo = { label = 'Turbo', slot = 18, maxLevel = 0, price = 12000, toggle = true },
        spoiler = { label = 'Spoiler', slot = 0, maxLevel = 15, price = 1800 },
        frontBumper = { label = 'Forkofanger', slot = 1, maxLevel = 15, price = 1600 },
        rearBumper = { label = 'Bagkofanger', slot = 2, maxLevel = 15, price = 1600 },
        sideSkirt = { label = 'Sideskørter', slot = 3, maxLevel = 15, price = 1400 },
        exhaust = { label = 'Udstødning', slot = 4, maxLevel = 15, price = 1300 },
        frame = { label = 'Karrosseri', slot = 5, maxLevel = 15, price = 1800 },
        grille = { label = 'Grill', slot = 6, maxLevel = 15, price = 1100 },
        hood = { label = 'Motorhjelm', slot = 7, maxLevel = 15, price = 1500 },
        fender = { label = 'Skærme', slot = 8, maxLevel = 15, price = 1200 },
        rightFender = { label = 'Højre skærm', slot = 9, maxLevel = 15, price = 1200 },
        roof = { label = 'Tag', slot = 10, maxLevel = 15, price = 1500 },
        horn = { label = 'Horn', slot = 14, maxLevel = 15, price = 900 },
        xenon = { label = 'Xenon lygter', slot = 22, maxLevel = 0, price = 2500, toggle = true },
        frontWheels = { label = 'Forhjul', slot = 23, maxLevel = 20, price = 2200 },
        rearWheels = { label = 'Baghjul', slot = 24, maxLevel = 20, price = 2200 },
        plateHolder = { label = 'Nummerpladeholder', slot = 25, maxLevel = 15, price = 500 },
        vanityPlates = { label = 'Dekorationsplade', slot = 26, maxLevel = 15, price = 500 },
        trim = { label = 'Interiørlister', slot = 27, maxLevel = 15, price = 700 },
        ornaments = { label = 'Pynt', slot = 28, maxLevel = 15, price = 500 },
        dashboard = { label = 'Instrumentbræt', slot = 29, maxLevel = 15, price = 900 },
        dial = { label = 'Instrumenter', slot = 30, maxLevel = 15, price = 700 },
        doorSpeaker = { label = 'Dørhøjttalere', slot = 31, maxLevel = 15, price = 800 },
        seats = { label = 'Sæder', slot = 32, maxLevel = 15, price = 1200 },
        steeringWheel = { label = 'Rat', slot = 33, maxLevel = 15, price = 800 },
        shifter = { label = 'Gearknop', slot = 34, maxLevel = 15, price = 500 },
        plaques = { label = 'Interiørmærker', slot = 35, maxLevel = 15, price = 400 },
        speakers = { label = 'Højttalere', slot = 36, maxLevel = 15, price = 900 },
        trunk = { label = 'Bagagerum', slot = 37, maxLevel = 15, price = 800 },
        hydraulics = { label = 'Hydraulik', slot = 38, maxLevel = 15, price = 4000 },
        engineBlock = { label = 'Motorblok', slot = 39, maxLevel = 15, price = 1700 },
        airFilter = { label = 'Luftfilter', slot = 40, maxLevel = 15, price = 900 },
        struts = { label = 'Støddæmperafstivere', slot = 41, maxLevel = 15, price = 1100 },
        archCover = { label = 'Skærmkanter', slot = 42, maxLevel = 15, price = 900 },
        aerials = { label = 'Antenner', slot = 43, maxLevel = 15, price = 400 },
        trim2 = { label = 'Ekstra interiørlister', slot = 44, maxLevel = 15, price = 700 },
        tank = { label = 'Tank', slot = 45, maxLevel = 15, price = 1000 },
        windows = { label = 'Vinduer', slot = 46, maxLevel = 15, price = 800 },
        livery = { label = 'Lakering / livery', slot = 48, maxLevel = 20, price = 3500 },
    },
    colors = {
        { label = 'Sort', value = 0 }, { label = 'Grafit', value = 1 },
        { label = 'Sølv', value = 4 }, { label = 'Hvid', value = 111 },
        { label = 'Rød', value = 27 }, { label = 'Mørkerød', value = 28 },
        { label = 'Orange', value = 38 }, { label = 'Gul', value = 88 },
        { label = 'Mørkegrøn', value = 49 }, { label = 'Grøn', value = 53 },
        { label = 'Blå', value = 64 }, { label = 'Mørkeblå', value = 62 },
        { label = 'Lilla', value = 71 }, { label = 'Lyserød', value = 135 },
    },
    paintPrice = 2500,
}

-- Varer i butikken. Opret item-navnene i ox_inventory/data/items.lua.
Config.ShopProducts = {
    repairkit = { label = 'Reparationskit', item = 'repairkit', price = 1500, description = 'Til almindelige reparationer' },
    advancedrepairkit = { label = 'Avanceret reparationskit', item = 'advancedrepairkit', price = 3500, description = 'Til større skader' },
    cleaningkit = { label = 'Bilplejesæt', item = 'cleaningkit', price = 500, description = 'Hold bilen ren og pæn' },
    engine_oil = { label = 'Motorolie', item = 'engine_oil', price = 400, description = 'Olie til bilens motor' },
    tirekit = { label = 'Dækreparationssæt', item = 'tirekit', price = 800, description = 'Reparér et punkteret dæk' },
    nitrous = { label = 'Nitro-kit', item = 'nitrous', price = 7500, description = 'Eftermonteret nitro-kit' },
}
