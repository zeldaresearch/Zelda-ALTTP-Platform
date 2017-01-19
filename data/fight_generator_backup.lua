local log 				= require("log")
local table_util 		= require("table_util")
local area_util 		= require("area_util")
local num_util 			= require("num_util")
local learningAlgorithms = require("learningAlgorithms")
local matrix			= require("matrix")

local fight_generator = {}
local lowestDifficulty = 2
local highestDifficulty = 5
local difficultyOfFights = lowestDifficulty
local everyEnemyDealsDamage = 2
local everyEnemyHasHealth = 3
local baseStress = 1.3787
local startLifeDifficulty = 0
local monsterAmountDifficulty = 0.2
local baseDifficulty = 0
local breedDifficulties = {	["minillosaur_egg_fixed"]	= 1,
							["snap_dragon"]				= 1,
							["blue_hardhat_beetle"]		= 1,
							["green_knight_soldier"]	= 1}
							
local roomContentsData = {{0,0,0,0,1}}
local roomDifficulties = {{baseStress}}
		
local enemyTried = 1 -- To initialize the training data, we need to try every enemy.
local starttime = 0

fight_generator.static_difficulty = false
fight_generator.difficulty = 0
local f = nil

function fight_generator.died()
	f = sol.file.open("userExperience.txt","a+")
	-- player is dying now, log the room.
	local game = map:get_game()
	 f:write(game:get_life() .. "-endlife\n")
	 f:write(os.time() .. "-endtime\n")
	 f:write("diedin-thefight\n")
	 f:flush()
	 f:close(); f = nil
	 map:open_doors("door_normal_area_")
	 hero.on_state_changed = nil
	analyseGameplaySoFar(map)
end

function fight_generator.make_static_fight(map, spawnAreas)
	local breedOptions={"minillosaur_egg_fixed","snap_dragon","blue_hardhat_beetle","green_knight_soldier"}	
	local hero = map:get_hero()
	local map_id = tonumber(map:get_id())
	local breedSelections = {}
	local enemiesInFight = {}
	local difficulty = 0
	if map_id == 0 or fight_generator.difficulty == 2 then
		local options = { {1, 1, 1, 1}, {4, 4}, {2, 2, 2}, {3, 3}}
		breedSelections = table_util.random(options)
		difficulty = 2
	elseif map_id == 1 or fight_generator.difficulty == 3 then
		local options = {{1, 1, 1, 1, 1, 1}, {4, 4, 4}, {2, 2, 2, 2, 2}, {3, 3, 3}}
		breedSelections = table_util.random(options)
		difficulty = 3
	elseif map_id == 2 or fight_generator.difficulty == 4 then
		local options = {{1, 1, 1, 1, 1, 1, 1, 1}, {2, 2, 2, 2, 2, 2}, {4, 4, 4, 4}, {3, 3, 3, 3}}
		breedSelections = table_util.random(options)
		difficulty = 4
	elseif map_id == 3 or fight_generator.difficulty == 5 then
		local options = {{3, 3, 3, 3, 3}, {1, 1, 1, 1, 1, 1, 1, 1, 3, 3}, {2, 2, 2, 2, 2, 2, 3, 3}, {4, 4, 4, 4, 3, 3} }
		breedSelections = table_util.random(options)
		difficulty = 5
	end
	for i, chosenBreed in ipairs(breedSelections) do
		local xPos, yPos = chooseAreaToSpawn(spawnAreas, hero)
		-- monster = {name, layer, x,y, direction, breed,rank,savegame_variable, treasure_name,treasure_variant,treasure_savegame_variable}
		table.insert(enemiesInFight,{name="generatedEnemy_thisOne", layer=0, x=xPos, y=yPos, direction=0, breed=breedOptions[chosenBreed]})
	end
	
	return enemiesInFight, difficulty
end

function fight_generator.add_effects_to_sensors (map, areas, area_details)
	sensorSide = "areasensor_inside_"
	if area_details.outside then sensorSide = "areasensor_outside_" end

	for sensor in map:get_entities(sensorSide) do
		-- areasensor_<inside/outside>_5_type_<F for fights>
		local sensorname = sensor:get_name()
		local split_table = table_util.split(sensorname, "_")
		
		if split_table[5] == "F" or split_table[5] == "TF" or split_table[5] == "BOSS" then 
		
			sensor.on_activated = 
				function()
					f = sol.file.open("userExperience.txt","a+")
					explore.fight_encountered( )
					starttime = os.clock()
					local game = map:get_game()
					local hero = map:get_hero()
					function hero:on_state_changed(state)
						local file_open = sol.file.open("userExperience.txt","a+")
						file_open:write(state .. "-hero\n")
						if state == "hurt" and game:get_life() <= 2 and game:get_life() > 0 then
							fight_generator.died()
							map:open_doors("door_normal_area_".. split_table[3])
						end
						file_open:flush();file_open:close()
						return false
					end
					
					 f:write(sensor:get_name() .. "\n")
					 f:write(split_table[2] .. "-ofADungeon\n")
					 f:write(game:get_life() .. "-beginlife\n")
					 f:write(os.time() .. "-starttime\n")
					 f:write((game:get_value("glove__1") and 1 or 0) .. "-hasGlove\n")
					 f:write((game:get_value("glove__2") and 1 or 0) .. "-hasGlove2\n")
					 f:write((game:get_value("bomb_bag__1") and 1 or 0) .. "-hasBomb\n")
					 
					f:write(areas["walkable"][tonumber(split_table[3])].contact_length["pitfall"] .. "-pits\n")
				 
					f:write(areas["walkable"][tonumber(split_table[3])].contact_length["spikes"] .. "-spikes\n")
				 
					f:write(areas["walkable"][tonumber(split_table[3])].throwables.white_rock .. "-whiteRock\n")
				 
					f:write(areas["walkable"][tonumber(split_table[3])].throwables.bush .. "-grass\n")
					local split_table = split_table
					
					for enemy in map:get_entities("generatedEnemy") do enemy:remove() end
					local spawnAreas = areas["walkable"][tonumber(split_table[3])].open_areas
					local enemiesInEncounter, resultingDiff
					local diff = difficultyOfFights
					 f:write(diff .. "-difficulty\n")
					if fight_generator.static_difficulty then 
						enemiesInEncounter, resultingDiff = fight_generator.make_static_fight(map, spawnAreas)
					else
						enemiesInEncounter, resultingDiff = fight_generator.make(spawnAreas, diff, map, game:get_life()) 
					end
					if split_table[5] == "BOSS" then 
						local hero = map:get_hero()
						if not game:get_value("bomb_bag__1") then hero:start_treasure("bomb_bag", 1, "bomb_bag__1") end
						local area = areas["walkable"][tonumber(split_table[3])].area
						enemiesInEncounter = {{name="generatedEnemy_thisOne", boss=true, layer=0, x=(area.x1+area.x2)/2, y=(area.y1+area.y2)/2, direction=0, breed="papillosaur_king"}}
						resultingDiff = 6
					end
					
					 f:write(resultingDiff .. "-intendedDifficulty\n")
					 f:flush()
					for _,enemy in pairs(enemiesInEncounter) do
						local theEnemyIJustMade = map:create_enemy(enemy)
						if not enemy.boss then
							theEnemyIJustMade:set_life(everyEnemyHasHealth)
							theEnemyIJustMade:set_damage(everyEnemyDealsDamage)
							theEnemyIJustMade:set_treasure("random")
						end
						f:write(theEnemyIJustMade:get_breed() .. "-spawned\n")
						
						function theEnemyIJustMade:on_hurt(attack)
							if f ~= nil then f:write(attack .. "-enemy\n") end
							-- returning false gives it back to the engine to handle
							return false
						end
						
						if split_table[5] == "BOSS" then
							function theEnemyIJustMade:on_dead()
								local f = sol.file.open("userExperience.txt","a+")
								explore.fight_finished( os.clock()-starttime )
								f:write(theEnemyIJustMade:get_breed() .. "-waskilled\n")

								map:open_doors("door_normal_area_".. split_table[3])
								difficultyOfFights = difficultyOfFights + 1
								if difficultyOfFights > highestDifficulty then difficultyOfFights = lowestDifficulty end
								local game = map:get_game()
								 f:write(game:get_life() .. "-endlife\n")
								 f:write(os.time() .. "-endtime\n")
								 f:write("finished-thefight\n")
								 f:flush()
								 f:close(); f = nil
								 hero.on_state_changed = nil
								analyseGameplaySoFar(map)
								return false
							end
						else
							function theEnemyIJustMade:on_dead()
								local f = sol.file.open("userExperience.txt","a+")
								f:write(theEnemyIJustMade:get_breed() .. "-waskilled\n")
								
								if not map:has_entities("generatedEnemy") then
									explore.fight_finished( os.clock()-starttime )
									map:open_doors("door_normal_area_".. split_table[3])
									
									difficultyOfFights = difficultyOfFights + 1
									if difficultyOfFights > highestDifficulty then difficultyOfFights = lowestDifficulty end
									local game = map:get_game()
									 f:write(game:get_life() .. "-endlife\n")
									 f:write(os.time() .. "-endtime\n")
									 f:write("finished-thefight\n")
									 f:flush()
									 f:close(); f = nil
									 hero.on_state_changed = nil
									analyseGameplaySoFar(map)
								end
								return false
							end
						end
					end
					map:close_doors("door_normal_area_"..split_table[3])
					
					if not map:has_entities("generatedEnemy") then 
						explore.fight_finished( os.clock()-starttime )
						map:open_doors("door_normal_area_"..split_table[3])
						
						difficultyOfFights = difficultyOfFights + 1
						if difficultyOfFights > highestDifficulty then difficultyOfFights = lowestDifficulty end
						local game = map:get_game()
						 f:write(game:get_life() .. "-endlife\n")
						 f:write(os.time() .. "-endtime\n")
						 f:write("finished-thefight\n")
						 f:flush()
						 f:close(); f = nil
						 hero.on_state_changed = nil
						analyseGameplaySoFar(map)
					end
					return false
				end
				
			sensor.on_left = 
				function()
					if map:has_entities("generatedEnemy") then
						f = sol.file.open("userExperience.txt","a+")
						difficultyOfFights = difficultyOfFights + 1
						if difficultyOfFights > highestDifficulty then difficultyOfFights = lowestDifficulty end
						local game = map:get_game()
						 f:write(game:get_life() .. "-endlife\n")
						 f:write(os.time() .. "-endtime\n")
						 f:write("ranawayfrom-thefight\n")
						 f:flush(); f:close(); f = nil
						 hero.on_state_changed = nil
						analyseGameplaySoFar(map)
					end
				end
		end
				
	end
end

function analyseGameplaySoFar(map)
	local file = sol.file.open("userExperience.txt","r")
	local nothing = {fightFinished=0, swordHits=0, explodeHits=0, thrownHits=0, monstersKilled=0, timeInRoom=0, surface=0, directionChange=0, 
			lifeLostInRoom=0, uselessKeys=0, monsterTypes={}, monsterTypesKilled={}, heroStates={}, bombUse=0, swordClang=0,hasGlove=0,hasGlove2=0,
			hasBomb=0,moving=0, standing=0, percentageStanding=0, startingLife=0, intendedDifficulty=0, insideDungeon=0, pitfalls=0, spikes=0,
			grass=0, whiteRock=0, goingHero=0,countedGoingHero=0,averageAggro=0}
	local room = table_util.copy( nothing )

	while true do
		local line = file:read("*line")
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
		if string.find(line, "areasensor") or string.find(line, "A NEW GAME IS STARTING NOW") then room = table_util.copy( nothing ) end	
		
		if splitLine[2] == "intendedDifficulty" then room.intendedDifficulty = tonumber (splitLine[1]) end
		if splitLine[2] == "hasGlove" then room.hasGlove = tonumber (splitLine[1]) end
		if splitLine[2] == "hasGlove2" then room.hasGlove2 = tonumber (splitLine[1]) end
		if splitLine[2] == "hasBomb" then room.hasBomb = tonumber (splitLine[1]) end
		if splitLine[2] == "pits" then room.pitfalls = tonumber (splitLine[1]) end
		if splitLine[2] == "spikes" then room.spikes = tonumber (splitLine[1]) end
		if splitLine[2] == "grass" then room.grass = tonumber (splitLine[1]) end
		if splitLine[2] == "whiteRock" then room.whiteRock = tonumber (splitLine[1]) end
		
		if splitLine[2] == "goingHero" then 
			room.goingHero = room.goingHero + tonumber (splitLine[1])
			room.countedGoingHero = room.countedGoingHero + 1
		end
		
	end
	if (room.moving+room.standing) ~= 0 then room.percentageStanding = room.standing/(room.moving+room.standing) end
	if (room.countedGoingHero) ~= 0 then room.averageAggro = room.goingHero/room.countedGoingHero end
	
	file:flush(); file:close()
	logTheRoom (room)
	local weights = learningAlgorithms.linearRegression(roomContentsData, roomDifficulties)
	
	if weights then updateWeights( weights ) end
end

function updateWeights (weights)
	breedDifficulties["minillosaur_egg_fixed"] = weights[1][1]
	breedDifficulties["snap_dragon"] = weights[2][1]
	breedDifficulties["blue_hardhat_beetle"] = weights[3][1]
	breedDifficulties["green_knight_soldier"] = weights[4][1]
	baseDifficulty = weights[5][1]
end

function absolute( number )
	if number < 0 then return -number else return number end
end

function logTheRoom (room) 
	local fightRoomData = {}
	local playerBehaviourData = {}
	local bias = 1
	
	fightRoomData[#fightRoomData+1] = game:get_player_name()
	fightRoomData[#fightRoomData+1] = tonumber(map:get_id())
	-- egg,snap_dragon,hardhat,knight,papillosaur,startLife,hasGlove,hasGlove2,hasBomb,pitfalls,spikes,grass,whiteRock,inside,surface
	fightRoomData[#fightRoomData+1] = room.monsterTypes.minillosaur_egg_fixed or 0
	fightRoomData[#fightRoomData+1] = room.monsterTypes.snap_dragon or 0
	fightRoomData[#fightRoomData+1] = room.monsterTypes.blue_hardhat_beetle or 0
	fightRoomData[#fightRoomData+1] = room.monsterTypes.green_knight_soldier or 0
	fightRoomData[#fightRoomData+1] = room.monsterTypes.papillosaur_king or 0
	fightRoomData[#fightRoomData+1] = room.startingLife
	fightRoomData[#fightRoomData+1] = room.hasGlove
	fightRoomData[#fightRoomData+1] = room.hasGlove2
	fightRoomData[#fightRoomData+1] = room.hasBomb
	fightRoomData[#fightRoomData+1] = room.pitfalls
	fightRoomData[#fightRoomData+1] = room.spikes
	fightRoomData[#fightRoomData+1] = room.grass
	fightRoomData[#fightRoomData+1] = room.whiteRock
	fightRoomData[#fightRoomData+1] = room.insideDungeon
	fightRoomData[#fightRoomData+1] = room.surface
	
	-- finished,swordHits,bombUsage,explodeHits,thrownHits,time,dirChange,lifeLost,clangs,uselessKeys,moving,standing,percStanding,avgAggro
	playerBehaviourData[#playerBehaviourData+1] = room.fightFinished
	playerBehaviourData[#playerBehaviourData+1] = room.swordHits
	playerBehaviourData[#playerBehaviourData+1] = room.bombUse
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
	
	writeTableToFile (fightRoomData, "roomSummaries.csv", ",")
	writeTableToFile (playerBehaviourData, "roomSummaries.csv", ",") 
	writeTableToFile (roomDifficultyPrediction, "roomSummaries.csv", ",")
	writeTableToFile (roomDifficultyIntention, "roomSummaries.csv", "\n")
	
	roomContentsData[#roomContentsData+1] = {room.monsterTypes.minillosaur_egg_fixed or 0, room.monsterTypes.snap_dragon or 0, 
											room.monsterTypes.blue_hardhat_beetle or 0, room.monsterTypes.green_knight_soldier or 0,
											bias}
	roomDifficulties[#roomDifficulties+1] = roomDifficultyPrediction
	
end

-- This line of code is the only thing this project is really about. I'm actually kind of amazed.
function makeDifficultyPrediction(room) 
	return 0.1652 * room.swordHits + 
		  -0.0269 * room.standing + 
		   0.499 * (room.heroStates.hurt or 0) + 
		   0.0412 * (room.heroStates["sword swinging"] or 0) + 
		   1.3787
end

function writeTableToFile (dataTable, file, add_this) 
	local f_opened = sol.file.open(file,"a+")
	for k,v in pairs(dataTable) do
		f_opened:write(v)
		if k ~= #dataTable then f_opened:write(",") end
	end
	f_opened:write(add_this);f_opened:flush(); f_opened:close()
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

function fight_generator.make(areas, maxDiff, map, currentLife) 

	local breedOptions={"minillosaur_egg_fixed","snap_dragon","blue_hardhat_beetle","green_knight_soldier"}	
	local hero = map:get_hero()
	local spawnAreas = areas
	
	local totalSurface = 0
	for _, area in ipairs(areas) do totalSurface = totalSurface + absolute ( area.x1-area.x2 ) * absolute ( area.y1-area.y2 ) end
	totalSurface = totalSurface / 64
	f:write(totalSurface .. "-spawnSurface\n"); f:flush()
	
	if enemyTried <= 4 then 
		local xPos, yPos = chooseAreaToSpawn(spawnAreas, hero)
		local chosenBreed = breedOptions[enemyTried]
		enemyTried=enemyTried+1
		return {{name="generatedEnemy_thisOne", layer=0, x=xPos, y=yPos, direction=0, breed=chosenBreed}}, breedDifficulties[chosenBreed]
	end
	
	if enemyTried == 5 then enemyTried=6; difficultyOfFights = lowestDifficulty end

	local difficulty = baseDifficulty + startLifeDifficulty * currentLife
	local enemiesInFight = {}
	
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
		table.insert(enemiesInFight,{name="generatedEnemy_thisOne", layer=0, x=xPos, y=yPos, direction=0, breed=chosenBreed})
		difficulty = difficulty + chosenDifficulty + monsterAmountDifficulty
	end
	return enemiesInFight, difficulty
end

return fight_generator