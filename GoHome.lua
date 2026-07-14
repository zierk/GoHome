_addon.name = 'GoHome'
_addon.author = 'Zierk'
_addon.version = '0.0.1'
_addon.commands = {'gohome', 'gh'}

local res = require('resources')

local zone_table = { 

    [0] = { 
        zone = "Port San d'Oria", 
        index = 87,  
        waypoints = { {84.580, -141.111} } 
    }, 

    [1] = { 
        zone = "Port Bastok",     
        index = 73,  
        waypoints = { {50.108, -237.790}, {52.120, -248.826} } 
    }, 

    [2] = { 
        zone = "Port Windurst",   
        index = 142, 
        waypoints = { {195.306, 224.108}, {197.933, 234.513}, {197.700, 265.516} } 
    }, 
}

local state = {
    player_loaded     = false,
    nation_id         = nil,
    nation_name       = "Unknown",
    destination_zone  = "Port Jeuno",
    target_hp_index   = nil,
    waypoints         = {},
    movement_active   = false,
    debug             = true
}

local function log_info(msg)
    local prefix = "\31\200[\31\05GoHome\31\200]\31\207 "
    windower.add_to_chat(1, prefix .. tostring(msg))
end

local function log_error(msg)
    local prefix = "\31\200[\31\05GoHome Addon\31\200] \31\123ERROR:\31\207 "
    windower.add_to_chat(1, prefix .. tostring(msg))
end

local function log_debug(msg)
    if state.debug then
        local prefix = "\31\200[\31\05GoHome Addon\31\200] \31\200DEBUG:\31\207 "
        windower.add_to_chat(1, prefix .. tostring(msg))
    end
end

local function initialize_player_data()
    local player = windower.ffxi.get_player()
    if not player then 
        state.player_loaded = false
        return 
    end

    -- Safely extract and cache tracking data points outside execution loops
    state.nation_id = player.nation
    state.nation_name = res.regions[player.nation] and res.regions[player.nation].english or "None"
    
    local target_data = zone_table[player.nation]
    if target_data then
        state.destination_zone = target_data.zone
        state.target_hp_index  = target_data.index
        state.waypoints        = target_data.waypoints
    else
        -- Unaligned / Mercenary status default values
        state.destination_zone = "Port Jeuno"
        state.target_hp_index  = 58
        log_error('No nation found, setting HP to Port Jeuno.')
    end

    state.player_loaded = true

    -- Print startup validation sequence to chat
    log_info('Initialized.   Nation: ' .. state.nation_name .. ' -> ' .. state.destination_zone)
    log_debug('Data Loaded. Nation ID: ' .. state.nation_id .. ' | Target HP Index: ' .. state.target_hp_index)
end

windower.register_event('load', function()
    -- Evaluates immediately if addon is loaded while already in-game
    if windower.ffxi.get_info().logged_in then
        initialize_player_data()
    end
end)

windower.register_event('login', function()
    -- Evaluates when logging into a fresh character
    initialize_player_data()
end)


local function find_nearby_homepoint()
    local mobs = windower.ffxi.get_mob_array()
    local closest_hp = nil
    local min_distance = 50.0 

    for _, mob in pairs(mobs) do
        if mob.name and string.find(mob.name, "Home Point") then
            local actual_distance = math.sqrt(mob.distance)
            if actual_distance < min_distance then
                min_distance = actual_distance
                closest_hp = mob
            end
        end
    end
    return closest_hp, min_distance
end

local function walk_to_coordinates(waypoint_list)
    if not waypoint_list or #waypoint_list == 0 then return end
    
    state.movement_active = true
    
    coroutine.schedule(function()
        -- Loop through every waypoint set in the array sequentially
        for i = 1, #waypoint_list do
            if not state.movement_active then break end
            
            local target_x = waypoint_list[i][1]
            local target_y = waypoint_list[i][2]
            
            log_debug(string.format("Moving to waypoint %d/%d...", i, #waypoint_list))
            
            -- Keep running vector calculations until reaching this specific node
            while state.movement_active do
                local player_mob = windower.ffxi.get_mob_by_target('me')
                if not player_mob then break end
                
                -- Dynamic real-time steering adjustment toward current target node
                local angle = math.atan2(target_y - player_mob.y, target_x - player_mob.x)
                windower.ffxi.run(-angle) 
                
                -- Distance check to this node
                local dist = math.sqrt((player_mob.x - target_x)^2 + (player_mob.y - target_y)^2)
                if dist < 1.0 then
                    -- Arrived at node; break this inner while loop to advance to the next "i" loop index
                    break
                end
                coroutine.sleep(0.1)
            end
        end
        
        -- Complete halt routine once all array entries are processed
        windower.ffxi.run(false) 
        state.movement_active = false
        log_info("Final destination reached successfully.")
    end, 0.1)
end

-- will become main loop
windower.register_event('addon command', function(cmd, ...)
    local command = cmd and cmd:lower() or nil

    if command == 'start' or command == 'run' then
        -- Enforce state configuration safety
        if not state.player_loaded or not state.target_hp_index then
            log_error("No player data loaded or unsupported nation assignment.")
            return
        end

        local hp, dist = find_nearby_homepoint() 

        -- Evaluate distance barrier conditional execution array
        if hp and dist <= 5.0 then
            local current_zone_id = windower.ffxi.get_info().zone
            local current_zone_name = res.zones[current_zone_id].english

            if current_zone_name == state.destination_zone and hp.index == state.target_hp_index then
                -- Already at destination: run walking vector sequence
                walk_to_coordinates(state.waypoints)
            else
                -- At wrong location: build and run dynamic SuperWarp string assignment
                log_info("Home Point found, but wrong crystal. Warping to " .. state.destination_zone .. "...")
                windower.send_command('sw hp "' .. state.destination_zone .. '" mh')
                -- !!! follow up with resume function after loading into next zone
            end
        else
            -- No crystal found OR crystal is too far away (> 5 yalms)
            log_info("No valid Home Point within 5 yalms. Initiating fallback warp...")
            -- !!! execute_fallback_warp()
        end

    elseif command == 'stop' or command == 'abort' then
        state.movement_active = false
        windower.ffxi.run(false)
        log_info("Sequence manually aborted.")
    end
end)