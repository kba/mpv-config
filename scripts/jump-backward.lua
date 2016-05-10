-- globals mp
--luacheck: globals mp

require 'mp.msg'

local TOLERANCE = 0.5
local OVERSEEKS_ZERO = 2
local OVERSEEKS_END = 2
local OVERSEEKS_PREV = 3
local OVERSEEKS_NEXT = 3
local previous_time = math.huge
local overseeks_left = 0
local overseeks_right = 0

function jump_to_previous()
    local current_time = mp.get_property_native('playback-time')
    local duration = mp.get_property_native('duration')
    if current_time == nil then
        return
    end
    local diff_left = math.abs(current_time - previous_time)
    if diff_left <= TOLERANCE then
        overseeks_left = overseeks_left + 1
    else
        overseeks_left = 0
    end
    local diff_right = math.abs(duration - current_time)
    if current_time + TOLERANCE >= duration then
        overseeks_right = overseeks_right + 1
    else
        overseeks_right = 0
    end
    mp.msg.log('info', 'Current Time: ' .. current_time)
    mp.msg.log('info', 'Previous Time: ' .. previous_time)
    mp.msg.log('fatal', 'Duration: ' .. duration)
    mp.msg.log('fatal', 'Left Diff: ' .. diff_left)
    mp.msg.log('info', 'Left Overseeks: ' .. overseeks_left)
    mp.msg.log('warn', 'Right Diff: ' .. diff_right)
    mp.msg.log('error', 'Right Overseeks: ' .. overseeks_right)

    if overseeks_left > OVERSEEKS_ZERO then
        mp.command("seek -1")
    end
    if overseeks_left > OVERSEEKS_PREV then
        mp.command("playlist-prev")
        overseeks_right = 0
        overseeks_left = 0
    end
    if overseeks_right > OVERSEEKS_END then
        mp.command("seek " .. (duration - 5))
    end
    if overseeks_right > OVERSEEKS_NEXT then
        mp.command("playlist-next")
        overseeks_right = 0
        overseeks_left = 0
    end
    previous_time = mp.get_property_number('playback-time')
end

mp.register_event("seek", jump_to_previous)
