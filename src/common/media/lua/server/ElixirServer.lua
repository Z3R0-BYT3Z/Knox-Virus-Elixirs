require "ElixirTransactions"

local MODULE = "ElixirCraftB42"
local compatibleClients = {}
local function key(player)
    return tostring(player:getOnlineID()) .. ":" .. tostring(player:getUsername())
end

function ElixirConsumption.IsCompatible(player, protocol)
    return protocol == 4 and compatibleClients[key(player)] == true
end

local function onClientCommand(module, command, player, args)
    if module ~= MODULE or not player then return end
    if command == "Hello" then
        local compatible = tonumber(args and args.protocol) == 4
        compatibleClients[key(player)] = compatible
        sendServerCommand(player, MODULE, compatible and "VersionAccepted" or "VersionMismatch", {
            protocol = 4, playerNum = player:getPlayerNum(),
            playerOnlineID = player:getOnlineID(),
        })
    elseif command == "UseTreatment" then
        -- Protocol 3's instant commands no longer change inventory or health.
        sendServerCommand(player, MODULE, "VersionMismatch", {
            protocol = 4, playerNum = player:getPlayerNum(), playerOnlineID = player:getOnlineID(),
        })
    end
end
Events.OnClientCommand.Add(onClientCommand)

local function onPlayerUpdate(player)
    local crashed, fatigue = ElixirConsumption.ProcessPostCrash(player)
    if crashed then ElixirConsumption.ReportResult(player, "StimulantCrash", { fatigue = fatigue }) end
end
Events.OnPlayerUpdate.Add(onPlayerUpdate)
