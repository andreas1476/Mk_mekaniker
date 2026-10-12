# Installation

1. Læg mappen `qbx_mekaniker` i `resources/[qbx]` (eller hvor du vil).
2. Tilføj `ensure ox_inventory` og derefter `ensure qbx_mekaniker` i `server.cfg` efter qbx_core, ox_lib, ox_target og oxmysql.
3. Opret jobbet i `qbx_core/shared/jobs.lua`:

```lua
['mechanic'] = {
    label = 'Mekaniker',
    type = 'mechanic',
    defaultDuty = true,
    offDutyPay = false,
    grades = {
        [0] = { name = 'Lærling',   payment = 50 },
        [1] = { name = 'Mekaniker', payment = 75 },
        [2] = { name = 'Senior',    payment = 100 },
        [3] = { name = 'Næstformand', payment = 125 },
        [4] = { name = 'Chef',      payment = 150, isboss = true, bankAuth = true },
    },
},
```

4. Ret chef-menuens position i `config.lua` (`Config.BossMenu.coords`).
5. Giv dig selv chef-jobbet første gang (i serverkonsollen eller med admin):
   `/setjob [id] mechanic 4`
6. Ret værkstedets placering i `config.lua` under `Config.Workshop.locations`. Tabellen med købte bilopgraderinger oprettes automatisk i databasen.
7. Item-definitionerne til værkstedsvarerne er tilføjet i `ox_inventory/data/items.lua`, inklusive animationer og brugseksporter. Genstart `ox_inventory` (eller hele serveren), så ændringerne indlæses.

Varerne kan bruges tæt på en bil: reparationskit reparerer mindre skader, avanceret kit reparerer bilen helt, bilpleje vasker den, motorolie forbedrer motorens helbred, dæksæt lapper dækkene, og nitro giver et kortvarigt boost.

# Brug

- **Mekanikertablet**: tryk **F6** eller skriv `/mekanikertablet`. Chefen kan ansætte spillere, se medarbejdere, ændre rank og fyre. Alle mekanikere kan se deres fakturaoversigt.
- Ved chefzonen (`Config.BossMenu.coords`) kan chefen også åbne tabletten.
- **Faktura** (alle mekanikere): `/faktura` eller tast **F7**. Kunden skal være tæt på og accepterer i en dialog.
- Betalingen tages fra kundens bank. Mekanikeren får `commissionPercent` % i sin bank, resten går til firmakontoen (hvis `qbx_management` kører).
- Alle fakturaer logges i tabellen `mechanic_invoices`.
- **Bilshop og tuning**: Kør `/bilshop`, eller brug ox_target ved en adresse i `Config.Workshop.locations`. Sid i førersædet tæt på værkstedet. Motor, bremser, transmission, undervogn, panser, turbo, lygter, hjul, karrosseri/interiørdele samt primær- og sekundærfarve kan købes og monteres.
- Fanen **Biltilbehør** sælger items til ox_inventory. Priser, varelisten, tuningdele, farver, lokationer og betalingskonto (`cash` eller `bank`) kan ændres i `config.lua`.
- Købte tuningdele gemmes pr. nummerplade i `mechanic_vehicle_tuning` og indlæses, når en spiller sætter sig ind i bilen. Dette er værkstedets egen lagring; hvis garage-resource gemmer komplette køretøjsegenskaber, skal den også bevare de relevante mod- og farvefelter.
