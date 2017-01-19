local item = ...

-- When it is created, this item creates another item randomly chosen
-- and then destroys itself.

-- Probability of each item between 0 and 1000.
local probabilities = {
  [{ "bomb", 1 }]       = 0,    -- 1 bomb.
  [{ "bomb", 2 }]       = 50,    -- 3 bombs.
  [{ "bomb", 3 }]       = 0,    -- 8 bombs.
  [{ "arrow", 1 }]      = 0,    -- 1 arrow.
  [{ "arrow", 2 }]      = 50,    -- 5 arrows.
  [{ "arrow", 3 }]      = 0,    -- 10 arrows.
  [{ "rupee", 1 }]      = 0,   -- 1 rupee.
  [{ "rupee", 2 }]      = 50,   -- 5 rupees.
  [{ "rupee", 3 }]      = 0,    -- 20 rupees.
  [{ "magic_flask", 1}] = 0,   -- Small magic jar.
  [{ "magic_flask", 2}] = 0,    -- Big magic jar.
  [{ "heart", 1}]       = 100,  -- Heart.
  [{ nil, 1}]     	    = 100, -- nothing
  --[{ "fairy", 1}]       = 2,    -- Fairy.
}

local item_list = {}

function item:on_pickable_created(pickable)

  local treasure_name, treasure_variant = self:choose_item_from_list()
  if treasure_name ~= nil then
    local map = pickable:get_map()
    local x, y, layer = pickable:get_position()
    map:create_pickable{
      layer = layer,
      x = x,
      y = y,
      treasure_name = treasure_name,
      treasure_variant = treasure_variant,
    }
  end
  pickable:remove()
end

-- Returns an item name and variant.
function item:choose_random_item()

  local random = math.random(1000)
  local sum = 0

  for key, probability in pairs(probabilities) do
    sum = sum + probability
    if random < sum then
      return key[1], key[2]
    end
  end

  return nil
end

function item:choose_item_from_list()
  if #item_list == 0 then 
  	item_list = {{ "rupee", 1 }, { "bomb", 1 }, { "arrow", 1 },{ "arrow", 1 }, { "heart", 1}, { "magic_flask", 1}, { "rupee", 1 },{ "rupee", 1 },{ "rupee", 1 }, }
  end
  local item_info = table.remove( item_list, math.random(#item_list) )
  
  return item_info[1], item_info[2]
end

