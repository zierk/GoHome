_addon.name = 'GoHome'
_addon.author = 'Zierk'
_addon.version = '0.0.1'
_addon.commands = {'gohome', 'gh'}

local res = require('resources')

local zone_table = {
    [0] = "Port San d'Oria",
    [1] = "Port Bastok",
    [2] = "Port Windurst",
}

local player = windower.ffxi.get_player()


if player then
    local nation_name = res.regions[player.nation].english
    local destination_zone = zone_table[player.nation] or "Port Jeuno"

    -- debug text to chat
    windower.add_to_chat(207, 'Current Nation: ' .. nation_name)
    windower.add_to_chat(207, 'GoHome Zone: ' .. destination_zone)
end

local function find_nearby_homepoint()
    local mobs = windower.ffxi.get_mob_array()
    local closest_hp = nil
    -- Set a maximum distance threshold (e.g., 50 yalms)
    local min_distance = 50 

    for _, mob in pairs(mobs) do
        -- Check if the NPC entity name contains "Home Point"
        if mob.name and string.find(mob.name, "Home Point") then
            -- Windower stores distance squared (distance^2). 
            -- math.sqrt() converts it to actual in-game yalms.
            local actual_distance = math.sqrt(mob.distance)

            if actual_distance < min_distance then
                min_distance = actual_distance
                closest_hp = mob
            end
        end
    end

    return closest_hp, min_distance
end

-- will become main loop
windower.register_event('addon command', function(cmd, ...)
    if cmd == 'findhp' then
        local hp, dist = find_nearby_homepoint()

        if hp then
            -- Formats the distance to 2 decimal places
            local message = string.format("Found %s! Distance: %.2f yalms. (Index: %d)", hp.name, dist, hp.index)
            windower.add_to_chat(207, message)
            -- next step
        else
            windower.add_to_chat(123, "No Home Point crystals detected within 50 yalms.")
            -- no HP, let's warp then
        end
    end
end)