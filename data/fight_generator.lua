local log 				= require("log")
local table_util 		= require("table_util")
local area_util 		= require("area_util")
local num_util 			= require("num_util")
local learningAlgorithms = require("learningAlgorithms")
local matrix			= require("matrix")
local tableserializer   = require("tableserializer")

-- Fight generator


-- initialize parameters
local fight_generator = {}
local lowestDifficulty = 3
local highestDifficulty = 5
local difficultyOfFights = lowestDifficulty
local everyEnemyDealsDamage = 2
local everyEnemyHasHealth = 3
local startLifeDifficulty = 0
local monsterAmountDifficulty = 0
local baseDifficulty = 0
local breedDifficulties = {	["minillosaur_egg_fixed"]	= 1,
							["snap_dragon"]				= 1,
							["blue_hardhat_beetle"]		= 1,
							["green_knight_soldier"]	= 1}


fight_generator.static_difficulty = false
fight_generator.fight_difficulty = 0
fight_generator.fighting = false

function fight_generator.set_monsterAmountDifficulty( i )
	monsterAmountDifficulty = i
end

-- prediction based on linear regression data, this can be expanded or replaced.
function makeDifficultyPrediction(room)
	return  2.3193 +
		   -0.9861 * room.fightFinished +
			0.03   * room.swordHits +
			0.0648 * room.lifeLostInRoom +
		   -0.0038 * room.standing +
			0.8371 * room.percentageStanding +
			0.0734 * (room.heroStates.free or 0) + 
		    0.3085 * (room.heroStates["back to solid ground"] or 0) 
end

local emptyRoom = {fightFinished=1, swordHits=0, explodeHits=0, thrownHits=0, monstersKilled=0, timeInRoom=0, surface=365, directionChange=0, 
			lifeLostInRoom=0, uselessKeys=0, monsterTypes={}, monsterTypesKilled={}, heroStates={}, 
			bowUse=0, appleUse=0, mirrorUse=0, bombUse=0, 
			swordClang=0,hasGlove=0,hasGlove2=0,
			hasBomb=0,moving=0, standing=0, percentageStanding=0, startingLife=24, intendedDifficulty=1, insideDungeon=0, pitfalls=0, spikes=0,
			--grass=0, whiteRock=0, 
			goingHero=0,countedGoingHero=0,averageAggro=0}
local roomContentsData = {{0,0,0,0,1}}
local roomDifficulties = {{makeDifficultyPrediction(emptyRoom)}}

local enemyTried = 1 -- To initialize the training data, we need to try every enemy.

-- keeps track of the areas already cleared
fight_generator.areastatus = {}

-- determine the type of fight generation algorithm to use
function fight_generator.prepare_enemies(game, map, hero, spawnAreas, split_table)
	local areanumber = split_table[3]
	local room_type = split_table[5]
	local enemiesInEncounter, resultingDiff
	if room_type == "BOSS" then 
		local hero = map:get_hero()
		if not game:get_value("bomb_bag__1") then hero:start_treasure("bomb_bag", 1, "bomb_bag__1") end
		local area = spawnAreas[1]
		enemiesInEncounter = {{name="generatedEnemy_"..areanumber.."_thisOne", boss=true, layer=0, x=(area.x1+area.x2)/2, y=(area.y1+area.y2)/2, direction=0, breed="papillosaur_king"}}
		resultingDiff = 6
	else
		if fight_generator.static_difficulty then 
			enemiesInEncounter, resultingDiff = fight_generator.make_static_fight(map, spawnAreas, areanumber)
		else
			enemiesInEncounter, resultingDiff = fight_generator.make(spawnAreas, difficultyOfFights, map, game:get_life(), areanumber) 
		end
	end

	local f = sol.file.open("userExperience.txt","a+"); f:write(difficultyOfFights .. "-difficulty\n"); f:flush(); f:close()
	local f = sol.file.open("userExperience.txt","a+"); f:write(resultingDiff .. "-intendedDifficulty\n"); f:flush(); f:close()

	return enemiesInEncounter
end

-- Add event for dying and set up initial logging
function fight_generator.setup_userexperience_and_logging(game, map, hero, areas, split_table)
	function hero:on_state_changed(state)
		if fight_generator.fighting then
			local f = sol.file.open("userExperience.txt","a+"); f:write(state .. "-hero\n"); f:flush(); f:close()
			if state == "hurt" and game:get_life() <= 2 and game:get_life() > 0 then
				-- player is dying now, log the room.
				local game = map:get_game()
				local f = sol.file.open("userExperience.txt","a+"); f:write(game:get_life() .. "-endlife\n"); f:flush(); f:close()
				local f = sol.file.open("userExperience.txt","a+"); f:write(os.time() .. "-endtime\n"); f:flush(); f:close()
				local f = sol.file.open("userExperience.txt","a+"); f:write("diedin-thefight\n"); f:flush(); f:close()
				analyseGameplaySoFar(map)
			end
		end
	end

	local f = sol.file.open("userExperience.txt","a+"); f:write(split_table[2] .. "-ofADungeon\n"); f:flush(); f:close()
	local f = sol.file.open("userExperience.txt","a+"); f:write(game:get_life() .. "-beginlife\n"); f:flush(); f:close()
	local f = sol.file.open("userExperience.txt","a+"); f:write(os.time() .. "-starttime\n"); f:flush(); f:close()
	local f = sol.file.open("userExperience.txt","a+"); f:write((game:get_value("glove__1") and 1 or 0) .. "-hasGlove\n"); f:flush(); f:close()
	local f = sol.file.open("userExperience.txt","a+"); f:write((game:get_value("glove__2") and 1 or 0) .. "-hasGlove2\n"); f:flush(); f:close()
	local f = sol.file.open("userExperience.txt","a+"); f:write((game:get_value("bomb_bag__1") and 1 or 0) .. "-hasBomb\n"); f:flush(); f:close()
	local f = sol.file.open("userExperience.txt","a+"); 
		f:write(areas["walkable"][tonumber(split_table[3])].contact_length["pitfall"] .. "-pits\n"); f:flush(); f:close()
	local f = sol.file.open("userExperience.txt","a+"); 
		f:write(areas["walkable"][tonumber(split_table[3])].contact_length["spikes"] .. "-spikes\n"); f:flush(); f:close()
	local f = sol.file.open("userExperience.txt","a+"); 
end

-- actually spawn the enemies that were determined earlier
function fight_generator.spawn_enemies(map, split_table, enemiesInEncounter)
	local areanumber = split_table[3]
	local room_type = split_table[5]
	for _,enemy in pairs(enemiesInEncounter) do
		local theEnemyIJustMade = map:create_enemy(enemy)
		if not enemy.boss then
			theEnemyIJustMade:set_life(everyEnemyHasHealth)
			theEnemyIJustMade:set_damage(everyEnemyDealsDamage)
			theEnemyIJustMade:set_treasure("random")
		else 
			sol.audio.play_music("boss")
		end
		local f = sol.file.open("userExperience.txt","a+") 
		f:write(theEnemyIJustMade:get_breed() .. "-spawned\n")
		f:flush(); f:close()
		
		function theEnemyIJustMade:on_hurt(attack)
			local f = sol.file.open("userExperience.txt","a+"); f:write(attack .. "-enemy\n"); f:flush(); f:close()
			-- returning false gives it back to the engine to handle
			return false
		end
		
		if split_table[5] == "BOSS" then
			function theEnemyIJustMade:on_dead()
				local f = sol.file.open("userExperience.txt","a+") 
				f:write(theEnemyIJustMade:get_breed() .. "-waskilled\n")
				f:flush(); f:close()
				explore.fight_finished( os.clock()-starttime )
				sol.audio.play_music("victory", false)
				fight_generator.areastatus[areanumber] = "done"
				map:open_doors("door_normal_area_".. split_table[3])
				difficultyOfFights = difficultyOfFights + 1
				if difficultyOfFights > highestDifficulty then difficultyOfFights = lowestDifficulty end
				local game = map:get_game()
				local f = sol.file.open("userExperience.txt","a+"); f:write(game:get_life() .. "-endlife\n"); f:flush(); f:close()
				local f = sol.file.open("userExperience.txt","a+"); f:write(os.time() .. "-endtime\n"); f:flush(); f:close()
				local f = sol.file.open("userExperience.txt","a+"); f:write("finished-thefight\n"); f:flush(); f:close()
				fight_generator.fighting = false
				analyseGameplaySoFar(map)
				return false
			end
		else
			function theEnemyIJustMade:on_dead()
				local f = sol.file.open("userExperience.txt","a+") 
				f:write(theEnemyIJustMade:get_breed() .. "-waskilled\n")
				f:flush(); f:close()
				
				if not map:has_entities("generatedEnemy_"..areanumber) then
					explore.fight_finished( os.clock()-starttime )
					map:open_doors("door_normal_area_".. split_table[3])
					fight_generator.areastatus[areanumber] = "done"
					difficultyOfFights = difficultyOfFights + 1
					if difficultyOfFights > highestDifficulty then difficultyOfFights = lowestDifficulty end
					local game = map:get_game()
					local f = sol.file.open("userExperience.txt","a+"); f:write(game:get_life() .. "-endlife\n"); f:flush(); f:close()
					local f = sol.file.open("userExperience.txt","a+"); f:write(os.time() .. "-endtime\n"); f:flush(); f:close()
					local f = sol.file.open("userExperience.txt","a+"); f:write("finished-thefight\n"); f:flush(); f:close()
					fight_generator.fighting = false
					analyseGameplaySoFar(map)
				end
				return false
			end
		end
	end
end

-- Add spawn effect to the sensors made by the space generator
function fight_generator.add_effects_to_sensors (map, areas, area_details)
	sensorSide = "areasensor_inside_"
	if area_details.outside then sensorSide = "areasensor_outside_" end

	for sensor in map:get_entities(sensorSide) do
		-- areasensor_<inside/outside>_5_type_<F for fights>
		local sensorname = sensor:get_name()
		local split_table = table_util.split(sensorname, "_")
		local room_type = split_table[5]
		local areanumber = split_table[3]
		
		if room_type == "F" or room_type == "TF" or room_type == "BOSS" then 
			
			sensor.on_activated = 
				function()
					local split_table = split_table
					
					local game = map:get_game()
					local hero = map:get_hero()
					starttime = os.clock()
					map:open_doors("door_normal_area_")

					if fight_generator.areastatus[areanumber] == "done" then 
						return false 
					elseif fight_generator.areastatus[areanumber] == "spawned" then	
						local f = sol.file.open("userExperience.txt","a+"); f:write(sensor:get_name() .. "\n"); f:flush(); f:close()
					elseif fight_generator.areastatus[areanumber] == nil then
						local f = sol.file.open("userExperience.txt","a+"); f:write(sensor:get_name() .. "\n"); f:flush(); f:close()
						explore.fight_encountered( )
						local spawnAreas = areas["walkable"][tonumber(split_table[3])].open_areas
						fight_generator.areastatus[areanumber] = "spawned"
						map:close_doors("door_normal_area_"..split_table[3])
						local enemiesInEncounter = fight_generator.prepare_enemies(game, map, hero, spawnAreas, split_table)
						fight_generator.spawn_enemies(map, split_table, enemiesInEncounter)
					end	
					fight_generator.fighting = true
					fight_generator.setup_userexperience_and_logging(game, map, hero, areas, split_table)
					
					if not map:has_entities("generatedEnemy_"..areanumber) then 
						explore.fight_finished( os.clock()-starttime )
						map:open_doors("door_normal_area_"..split_table[3])
						fight_generator.areastatus[areanumber] = "done"
						difficultyOfFights = difficultyOfFights + 1
						if difficultyOfFights > highestDifficulty then difficultyOfFights = lowestDifficulty end
						local game = map:get_game()
						local f = sol.file.open("userExperience.txt","a+"); f:write(game:get_life() .. "-endlife\n"); f:flush(); f:close()
						local f = sol.file.open("userExperience.txt","a+"); f:write(os.time() .. "-endtime\n"); f:flush(); f:close()
						local f = sol.file.open("userExperience.txt","a+"); f:write("finished-thefight\n"); f:flush(); f:close()
						fight_generator.fighting = false
						analyseGameplaySoFar(map)
						
					end
					return false
					
				end

			local outside_sensor = map:get_entity("areasensor_outside_"..split_table[3].."_type_"..split_table[5])
			outside_sensor.on_left = 
				function()
					last_areanumber_triggered = -1
					if map:has_entities("generatedEnemy_"..areanumber) then
						difficultyOfFights = difficultyOfFights + 1
						if difficultyOfFights > highestDifficulty then difficultyOfFights = lowestDifficulty end
						local game = map:get_game()
						local f = sol.file.open("userExperience.txt","a+"); f:write(game:get_life() .. "-endlife\n"); f:flush(); f:close()
						local f = sol.file.open("userExperience.txt","a+"); f:write(os.time() .. "-endtime\n"); f:flush(); f:close()
						local f = sol.file.open("userExperience.txt","a+"); f:write("ranawayfrom-thefight\n"); f:flush(); f:close()
						fight_generator.fighting = false
						analyseGameplaySoFar(map)
					end
				end
		end
				
	end
end

-- analyse gameplay so far using the logging
function analyseGameplaySoFar(map)
	local f = sol.file.open("userExperience.txt","r")
	local room = table_util.copy( emptyRoom )

	while true do
		local line = f:read("*line")
		if not line then break end
		
		local splitLine = table_util.split(line, "-")
		if line=="sword-enemy" then room.swordHits = room.swordHits + 1 end
		if line=="thrown_item-enemy" then room.thrownHits = room.thrownHits + 1 end
		if line=="explosion-enemy" then room.explodeHits = room.explodeHits + 1 end
		if line=="swords-clang" then room.swordClang = room.swordClang + 1 end
		if splitLine[2] == "hero" then 
			if room.heroStates[splitLine[1]] == nil then room.heroStates[splitLine[1]] = 1 
			else room.heroStates[splitLine[1]] = room.heroStates[splitLine[1]] + 1 end
		end

		if splitLine[2] == "spawned" then 
			if room.monsterTypes[splitLine[1]] == nil then room.monsterTypes[splitLine[1]] = 1
			else room.monsterTypes[splitLine[1]] = room.monsterTypes[splitLine[1]] + 1 end
		end
		if splitLine[2] == "waskilled" then 
			room.monstersKilled = room.monstersKilled + 1 
			if room.monsterTypesKilled[splitLine[1]] == nil then room.monsterTypesKilled[splitLine[1]] = 1
			else room.monsterTypesKilled[splitLine[1]] = room.monsterTypesKilled[splitLine[1]] + 1 end
		end
		if line == "apple-used" then room.appleUse = room.appleUse + 1 end
		if line == "mirror-used" then room.mirrorUse = room.mirrorUse + 1 end
		if line == "bow-used" then room.bowUse = room.bowUse + 1 end
		if line == "bomb-used" then room.bombUse = room.bombUse + 1 end
		if line == "moving around" then room.moving = room.moving + 1 end
		if line == "standing still" then room.standing = room.standing + 1 end
		if string.find(line, "beginlife") then 
			local game = map:get_game()
			room.lifeLostInRoom = tonumber (splitLine[1]) - game:get_life()
			room.startingLife = tonumber (splitLine[1])
		end
		if string.find(line, "thefight") then 
			room.fightFinished = (splitLine[1] == "finished") and 1 or 0
			room.fightFinished = room.fightFinished - ( (splitLine[1] == "diedin") and 1 or 0 )
		end
		if string.find(line, "ofADungeon") then room.insideDungeon = (splitLine[1] == "inside") and 1 or 0 end
		if string.find(line, "starttime") then room.timeInRoom = os.time() - tonumber (splitLine[1]) end
		if string.find(line, "spawnSurface") then room.surface = tonumber (splitLine[1]) end
		if line=="right-keypress" or line=="left-keypress" or line=="up-keypress" or line=="down-keypress" then 
			room.directionChange = room.directionChange + 1
		end
		if splitLine[2] == "keypress" and splitLine[1]~="right" and splitLine[1]~="left" and splitLine[1]~="up" and splitLine[1]~="down" 
				and splitLine[1]~="c" and splitLine[1]~="space" and splitLine[1]~="x" and splitLine[1]~="v" and splitLine[1]~="d" then 
			room.uselessKeys = room.uselessKeys + 1
		end
		if string.find(line, "areasensor") or string.find(line, "A NEW GAME IS STARTING NOW") then room = table_util.copy( emptyRoom ) end	
		
		if splitLine[2] == "intendedDifficulty" then room.intendedDifficulty = tonumber (splitLine[1]) end
		if splitLine[2] == "hasGlove" then room.hasGlove = tonumber (splitLine[1]) end
		if splitLine[2] == "hasGlove2" then room.hasGlove2 = tonumber (splitLine[1]) end
		if splitLine[2] == "hasBomb" then room.hasBomb = tonumber (splitLine[1]) end
		if splitLine[2] == "pits" then room.pitfalls = tonumber (splitLine[1]) end
		if splitLine[2] == "spikes" then room.spikes = tonumber (splitLine[1]) end
		-- if splitLine[2] == "grass" then room.grass = tonumber (splitLine[1]) end
		-- if splitLine[2] == "whiteRock" then room.whiteRock = tonumber (splitLine[1]) end
		
		if splitLine[2] == "goingHero" then 
			room.goingHero = room.goingHero + tonumber (splitLine[1])
			room.countedGoingHero = room.countedGoingHero + 1
		end
		
	end
	if (room.moving+room.standing) ~= 0 then room.percentageStanding = room.standing/(room.moving+room.standing) end
	if (room.countedGoingHero) ~= 0 then room.averageAggro = room.goingHero/room.countedGoingHero end
	
	f:flush(); f:close()
	logTheRoom (room)
	
	if enemyTried >= 5 then 
		table.save(roomContentsData, "roomdata"..game:get_value("saveslot")) 
		table.save(roomDifficulties, "roomdiff"..game:get_value("saveslot")) 
	end
	
	updateMonsterOffset()
	local weights = learningAlgorithms.linearRegression(roomContentsData, roomDifficulties)
	if weights then updateWeights( weights ) end
end

-- offset the difficulty for a certain amount of fights
function updateMonsterOffset()
	local new_offset = 1.0-((#roomContentsData-5)*0.1) -- at least 4 tutorial and 10 generated examples and 1 base example before fully relying on the algorithm
	if new_offset < 0 then new_offset = 0 end
	monsterAmountDifficulty = new_offset
end

function updateWeights (weights)
	breedDifficulties["minillosaur_egg_fixed"] = weights[1][1]
	breedDifficulties["snap_dragon"] = weights[2][1]
	breedDifficulties["blue_hardhat_beetle"] = weights[3][1]
	breedDifficulties["green_knight_soldier"] = weights[4][1]
	baseDifficulty = weights[5][1] 
end

-- import weights from save file
function fight_generator.importWeights()
	if sol.file.exists("roomdata"..game:get_value("saveslot")) and sol.file.exists("roomdiff"..game:get_value("saveslot")) then
		roomContentsData = table.load("roomdata"..game:get_value("saveslot"))
		roomDifficulties = table.load("roomdiff"..game:get_value("saveslot"))
		updateMonsterOffset()
		local weights = learningAlgorithms.linearRegression(roomContentsData, roomDifficulties)
		updateWeights( weights )
		enemyTried = 5
	end
end

function absolute( number )
	if number < 0 then return -number else return number end
end

function logTheRoom (room) 
	local fightRoomData = {}
	local playerBehaviourData = {}
	local bias = 1
	
	-- name,mapID,egg,snap_dragon,hardhat,knight,papillosaur,startLife,hasBow,hasMirror,hasFairyBottle,hasGlove,hasGlove2,hasBomb,pitfalls,spikes,inside,surface
	fightRoomData[#fightRoomData+1] = game:get_player_name()
	fightRoomData[#fightRoomData+1] = map:get_id()
	fightRoomData[#fightRoomData+1] = room.monsterTypes.minillosaur_egg_fixed or 0
	fightRoomData[#fightRoomData+1] = room.monsterTypes.snap_dragon or 0
	fightRoomData[#fightRoomData+1] = room.monsterTypes.blue_hardhat_beetle or 0
	fightRoomData[#fightRoomData+1] = room.monsterTypes.green_knight_soldier or 0
	fightRoomData[#fightRoomData+1] = room.monsterTypes.papillosaur_king or 0
	fightRoomData[#fightRoomData+1] = room.startingLife
	fightRoomData[#fightRoomData+1] = (game:get_value("bow") and 1 or 0)
	fightRoomData[#fightRoomData+1] = (game:get_value("magic_aoe") and 1 or 0)
	fightRoomData[#fightRoomData+1] = (game:get_first_bottle_with(6) and 1 or 0)
	fightRoomData[#fightRoomData+1] = room.hasGlove
	fightRoomData[#fightRoomData+1] = room.hasGlove2
	fightRoomData[#fightRoomData+1] = room.hasBomb
	fightRoomData[#fightRoomData+1] = room.pitfalls
	fightRoomData[#fightRoomData+1] = room.spikes
	-- fightRoomData[#fightRoomData+1] = room.grass + room.whiteRock + room.blackRock
	fightRoomData[#fightRoomData+1] = room.insideDungeon
	fightRoomData[#fightRoomData+1] = room.surface
	
	-- finished,swordHits,bombUsage,bowUsage,mirrorUsage,appleUsage,explodeHits,thrownHits,time,dirChange,lifeLost,clangs,uselessKeys,moving,standing,percStanding,avgAggro
	playerBehaviourData[#playerBehaviourData+1] = room.fightFinished
	playerBehaviourData[#playerBehaviourData+1] = room.swordHits
	playerBehaviourData[#playerBehaviourData+1] = room.bombUse
	playerBehaviourData[#playerBehaviourData+1] = room.bowUse
	playerBehaviourData[#playerBehaviourData+1] = room.mirrorUse
	playerBehaviourData[#playerBehaviourData+1] = room.appleUse
	playerBehaviourData[#playerBehaviourData+1] = room.explodeHits
	playerBehaviourData[#playerBehaviourData+1] = room.thrownHits
	playerBehaviourData[#playerBehaviourData+1] = room.timeInRoom
	playerBehaviourData[#playerBehaviourData+1] = room.directionChange
	playerBehaviourData[#playerBehaviourData+1] = room.lifeLostInRoom
	playerBehaviourData[#playerBehaviourData+1] = room.swordClang
	playerBehaviourData[#playerBehaviourData+1] = room.uselessKeys
	playerBehaviourData[#playerBehaviourData+1] = room.moving
	playerBehaviourData[#playerBehaviourData+1] = room.standing
	playerBehaviourData[#playerBehaviourData+1] = room.percentageStanding
	playerBehaviourData[#playerBehaviourData+1] = room.averageAggro
	
	-- killEgg,killsnap_dragon,killHardhat,killKnight
	playerBehaviourData[#playerBehaviourData+1] = room.monsterTypesKilled.minillosaur_egg_fixed or 0
	playerBehaviourData[#playerBehaviourData+1] = room.monsterTypesKilled.snap_dragon or 0
	playerBehaviourData[#playerBehaviourData+1] = room.monsterTypesKilled.blue_hardhat_beetle or 0
	playerBehaviourData[#playerBehaviourData+1] = room.monsterTypesKilled.green_knight_soldier or 0

	-- free,freezed,grabbing,hurt,stairs,loading,spin,swing,tap,carry,lift,treasure,useItem,falling,backOnFeet
	playerBehaviourData[#playerBehaviourData+1] = room.heroStates.free or 0
	playerBehaviourData[#playerBehaviourData+1] = room.heroStates.freezed or 0
	playerBehaviourData[#playerBehaviourData+1] = room.heroStates.grabbing or 0
	playerBehaviourData[#playerBehaviourData+1] = room.heroStates.hurt or 0
	playerBehaviourData[#playerBehaviourData+1] = room.heroStates.stairs or 0
	playerBehaviourData[#playerBehaviourData+1] = room.heroStates["sword loading"] or 0
	playerBehaviourData[#playerBehaviourData+1] = room.heroStates["sword spin attack"] or 0
	playerBehaviourData[#playerBehaviourData+1] = room.heroStates["sword swinging"] or 0
	playerBehaviourData[#playerBehaviourData+1] = room.heroStates["sword tapping"] or 0
	playerBehaviourData[#playerBehaviourData+1] = room.heroStates["carrying"] or 0
	playerBehaviourData[#playerBehaviourData+1] = room.heroStates["lifting"] or 0
	playerBehaviourData[#playerBehaviourData+1] = room.heroStates["treasure"] or 0
	playerBehaviourData[#playerBehaviourData+1] = room.heroStates["using item"] or 0
	playerBehaviourData[#playerBehaviourData+1] = room.heroStates["falling"] or 0
	playerBehaviourData[#playerBehaviourData+1] = room.heroStates["back to solid ground"] or 0
	
	-- The following aren't being logged because they are not very useful for now.
	--"boomerang", "bow", "forced walking", "hookshot", "jumping", 
	--"plunging", "pulling", "pushing", "running", "stream", "swimming", "victory"
	
	roomDifficultyPrediction = { makeDifficultyPrediction(room) }
	roomDifficultyIntention = { room.intendedDifficulty }
	
	writeTableToFile (fightRoomData, "roomSummaries.csv")
	local f = sol.file.open("roomSummaries.csv","a+"); f:write(","); f:flush(); f:close()
	writeTableToFile (playerBehaviourData, "roomSummaries.csv")
	local f = sol.file.open("roomSummaries.csv","a+"); f:write(","); f:flush(); f:close()
	writeTableToFile (roomDifficultyPrediction, "roomSummaries.csv")
	local f = sol.file.open("roomSummaries.csv","a+"); f:write(","); f:flush(); f:close()
	writeTableToFile (roomDifficultyIntention, "roomSummaries.csv")
	local f = sol.file.open("roomSummaries.csv","a+"); f:write("\n"); f:flush(); f:close()
	
	roomContentsData[#roomContentsData+1] = {room.monsterTypesKilled.minillosaur_egg_fixed or 0, room.monsterTypesKilled.snap_dragon or 0, 
											room.monsterTypesKilled.blue_hardhat_beetle or 0, room.monsterTypesKilled.green_knight_soldier or 0,
											bias}
	roomDifficulties[#roomDifficulties+1] = roomDifficultyPrediction
	
end

function writeTableToFile (dataTable, file) 
	local f = sol.file.open(file,"a+")
	for k,v in pairs(dataTable) do
		f:write(v)
		if k ~= #dataTable then f:write(",") end
	end
	f:flush(); f:close()
end

function chooseAreaToSpawn(spawnAreas, hero, center)
	local chosenArea = table_util.random(spawnAreas)
	local xPos = math.random(chosenArea.x1+13, chosenArea.x2-13)
	local yPos = math.random(chosenArea.y1+13, chosenArea.y2-13)
	while hero:get_distance(xPos, yPos) <= 100 or ( area_util.get_area_size(chosenArea).size <= 16*16 ) do
		chosenArea = table_util.random(spawnAreas)
		if center then 
			xPos = (chosenArea.x1 + chosenArea.x2 / 2)
			yPos = (chosenArea.y1 + chosenArea.y2 / 2)
		else
			xPos = math.random(chosenArea.x1+13, chosenArea.x2-13)
			yPos = math.random(chosenArea.y1+13, chosenArea.y2-13)
		end
	end
	return xPos, yPos
end

-- Determine the enemies to spawn for dynamic difficulty
function fight_generator.make(areas, maxDiff, map, currentLife, areanumber) 

	local breedOptions={"minillosaur_egg_fixed","snap_dragon","blue_hardhat_beetle","green_knight_soldier"}	
	local hero = map:get_hero()
	local spawnAreas = areas
	
	local totalSurface = 0
	for _, area in ipairs(areas) do totalSurface = totalSurface + absolute ( area.x1-area.x2 ) * absolute ( area.y1-area.y2 ) end
	totalSurface = totalSurface / 64
	local f = sol.file.open("userExperience.txt","a+"); f:write(totalSurface .. "-spawnSurface\n"); f:flush(); f:close()
	
	if enemyTried <= 4 then 
		local xPos, yPos = chooseAreaToSpawn(spawnAreas, hero)
		local chosenBreed = breedOptions[enemyTried]
		enemyTried=enemyTried+1
		return {{name="generatedEnemy_areanumber_".. areanumber .."_thisOne", layer=0, x=xPos, y=yPos, direction=0, breed=chosenBreed}}, breedDifficulties[chosenBreed]
	end
	
	if enemyTried == 5 then enemyTried=6; difficultyOfFights = lowestDifficulty end

	local difficulty = baseDifficulty + startLifeDifficulty * currentLife
	local enemiesInFight = {}
	
	-- For testing purposes only, to diversify the data.
	-- local randomBadRoom = math.random()
	-- if randomBadRoom > 0.96 then maxDiff = 7 end
	-- if randomBadRoom < 0.04 then maxDiff = 2 end
	-- -- Remove these three lines when testing is done.
	
	while difficulty < maxDiff do
		local xPos, yPos = chooseAreaToSpawn(spawnAreas, hero)
		
		local chosenBreed = breedOptions[math.random(1,#breedOptions)] 
		local chosenDifficulty = breedDifficulties[chosenBreed]
		if chosenDifficulty <= 0 then chosenDifficulty = 1 end
		
		local iterations = 0
		while absolute( maxDiff - (difficulty+chosenDifficulty+monsterAmountDifficulty) ) >= absolute( maxDiff - difficulty ) do
			iterations = iterations + 1
			if iterations > 40 then break end
			chosenBreed = breedOptions[math.random(1,#breedOptions)] 
			chosenDifficulty = breedDifficulties[chosenBreed]
			if chosenDifficulty <= 0.1 then chosenDifficulty = 1 end
		end
		
		local offBy = absolute( maxDiff - (difficulty+chosenDifficulty+monsterAmountDifficulty) )
		iterations = 0
		while (difficulty+chosenDifficulty+monsterAmountDifficulty) > maxDiff do
			iterations = iterations + 1
			if iterations > 40 then break end
			local altBreed = breedOptions[math.random(1,#breedOptions)] 
			local altDifficulty = breedDifficulties[altBreed]
			if altDifficulty <= 0 then altDifficulty = 1 end
			if absolute( maxDiff - (difficulty+altDifficulty+monsterAmountDifficulty) ) < offBy then
				chosenBreed = altBreed; chosenDifficulty = altDifficulty
			end
		end
		
		-- monster = {name, layer, x,y, direction, breed,rank,savegame_variable, treasure_name,treasure_variant,treasure_savegame_variable}
		table.insert(enemiesInFight,{name="generatedEnemy_"..areanumber.."_thisOne", layer=0, x=xPos, y=yPos, direction=0, breed=chosenBreed})
		difficulty = difficulty + chosenDifficulty + monsterAmountDifficulty
	end
	return enemiesInFight, difficulty
end

-- Determine the enemies to spawn for static difficulty
function fight_generator.make_static_fight(map, spawnAreas, areanumber)
	local breedOptions={"minillosaur_egg_fixed","snap_dragon","blue_hardhat_beetle","green_knight_soldier"}	
	local hero = map:get_hero()
	local map_id = tonumber(map:get_id())
	local breedSelections = {}
	local enemiesInFight = {}
	local difficulty = 0
	if fight_generator.fight_difficulty == 2 then
		local options = { {1, 1, 1, 1}, {4, 4}, {2, 2, 2} }
		breedSelections = table_util.random(options)
		difficulty = 2
	elseif fight_generator.fight_difficulty == 3 then
		local options = {{1, 1, 1, 1, 1, 1}, {4, 4, 4}, {2, 2, 2, 2, 2}}
		breedSelections = table_util.random(options)
		difficulty = 3
	elseif fight_generator.fight_difficulty == 4 then
		local options = {{1, 1, 1, 1, 1, 1, 1, 1}, {2, 2, 2, 2, 2, 2}, {4, 4, 4, 4}}
		breedSelections = table_util.random(options)
		difficulty = 4
	elseif fight_generator.fight_difficulty == 5 then
		local options = {{3, 3, 3, 3, 3}, {1, 1, 1, 1, 1, 1, 1, 1, 3, 3}, {2, 2, 2, 2, 2, 2, 3, 3}, {4, 4, 4, 4, 3, 3} }
		breedSelections = table_util.random(options)
		difficulty = 5
	end
	for i, chosenBreed in ipairs(breedSelections) do
		local xPos, yPos = chooseAreaToSpawn(spawnAreas, hero)
		-- monster = {name, layer, x,y, direction, breed,rank,savegame_variable, treasure_name,treasure_variant,treasure_savegame_variable}
		table.insert(enemiesInFight,{name="generatedEnemy_"..areanumber.."_thisOne", layer=0, x=xPos, y=yPos, direction=0, breed=breedOptions[chosenBreed]})
	end

	local totalSurface = 0
	for _, area in ipairs(spawnAreas) do totalSurface = totalSurface + absolute ( area.x1-area.x2 ) * absolute ( area.y1-area.y2 ) end
	totalSurface = totalSurface / 64
	local f = sol.file.open("userExperience.txt","a+"); f:write(totalSurface .. "-spawnSurface\n"); f:flush(); f:close()

	return enemiesInFight, difficulty
end

return fight_generator