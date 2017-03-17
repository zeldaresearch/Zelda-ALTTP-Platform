
local lookup = {}
-- data lookups


-- Creates an entity of type destructible object on the map.

-- properties (table): A table that describes all properties of the entity to create. Its key-value pairs must be:
-- name (string, optional): Name identifying the entity or nil. If the name is already used by another entity, a suffix (of the form "_2", "_3", etc.) will be automatically appended to keep entity names unique.
-- layer (number): Layer on the map (0: low, 1: intermediate, 2: high).
-- x (number): X coordinate on the map.
-- y (number): Y coordinate on the map.
-- treasure_name (string, optional): Kind of pickable treasure to hide in the destructible object (the name of an equipment item). If this value is not set, then no treasure is placed in the destructible object. If the treasure is not obtainable when the object is destroyed, no pickable treasure is created.
-- treasure_variant (number, optional): Variant of the treasure if any (because some equipment items may have several variants). The default value is 1 (the first variant).
-- treasure_savegame_variable (string, optional): Name of the boolean value that stores in the savegame whether the pickable treasure hidden in the destructible object was found. No value means that the treasure (if any) is not saved. If the treasure is saved and the player already has it, then no treasure is put in the destructible object.
-- sprite (string): Name of the animation set of a sprite to create for the destructible object.
-- destruction_sound (string, optional): Sound to play when the destructible object is cut or broken after being thrown. No value means no sound.
-- weight (number, optional): Level of "lift" ability required to lift the object. 0 allows the player to lift the object unconditionally. The special value -1 means that the object can never be lifted. The default value is 0.
-- can_be_cut (boolean, optional): Whether the hero can cut the object with the sword. No value means false.
-- can_explode (boolean, optional): Whether the object should explode when it is cut, hit by a weapon and after a delay when the hero lifts it. The default value is false.
-- can_regenerate (boolean, optional): Whether the object should automatically regenerate after a delay when it is destroyed. The default value is false.
-- damage_on_enemies (number, optional): Number of life points to remove from an enemy that gets hit by this object after the hero throws it. If the value is 0, enemies will ignore the object. The default value is 1.
-- ground (string, optional): Ground defined by this entity. The ground is usually "wall", but you may set "traversable" to make the object traversable, or for example "grass" to make it traversable too but with an additional grass sprite below the hero. The default value is "wall".
-- Return value (destructible object): The destructible object created.

lookup.equipment = {
	["sword-1"]={requires=nil, 				treasure_name="sword",treasure_variant=1,treasure_savegame_variable="sword__1"},
	["sword-2"]={requires="sword__1", 		treasure_name="sword",treasure_variant=2,treasure_savegame_variable="sword__2"},
	["sword-3"]={requires="sword__2", 		treasure_name="sword",treasure_variant=3,treasure_savegame_variable="sword__3"},
	["glove-1"]={requires=nil, 				treasure_name="glove",treasure_variant=1,treasure_savegame_variable="glove__1"},
	["glove-2"]={requires="glove__1", 		treasure_name="glove",treasure_variant=2,treasure_savegame_variable="glove__2"},
	["bomb_bag-1"]={requires=nil, 			treasure_name="bomb_bag",treasure_variant=1,treasure_savegame_variable="bomb_bag__1"},
	["bomb_bag-2"]={requires="bomb_bag__1", treasure_name="bomb_bag",treasure_variant=2,treasure_savegame_variable="bomb_bag__2"},
	["bomb_bag-3"]={requires="bomb_bag__2", treasure_name="bomb_bag",treasure_variant=3,treasure_savegame_variable="bomb_bag__3"},
}

lookup.rewards = {
	["rupees"]={requires=nil, 				treasure_name="rupee",treasure_variant=5 },
	["heart_container"]={requires=nil, treasure_name="heart_container", treasure_variant=1}
}

lookup.destructible = {
	["bush"]=		{layer = 0, treasure_name = "random_extra", sprite = "entities/bush", destruction_sound = "bush", weight = 1, damage_on_enemies = 2,  can_be_cut = true, required_size={x=16, y=16}, offset={x=8, y=13}},
	["white_rock"]=	{layer = 0, treasure_name = "random_extra", sprite = "entities/stone_small_white", destruction_sound = "stone", weight = 1,  damage_on_enemies = 2, required_size={x=16, y=16}, offset={x=8, y=13}},
	["black_rock"]= {layer = 0, treasure_name = "random_extra", sprite = "entities/stone_small_black", destruction_sound = "stone", weight = 2,  damage_on_enemies = 2, required_size={x=16, y=16}, offset={x=8, y=13}},
	["pot"]=		{layer = 0, treasure_name = "random_extra", sprite = "entities/pot",  destruction_sound = "stone",  damage_on_enemies = 2, required_size={x=16, y=16}, offset={x=8, y=13}}, -- treasure undecided
}

lookup.doors = {
	["door_weak_block"]={ layer = 0, direction = 1, sprite = "entities/door_weak_block", opening_method = "explosion", required_size={x=16, y=16}, offset={x=0, y=0}},
	["door_normal"]={ layer = 0, direction = 1, sprite = "entities/door_normal"},
	["door_small_key"]={ layer = 0, direction = 1, sprite = "entities/door_small_key", opening_method = "interaction_if_savegame_variable", 
						 opening_condition = "small_key", opening_condition_consumed = true, cannot_open_dialog = "_small_key_required"},
	["door_boss_key"]= { layer = 0, direction = 1, sprite = "entities/door_boss_key",
						 opening_method = "interaction_if_savegame_variable", opening_condition = "dungeon_1_boss_key", cannot_open_dialog = "_boss_key_required"},
}

-- format = ["keyname"] = 
-- { 
-- 		required_size={x=num, y=num}, [orderOfPlacement] = { [{area as key}] = { [tileset_number]=tile_id, ... } }
-- }
lookup.transitions = 
{
	["cave_stairs_1"] = 		{required_size={x=32, y=48},
								 [{x1=0, y1=0, x2=8, y2=2*16}]={[1]=865}, 
								 [{x1=8, y1=0, x2=8+16, y2=8}]={[1]=867},
								 [{x1=8+16, y1=0, x2=2*16, y2=2*16}]={[1]=866},
								 [{x1=8, y1=8, x2=8+16, y2=2*16}]={[1]=868}
								 },
	["cave_entrance"] = 		{required_size={x=32, y=24},
								 [{x1=0, y1=-8, x2=8, y2=0, layer=0}]={[3]=184}, -- left floortile
								 [{x1=24, y1=-8, x2=32, y2=0, layer=0}]={[3]=183}, -- right floortile
								 [{x1=0, y1=0, x2=8, y2=16, layer=0}]={[3]=377}, -- left doorpost
								 [{x1=8, y1=-8, x2=24, y2=16, layer=0}]={[3]=379}, -- opening
								 [{x1=24, y1=0, x2=32, y2=16, layer=0}]={[3]=378}, -- right doorpost
								 [{x1=0, y1=16, x2=32, y2=24, layer=1}]={[3]=400} -- doorbeam
								 },
	["cave_stairs_up"] = 		{required_size={x=48, y=24},
								  [{x1=0, y1=8, x2=8, y2=24, layer=0}]={[3]=304}, --leftpost 
								  [{x1=0, y1=0, x2=32, y2=8, layer=1}]={[3]=309}, --doorbeam
								  [{x1=24, y1=8, x2=32, y2=24, layer=0}]={[3]=301}, --rightpost
								  [{x1=8, y1=8, x2=24, y2=24, layer=0}]={[3]=250}, --stairs
								  [{x1=8, y1=8, x2=24, y2=8, layer=2}]={[3]=346}}, --arrow


	["edge_stairs_1"] = 	    {required_size={x=48, y=24},
								  [{x1=16, y1=-8, x2=32, y2=0, layer=0}]={[4]=70},
								  [{x1=16, y1=0, x2=32, y2=8, layer=0}]={[4]=328}, 
								  [{x1=8, y1=0, x2=40, y2=8, layer=1}]={[4]=152}, 
								  [{x1=8, y1=8, x2=16, y2=24, layer=0}]={[4]=72},
								  [{x1=16, y1=8, x2=32, y2=24, layer=0}]={[4]=192},
								  [{x1=32, y1=8, x2=40, y2=24, layer=0}]={[4]=73}},
	["edge_stairs_3"] = 		{required_size={x=48, y=24},
								  [{x1=8, y1=24, x2=32, y2=32, layer=0}]={[4]=70}, 
								  [{x1=8, y1=16, x2=32, y2=24, layer=0}]={[4]=328}, 
							      [{x1=8, y1=0, x2=16, y2=16, layer=0}]={[4]=74}, 
								  [{x1=16, y1=0, x2=32, y2=16, layer=0}]={[4]=196},
								  [{x1=32, y1=0, x2=40, y2=16, layer=0}]={[4]=75},
								  [{x1=8, y1=16, x2=40, y2=24, layer=1}]={[4]=153}},
	 ["edge_stairs_2"] = 	    {required_size={x=64, y=24},
								 [{x1=0, y1=0, x2=24, y2=24, layer=0}]={[4]=49}, 
								 [{x1=40, y1=0, x2=64, y2=24, layer=0}]={[4]=49}, 
								 [{x1=0, y1=0, x2=32, y2=8, layer=1}]={[4]=152}, 
								 [{x1=0, y1=8, x2=8, y2=24, layer=0}]={[4]=72},
								 [{x1=8, y1=8, x2=24, y2=24, layer=0}]={[4]=192},
								 [{x1=24, y1=8, x2=32, y2=24, layer=0}]={[4]=73}},
	["edge_stairs_0"] = 		{required_size={x=64, y=32},
								 [{x1=0, y1=0, x2=24, y2=24, layer=0}]={[4]=52}, 
								 [{x1=40, y1=0, x2=64, y2=24, layer=0}]={[4]=52}, 
							     [{x1=0, y1=0, x2=8, y2=16, layer=0}]={[4]=74}, 
								 [{x1=8, y1=0, x2=8+16, y2=16, layer=0}]={[4]=196},
								 [{x1=8+16, y1=0, x2=2*16, y2=16, layer=0}]={[4]=75},
								 [{x1=0, y1=16, x2=32, y2=24, layer=1}]={[4]=153}},			
	["edge_doors_3"] = 	    {required_size={x=32, y=64},
							 [1]={
							  [{x1=0, y1=24, x2=32, y2=40, layer=1}]={[4]=170, [3]=170}, -- overlay
							  [{x1=0, y1=24, x2=8, y2=40, layer=0}]={[4]=69, [3]=408}, -- barrier
							  [{x1=24, y1=24, x2=32, y2=40, layer=0}]={[4]=69, [3]=408}, -- barrier
							  [{x1=8, y1=16, x2=24, y2=48, layer=0}]={[4]=328, [3]=2}, --ground
							  [{x1=0, y1=40, x2=32, y2=48, layer=1}]={[4]=152, [3]=309}, --bottom doorbeam
							  [{x1=0, y1=48, x2=8, y2=64, layer=0}]={[4]=72, [3]=304}, --bottomleft doorpost
							  [{x1=8, y1=48, x2=24, y2=64, layer=0}]={[4]=76, [3]=293}, --bottom opening
							  [{x1=24, y1=48, x2=32, y2=64, layer=0}]={[4]=73, [3]=301}, --bottomright doorpost
							  [{x1=0, y1=0, x2=8, y2=16, layer=0}]={[4]=74, [3]=303}, --topleft doorpost
							  [{x1=8, y1=0, x2=24, y2=16, layer=0}]={[4]=77, [3]=294}, --top opening
							  [{x1=24, y1=0, x2=32, y2=16, layer=0}]={[4]=75, [3]=302}, --topright doorpost
							  [{x1=0, y1=16, x2=32, y2=24, layer=1}]={[4]=153, [3]=310} --top doorbeam
							  }}, 
	["edge_doors_0"] = 	    {required_size={x=64, y=32},
						      [1]={
							  [{x1=24, y1=0, x2=40, y2=32, layer=1}]={[4]=170, [3]=170}, -- overlay
							  [{x1=24, y1=0, x2=40, y2=8, layer=0}]={[4]=69, [3]=408}, -- barrier
							  [{x1=24, y1=24, x2=40, y2=32, layer=0}]={[4]=69, [3]=408}, -- barrier
							  [{x1=0, y1=0, x2=16, y2=8, layer=0}]={[4]=79, [3]=298}, -- lefttop doorpost
							  [{x1=0, y1=8, x2=16, y2=24, layer=0}]={[4]=83, [3]=296}, -- left opening
							  [{x1=0, y1=24, x2=16, y2=32, layer=0}]={[4]=81, [3]=300}, -- leftbottom doorpost
							  [{x1=16, y1=0, x2=24, y2=32, layer=1}]={[4]=165, [3]=306}, -- left doorbeam
							  [{x1=40, y1=0, x2=48, y2=32, layer=1}]={[4]=164, [3]=305}, -- right doorbeam
							  [{x1=48, y1=0, x2=64, y2=8, layer=0}]={[4]=78, [3]=297}, -- righttop doorpost
							  [{x1=48, y1=8, x2=64, y2=24, layer=0}]={[4]=82, [3]=295}, -- right opening
							  [{x1=48, y1=24, x2=64, y2=32, layer=0}]={[4]=80, [3]=299}, -- rightbottom doorpost
							  [{x1=16, y1=8, x2=48, y2=24, layer=0}]={[4]=328, [3]=2}, -- ground
							  }},

}


lookup.tiles =
{
	["maze_wall_hor"]={[1]=1016, [13]=1016, [4]=70,  [3]=70},
	["maze_wall_ver"]={[1]=1016, [13]=1016, [4]=71,  [3]=71},
	["maze_post"]=	  {[1]=1016, [13]=1016,[4]=69,  [3]=69},
	["dungeon_floor"]=			{[4]=328, [3]=2},
	["dungeon_spacer"]=			{[4]=170, [3]=170},
	["pot_stand"]=				{[4]=101, [3]=364},
	["debug_corner"]= {[1]=63,  [13]=63, [4]=327, [3]=407}
}

-- wall and floortile 0 = east, 3 = south
-- corner and floorcorner 0= south-east 3=south-west
lookup.wall_tiling =
{
	["walltile"]    ={[0]={[3]=50},
				  [1]={[3]=49},
				  [2]={[3]=51},
				  [3]={[3]=52},
				 },
	["wallcorner"]  ={[0]={[3]=48},
				  [1]={[3]=46},
				  [2]={[3]=45},
				  [3]={[3]=47},
				 },
	["floortile"] ={[0]={[1]=57, [13]=57, [3]=182},
				  [1]={[1]=60 , [13]=60, [3]=179},
				  [2]={[1]=58 , [13]=58, [3]=181},
				  [3]={[1]=55 , [13]=55, [3]=180},
				 },
	["floorcorner"] ={[0]={[1]= 50, [13]= 50,[3]=17},
				  [1]={[1]=52 , [13]= 52, [3]=15},
				  [2]={[1]=53 , [13]= 53, [3]=14},
				  [3]={[1]=51 , [13]= 51, [3]=16},
				 },
}

-- format = ["keyname"] = 
-- { 
-- 		required_size={x=num, y=num}, [orderOfPlacement] = { [{area as key}] = { [tileset_number]=tile_id, ... } }
-- }
lookup.props = 
{
	-- forest props
	["green_tree"]= { required_size={x=64, y=64},
					 [{x1=0, y1=-8, x2=8, y2=4*8, layer=2}]=513, -- left canopy
					 [{x1=8, y1=-16, x2=7*8, y2=0, layer=2}]=512, -- top canopy
					 [{x1=8, y1=0, x2=7*8, y2=5*8, layer=2}]=511, -- middle canopy
					 [{x1=7*8, y1=-8, x2=8*8, y2=4*8, layer=2}]=514, -- right canopy
					 [{x1=0, y1=4*8, x2=8, y2=6*8, layer=0}]=503, --left trunk
					 [{x1=7*8, y1=4*8, x2=8*8, y2=6*8, layer=0}]=504, -- right trunk
					 [{x1=8, y1=5*8, x2=7*8, y2=7*8, layer=0}]=505, -- middle trunk
					 [{x1=16, y1=7*8, x2=6*8, y2=8*8, layer=0}]=523, -- bottom trunk
					 [{x1=8, y1=0, x2=7*8, y2=5*8, layer=0}]=502}, -- wall
	["small_green_tree"]={[{x1=0, y1=0, x2=32, y2=32, layer=0}]=526, required_size={x=32, y=32}},
	["tiny_yellow_tree"]={	[{x1=0, y1=-8, x2=16, y2=0, layer=1}]=1232,
							[{x1=0, y1=0, x2=16, y2=16, layer=0}]=951,
							required_size={x=16, y=16}},
	["small_lightgreen_tree"]={[{x1=0, y1=0, x2=32, y2=32, layer=0}]=527, required_size={x=32, y=32}},
	["tree_stump"]={[{x1=0, y1=0, x2=32, y2=32, layer=0}]=630, required_size={x=32, y=32}},
	["flower1"]={[{x1=0, y1=0, x2=16, y2=16, layer=0}]=42, required_size={x=16, y=16}},
	["flower2"]={[{x1=0, y1=0, x2=16, y2=16, layer=0}]=43, required_size={x=16, y=16}},
	["halfgrass"]={[{x1=0, y1=0, x2=16, y2=16, layer=0}]=36, required_size={x=16, y=16}},
	["fullgrass"]={[{x1=0, y1=0, x2=16, y2=16, layer=0}]=37, required_size={x=16, y=16}},
	["hole"] = {[{x1=0, y1=0, x2=16, y2=16, layer=0}]=825, required_size={x=16, y=16}},
	["impassable_rock_16x16"] = { 	[{x1=0, y1=0, x2=8, y2=8, layer=0}]=288, 
									[{x1=8, y1=0, x2=16, y2=8, layer=0}]=287, 
									[{x1=0, y1=8, x2=8, y2=16, layer=0}]=286, 
									[{x1=8, y1=8, x2=16, y2=16, layer=0}]=285, 
									required_size={x=16, y=16}},
	["impassable_rock_32x16"] = { 	[{x1=0, y1=0, x2=8, y2=8, layer=0}]=284, 
									[{x1=24, y1=0, x2=32, y2=8, layer=0}]=283, 
									[{x1=0, y1=8, x2=8, y2=16, layer=0}]=282, 
									[{x1=24, y1=8, x2=32, y2=16, layer=0}]=281,
									[{x1=8, y1=0, x2=24, y2=8, layer=0}]=265, 
									[{x1=8, y1=8, x2=24, y2=16, layer=0}]=266,
									required_size={x=32, y=16}},
	["impassable_rock_16x32"] = { 	[{x1=0, y1=0, x2=8, y2=8, layer=0}]=288, 
									[{x1=8, y1=0, x2=16, y2=8, layer=0}]=287, 
									[{x1=0, y1=24, x2=8, y2=32, layer=0}]=286, 
									[{x1=8, y1=24, x2=16, y2=32, layer=0}]=285,
									[{x1=0, y1=8, x2=8, y2=24, layer=0}]=273, 
									[{x1=8, y1=8, x2=16, y2=24, layer=0}]=274,
									required_size={x=16, y=32}},
	["big_statue"]={[{x1=0, y1=-16, x2=32, y2=0, layer=1}]=1230,
					[{x1=0, y1=0, x2=32, y2=32, layer=0}]=916,
					required_size={x=32, y=32}},
	["old_prison"]={required_size={x=48, y=48},
					[{x1=0, y1=0, x2=8, y2=8, layer=0}]=688, --topleft
					[{x1=8, y1=0, x2=40, y2=8, layer=0}]=689, --top
					[{x1=40, y1=0, x2=48, y2=8, layer=0}]=690, --topright
					[{x1=0, y1=8, x2=8, y2=24, layer=0}]=692, --left
					[{x1=8, y1=8, x2=40, y2=24, layer=0}]=696, --middle
					[{x1=40, y1=8, x2=48, y2=24, layer=0}]=691, --right
					[{x1=0, y1=24, x2=8, y2=32, layer=0}]=693, --bottomleft
					[{x1=8, y1=24, x2=40, y2=32, layer=0}]=694, --bottom
					[{x1=40, y1=24, x2=48, y2=32, layer=0}]=695, --bottomright
					[{x1=0, y1=32, x2=8, y2=48, layer=0}]=697, --leftwall
					[{x1=8, y1=32, x2=40, y2=48, layer=0}]=698, --windows
					[{x1=40, y1=32, x2=48, y2=48, layer=0}]=700, --rightwall
				   },
	["stone_hedge"]={required_size={x=32, y=32},
					[1]={	[{x1=8, y1=8, x2=24, y2=24, layer=0}]=696}, --middle
					[2]={	[{x1=0, y1=0, x2=8, y2=8, layer=0}]=795, --topleft
							[{x1=8, y1=0, x2=24, y2=8, layer=0}]=796, --top
							[{x1=24, y1=0, x2=32, y2=8, layer=0}]=797, --topright
							[{x1=0, y1=8, x2=8, y2=16, layer=0}]=798, --left
							[{x1=24, y1=8, x2=32, y2=16, layer=0}]=799, --right
							[{x1=8, y1=16, x2=24, y2=24, layer=0}]=794, --bottom
							[{x1=0, y1=16, x2=8, y2=32, layer=0}]=791, --leftwall
							[{x1=8, y1=24, x2=24, y2=32, layer=0}]=793, --middlewall
							[{x1=24, y1=16, x2=32, y2=32, layer=0}]=792, --rightwall
						}
					},
	["blue_block"]={[{x1=0, y1=0, x2=16, y2=16, layer=0}]=806, required_size={x=16, y=16}},

	-- cave props
	["bright_rock_64x64"]={required_size={x=64, y=64},
							[2]={[{x1=0, y1=0, x2=24, y2=24, layer=0}]=53, --topleft
								[{x1=40, y1=0, x2=64, y2=24, layer=0}]=54, --topright
								[{x1=0, y1=40, x2=24, y2=64, layer=0}]=55, --bottomleft
								[{x1=40, y1=40, x2=64, y2=64, layer=0}]=56, --bottomright
							},
							[1]={
								[{x1=16, y1=0, x2=48, y2=24, layer=0}]=52, --top
								[{x1=0, y1=16, x2=24, y2=48, layer=0}]=50, --left
								[{x1=24, y1=24, x2=40, y2=40, layer=0}]=170, --middle
								[{x1=40, y1=16, x2=64, y2=48, layer=0}]=51, --right
								[{x1=16, y1=40, x2=48, y2=64, layer=0}]=49, --bottom
							},
						   },
	["bright_rock_48x48"]={required_size={x=48, y=48},
							[2]={[{x1=0, y1=0, x2=24, y2=24, layer=0}]=53, --topleft
								[{x1=24, y1=0, x2=48, y2=24, layer=0}]=54, --topright
								[{x1=0, y1=24, x2=24, y2=48, layer=0}]=55, --bottomleft
								[{x1=24, y1=24, x2=48, y2=48, layer=0}]=56, --bottomright
							},
							[1]={
								[{x1=16, y1=0, x2=32, y2=24, layer=0}]=52, --top
								[{x1=0, y1=16, x2=24, y2=32, layer=0}]=50, --left
								[{x1=24, y1=16, x2=48, y2=32, layer=0}]=51, --right
								[{x1=16, y1=24, x2=32, y2=48, layer=0}]=49, --bottom
							},
						   },
    ["bright_rock_32x32"]={required_size={x=32, y=32},
							[1]={[{x1=0, y1=0, x2=24, y2=24, layer=0}]=53, --topleft
								[{x1=8, y1=0, x2=32, y2=24, layer=0}]=54, --topright
								[{x1=0, y1=8, x2=24, y2=32, layer=0}]=55, --bottomleft
								[{x1=8, y1=8, x2=32, y2=32, layer=0}]=56, --bottomright
							},
							[2]={
								[{x1=8, y1=8, x2=16, y2=16, layer=0}]=17, --topleft
								[{x1=16, y1=8, x2=24, y2=16, layer=0}]=16, --topright
								[{x1=8, y1=16, x2=16, y2=24, layer=0}]=15, --bottomleft
								[{x1=16, y1=16, x2=24, y2=24, layer=0}]=14, --bottomright
							},
						   },

	["dark_rock_64x64"]={required_size={x=64, y=64},
							[2]={[{x1=0, y1=0, x2=24, y2=24, layer=0}]=65, --topleft
								[{x1=40, y1=0, x2=64, y2=24, layer=0}]=66, --topright
								[{x1=0, y1=40, x2=24, y2=64, layer=0}]=67, --bottomleft
								[{x1=40, y1=40, x2=64, y2=64, layer=0}]=68, --bottomright
							},
							[1]={
								[{x1=16, y1=0, x2=48, y2=24, layer=0}]=226, --top
								[{x1=0, y1=16, x2=24, y2=48, layer=0}]=225, --left
								[{x1=24, y1=24, x2=40, y2=40, layer=0}]=481, --middle
								[{x1=40, y1=16, x2=64, y2=48, layer=0}]=227, --right
								[{x1=16, y1=40, x2=48, y2=64, layer=0}]=224, --bottom
							},
						   },
    ["dark_rock_48x48"]={required_size={x=48, y=48},
							[2]={[{x1=0, y1=0, x2=24, y2=24, layer=0}]=65, --topleft
								[{x1=24, y1=0, x2=48, y2=24, layer=0}]=66, --topright
								[{x1=0, y1=24, x2=24, y2=48, layer=0}]=67, --bottomleft
								[{x1=24, y1=24, x2=48, y2=48, layer=0}]=68, --bottomright
							},
							[1]={
								[{x1=16, y1=0, x2=32, y2=24, layer=0}]=226, --top
								[{x1=0, y1=16, x2=24, y2=32, layer=0}]=225, --left
								[{x1=24, y1=16, x2=48, y2=32, layer=0}]=227, --right
								[{x1=16, y1=24, x2=32, y2=48, layer=0}]=224, --bottom
							},
						   },
    ["dark_rock_32x32"]={required_size={x=32, y=32},
							[1]={[{x1=0, y1=0, x2=24, y2=24, layer=0}]=65, --topleft
								[{x1=8, y1=0, x2=32, y2=24, layer=0}]=66, --topright
								[{x1=0, y1=8, x2=24, y2=32, layer=0}]=67, --bottomleft
								[{x1=8, y1=8, x2=32, y2=32, layer=0}]=68, --bottomright
							},
							[2]={
								[{x1=8, y1=8, x2=16, y2=16, layer=0}]=215, --topleft
								[{x1=16, y1=8, x2=24, y2=16, layer=0}]=214, --topright
								[{x1=8, y1=16, x2=16, y2=24, layer=0}]=213, --bottomleft
								[{x1=16, y1=16, x2=24, y2=24, layer=0}]=212, --bottomright
							},
						   },
	["pipe_16x16_h"]={[{x1=0, y1=0, x2=8, y2=16, layer=0}]=486,
					[{x1=8, y1=0, x2=16, y2=16, layer=0}]=487,
					required_size={x=16, y=16}},
	["pipe_16x16_v"]={[{x1=0, y1=0, x2=16, y2=8, layer=0}]=488,
					[{x1=0, y1=8, x2=16, y2=16, layer=0}]=489,
					required_size={x=16, y=16}},
	["pipe_32x16_h"]={[{x1=0, y1=0, x2=8, y2=16, layer=0}]=486,
					[{x1=8, y1=0, x2=24, y2=16, layer=0}]=463,
					[{x1=24, y1=0, x2=32, y2=16, layer=0}]=487,
					required_size={x=32, y=16}},
	["pipe_16x32_v"]={[{x1=0, y1=0, x2=16, y2=8, layer=0}]=488,
					[{x1=0, y1=8, x2=16, y2=24, layer=0}]=464,
					[{x1=0, y1=24, x2=16, y2=32, layer=0}]=489,
					required_size={x=16, y=32}},
	["pipe_32x32_v"]={[1]={	[{x1=0, y1=0, x2=16, y2=16, layer=0}]=459,
							[{x1=16, y1=0, x2=32, y2=16, layer=0}]=460,
							[{x1=0, y1=16, x2=16, y2=32, layer=0}]=464,
							[{x1=16, y1=16, x2=32, y2=32, layer=0}]=464,
							},
					  [2]={	[{x1=0, y1=24, x2=16, y2=32, layer=0}]=489,
							[{x1=16, y1=24, x2=32, y2=32, layer=0}]=489},
							required_size={x=32, y=32}},
	["pipe_64x32_h"]={	[1]={	[{x1=0, y1=0, x2=16, y2=16, layer=0}]=464,
								[{x1=0, y1=16, x2=16, y2=32, layer=0}]=462,
								[{x1=16, y1=16, x2=32, y2=32, layer=0}]=461,
								[{x1=16, y1=0, x2=32, y2=16, layer=0}]=459,
								[{x1=32, y1=0, x2=48, y2=16, layer=0}]=460,
								[{x1=32, y1=16, x2=48, y2=32, layer=0}]=462,
								[{x1=48, y1=16, x2=64, y2=32, layer=0}]=461,
								[{x1=48, y1=0, x2=64, y2=16, layer=0}]=464,
							},
						[2]={	[{x1=0, y1=0, x2=16, y2=8, layer=0}]=488,
					  			[{x1=48, y1=0, x2=64, y2=8, layer=0}]=488},
						required_size={x=64, y=32}},

}


lookup.sign_to_0=[[
     To the mines
         --->
]]
lookup.sign_to_1=[[
     To the mines
          ^
          |
]]
lookup.sign_to_2=[[
     To the mines
        <---
]]
lookup.sign_to_3=[[
     To the mines
          |
          v
]]

lookup.sign_from_0=[[

    To the village
         --->
]]
lookup.sign_from_1=[[
    To the village
          ^
          |
]]
lookup.sign_from_2=[[
    To the village
        <---
]]
lookup.sign_from_3=[[
    To the village
          |
          v
]]

lookup.hint_stone_to_0=[[
To the mine back exit
         --->
]]
lookup.hint_stone_to_1=[[
To the mine back exit
          ^
          |
]]
lookup.hint_stone_to_2=[[
To the mine back exit
        <---
]]
lookup.hint_stone_to_3=[[
To the mine back exit
          |
          v
]]

lookup.hint_stone_from_0=[[
To the mine entrance
         --->
]]
lookup.hint_stone_from_1=[[
To the mine entrance
          ^
          |
]]
lookup.hint_stone_from_2=[[
To the mine entrance
        <---
]]
lookup.hint_stone_from_3=[[
To the mine entrance
          |
          v
]]

return lookup