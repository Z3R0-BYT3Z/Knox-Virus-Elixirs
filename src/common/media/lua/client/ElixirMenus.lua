require "TimedActions/ISElixirAction"
require "TimedActions/ISTimedActionQueue"
require "ISUI/ISWorldObjectContextMenu"
require "ElixirClient"

local function ready()
    return not isClient() or ElixirConsumption.ProtocolReady()
end

local function queue(player, operation, object, item)
    if not ready() then return end
    if object and not luautils.walkAdjObject(player, object, true, true) then return end
    ISTimedActionQueue.add(ISElixirAction:new(player, operation, object, item, 4))
end

local function onInventory(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end
    local seen = {}
    for _, selection in ipairs(items) do
        local item = selection
        if type(selection) == "table" and selection.items then item = selection.items[1] end
        if item and item.getFullType then
            local fullType = item:getFullType()
            local operation = fullType == "ElixirCraft.KnoxCure" and "KnoxCure"
                or fullType == "ElixirCraft.StaminaElixir" and "AdrenalineStimulant" or nil
            if operation and not seen[operation] and ElixirConsumption.OwnsItem(player, item, fullType) then
                seen[operation] = true
                local label = operation == "KnoxCure" and "ContextMenu_ElixirCraft_UseKnoxCure"
                    or "ContextMenu_ElixirCraft_UseAdrenaline"
                local option = context:addOption(getText(label), player, queue, operation, nil, item)
                option.notAvailable = not ready()
            end
        end
    end
end

local function findCure(container)
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item:getFullType() == "ElixirCraft.KnoxCure" then return item end
        if item.getInventory and item:getInventory() then
            local found = findCure(item:getInventory())
            if found then return found end
        end
    end
end

local function onWorld(playerNum, context, worldobjects, test)
    if test or not ElixirConsumption.Setting("EnableHealingWell", true) then return end
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end
    local seen = {}
    for _, clicked in ipairs(worldobjects) do
        local square = clicked:getSquare()
        local objects = square and square:getObjects()
        if objects then
            for i = 0, objects:size() - 1 do
                local object = objects:get(i)
                if not seen[object] then
                    seen[object] = true
                    local record = ElixirWell.Record(object)
                    local admin = ElixirWell.IsAdministrator(player)
                    if record then
                        local root = context:addOption(getText("ContextMenu_ElixirCraft_Well"))
                        local submenu = ISContextMenu:getNew(context)
                        context:addSubMenu(root, submenu)
                        local unlimited = ElixirWell.Unlimited()
                        local full = ElixirConsumption.Setting("WellFullRecovery", true)
                        if unlimited then
                            submenu:addOption(getText("ContextMenu_ElixirCraft_WellUnlimited")).notAvailable = true
                        else
                            submenu:addOption(getText("ContextMenu_ElixirCraft_WellCharges",
                                record.charges or 0, record.capacity or 0)).notAvailable = true
                        end
                        if full then
                            submenu:addOption(getText("ContextMenu_ElixirCraft_WellFullRecovery")).notAvailable = true
                        else
                            submenu:addOption(getText("ContextMenu_ElixirCraft_WellEffect",
                                ElixirConsumption.Setting("WellHealAmount", 25))).notAvailable = true
                            if ElixirConsumption.Setting("WellHealWounds", false) then
                                submenu:addOption(getText("ContextMenu_ElixirCraft_WellWounds")).notAvailable = true
                            end
                            if ElixirConsumption.Setting("WellCuresKnox", false) then
                                submenu:addOption(getText("ContextMenu_ElixirCraft_WellKnox")).notAvailable = true
                            end
                        end
                        local drink = submenu:addOption(getText("ContextMenu_ElixirCraft_DrinkWell"),
                            player, queue, "DrinkWell", object)
                        drink.notAvailable = not ready() or (not unlimited and (tonumber(record.charges) or 0) <= 0)
                        if not unlimited and (ElixirConsumption.Setting("WellAllowPlayerRefill", true) or admin) then
                            local cure = findCure(player:getInventory())
                            local refill = submenu:addOption(getText("ContextMenu_ElixirCraft_RefillWell"),
                                player, queue, "RefillWell", object, cure)
                            refill.notAvailable = not ready() or not cure or record.charges >= record.capacity
                        end
                        if admin then
                            if not unlimited then
                                submenu:addOption(getText("ContextMenu_ElixirCraft_AdminRechargeWell"),
                                    player, queue, "AdminRechargeWell", object).notAvailable = not ready()
                            end
                            submenu:addOption(getText("ContextMenu_ElixirCraft_RemoveWell"),
                                player, queue, "RemoveWell", object).notAvailable = not ready()
                        end
                    elseif admin and ElixirWell.IsWaterSource(object) then
                        context:addOption(getText("ContextMenu_ElixirCraft_DesignateWell"),
                            player, queue, "DesignateWell", object).notAvailable = not ready()
                    end
                end
            end
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onInventory)
Events.OnFillWorldObjectContextMenu.Add(onWorld)

local function onPlayerUpdate(player)
    if isClient() then return end
    local crashed, fatigue = ElixirConsumption.ProcessPostCrash(player)
    if crashed then ElixirConsumption.HandleResult("StimulantCrash", { fatigue = fatigue }, player) end
end
Events.OnPlayerUpdate.Add(onPlayerUpdate)
