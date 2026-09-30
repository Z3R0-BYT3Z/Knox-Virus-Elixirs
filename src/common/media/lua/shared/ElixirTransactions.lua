require "ElixirConsumption"
require "ElixirWell"

local MODULE = "ElixirCraftB42"
local announcements = {}

function ElixirConsumption.OwnsItem(player, item, expectedType)
    if not player or not item or item:getFullType() ~= expectedType then return false end
    local container = item:getContainer()
    if not container then return false end
    -- Follow containers to the player's inventory. Nearby ground/loot is not owned.
    local current = container
    for _ = 1, 32 do
        if current == player:getInventory() then
            return container:contains(item)
        end
        local containingItem = current.getContainingItem and current:getContainingItem()
        if not containingItem then return false end
        current = containingItem:getContainer()
        if not current then return false end
    end
    return false
end

function ElixirConsumption.RemoveOwnedItem(item)
    local container = item:getContainer()
    if isServer() then sendRemoveItemFromContainer(container, item) end
    container:Remove(item)
end

local function returnItem(container, item)
    container:AddItem(item)
    if isServer() then sendAddItemToContainer(container, item) end
end

local function setting(name, fallback)
    return ElixirConsumption.Setting(name, fallback)
end

function ElixirConsumption.ReportResult(player, command, args)
    args.playerNum = player:getPlayerNum()
    args.playerOnlineID = player:getOnlineID()
    if isServer() then sendServerCommand(player, MODULE, command, args)
    else ElixirConsumption.HandleResult(command, args, player) end
end

function ElixirConsumption.ReportFailure(player, treatment, reason, detail)
    ElixirConsumption.ReportResult(player, "TreatmentRejected", {
        treatment = treatment, reason = reason,
        remaining = type(detail) == "number" and detail or nil,
    })
end

function ElixirConsumption.Announce(player, treatment)
    if not isServer() then return end
    local mode = tonumber(setting("UsageAnnouncement", 2)) or 2
    if mode ~= 3 and mode ~= 4 then return end
    local key = tostring(player:getOnlineID()) .. ":" .. tostring(player:getUsername())
    local now = getTimestampMs()
    local wait = math.max(0, tonumber(setting("UsageAnnouncementCooldownSeconds", 5)) or 5) * 1000
    if announcements[key] and now - announcements[key] < wait then return end
    announcements[key] = now
    local args = { username = player:getUsername(), treatment = treatment }
    if mode == 4 then sendServerCommand(MODULE, "UsageAnnouncement", args)
    else sendServerCommand(player, MODULE, "UsageAnnouncement", args) end
end

function ElixirConsumption.CommitBottle(player, item, treatment)
    if isClient() then return false, "invalid-request" end
    local fullType = treatment == "KnoxCure" and "ElixirCraft.KnoxCure"
        or treatment == "AdrenalineStimulant" and "ElixirCraft.StaminaElixir" or nil
    if not fullType or not ElixirConsumption.OwnsItem(player, item, fullType) then
        return false, "item-not-found"
    end
    local ok, reason, detail = ElixirConsumption.ValidateTreatment(player, treatment)
    if not ok then
        local consume = treatment == "KnoxCure" and setting("ConsumeCureOnFailedUse", false)
            or treatment == "AdrenalineStimulant" and not setting("ReturnRejectedStimulant", true)
        if consume then ElixirConsumption.RemoveOwnedItem(item) end
        return false, reason, detail
    end
    local container = item:getContainer()
    ElixirConsumption.RemoveOwnedItem(item)
    local executed, applied, provider, result = pcall(ElixirConsumption.ApplyTreatment, player, treatment)
    if not executed then
        -- Do not refund after an exception: health may already have changed.
        print("[ElixirCraftB42] ERROR bottle treatment failed: " .. tostring(applied))
        return false, "treatment-error"
    end
    if not applied then
        -- Only the effectiveness roll can fail after validation, before mutation.
        if provider == "effectiveness-failed" and not setting("ConsumeCureOnFailedUse", false) then
            returnItem(container, item)
        end
        return false, provider, result
    end
    result = result or {}
    result.treatment = treatment
    result.provider = provider
    ElixirConsumption.ReportResult(player, "TreatmentApplied", result)
    ElixirConsumption.Announce(player, treatment)
    return true, provider, result
end

function ElixirConsumption.CommitWell(player, object, operation, item)
    if isClient() then return false, "invalid-request" end
    local ok, reason, detail
    if operation == "DrinkWell" then
        ok, reason, detail = ElixirWell.Drink(player, object)
        if ok then
            ElixirConsumption.ReportResult(player, "WellApplied", detail)
            ElixirConsumption.Announce(player, "HealingWell")
        end
    elseif operation == "RefillWell" then
        ok, reason, detail = ElixirWell.Refill(player, object, item)
        if ok then ElixirConsumption.ReportResult(player, "WellChanged", { operation = operation }) end
    else
        ok, reason, detail = ElixirWell.AdminChange(player, object, operation)
        if ok then ElixirConsumption.ReportResult(player, "WellChanged", { operation = operation }) end
    end
    if ok and setting("EnableUsageLogging", true) then
        print(string.format("[ElixirCraftB42] WELL operation=%s username=%s x=%d y=%d z=%d",
            operation, player:getUsername(), object:getSquare():getX(),
            object:getSquare():getY(), object:getSquare():getZ()))
    end
    return ok, reason, detail
end
