require "ElixirConsumption"

ElixirWell = ElixirWell or {}
local KEY = "ElixirCraftB42Well"
local REGISTRY = "ElixirCraftB42WellRegistry"

local function setting(name, fallback)
    return ElixirConsumption.Setting(name, fallback)
end

local function hours()
    return getGameTime():getWorldAgeHours()
end

local function bounded(name, fallback, low, high)
    return math.max(low, math.min(high, tonumber(setting(name, fallback)) or fallback))
end

function ElixirWell.IsAdministrator(player)
    if not player then return false end
    if not isClient() and not isServer() then return true end
    return player.getAccessLevel and string.lower(tostring(player:getAccessLevel())) == "admin"
end

function ElixirWell.IsWaterSource(object)
    if not object or not object:getSquare() or object:getObjectIndex() < 0 then return false end
    local sprite = object:getSprite()
    local props = sprite and sprite:getProperties()
    local name = props and props:get("CustomName") or ""
    if string.find(string.lower(tostring(name)), "well", 1, true) then return true end
    if object.getFluidContainer and object:getFluidContainer() then return true end
    return props and (props:has("waterPiped") or props:has("waterAmount")) or false
end

function ElixirWell.Near(player, object)
    if not player or player:isDead() or player:getVehicle() or not object then return false end
    local square, current = object:getSquare(), player:getCurrentSquare()
    if not square or not current or object:getObjectIndex() < 0 then return false end
    if current:getZ() ~= square:getZ() then return false end
    if math.abs(current:getX() - square:getX()) > 1
        or math.abs(current:getY() - square:getY()) > 1 then return false end
    -- Reject interactions through closed doors, windows, walls and fences.
    if current ~= square and (current:isBlockedTo(square) or current:isWindowTo(square)) then
        return false
    end
    return true
end

local function spriteName(object)
    local sprite = object:getSprite()
    return sprite and sprite:getName() or ""
end

local function registry()
    return ModData.getOrCreate(REGISTRY)
end

function ElixirWell.Record(object)
    if not object or not object:getSquare() or object:getObjectIndex() < 0 then return nil end
    local marker = object:getModData()[KEY]
    if type(marker) ~= "table" or not marker.id then return nil end
    if isClient() then return marker end -- UI preview only; never authority.
    local record = registry()[tostring(marker.id)]
    local sq = object:getSquare()
    if type(record) ~= "table" or record.x ~= sq:getX() or record.y ~= sq:getY()
        or record.z ~= sq:getZ() or record.sprite ~= spriteName(object) then return nil end
    return record
end

function ElixirWell.Sync(object, record)
    if isClient() then return end
    if record then
        -- Send a copy: incoming object modData must never alias server charge state.
        object:getModData()[KEY] = {
            id = record.id, charges = record.charges, capacity = record.capacity,
        }
    else
        object:getModData()[KEY] = nil
    end
    object:transmitModData()
end

function ElixirWell.Remaining(player)
    -- Wells never inherit bottle/stimulant cooldowns.
    return 0
end

function ElixirWell.Unlimited()
    return setting("WellUnlimitedSupply", true) == true
end

function ElixirWell.Validate(player, object, operation)
    if not setting("EnableHealingWell", true) then return false, "disabled" end
    if not ElixirWell.Near(player, object) then return false, "well-distance" end
    local record = ElixirWell.Record(object)
    if operation == "DesignateWell" then
        if not ElixirWell.IsAdministrator(player) then return false, "admin-only" end
        if record then return false, "well-already-active" end
        if not ElixirWell.IsWaterSource(object) then return false, "not-water-source" end
        return true
    end
    if not record then return false, "well-missing" end
    if operation == "RemoveWell" or operation == "AdminRechargeWell" then
        if not ElixirWell.IsAdministrator(player) then return false, "admin-only" end
        return true, nil, record
    end
    if operation == "RefillWell" then
        if ElixirWell.Unlimited() then return false, "well-unlimited" end
        if not setting("WellAllowPlayerRefill", true) and not ElixirWell.IsAdministrator(player) then
            return false, "admin-only"
        end
        if record.charges >= record.capacity then return false, "well-full" end
        return true, nil, record
    end
    if operation ~= "DrinkWell" then return false, "invalid-request" end
    if not ElixirWell.Unlimited() and record.charges <= 0 then return false, "well-empty" end
    return true, nil, record
end

function ElixirWell.AdminChange(player, object, operation)
    if isClient() then return false, "invalid-request" end
    local ok, reason, record = ElixirWell.Validate(player, object, operation)
    if not ok then return false, reason end
    if operation == "DesignateWell" then
        local records = registry()
        records.nextId = (tonumber(records.nextId) or 0) + 1
        local id = tostring(records.nextId)
        local sq = object:getSquare()
        local capacity = math.floor(bounded("WellCapacity", 20, 1, 10000))
        record = { id = id, x = sq:getX(), y = sq:getY(), z = sq:getZ(),
            sprite = spriteName(object), capacity = capacity,
            charges = math.floor(bounded("WellInitialCharges", 5, 0, capacity)) }
        records[id] = record
    elseif operation == "RemoveWell" then
        registry()[tostring(record.id)] = nil
        record = nil
    elseif operation == "AdminRechargeWell" then
        record.charges = record.capacity
    else
        return false, "invalid-request"
    end
    ElixirWell.Sync(object, record)
    return true
end

function ElixirWell.ApplyHealing(player, detail)
    local damage = player:getBodyDamage()
    local parts = damage:getBodyParts()
    local after = {}
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        -- Keep bite wounds unless the optional cure actually succeeded.
        local restore = detail.healWounds and (detail.curedKnox or not part:bitten())
        if restore then part:RestoreToFullHealth()
        else part:AddHealth(math.min(detail.healAmount, math.max(0, 100 - part:getHealth()))) end
        after[i + 1] = part:getHealth()
    end
    damage:calculateOverallHealth()
    return after, damage:getOverallBodyHealth()
end

function ElixirWell.Drink(player, object)
    if isClient() then return false, "invalid-request" end
    local ok, reason, record = ElixirWell.Validate(player, object, "DrinkWell")
    if not ok then return false, reason, record end
    -- Limited mode reserves a charge before mutation. Unlimited mode leaves the
    -- saved pool intact, including wells created by the previous version.
    local unlimited = ElixirWell.Unlimited()
    if not unlimited then record.charges = record.charges - 1 end
    ElixirWell.Sync(object, record)
    local detail = {
        healAmount = bounded("WellHealAmount", 25, 1, 100),
        healWounds = setting("WellHealWounds", false), curedKnox = false,
        charges = record.charges,
        usedAt = hours(),
        unlimited = unlimited,
    }
    if setting("WellFullRecovery", true) then
        detail.provider = ElixirConsumption.RestoreFully(player)
        detail.curedKnox, detail.healWounds, detail.cureScope = true, true, 4
        detail.fullRecovery = true
        detail.healAmount = 100
    elseif setting("WellCuresKnox", false) then
        -- Wells are independent of every bottled cure eligibility rule.
        detail.provider = ElixirConsumption.RestoreFully(player)
        detail.curedKnox, detail.healWounds, detail.cureScope = true, true, 4
    end
    detail.partHealth, detail.healthAfter = ElixirWell.ApplyHealing(player, detail)
    return true, "well", detail
end

function ElixirWell.Refill(player, object, item)
    if isClient() then return false, "invalid-request" end
    local ok, reason, record = ElixirWell.Validate(player, object, "RefillWell")
    if not ok then return false, reason end
    if not ElixirConsumption.OwnsItem(player, item, "ElixirCraft.KnoxCure") then
        return false, "item-not-found"
    end
    ElixirConsumption.RemoveOwnedItem(item)
    record.charges = math.min(record.capacity, record.charges
        + math.floor(bounded("WellRefillCharges", 5, 1, 10000)))
    ElixirWell.Sync(object, record)
    return true, "well", { charges = record.charges }
end
