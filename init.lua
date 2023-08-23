local blacklist = { }
minetest.register_chatcommand("drop", {
    params = "[param...]",
    description = "Don't add the specified drop(s) to the inventory when digging. Example: /drop default:cobble default:sand",
    func = function(name, param)
        if string.find(param, " ", 1, true) then
            param = param:split(" ")
        else
            param = {param}
        end

        blacklist[name] = param
    end
})

local function itemmeta_is_empty(meta)
		local t = meta:to_table()
		for k, v in pairs(t) do
			if k ~= "fields" then
				return false
			end
			assert(type(v) == "table")
			if next(v) ~= nil then
				return false
			end
		end
		return true
end

-- Tests if the item has special information such as metadata
local function can_split_item(item)
	return item:get_wear() == 0 and itemmeta_is_empty(item:get_meta())
end

local function spawn_items(pos, items_to_spawn)
	for i = 1,#items_to_spawn do
		local obj = minetest.add_item(pos, items_to_spawn[i])
		if not obj then
			error("Couldn't spawn item " .. name .. ", drops: "
				.. dump(drops))
		end

		local vel = obj:get_velocity()
		local x = math.random(-5, 4)
		if x >= 0 then
			x = x+1
		end
		vel.x = 1 / x
		local z = math.random(-5, 4)
		if z >= 0 then
			z = z+1
		end
		vel.z = 1 / z
		obj:set_velocity(vel)
	end
end

local old_handle_node_drops = minetest.handle_node_drops
function minetest.handle_node_drops(pos, drops, player)
	if not player or player.is_fake_player then
		-- Node Breaker or similar machines should receive items in the
		-- inventory
		return old_handle_node_drops(pos, drops, player)
	end
	for i = 1,#drops do
		local item = drops[i]
		if type(item) == "string" then
			-- The string is not necessarily only the item name,
			-- so always convert it to ItemStack
			item = ItemStack(item)
		end
		local count = item:get_count()
		local name = item:get_name()

		-- Sometimes nothing should be dropped or added to the inventory
		if name == ""
		or not minetest.registered_items[name]
        or count <= 0 then
            return
		end
        local player_name = player:get_player_name()
        blacklist[player_name] = blacklist[player_name] or {""} 
        
        local drop_is_blacklisted = false
        for _,v in pairs(blacklist[player_name]) do
            if name == v then
                drop_is_blacklisted = true
                break
            end
        end

        if not drop_is_blacklisted then
            player:get_inventory():add_item("main", item)
        else
            -- Split items if possible
            local items_to_spawn = {item}
            if can_split_item(item) then
                for i = 1,count do
                    items_to_spawn[i] = name
                end
            end
        
            spawn_items(pos, items_to_spawn)
        end
    end
end
