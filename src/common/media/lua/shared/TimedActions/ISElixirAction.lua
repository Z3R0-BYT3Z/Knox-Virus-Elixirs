require "TimedActions/ISBaseTimedAction"
require "ElixirTransactions"

ISElixirAction = ISBaseTimedAction:derive("ISElixirAction")
local BOTTLES = { KnoxCure = "ElixirCraft.KnoxCure", AdrenalineStimulant = "ElixirCraft.StaminaElixir" }
local OPERATIONS = { DrinkWell = true, RefillWell = true, DesignateWell = true,
    RemoveWell = true, AdminRechargeWell = true }

function ISElixirAction:isValid()
    if not self.character or self.character:isDead() or self.protocol ~= 4 then return false end
    if isServer() and (not ElixirConsumption.IsCompatible
        or not ElixirConsumption.IsCompatible(self.character, self.protocol)) then return false end
    if BOTTLES[self.operation] then
        return ElixirConsumption.OwnsItem(self.character, self.item, BOTTLES[self.operation])
    end
    if not OPERATIONS[self.operation] then return false end
    if self.operation == "RefillWell"
        and not ElixirConsumption.OwnsItem(self.character, self.item, "ElixirCraft.KnoxCure") then
        return false
    end
    -- Keep the action valid while a charge/cooldown changes so complete can explain
    -- a final validation rejection instead of silently cancelling the animation.
    if not ElixirWell.Near(self.character, self.object) then return false end
    if self.operation == "DesignateWell" then
        return ElixirWell.IsAdministrator(self.character) and ElixirWell.IsWaterSource(self.object)
    end
    if self.operation == "RemoveWell" or self.operation == "AdminRechargeWell" then
        return ElixirWell.IsAdministrator(self.character) and ElixirWell.Record(self.object) ~= nil
    end
    return ElixirWell.Record(self.object) ~= nil
end

function ISElixirAction:waitToStart()
    if self.object then
        self.character:faceThisObject(self.object)
        return self.character:shouldBeTurning()
    end
    return false
end

function ISElixirAction:update()
    if self.object then self.character:faceThisObject(self.object) end
end

function ISElixirAction:start()
    if BOTTLES[self.operation] then
        self:setActionAnim(CharacterActionAnims.Drink)
        self:setAnimVariable("FoodType", "2handbottle")
        self:setOverrideHandModels(nil, self.item)
        self.character:reportEvent("EventEating")
    elseif self.operation == "DrinkWell" then
        self:setActionAnim("drink_tap")
        self:setOverrideHandModels(nil, nil)
        self.character:reportEvent("EventTakeWater")
    else
        self:setActionAnim("Loot")
        self.character:SetVariable("LootPosition", "Mid")
    end
end

function ISElixirAction:perform()
    -- B42 calls complete on the server (or single-player); perform is UI only.
    ISBaseTimedAction.perform(self)
end

function ISElixirAction:complete()
    if isClient() or self.committed then return true end
    self.committed = true
    if not self:isValid() then
        ElixirConsumption.ReportFailure(self.character, self.operation, "invalid-request")
        return true
    end
    local executed, ok, reason, detail = pcall(function()
        if BOTTLES[self.operation] then
            return ElixirConsumption.CommitBottle(self.character, self.item, self.operation)
        end
        return ElixirConsumption.CommitWell(self.character, self.object, self.operation, self.item)
    end)
    if not executed then
        print("[ElixirCraftB42] ERROR action failed: " .. tostring(ok))
        ok, reason = false, "treatment-error"
    end
    if not ok then ElixirConsumption.ReportFailure(self.character, self.operation, reason, detail) end
    return true
end

function ISElixirAction:getDuration()
    -- Client-supplied duration is never a constructor parameter.
    if self.operation == "DrinkWell" then
        return math.max(30, math.min(600, tonumber(ElixirConsumption.Setting("WellActionTime", 120)) or 120))
    end
    return BOTTLES[self.operation] and 120 or 90
end

function ISElixirAction:new(character, operation, object, item, protocol)
    local o = ISBaseTimedAction.new(self, character)
    o.operation, o.object, o.item, o.protocol = operation, object, item, protocol
    o.stopOnWalk, o.stopOnRun, o.stopOnAim = true, true, true
    o.maxTime = o:getDuration()
    return o
end
