local pl = {}
local table_util = require("table_util")

pl.log_template = {
	-- personal settings
	name=game:get_player_name(),
	map_id=0;
	-- data gathered on all puzzles
	total_time=0,
	
	sokoban_total_time=0,
	sokoban_retries=0,
	sokoban_quits=0,
	sokoban_puzzles=0,
	sokoban_completed=0,
	sokoban_average_difficulty=0,
	sokoban_vfm=0,

	pike_room_total_time=0,
	pike_room_got_hurt=0,
	pike_room_deaths=0,
	pike_room_puzzles=0,
	pike_room_completed=0,
	pike_room_average_difficulty=0,

	maze_total_time=0,
	maze_got_hurt=0,
	maze_falls=0,
	maze_deaths=0,
	maze_puzzles=0,
	maze_completed=0,
	maze_average_difficulty=0,
}

pl.current_areanumber = 0
pl.current_puzzle_log = {}
pl.log = {}

function pl.init_logs()
	pl.current_puzzle_log = {}
	pl.log = table_util.copy(pl.log_template)
	pl.log.map_id = map:get_id()
end


function pl.complete_puzzle()
	local cl = pl.current_puzzle_log[pl.current_areanumber]
	if not cl.completed then
		cl.completed = true
		pl.stop_recording()
		pl.update_total_log( cl )
		puzzle_gen.interpret_log( cl )
		pl.current_log_to_data( cl )
		explore.puzzle_finished ( cl.total_time ) 
	end
end

function pl.update_total_log( current_puzzle_log )
	local cl = current_puzzle_log
	local tl = pl.log
	local puzzle_type = cl.puzzle_type
	tl.total_time = tl.total_time + cl.total_time
	tl[puzzle_type.."_total_time"] = tl[puzzle_type.."_total_time"] + cl.total_time
	tl[puzzle_type.."_puzzles"] = tl[puzzle_type.."_puzzles"] +1
	if puzzle_type == "sokoban" then
		if cl.quit then	tl.sokoban_quits = tl.sokoban_quits +1 end
		tl.sokoban_retries = tl.sokoban_retries + cl.retries
		tl.sokoban_vfm = tl.sokoban_vfm + cl.total_vfm_time + cl.vfm_time
	elseif puzzle_type == "pike_room" then
		tl[cl.puzzle_type.."_deaths"] = tl[cl.puzzle_type.."_deaths"] + cl.deaths
		tl.pike_room_got_hurt = tl.pike_room_got_hurt + cl.got_hurt
	elseif puzzle_type == "maze" then
		tl.maze_falls = tl.maze_falls + cl.falls
		tl[cl.puzzle_type.."_deaths"] = tl[cl.puzzle_type.."_deaths"] + cl.deaths
		tl.maze_got_hurt = tl.maze_got_hurt + cl.got_hurt
	end
end

function pl.get_new_current_log(puzzle_type, difficulty)
	return 	{
			name=game:get_player_name(),
			started_recording = true,
			difficulty=difficulty,
			time_start=os.clock(),
			time_end=0,
			total_time=0,
			retries=0,
			got_hurt=0,
			puzzle_type=puzzle_type,
			quit=false,
			completed=false,
			died=false,
			fell=false,
			deaths=0,
			falls=0,
			vfm_time=0,
			total_vfm_time=0,
			difficulty_difference=0
		}
end

function pl.start_recording( puzzle_type, areanumber, difficulty )
	pl.current_areanumber = areanumber
	local cl = pl.current_puzzle_log[areanumber]
	if cl == nil then 
		pl.current_puzzle_log[areanumber] = pl.get_new_current_log(puzzle_type, difficulty)
		cl = pl.current_puzzle_log[areanumber]
	elseif cl.completed or cl.quit then 
		return
	else
		cl.started_recording = true
		cl.died = false
		cl.time_start=os.clock()
	end
	
	function hero:on_state_changed(state)
		if state ~= "free" then
			cl.fell = false
		end
		if state == "hurt" then 
			cl.got_hurt = cl.got_hurt +1
			if game:get_life() <= 2 and game:get_life() > 0 and not cl.died then
				pl.stop_recording()
				cl.died = true
				cl.deaths = cl.deaths +1
			end
		end
		if state == "falling" then
			cl.fell = true
			cl.falls = cl.falls + 1
		end
		return false
	end
end

function pl.below_difficulty_setting(puzzle_type, difficulty, areanumber)
	local cl = pl.current_puzzle_log[areanumber]
	if cl == nil then
		pl.current_puzzle_log[areanumber] = pl.get_new_current_log(puzzle_type, difficulty)
		cl = pl.current_puzzle_log[areanumber]
	end
	cl.difficulty_difference = -1
end

function pl.above_difficulty_setting(puzzle_type, difficulty, areanumber)
	local cl = pl.current_puzzle_log[areanumber]
	if cl == nil then
		pl.current_puzzle_log[areanumber] = pl.get_new_current_log(puzzle_type, difficulty)
		cl = pl.current_puzzle_log[areanumber]
	end
	cl.difficulty_difference = 1
end

function pl.over_time_limit()
	local cl = pl.current_puzzle_log[pl.current_areanumber]
	if pl.get_current_time_spent() > 90 then
		return true
	end
	return false
end

function pl.get_current_time_spent()
	local cl = pl.current_puzzle_log[pl.current_areanumber]
	if cl and not cl.started_recording then return 0 end
	return cl.total_time + (os.clock() - cl.time_start)
end

function pl.pressed_quit()
	local cl = pl.current_puzzle_log[pl.current_areanumber]
	if cl.started_recording and not cl.quit and not cl.completed then
		pl.current_puzzle_log.quit = true
		pl.stop_recording()
		pl.update_total_log( cl )
		puzzle_gen.interpret_log( cl )
		pl.current_log_to_data( cl )
		return true
	else
		return false
	end
end

function pl.retry()
	cl = pl.current_puzzle_log[pl.current_areanumber]
	if cl.vfm_time ~= 0 then  
		cl.retries = cl.retries+1
		cl.total_vfm_time = cl.total_vfm_time + cl.vfm_time
		cl.vfm_time = 0
	end
end

function pl.made_first_move()
	local cl = pl.current_puzzle_log[pl.current_areanumber]
	if cl.vfm_time == 0 and cl.started_recording then
		cl.vfm_time = os.clock() - cl.time_start
	end
end

function pl.can_reset_puzzle()
	local cl = pl.current_puzzle_log[pl.current_areanumber]
	if cl and cl.vfm_time ~= 0 then
		return true
	end
	return false
end

function pl.stop_recording()
	local cl = pl.current_puzzle_log[pl.current_areanumber]
	if cl.started_recording then
		cl.time_end = os.clock()
		cl.total_time = cl.total_time + cl.time_end - cl.time_start
		cl.total_vfm_time = cl.total_vfm_time + cl.vfm_time
		cl.started_recording = false
	end
	function hero:on_state_changed(state)
		return false
	end
end

function pl.current_log_to_data( current_puzzle_log )
	local cl = current_puzzle_log
	local data ={}
	-- name, map_id, puzzle_type, difficulty, time_spent, retries, got_hurt, falls, deaths, quit, completed, average_vfm_time
	table.insert(data, game:get_player_name()) 		-- name, 
	table.insert(data, map:get_id()) 				-- map_id
	table.insert(data, cl.puzzle_type) 				-- puzzle_type
	table.insert(data, cl.difficulty) 				-- difficulty 1-5
	table.insert(data, cl.total_time) 				-- time_spent
	table.insert(data, cl.retries) 					-- retries
	table.insert(data, cl.got_hurt) 				-- got_hurt
	table.insert(data, cl.falls) 				-- got_hurt
	table.insert(data, cl.deaths) 					-- deaths
	table.insert(data, (cl.quit and 1 or 0)) 					-- quit
	table.insert(data, (cl.completed and 1 or 0)) 				-- completed
	table.insert(data, cl.total_vfm_time/(cl.retries+1)) -- average_vfm_time
	pl.writeTableToFile (data, "individual_puzzles.csv") 
end

function pl.log_to_data( )
	local l = pl.log
	local data ={}
	-- name, map_id, total_time, sokoban_total_time, sokoban_retries, sokoban_quits, sokoban_puzzles, sokoban_vfm, pike_room_total_time, pike_room_got_hurt, pike_room_deaths, pike_room_puzzles, maze_total_time, maze_got_hurt, maze_falls, maze_deaths, maze_puzzles
	table.insert(data, game:get_player_name()) 	-- name
 	table.insert(data, map:get_id())
	table.insert(data, l.total_time) 			-- total_time
	table.insert(data, l.sokoban_total_time) 	-- sokoban_total_time
	table.insert(data, l.sokoban_retries) 		-- sokoban_retries
	table.insert(data, l.sokoban_quits) 		-- sokoban_quits
	table.insert(data, l.sokoban_puzzles) 		-- sokoban_puzzles
	table.insert(data, l.sokoban_vfm) 			-- sokoban_vfm
	table.insert(data, l.pike_room_total_time) 	-- pike_room_total_time
	table.insert(data, l.pike_room_got_hurt) -- pike_room_got_hurt
	table.insert(data, l.pike_room_deaths) 		-- pike_room_deaths
	table.insert(data, l.pike_room_puzzles) 	-- pike_room_puzzles
	table.insert(data, l.maze_total_time) 		-- maze_total_time
	table.insert(data, l.maze_got_hurt) 		-- maze_got_hurt
	table.insert(data, l.maze_falls)
	table.insert(data, l.maze_deaths) 			-- maze_deaths
	table.insert(data, l.maze_puzzles) 			-- maze_puzzles
	pl.writeTableToFile (data, "all_puzzles.csv") 
end

function pl.writeTableToFile (dataTable, file) 
	local f = sol.file.open(file,"a+")
	for k,v in pairs(dataTable) do
		f:write(tostring(v))
		if k ~= #dataTable then f:write(",")
		else f:write("\n") end
	end
	f:flush(); f:close()
end

return pl