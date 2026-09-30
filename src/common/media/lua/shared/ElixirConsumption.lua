ElixirConsumption = ElixirConsumption or {}

local MOD_DATA_KEY = "ElixirCraftB42"
local MODULE = "ElixirCraftB42"

local function setting(name, fallback)
    local options = SandboxVars and SandboxVars.ElixirCraftB42
    if options and options[name] ~= nil then return options[name] end
    return fallback
end

local function worldHours()
    local gameTime = getGameTime()
    return gameTime and gameTime:getWorldAgeHours() or 0
end

local function stateFor(player)
    local modData = player:getModData()
    modData[MOD_DATA_KEY] = modData[MOD_DATA_KEY] or {}
    return modData[MOD_DATA_KEY]
end

function ElixirConsumption.Setting(name, fallback)
    return setting(name, fallback)
end

local function validPlayer(player)
    return player and instanceof(player, "IsoPlayer") and not player:isDead()
end

local function remainingCooldown(player, field, cooldown)
    if cooldown <= 0 then return 0 end
    local usedAt = tonumber(stateFor(player)[field]) or -1000000
    return math.max(0, cooldown - (worldHours() - usedAt))
end

local function notify(player, text)
    if not player then return end
    if HaloTextHelper and HaloTextHelper.addGoodText then
        HaloTextHelper.addGoodText(player, text)
    elseif player.Say then
        player:Say(text)
    end
end

local function medicalLevel(recipeData)
    local player = recipeData and (recipeData.getCharacter and recipeData:getCharacter()
        or recipeData.character or recipeData.player)
    if not player and getPlayer then player = getPlayer() end
    if not player or not player.getPerkLevel or not Perks or not Perks.Doctor then return 0 end
    return tonumber(player:getPerkLevel(Perks.Doctor)) or 0
end

local function recipePlayer(recipeData)
    local player = recipeData and (recipeData.getCharacter and recipeData:getCharacter()
        or recipeData.character or recipeData.player)
    if not player and getPlayer then player = getPlayer() end
    return player
end

local function isAdministrator(player)
    if not player then return false end
    if (not isClient or not isClient()) and (not isServer or not isServer()) then
        return true
    end
    if not player.getAccessLevel then return false end
    local access = string.lower(tostring(player:getAccessLevel() or ""))
    return access == "admin"
end

local function craftingAllowed(recipeData)
    return not setting("AdminOnlyCrafting", false)
        or isAdministrator(recipePlayer(recipeData))
end

local function cureKnoxInfection(player)
    if setting("EnableAntibodiesIntegration", true) then
        local loaded, medicalFileModule = pcall(require, "antibodies_medical_file")
        if loaded and medicalFileModule and medicalFileModule.of then
            local medicalFile = medicalFileModule.of(player, false)
            if medicalFile and medicalFile.cureKnoxVirus then
                medicalFile:cureKnoxVirus(player)
                medicalFile.knoxInfectionLevel = 0
                medicalFile.knoxInfectionDelta = 0
                medicalFile.knoxAntibodiesLevel = 0
                if medicalFile.updateKnoxInfection then medicalFile:updateKnoxInfection(player) end
                return "Antibodies"
            end
        end
    end

    local damage = player:getBodyDamage()
    damage:setInfected(false)
    damage:setInfectionTime(-1.0)
    damage:setInfectionMortalityDuration(-1.0)
    return "Vanilla"
end

local function bodyParts(player)
    local damage = player and player:getBodyDamage()
    return damage, damage and damage:getBodyParts() or nil
end

local function clearBites(parts)
    if not parts then return end
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part.SetBitten then part:SetBitten(false) end
        if part.setBiteTime then part:setBiteTime(-1.0) end
    end
end

local function clearWoundInfections(parts)
    if not parts then return end
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part.SetInfected then part:SetInfected(false) end
        if part.setWoundInfectionLevel then part:setWoundInfectionLevel(0.0) end
    end
end

local function restoreBodyParts(parts)
    if not parts then return end
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part.RestoreToFullHealth then part:RestoreToFullHealth() end
    end
end

-- The well's guaranteed mode uses the same restoration as the bottled cure's
-- full scope, without the bottle's chance roll, cooldown or lifetime-use limit.
function ElixirConsumption.RestoreFully(player)
    local provider = cureKnoxInfection(player)
    local damage, parts = bodyParts(player)
    clearBites(parts)
    clearWoundInfections(parts)
    restoreBodyParts(parts)
    damage:RestoreToFullHealth()
    damage:setOverallBodyHealth(100.0)
    return provider
end

-- Well-only survival restoration. Set reserves instead of adding a dose, so
-- unlimited drinks cannot stack calories or invoke bottled stimulant penalties.
function ElixirConsumption.RestoreWellSurvival(player, caloriesAfter)
    local stats = player:getStats()
    stats:setHunger(0)
    stats:setThirst(0)
    stats:setFatigue(0)
    stats:setEndurance(1)
    stats:setEnduranceRecharging(false)
    local nutrition = player:getNutrition()
    local calories = tonumber(caloriesAfter)
    if not calories then
        local current = tonumber(nutrition:getCalories()) or 0
        if current ~= current then current = 0 end
        calories = math.max(2500, current)
    end
    nutrition:setCalories(calories)
    return calories
end

local function effectivenessSucceeded()
    local effectiveness = math.max(1, math.min(100,
        tonumber(setting("CureEffectiveness", 100.0)) or 100.0))
    if effectiveness >= 100 then return true end
    local roll = ZombRand and ZombRand(10000) or math.random(0, 9999)
    return roll < math.floor(effectiveness * 100)
end

local function logUse(player, treatment, provider)
    local announcement = tonumber(setting("UsageAnnouncement", 2)) or 2
    if not setting("EnableUsageLogging", true) and announcement ~= 2 then return end
    local username = player:getUsername() or "unknown"
    print(string.format(
        "[ElixirCraftB42] USE treatment=%s provider=%s username=%s character=%s x=%d y=%d z=%d",
        treatment, provider or "native", username, player:getDisplayName() or username,
        math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    ))
end

function ElixirConsumption.GetRemainingCooldown(player, treatment)
    if not validPlayer(player) then return 0 end
    if treatment == "KnoxCure" then
        return remainingCooldown(player, "lastKnoxCureUse",
            tonumber(setting("KnoxCureCooldownHours", 24.0)) or 24.0)
    end
    return remainingCooldown(player, "lastAdrenalineUse",
        tonumber(setting("AdrenalineCooldownHours", 6.0)) or 6.0)
end

function ElixirConsumption.CanCraftKnoxCure(recipeData)
    return setting("EnableKnoxCure", true)
        and setting("EnableKnoxCureCrafting", true)
        and craftingAllowed(recipeData)
        and medicalLevel(recipeData) >= (tonumber(setting("KnoxCureMedicalLevel", 0)) or 0)
end

function ElixirConsumption.CanCraftAdrenalineStimulant(recipeData)
    return setting("EnableAdrenalineStimulant", true)
        and setting("EnableAdrenalineCrafting", true)
        and craftingAllowed(recipeData)
        and medicalLevel(recipeData) >= (tonumber(setting("AdrenalineMedicalLevel", 0)) or 0)
end

function ElixirConsumption.ValidateTreatment(player, treatment)
    if not validPlayer(player) then return false, "invalid-player" end
    if treatment == "KnoxCure" then
        if not setting("EnableKnoxCure", true) then return false, "disabled" end
        if setting("OneCurePerCharacter", false)
            and stateFor(player).successfulKnoxCure == true then
            return false, "cure-limit"
        end
    elseif treatment == "AdrenalineStimulant" then
        if not setting("EnableAdrenalineStimulant", true) then return false, "disabled" end
    else
        return false, "unknown-treatment"
    end
    local remaining = ElixirConsumption.GetRemainingCooldown(player, treatment)
    if remaining > 0 then return false, "cooldown", math.ceil(remaining) end
    return true
end

function ElixirConsumption.ApplyTreatment(player, treatment)
    local valid, validationReason, validationDetail =
        ElixirConsumption.ValidateTreatment(player, treatment)
    if not valid then return false, validationReason, validationDetail end

    if treatment == "KnoxCure" then
        local damage, parts = bodyParts(player)
        if not damage then return false, "no-body-damage" end
        if not effectivenessSucceeded() then return false, "effectiveness-failed" end
        local provider = cureKnoxInfection(player)
        local scope = math.max(1, math.min(4,
            tonumber(setting("CureTreatmentScope", 2)) or 2))
        if scope >= 2 then clearBites(parts) end
        if scope >= 3 then
            clearWoundInfections(parts)
            restoreBodyParts(parts)
        end
        if scope >= 4 then
            damage:RestoreToFullHealth()
            damage:setOverallBodyHealth(100.0)
        end
        local state = stateFor(player)
        state.lastKnoxCureUse = worldHours()
        -- IsoPlayer modData is character-scoped and persists across relogs.
        state.successfulKnoxCure = true
        state.successfulKnoxCureAt = state.lastKnoxCureUse
        logUse(player, treatment, provider)
        return true, provider, { scope = scope, healthAfter = damage:getOverallBodyHealth() }
    end

    if treatment == "AdrenalineStimulant" then
        if not setting("EnableAdrenalineStimulant", true) then return false, "disabled" end
        local stats = player:getStats()
        if not stats then return false, "no-stats" end

        local state = stateFor(player)
        local now = worldHours()
        local previousUse = tonumber(state.lastAdrenalineUse)
        local overdoseWindow = math.max(0,
            tonumber(setting("StimulantOverdoseWindowHours", 12.0)) or 12.0)
        local elapsed = previousUse and (now - previousUse) or nil
        local overdose = overdoseWindow > 0 and elapsed ~= nil
            and elapsed >= 0 and elapsed <= overdoseWindow

        local restore = math.max(1, math.min(100,
            tonumber(setting("AdrenalineRestorePercent", 100.0)) or 100.0)) / 100
        local enduranceAfter = math.min(1.0, stats:getEndurance() + restore)
        local fatigueAfter = setting("ClearFatigue", true) and 0 or stats:getFatigue()
        local panicAfter = math.min(100, stats:getPanic()
            + (tonumber(setting("AdrenalinePanic", 0)) or 0))
        local stressAfter = math.min(1.0, stats:getStress()
            + (tonumber(setting("AdrenalineStress", 0.0)) or 0.0))
        local thirstAfter = math.min(1.0, stats:getThirst()
            + (tonumber(setting("AdrenalineThirst", 0.0)) or 0.0))
        stats:setEndurance(enduranceAfter)
        if setting("ClearFatigue", true) then stats:setFatigue(0) end
        stats:setEnduranceRecharging(false)
        stats:setPanic(panicAfter)
        stats:setStress(stressAfter)
        stats:setThirst(thirstAfter)

        local healthAfter = nil
        local overdoseHealthLoss = math.max(0, math.min(100,
            tonumber(setting("StimulantOverdoseHealthLoss", 10.0)) or 10.0))
        if overdose and overdoseHealthLoss > 0 then
            local damage = player:getBodyDamage()
            if damage and damage.getOverallBodyHealth then
                local healthBefore = damage:getOverallBodyHealth()
                healthAfter = math.max(1, healthBefore - overdoseHealthLoss)
                overdoseHealthLoss = math.max(0, healthBefore - healthAfter)
                damage:setOverallBodyHealth(healthAfter)
            end
        end

        state.lastAdrenalineUse = now
        if setting("EnableStimulantPostCrash", true) then
            local duration = math.max(0,
                tonumber(setting("StimulantEffectDurationHours", 1.0)) or 1.0)
            state.stimulantCrashAt = now + duration
            state.stimulantCrashPending = true
        else
            state.stimulantCrashAt = nil
            state.stimulantCrashPending = nil
        end

        logUse(player, treatment, overdose and "native-overdose" or "native")
        return true, "native", {
            overdose = overdose,
            overdoseHealthLoss = overdose and overdoseHealthLoss or 0,
            healthAfter = healthAfter,
            enduranceAfter = enduranceAfter,
            fatigueAfter = fatigueAfter,
            panicAfter = panicAfter,
            stressAfter = stressAfter,
            thirstAfter = thirstAfter,
        }
    end

    return false, "unknown-treatment"
end

function ElixirConsumption.ProcessPostCrash(player)
    if not validPlayer(player) then return false end
    local state = stateFor(player)
    if state.stimulantCrashPending ~= true then return false end

    if not setting("EnableStimulantPostCrash", true) then
        state.stimulantCrashAt = nil
        state.stimulantCrashPending = nil
        return false
    end

    local crashAt = tonumber(state.stimulantCrashAt)
    if not crashAt or worldHours() < crashAt then return false end

    local stats = player:getStats()
    if not stats then return false end
    local fatigue = math.max(0, math.min(1,
        tonumber(setting("StimulantCrashFatigue", 0.35)) or 0.35))

    state.stimulantCrashAt = nil
    state.stimulantCrashPending = nil
    stats:setFatigue(math.max(stats:getFatigue(), fatigue))
    return true, fatigue
end

function ElixirConsumption.HandleResult(command, args, player)
    args = args or {}
    if not player and tonumber(args.playerOnlineID) and getNumActivePlayers and getSpecificPlayer then
        for i = 0, getNumActivePlayers() - 1 do
            local candidate = getSpecificPlayer(i)
            if candidate and candidate:getOnlineID() == tonumber(args.playerOnlineID) then
                player = candidate
                break
            end
        end
        if not player then return end
    end
    player = player or (getSpecificPlayer and getSpecificPlayer(tonumber(args.playerNum) or 0))
    if not player then return end
    if command == "TreatmentApplied" then
        -- Exact server-calculated after-values prevent additive effects from
        -- being applied twice when multiplayer state synchronization catches up.
        if isClient() and args.treatment == "KnoxCure" then
            local damage, parts = bodyParts(player)
            if damage then
                cureKnoxInfection(player)
                local scope = tonumber(args.scope) or 1
                if scope >= 2 then clearBites(parts) end
                if scope >= 3 then
                    clearWoundInfections(parts)
                    restoreBodyParts(parts)
                end
                if scope >= 4 then damage:RestoreToFullHealth() end
                if tonumber(args.healthAfter) then
                    damage:setOverallBodyHealth(tonumber(args.healthAfter))
                end
            end
        elseif isClient() and args.treatment == "AdrenalineStimulant" then
            local stats = player:getStats()
            if stats then
                if tonumber(args.enduranceAfter) then stats:setEndurance(tonumber(args.enduranceAfter)) end
                if tonumber(args.fatigueAfter) then stats:setFatigue(tonumber(args.fatigueAfter)) end
                if tonumber(args.panicAfter) then stats:setPanic(tonumber(args.panicAfter)) end
                if tonumber(args.stressAfter) then stats:setStress(tonumber(args.stressAfter)) end
                if tonumber(args.thirstAfter) then stats:setThirst(tonumber(args.thirstAfter)) end
                stats:setEnduranceRecharging(false)
            end
            if args.overdose == true and tonumber(args.healthAfter) then
                local damage = player:getBodyDamage()
                if damage then damage:setOverallBodyHealth(math.max(1, tonumber(args.healthAfter))) end
            end
        end

        notify(player, getText(args.treatment == "KnoxCure"
            and "IGUI_ElixirCraft_KnoxCureUsed"
            or "IGUI_ElixirCraft_AdrenalineUsed"))
        if args.overdose == true and tonumber(args.overdoseHealthLoss)
            and tonumber(args.overdoseHealthLoss) > 0 then
            local text = getText("IGUI_ElixirCraft_Overdose",
                string.format("%.1f", tonumber(args.overdoseHealthLoss)))
            if HaloTextHelper and HaloTextHelper.addBadText then
                HaloTextHelper.addBadText(player, text)
            else
                notify(player, text)
            end
        end
    elseif command == "WellApplied" then
        if isClient() then
            if args.fullRecovery == true and tonumber(args.caloriesAfter) then
                ElixirConsumption.RestoreWellSurvival(player, tonumber(args.caloriesAfter))
            end
            local damage, parts = bodyParts(player)
            if damage then
                if args.curedKnox == true then
                    cureKnoxInfection(player)
                    if (tonumber(args.cureScope) or 1) >= 2 then clearBites(parts) end
                    if (tonumber(args.cureScope) or 1) >= 3 then
                        clearWoundInfections(parts)
                        restoreBodyParts(parts)
                    end
                    if (tonumber(args.cureScope) or 1) >= 4 then damage:RestoreToFullHealth() end
                end
                for i = 0, parts:size() - 1 do
                    local part = parts:get(i)
                    if args.healWounds == true and (args.curedKnox == true or not part:bitten()) then
                        part:RestoreToFullHealth()
                    end
                    local value = type(args.partHealth) == "table" and tonumber(args.partHealth[i + 1])
                    if value then part:setHealth(math.max(0, math.min(100, value))) end
                end
                if tonumber(args.healthAfter) then damage:setOverallBodyHealth(tonumber(args.healthAfter)) end
            end
        end
        if args.unlimited == true then
            notify(player, getText("IGUI_ElixirCraft_WellHealedUnlimited"))
        else
            notify(player, getText("IGUI_ElixirCraft_WellHealed", args.charges or 0))
        end
        if args.cureFailed == true then notify(player, getText("IGUI_ElixirCraft_CureFailed")) end
    elseif command == "WellChanged" then
        notify(player, getText("IGUI_ElixirCraft_WellChanged_" .. tostring(args.operation)))
    elseif command == "VersionAccepted" then
        if ElixirConsumption.SetProtocolState then
            ElixirConsumption.SetProtocolState(true, false, tonumber(args.protocol))
        end
    elseif command == "VersionMismatch" then
        if ElixirConsumption.SetProtocolState then
            ElixirConsumption.SetProtocolState(false, true, tonumber(args.protocol))
        end
        notify(player, getText("IGUI_ElixirCraft_VersionMismatch"))
    elseif command == "UsageAnnouncement" then
        local treatmentName = args.treatment == "HealingWell"
            and getText("IGUI_ElixirCraft_TreatmentHealingWell")
            or args.treatment == "KnoxCure"
            and getText("IGUI_ElixirCraft_TreatmentKnoxCure")
            or getText("IGUI_ElixirCraft_TreatmentAdrenaline")
        notify(player, getText("IGUI_ElixirCraft_GlobalUse",
            tostring(args.username or "unknown"), treatmentName))
    elseif command == "StimulantCrash" then
        local stats = player:getStats()
        if stats then
            local fatigue = math.max(0, math.min(1,
                tonumber(args.fatigue) or tonumber(setting("StimulantCrashFatigue", 0.35)) or 0.35))
            stats:setFatigue(math.max(stats:getFatigue(), fatigue))
        end
        if HaloTextHelper and HaloTextHelper.addBadText then
            HaloTextHelper.addBadText(player, getText("IGUI_ElixirCraft_AdrenalineCrash"))
        end
    elseif command == "TreatmentRejected" then
        if args.reason == "cooldown" then
            notify(player, getText("IGUI_ElixirCraft_Cooldown", args.remaining or 1))
        elseif args.reason == "cure-limit" then
            notify(player, getText("IGUI_ElixirCraft_CureLimit"))
        elseif args.reason == "effectiveness-failed" then
            notify(player, getText("IGUI_ElixirCraft_CureFailed"))
        else
            local key = "IGUI_ElixirCraft_Reason_" .. string.gsub(tostring(args.reason), "-", "_")
            local text = getTextOrNull and getTextOrNull(key)
            notify(player, text or getText("IGUI_ElixirCraft_TreatmentRejected"))
        end
    end
end

local function onServerCommand(module, command, args)
    if module == MODULE then ElixirConsumption.HandleResult(command, args) end
end

if Events and Events.OnServerCommand and isClient and isClient() then
    Events.OnServerCommand.Add(onServerCommand)
end
