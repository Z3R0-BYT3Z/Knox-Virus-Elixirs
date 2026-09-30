require "ElixirConsumption"

local MODULE = "ElixirCraftB42"
local PROTOCOL_VERSION = 4
local accepted = false
local mismatched = false
local lastHelloAt = 0
local HELLO_RETRY_MS = 5000

function ElixirConsumption.SetProtocolState(isAccepted, isMismatch)
    accepted = isAccepted == true
    mismatched = isMismatch == true
end

function ElixirConsumption.ProtocolReady()
    return accepted and not mismatched
end

local function requestHello()
    if not isClient or not isClient() then return end
    lastHelloAt = getTimestampMs and getTimestampMs() or 0
    sendClientCommand(MODULE, "Hello", { protocol = PROTOCOL_VERSION })
end

local function retryHello()
    if accepted or mismatched then return end
    local now = getTimestampMs and getTimestampMs() or 0
    if now <= 0 or lastHelloAt <= 0 or now - lastHelloAt >= HELLO_RETRY_MS then
        requestHello()
    end
end

-- Protocol 4 uses shared B42 timed actions; commands only negotiate compatibility.
if Events.OnCreatePlayer then Events.OnCreatePlayer.Add(requestHello) end
if Events.OnPlayerUpdate then Events.OnPlayerUpdate.Add(retryHello) end
