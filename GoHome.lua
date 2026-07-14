_addon.name = 'GoHome' 
_addon.author = 'Zierk' 
_addon.version = '0.0.1' 
_addon.commands = {'gohome', 'gh'} 

local res = require('resources') 

local zone_table = { 
    [0] = { zone = "Port San d'Oria", index = 87,  waypoints = { {84.580, -141.111} } }, 
    [1] = { zone = "Port Bastok",     index = 73,  waypoints = { {50.108, -237.790}, {52.120, -248.826} } }, 
    [2] = { zone = "Port Windurst",   index = 142, waypoints = { {195.306, 224.108}, {197.933, 234.513}, {197.700, 265.516} } }, 
}

local state = { 
    player_loaded = false, 
    nation_id = nil, 
    nation_name = "Unknown", 
    destination_zone = "Port Jeuno", 
    target_hp_index = nil, 
    waypoints = {}, 
    movement_active = false, 
    debug = true 
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
    
    state.nation_id = player.nation 
    state.nation_name = res.regions[player.nation] and res.regions[player.nation].english or "None" 
    
    local target_data = zone_table[player.nation] 
    if target_data then 
        state.destination_zone = target_data.zone 
        state.target_hp_index = target_data.index 
        state.waypoints = target_data.waypoints 
    else 
        state.destination_zone = "Port Jeuno" 
        state.target_hp_index = 58 
        log_error('No nation found, setting HP to Port Jeuno.') 
    end 
    
    state.player_loaded = true 
    
    log_info('Initialized. Nation: ' .. state.nation_name .. ' -> ' .. state.destination_zone) 
    log_debug('Data Loaded. Nation ID: ' .. state.nation_id .. ' | Target HP Index: ' .. state.target_hp_index) 
end 

windower.register_event('load', function() 
    if windower.ffxi.get_info().logged_in then 
        initialize_player_data() 
    end 
end) 

windower.register_event('login', function() 
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
        for i = 1, #waypoint_list do 
            if not state.movement_active then break end 
            local target_x = waypoint_list[i][1] 
            local target_y = waypoint_list[i][2] 
            
            log_debug(string.format("Moving to waypoint %d/%d...", i, #waypoint_list)) 
            
            while state.movement_active do 
                local player_mob = windower.ffxi.get_mob_by_target('me') 
                if not player_mob then break end 
                
                local angle = math.atan2(target_y - player_mob.y, target_x - player_mob.x) 
                windower.ffxi.run(-angle) 
                
                local dist = math.sqrt((player_mob.x - target_x)^2 + (player_mob.y - target_y)^2) 
                if dist < 1.0 then 
                    break 
                end 
                coroutine.sleep(0.1) 
            end 
        end 
        
        windower.ffxi.run(false) 
        state.movement_active = false 
        log_info("Final destination reached successfully.") 
    end, 0.1) 
end 

windower.register_event('addon command', function(cmd, ...) 
    local command = cmd and cmd:lower() or nil 
    
    if command == 'start' or command == 'run' then 
        if not state.player_loaded or not state.target_hp_index then 
            log_error("No player data loaded or unsupported nation assignment.") 
            return 
        end 
        
        local hp, dist = find_nearby_homepoint() 
        
        if hp and dist <= 5.0 then 
            local current_zone_id = windower.ffxi.get_info().zone 
            local current_zone_name = res.zones[current_zone_id].english 
            
            if current_zone_name == state.destination_zone and hp.index == state.target_hp_index then 
                walk_to_coordinates(state.waypoints) 
            else 
                log_info("Home Point found, but wrong crystal. Warping to " .. state.destination_zone .. "...") 
                
                local starting_zone_id = windower.ffxi.get_info().zone
                windower.send_command('sw hp "' .. state.destination_zone .. '" mh') 
                
                coroutine.schedule(function() 
                    log_debug("Warp sequence initiated. Waiting for transition delay...")
                    coroutine.sleep(1.5)
                    
                    log_debug("Monitoring zone change status...")
                    while windower.ffxi.get_info().zone == starting_zone_id do
                        coroutine.sleep(0.5)
                    end 
                    
                    log_debug("Zone change detected. Checking player entity spawn status...")
                    while not windower.ffxi.get_player() or not windower.ffxi.get_mob_by_target('me') do
                        coroutine.sleep(0.5)
                    end
                    
                    log_debug("Character entity spawned. Waiting for client status initialization to finish...")
                    -- Safe combination check: Validates player exists BEFORE evaluating status inequalities
                    while true do
                        local p = windower.ffxi.get_player()
                        if p and (p.status == 0 or p.status == 1) then
                            break
                        end
                        coroutine.sleep(0.5)
                    end
                    
                    -- 10 second delay ensures the 3D map environment parameters load securely
                    coroutine.sleep(10.0)
                    log_info("Post-warp stability verified. Re-running start checks...")
                    windower.send_command('gohome start')
                end, 0.1)
            end 
        else 
            log_info("No valid Home Point within 5 yalms. Initiating fallback warp...") 
            -- !!! execute_fallback_warp() 
        end 
        
    elseif command == 'stop' or command == 'abort' then 
        state.movement_active = false 
        windower.ffxi.run(false) 
        log_info("Sequence manually aborted.") 
    end 
end)
