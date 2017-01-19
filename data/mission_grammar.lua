local mission_grammar = {}

local lookup = require("data_lookup")

local table_util = require("table_util")
local log = require("log")

mission_grammar.planned_items = {

}

mission_grammar.available_keys = {

}

mission_grammar.available_barriers = {
	
}

-- keys as keys and the values are the barriers opened with it
mission_grammar.key_barrier_lookup = {
	["EQ"]=	{
			["sword-1"]={"bush"},
			["glove-1"]={"white_rock"},
			["glove-2"]={"black_rock"},
			["bomb_bag-1"]={"door_weak_block"}
			},
	["K"]=	{	
			["boss_key"]={"door_boss_key"},
			["dungeon_key"]={"door_small_key"}
			}
}


mission_grammar.key_types = 	{"K", "EQ", "R"}
mission_grammar.barrier_types = {"L", "B", "OB", "NB", "S"}
mission_grammar.area_types = 	{"C", "P", "F", "PF", "CH", "T", "BT", "E", "BOSS", "TF", "TP"}
-- based on:
-- http://sander.landofsand.com/publications/Dormans_Bakkes_-_Generating_Missions_and_Spaces_for_Adaptable_Play_Experiences.pdf

-- Ideas for possible node types: 
-- ?:any node, 
-- EQ:new equipment, which unlocks B:barrier (use key_barriers lookups and available keys), 
-- OB:old barrier (hero should be able to open these based on the available keys list)
-- NB:new barrier (hero should be able to open this with an equipment piece found later in game)
-- K:key, unlocks L:lock
-- R:reward (rupees/story)
-- T:Task or BT:Branch task, which can turn into F:(mandatory) fight room, P:puzzle, E:empty room, PF: puzzle with enemies
-- CH:challenge room
-- S:secret transition, C:treasure chest room
-- BOSS: boss room

-- graph grammar rules lookup where the keys are the rule numbers, and the values the left and right hand sides
-- grammar = [1]={prob=100, lhs={ nodes={[1]="T", [2]="T", [3]="T"}, edges={ [1]={ [2]="undir_fw" }, [2]={[3]="undir_fw"} } }, 
--							 rhs={ nodes={[1]="T", [2]="T", [3]="T"}, edges={ [1]={ [2]="undir_fw", [3]="undir_fw"} } } }
-- NOTE: Ensure that the lhs edges are connected from the [1] on, there is no recursive search for loose ends that have not been found before
mission_grammar.grammar = {
	-- 1 to 4 are the example rules from the paper
	-- reorganize tasks, creates a branch
 	[1]={ lhs={ nodes={[1]="T", [2]="T", [3]="T"}, edges={ [1]={ [2]="undir_fw" }, [2]={[3]="undir_fw"} } }, 
		  rhs={ nodes={[1]="T", [2]="T", [3]="T"}, edges={ [1]={ [2]="undir_fw", [3]="undir_fw"} } } },
	-- moving a lock forward and branching
	[2]={ lhs={ nodes={[1]="T", [2]="?", [3]="L"}, edges={ [1]={ [2]="undir_fw" }, [2]={[3]="undir_fw"} } }, 
		  rhs={ nodes={[1]="T", [2]="?", [3]="L"}, edges={ [1]={ [2]="undir_fw", [3]="undir_fw"} } } },
	-- create a key and lock in between two tasks
	[3]={ lhs={ nodes={[1]="T", [2]="T",		}, edges={ [1]={ [2]="undir_fw" } } }, 
		  rhs={ nodes={[1]="T", [2]="T", [3]="K", [4]="L"}, 
			    edges={ [1]={ [3]="undir_fw", [4]="undir_fw"}, [3]={[4]="dir_fw"}, [4]={[2]="undir_fw"} } } },	
	-- move key backwards by moving tasks from behind it's lock to in front of the key		
	[4]={ lhs={ nodes={[1]="K", [2]="L", [3]="T", [4]="T", [5]="?" }, 
		  	    edges={ [1]={ [2]="dir_fw", [5]="undir_bk" }, [2]={ [3]="undir_fw" }, [3]={ [4]="undir_fw" } } }, 
		  rhs={ nodes={[1]="K", [2]="L", [3]="T", [4]="T", [5]="?" }, 
			    edges={ [1]={ [2]="dir_fw" }, [2]={ [4]="undir_fw" }, [3]={ [1]="undir_fw" }, [5]={ [3]="undir_fw" } } } },	
	-----------------------------------------------------------------------------------------------
	-- new rules that utilize a new equipment piece			    
	-- create an new Equipment item and 1 barrier in between two tasks
	[5]={ lhs={ nodes={[1]="T", [2]="T",		  }, edges={ [1]={ [2]="undir_fw" } } }, 
		  rhs={ nodes={[1]="T", [2]="T", [3]="EQ:?", [4]="B:?"}, 
			    edges={ [1]={ [3]="undir_fw", [4]="undir_fw"}, [3]={[4]="dir_fw"}, [4]={[2]="undir_fw"} } } },
	-- move a barrier forward and cause branching				  
	[6]={ lhs={ nodes={[1]="T", [2]="?", [3]="B"}, edges={ [1]={ [2]="undir_fw" }, [2]={[3]="undir_fw"} } }, 
		  rhs={ nodes={[1]="T", [2]="?", [3]="B"}, edges={ [1]={ [2]="undir_fw", [3]="undir_fw"} } } },
	-- move an equiment piece back
	[7]={ lhs={ nodes={[1]="EQ", [2]="B", [3]="T", [4]="T", [5]="?" }, 
		  	    edges={ [1]={ [2]="dir_fw", [5]="undir_bk" }, [2]={ [3]="undir_fw" }, [3]={ [4]="undir_fw" } } }, 
		  rhs={ nodes={[1]="EQ", [2]="B", [3]="T", [4]="T", [5]="?" }, 
			    edges={ [1]={ [2]="dir_fw" }, [2]={ [4]="undir_fw" }, [3]={ [1]="undir_fw" }, [5]={ [3]="undir_fw" } } } },
	-- Add a Barier -> Secret passage -> Challenge -> Treasure -> Back to the room before secret passage
	[8]={ lhs={ nodes={[1]="EQ", [2]="T" 		}, edges={ [1]={ [2]="undir_bk" } } }, 
		  rhs={ nodes={[1]="EQ", [2]="T", [3]="B", [4]="S", [5]="CH", [6]="C"}, 
		  	 	edges={ [1]={ [2]="undir_bk", [3]="dir_fw" }, [2]={[3]="undir_fw"}, [3]={[4]="undir_fw"}, [4]={[5]="undir_fw"}, [5]={[6]="undir_fw"}, [6]={[2]="dir_fw"} } } },
	-- Randomly adding a barrier for an old equipment piece between tasks
	[9]={ lhs={ nodes={[1]="T", [2]="T", 		}, edges={ [1]={ [2]="undir_fw" } } }, 
		  rhs={ nodes={[1]="T", [2]="T", [3]="OB:?"}, edges={ [1]={ [2]="undir_fw"}, [1]={ [3]="undir_fw"}, [3]={ [2]="undir_fw"} } } },
	["B_OB"]={ lhs={ nodes={[1]="BT", [2]="BT", 		}, edges={ [1]={ [2]="undir_fw" } } }, 
		  rhs={ nodes={[1]="BT", [2]="BT", [3]="OB:?"}, edges={ [1]={ [2]="undir_fw"}, [1]={ [3]="undir_fw"}, [3]={ [2]="undir_fw"} } } },
	-------------------------------------------------------------------------------------------------
	-- Replacing nodes
	[10]={ lhs={ nodes={[1]="T"}, edges={} }, 
		   rhs={ nodes={[1]="F"}, edges={} } },	   
    [11]={ lhs={ nodes={[1]="T", [2]="?" }, edges={ [1]={ [2]="undir_fw" } } }, 
		   rhs={ nodes={[1]="P", [2]="?" }, edges={ [1]={ [2]="undir_fw" } } } },
	["BT:F"]={ lhs={ nodes={[1]="BT"}, edges={} }, 
		   rhs={ nodes={[1]="F"}, edges={} } },
	["BT:P"]={ lhs={ nodes={[1]="BT"}, edges={} }, 
		   rhs={ nodes={[1]="P"}, edges={} } },
	[12]={ lhs={ nodes={[1]="T", [2]="goal" }, edges={ [1]={ [2]="undir_fw" } } }, 
		   rhs={ nodes={[1]="T", [2]="goal", [3]="BOSS"}, 
			    edges={ [1]={ [3]="undir_fw"}, [3]={[2]="dir_fw"} } } },
    [13]={ lhs={ nodes={[1]="E", [2]="T",		}, edges={ [1]={ [2]="undir_fw" } } }, 
		   rhs={ nodes={[1]="E", [2]="T", [3]="K:dungeon_key", [4]="L:door_small_key", [5]="P"}, 
			     edges={ [1]={ [3]="undir_fw", [4]="undir_fw"}, [3]={[4]="dir_fw"}, [4]={[5]="undir_fw"}, [5]={[2]="undir_fw"} } } },
	[14]={ lhs={ nodes={[1]="EQ:?", [2]="?" }, edges={ [1]={ [2]="undir_bk" } } }, 
		   rhs={ nodes={[1]="EQ", [2]="?", [3]="C" }, edges={ [2]={ [3]="undir_fw" }, [3]={[1]="undir_fw"} } } },
    [15]={ lhs={ nodes={[1]="EQ:?", [2]="?" }, edges={ [1]={ [2]="undir_bk" } } }, 
		   rhs={ nodes={[1]="EQ", [2]="?", [3]="BT" }, edges={ [2]={ [3]="undir_fw" }, [3]={[1]="undir_fw"} } } },	
	-------------------------------------------------------------------------------------------------
	-- rules that add to the example rules
}

-- start off with 3 node types, start, Expand_nodes * N, goal in that order
-- non_terminals = {2}, first in first out
-- nodes = {[1]="start", [2]="T", [3]="goal"}
-- edges = { [<lower_index>]={ [<higher_index>]={edge_type} } and [<higher_index>]={ [<lower_index>]={edge_type_reversed} } }
-- edge_types = dir_fw, dir_bk, undir_fw, undir_bk
-- we use the undirected forward and backward as a method of distinguishing edges which are in the space generation going to be two way transitions
-- so we can just check the pairs of any of the two which edges are available
-- all new nodes are placed at the end of the table
mission_grammar.produced_graph = {}

function mission_grammar.create_standard_graph_for_testing( params )
	local main_length = params.main_length or 6
	local optional_length = params.optional_length or 4
	local branch_length = params.branch_length or 1
	local nodes = {[1]="start"}
	local edges = {}
	local non_terminals = {}
	local n, e, nt, starting_number
	local next_eq
	local next_bar

	if #mission_grammar.planned_items > 0 then 
		next_eq = table.remove(mission_grammar.planned_items, 1)
		next_bar = table_util.random(mission_grammar.key_barrier_lookup.EQ[next_eq])
	end

	starting_number = #nodes+1
	local main_sequence = {}
	local add_fight = true
	for i=1,main_length do
		if add_fight then table.insert(main_sequence, "F"); add_fight = false
		else table.insert(main_sequence, "P"); add_fight = true end
		if i == math.ceil(main_length/2) and next_eq then 
			table.insert(main_sequence, "C");table.insert(main_sequence, "B:"..next_bar)
		end
	end
	table.insert(main_sequence, "goal")
	--n, e, nt = mission_grammar.create_new_task_sequence( starting_number, {"F", "P", "F", "C","B:"..next_bar, "P", "F", "P", "goal"})
	n, e, nt = mission_grammar.create_new_task_sequence( starting_number, main_sequence)
	nodes = table_util.union(nodes, n)
	edges = table_util.union(edges, e)
	table_util.add_table_to_table(nt, non_terminals)
	edges[1] = {[starting_number]="undir_fw"}
	edges[starting_number][1]="undir_bk"

	if next_eq then
		eq_nr = #nodes+1
		nodes[eq_nr] = "EQ:"..next_eq
		edges[math.ceil(main_length/2)+2][eq_nr]="undir_fw"
		edges[eq_nr]= { [math.ceil(main_length/2)+2]="undir_bk" }
	end


	-- starting on the optional path
	starting_number = #nodes+1
	local optional_sequence = {}
	for i=1,optional_length do
		table.insert(optional_sequence, "BT")
	end
	n, e, nt_BTS = mission_grammar.create_new_task_sequence( starting_number, optional_sequence ) 
	--n, e, nt_BTS = mission_grammar.create_new_task_sequence( starting_number, {"BT","BT","BT","BT"} ) 
	nodes = table_util.union(nodes, n)
	edges = table_util.union(edges, e)
	table_util.add_table_to_table(nt_BTS, non_terminals)
	log.debug("these non-terminals will have branches attached")
	log.debug(nt)

	-- connecting optional path with main path with next bar in between
	if next_eq then mission_grammar.insert_symbol_between (math.ceil(main_length/2)+1, starting_number, "B:"..next_bar, nodes, edges)
	else mission_grammar.insert_symbol_between (math.ceil(main_length/2)+1, starting_number, "B:"..table_util.random(mission_grammar.available_barriers), nodes, edges) end

	local branch_symbol_list = {"C", "R:rupees"}
	for i=1, branch_length, 1 do
		table.insert(branch_symbol_list, 1, "BT")
	end

	for index,node_nr in ipairs(nt_BTS) do
		if index == #nt_BTS and params.add_heart then branch_symbol_list[#branch_symbol_list] = "R:heart_container" end
		starting_number = #nodes+1
		n, e, nt = mission_grammar.create_new_task_sequence( starting_number, branch_symbol_list )
		nodes = table_util.union(nodes, n)
		edges = table_util.union(edges, e)
		table_util.add_table_to_table(nt, non_terminals)

		edges[node_nr][starting_number]="undir_fw"
		edges[starting_number] = edges[starting_number] or {}
		edges[starting_number][node_nr]="undir_bk"
	end

	mission_grammar.produced_graph = {nodes=nodes, edges=edges, non_terminals=non_terminals, branching={}}
end

function mission_grammar.insert_symbol_between (nt1, nt2, symbol, nodes, edges)
	local new_node_nr = #nodes+1
	nodes[new_node_nr] = symbol
	edges[nt1][new_node_nr]="undir_fw"
	edges[new_node_nr]={[nt1]="undir_bk", [nt2]="undir_fw"}
	edges[nt2][new_node_nr]="undir_bk"
end

function mission_grammar.create_new_task_sequence( starting_number, symbol_list)
	local nodes = {[starting_number]=symbol_list[1]}
	local edges = {}
	local non_terminals = {}
	if table_util.contains({"T", "BT"}, symbol_list[1]) then
		table.insert(non_terminals, starting_number)
	end
	local symbol_counter = 2
	for i=starting_number+1, #symbol_list+starting_number-1 do
		nodes[i] = symbol_list[symbol_counter]
		edges[i-1]= edges[i-1] or {}
		edges[i-1][i]="undir_fw"
		edges[i]= edges[i] or {}
		edges[i][i-1]="undir_bk"
		if table_util.contains({"T", "BT"}, symbol_list[symbol_counter]) then
			table.insert(non_terminals, i)
		end
		symbol_counter = symbol_counter +1
	end
	return nodes, edges, non_terminals
end

function mission_grammar.initialize_graph( task_length )
	local nodes = {[1]="start"}
	local edges = {[1]={}}
	local non_terminals = {}
	for i=2, task_length+1 do
		nodes[i] = "T"
		edges[i-1]= edges[i-1] or {}
		edges[i-1][i]="undir_fw"
		edges[i]= edges[i] or {}
		edges[i][i-1]="undir_bk"
		table.insert(non_terminals, i)
	end
	edges[task_length+1][task_length+2]="undir_fw"
	edges[task_length+2]={[task_length+1]="undir_bk"}
	table.insert(nodes, "goal")
	mission_grammar.produced_graph = {nodes=nodes, edges=edges, non_terminals=non_terminals, branching={}} -- max one branch per NT
end

function mission_grammar.update_keys_and_barriers( game )
	mission_grammar.available_keys = {}
	mission_grammar.available_barriers = {}
	local k = 0
	for item,data in pairs(lookup.equipment) do
		if game:get_value(data.treasure_savegame_variable) then 
			k = k + 1
			mission_grammar.available_keys[k]=item
			table_util.add_table_to_table(mission_grammar.key_barrier_lookup["EQ"][item], mission_grammar.available_barriers)
		end
	end
end

function mission_grammar.initialize_tutorial_graph( params )
	local nodes = {[1]="start"}
	local edges = {}
	local non_terminals = {}
	local task_length = params.length
	for i=2, params.fights+1 do
		nodes[i] = "TF"
		edges[i-1]= edges[i-1] or {}
		edges[i-1][i]="undir_fw"
		edges[i]= edges[i] or {}
		edges[i][i-1]="undir_bk"
		table.insert(non_terminals, i)
	end
	for i=params.fights+2, params.fights+params.puzzles+1 do
		nodes[i] = "TP"
		edges[i-1]= edges[i-1] or {}
		edges[i-1][i]="undir_fw"
		edges[i]= edges[i] or {}
		edges[i][i-1]="undir_bk"
		table.insert(non_terminals, i)
	end
	edges[task_length+1][task_length+2]="undir_fw"
	edges[task_length+2]={[task_length+1]="undir_bk"}
	table.insert(nodes, "goal")
	mission_grammar.produced_graph = {nodes=nodes, edges=edges, non_terminals=non_terminals, branching={}} -- max one branch per NT
end


-- what kind of map type are we producing
function mission_grammar.produce_graph( params)
	log.debug(params)
	local params_clone = table_util.copy(params)
	mission_grammar.initialize_graph( params_clone.length )
	mission_grammar.add_branches( params )
	mission_grammar.add_old_barriers( params_clone )
	mission_grammar.assign_fights_and_puzzles( params )
	return params_clone
end

function mission_grammar.produce_standard_testing_graph( params)
	log.debug(params)
	local params_clone = table_util.copy(params)
	if params.mission_type=="tutorial" then
		mission_grammar.initialize_tutorial_graph( params )
	elseif params.mission_type=="boss" then
		mission_grammar.initialize_graph( 0 )
		local graph = mission_grammar.produced_graph
		graph.nodes[3]= "BOSS"
		graph.edges= {[1]={[3]="undir_fw"}, [2]={[3]="undir_bk"}, [3]={[1]="undir_bk", [2]="undir_fw"} }
	elseif params.mission_type=="normal" then
		mission_grammar.create_standard_graph_for_testing( params_clone )
		mission_grammar.add_old_barriers( params_clone )
		mission_grammar.assign_branch_tasks( params_clone )
	else 
		mission_grammar.produce_graph( params)
	end
	return params_clone
end

function mission_grammar.add_planned_equipment_and_barrier( params )
	-- add and branch
	local matches = mission_grammar.match( 5 )
	if next(matches) ~= nil then
		local next_eq = table.remove(mission_grammar.planned_items, 1)
		local next_bar = table_util.random(mission_grammar.key_barrier_lookup.EQ[next_eq])
		mission_grammar.apply_rule( table_util.random(matches), 5, {next_eq, next_bar} )
	end
	-- create room between branch and EQ
	for i=1, params.branch_length do -- the amount needs to be determined by Openness
		matches = mission_grammar.match( 15 )
		if next(matches) == nil then break end
		mission_grammar.apply_rule( matches[1], 15 )
	end
	matches = mission_grammar.match( 14 )
	if next(matches) ~= nil then mission_grammar.apply_rule( matches[1], 14 ) end
end

function mission_grammar.add_boss_fight( )
	local matches = mission_grammar.match( 12 )
	if next(matches) == nil then return end
	mission_grammar.apply_rule( matches[1], 12 )
end

function mission_grammar.assign_branch_tasks (params)
	local fight_perc = params.fights/(params.fights+params.puzzles)
	local puzzle_perc = params.puzzles/(params.fights+params.puzzles)
	local fights_generated = 0
	local puzzles_generated = 0
	local branch_tasks = mission_grammar.match( "BT:F" )
	for i=1, #branch_tasks do
		local selected_option 
		if fights_generated >= #branch_tasks * fight_perc then
			selected_option = "BT:P"
		elseif puzzles_generated >= #branch_tasks * puzzle_perc then
			selected_option = "BT:F"
		else
			selected_option = table_util.random({"BT:F", "BT:P"})
			if selected_option == "BT:F" then 
				 fights_generated = fights_generated +1
			else puzzles_generated = puzzles_generated +1 end
		end
		mission_grammar.apply_rule( branch_tasks[i], selected_option )
	end
end

function mission_grammar.assign_fights_and_puzzles( params )
	local fights_left, puzzles_left = params.fights, params.puzzles
	local puzzle_matches = mission_grammar.match( 11 )
	for i=1, puzzles_left do
		local selected_match = table.remove(puzzle_matches, math.random(#puzzle_matches))
		mission_grammar.apply_rule( selected_match, 11 )
		params.puzzles = params.puzzles - 1
	end
	local fights_matches = mission_grammar.match( 10 )
	for i=1, fights_left do
		local selected_match = table.remove(fights_matches, math.random(#fights_matches))
		mission_grammar.apply_rule( selected_match, 10 )
		params.fights = params.fights - 1
	end
	local branch_tasks = mission_grammar.match( "BT:F" )
	for i=1, #branch_tasks do
		local selected_option = table_util.random({"BT:F", "BT:P"})
		mission_grammar.apply_rule( branch_tasks[i], selected_option )
	end
end

function mission_grammar.add_branches( params )
	local branches_left = params.branches
	for i=1, branches_left do 
		local matches = mission_grammar.match( 1, mission_grammar.produced_graph.branching )
		if next(matches) == nil then break end
		local selected_match = matches[math.random(#matches)]
		table.insert( mission_grammar.produced_graph.branching, selected_match[1] )
		mission_grammar.apply_rule( selected_match, 1 )
		params.branches = params.branches -1
	end
end

function mission_grammar.add_old_barriers( params )
	local bar = mission_grammar.available_barriers
	local bar_amount = #bar
	local matches = mission_grammar.match( 9 )
	local branch_matches = mission_grammar.match( "B_OB" )
	for i=1, math.ceil(#matches * params.barrier_perc), 1 do
		if #matches > 0 then
			mission_grammar.apply_rule( table.remove(matches, math.random(#matches)), 9, {bar[math.random(bar_amount)]} )
		else break end;
	end
	for i=1, math.ceil(#branch_matches * params.barrier_perc), 1 do
		if #branch_matches > 0 then
			mission_grammar.apply_rule( table.remove(branch_matches, math.random(#branch_matches)), "B_OB", {bar[math.random(bar_amount)]} )
		else break end;
	end
end

-- brute force matching of subset of graph
-- non-terminal and pattern node [1] should be the same otherwise skip
function mission_grammar.match( rule_number, except_non_terminals )
	-- check each non-terminal whether it is the starting point of the given pattern
	local pattern = mission_grammar.grammar[rule_number].lhs
	local matches = {}
	local nodes = mission_grammar.produced_graph.nodes
	local edges = mission_grammar.produced_graph.edges
	local non_terminals = mission_grammar.produced_graph.non_terminals
	for _,nt in ipairs(non_terminals) do
		if not table_util.contains(except_non_terminals, nt) then
			local split_node = table_util.split(nodes[nt], ":")
			local split_node_pattern = table_util.split(pattern.nodes[1], ":")
			if split_node_pattern[1] == "?" or split_node[1] == split_node_pattern[1] and (split_node_pattern[2] == "?" or split_node[2] == nil or split_node[2] == split_node_pattern[2]) then 
				-- log.debug("starting recursive_search on node "..nt)
				local new_matches = mission_grammar.recursive_search( nodes, edges, pattern, {[1]=nt}, {[1]=nt})
				if new_matches then table_util.add_table_to_table(new_matches, matches) end
			end
		end
	end
	return matches
end

function mission_grammar.recursive_search( nodes, edges, pattern, candidates, current_match)
	local new_candidates = {}
	for pattern_index, candidate in pairs(candidates) do
		if pattern.edges[pattern_index] ~= nil then
			for index,edge in pairs(pattern.edges[pattern_index]) do -- pattern edges
				local found = false
				for i,v in pairs(edges[candidate]) do -- existing edges
					-- we need to check whether the edge and the non-terminal type 
					-- are the same for each node connected to the current node
					local split_node = table_util.split(nodes[i], ":")
					local split_node_pattern = table_util.split(pattern.nodes[index], ":")
					if edge == v and (pattern.nodes[index]== "?" or split_node[1] == split_node_pattern[1] and (split_node_pattern[2] == "?" or split_node[2]==nil or split_node[2] == split_node_pattern[2])) then 
						-- edge types and node types are the same 
						-- log.debug("found a node that is connected in the right way")
						-- log.debug("candidate "..candidate.." is connected with "..edge.." to node "..i)
						-- we have found our next candidate for the current node index
						-- add to result list
						if current_match[index] == nil then 
							-- if we didn't have this match before we have found a new candidate for that position
							found = true
							if not table_util.contains(new_candidates[index], i) then
								new_candidates[index] = new_candidates[index] or {}
								table.insert(new_candidates[index], i)
							end
						elseif current_match[index] == i then
							-- if we have found the match before for that index, then it should be that number again, not some other node
							found = true
							break
						end
					end
				end
				if not found then 
					-- log.debug("did not find any edges that had the required type")
					-- log.debug("returning false, going backward")
					return false 
				end
			end
		end
	end
	-- log.debug("finished checking the candidates")
	-- log.debug(new_candidates)
	if next(new_candidates) == nil then
		-- log.debug("new_candidates is empty returning candidates")
		return {candidates}
	else
		-- after checking each edge and connected node in the current node index
		-- we go into the recursion
		-- after creating a combination list of the found candidates
		-- log.debug("creating combinations")
		local combinations = table_util.combinations(new_candidates)
		-- log.debug("creating combinations done")
		-- log.debug(table_util.tostring(combinations))
		local result = {}
		local r = 0
		for nr,combi in ipairs(combinations) do
			local new_match = table_util.union(current_match, combi)
			local output = mission_grammar.recursive_search( nodes, edges, pattern, combi, new_match)
			if output then
				for _, out in ipairs(output) do
				-- log.debug(candidates)
				-- log.debug("+")
				-- log.debug(out)
				-- log.debug("becomes")
				-- output is good, so we create an entry in the results containing every used node on the right position
				r = r+1
				result[r] = {}
				for k,v in pairs(candidates) do result[r][k]=v end
				for k,v in pairs(out) do result[r][k]=v end
				-- log.debug(result[r])
				end
			else
				-- skip that output
			end
		end
		-- log.debug("result")
		-- log.debug(result)
		-- if there are no nodes added because the recursion didn't find anything then we can conclude that we didn't find anything
		if next(result)==nil then return false end
		return result
	end
end

function mission_grammar.apply_rule( match, rule_number, custom_terminal )
	-- log.debug("applying rule number "..rule_number)
	-- log.debug("using match:")
	-- log.debug(match)
	rule = mission_grammar.grammar[rule_number]
	-- remove the listed connections in the lhs from edges
	for index_from, v in pairs(rule.lhs.edges) do
		for index_to, _ in pairs(v) do
			-- log.debug(index_from.." to "..index_to)
			mission_grammar.produced_graph.edges[match[index_from]][match[index_to]]=nil
			mission_grammar.produced_graph.edges[match[index_to]][match[index_from]]=nil
		end
	end
	-- replace nodes if necessary
	for i=1, #rule.lhs.nodes, 1 do
		local split_lhs_node = table_util.split(mission_grammar.produced_graph.nodes[match[i]], ":")
		if not (rule.rhs.nodes[i] == "?" or split_lhs_node[1] == rule.rhs.nodes[i]) then -- NT:term --> NT results in NT:term // NT --> NT:term goes through
			local split_node = table_util.split(rule.rhs.nodes[i], ":")
			if split_node[2] == "?" then mission_grammar.produced_graph.nodes[match[i]]=split_node[1]..":"..table.remove(custom_terminal, 1)	-- NT:? --> NT:custom_terminal		
			else mission_grammar.produced_graph.nodes[match[i]]=rule.rhs.nodes[i] end -- NT:term1 --> NT2 or NT:term2 // NT1 --> NT2
		end
	end
	-- create new node in nodes if keys of lhs and rhs are different, we are not removing nodes only adding and replacing
	local used_nodes = table_util.copy(match)
	for i=#rule.lhs.nodes+1, #rule.rhs.nodes, 1 do
		local split_node = table_util.split(rule.rhs.nodes[i], ":")
		if split_node[2] == "?" then table.insert(mission_grammar.produced_graph.nodes, split_node[1]..":"..table.remove(custom_terminal, 1) )
		else table.insert(mission_grammar.produced_graph.nodes, rule.rhs.nodes[i]) end
		local last_node = #mission_grammar.produced_graph.nodes
		table.insert(mission_grammar.produced_graph.non_terminals, last_node)
		used_nodes[i] = last_node
	end
	-- log.debug("used_nodes")
	-- log.debug(used_nodes)
	-- create new edges by applying the rhs edges
	for index_from, v in pairs(rule.rhs.edges) do
		-- log.debug(v)
		for index_to, edge in pairs(v) do
			mission_grammar.produced_graph.edges[used_nodes[index_from]] = mission_grammar.produced_graph.edges[used_nodes[index_from]] or {}
			mission_grammar.produced_graph.edges[used_nodes[index_from]][used_nodes[index_to]]=edge
			mission_grammar.produced_graph.edges[used_nodes[index_to]] = mission_grammar.produced_graph.edges[used_nodes[index_to]] or {}
			mission_grammar.produced_graph.edges[used_nodes[index_to]][used_nodes[index_from]]=mission_grammar.inverse(edge)
		end
	end
end

function mission_grammar.inverse(edge)
	if 		edge == "undir_fw" then return "undir_bk"
	elseif 	edge == "undir_bk" then return "undir_fw"
	elseif 	edge == "dir_fw" then return "dir_bk"
	elseif 	edge == "dir_bk" then return "dir_fw" 
	end
end

-- local area_details = {	nr_of_areas=nr_of_areas, -- 
-- 							tileset_id=1, -- tileset id, light world
-- 							outside=true,
-- 							from_direction="west",
-- 							to_direction="east",
-- 							preferred_area_surface=preferred_area_surface, 
-- 							[1]={	area_type="empty",--area_type
-- 									shape_mod=nil, --shape_modifier 
-- 									transition_details=nil, --"transistion <map> <destination>"
-- 									nr_of_connections=1,
-- 									[1]={ type="twoway", areanumber=2, direction="south"}
-- 								}
-- 						  }

function mission_grammar.transform_to_space( params )
	if params.merge then

	else -- a task is one area
		-- transform nodes into area details
		-- initialize the table with the parameters
		log.debug("graph_transform")
		local area_details = {	nr_of_areas=0, -- 
								tileset_id=params.tileset_id, -- tileset id, light world
								outside=params.outside,
								from_direction=params.from_direction,
								to_direction=params.to_direction,
								area_size = params.area_size,
								path_width=params.path_width,
								["start"]={area_type="E", nr_of_connections=1, contains_items={}, [1]={type="twoway", areanumber=1}},
								["goal"]={area_type="E", nr_of_connections=0, contains_items={}},
							  }
		if params.outside then area_details.wall_width = 0
		else area_details.wall_width = 24 end -- dungeon wall = (wall 24)
		local graph = mission_grammar.produced_graph
		if table_util.contains( graph.nodes, "optionalgoal" ) then 
			area_details.optionalgoal = {area_type="E", nr_of_connections=0, contains_items={}} 
		end
		local visited_nodes = {}
		local area_assignment = {}
		local areas_assigned = 0
		-- for each node in the graph we check in forward direction
		for index, node in ipairs(graph.nodes) do
			-- but only if the current node is an area, and not a modifier or start or goal
			if visited_nodes[index] == nil and table_util.contains(mission_grammar.area_types, node) then
				visited_nodes[index]=true
				if area_assignment[index] == nil then
					areas_assigned = areas_assigned +1
					area_assignment[index] = areas_assigned
				end
				local areanumber = area_assignment[index]
				-- initialize the area
				area_details[areanumber]={area_type=node, nr_of_connections=0, contains_items={}}
				local current_area = area_details[areanumber]
				for k,v in pairs(graph.edges[index]) do
					-- now for every edge that that node has we make a connection
					if (v == "undir_fw" or v == "dir_fw") then -- only in forward direction
						local connected_node = graph.nodes[k]
						local split_node = table_util.split(connected_node, ":")
						-- log.debug("edge "..index.."-->"..k.." "..v)
						-- log.debug(connected_node)
						-- log.debug(split_node)
						if table_util.contains(mission_grammar.area_types, split_node[1]) then
							-- log.debug("new area found")
							-- it's an area: look no further, assign the area an area number and continue
							current_area.nr_of_connections=current_area.nr_of_connections+1
							if area_assignment[k] == nil then
								areas_assigned = areas_assigned +1
								area_assignment[k] = areas_assigned
							end
							local connection = "twoway"
							if v == "dir_fw" then connection = "oneway" end
							current_area[current_area.nr_of_connections] = {type=connection, areanumber=area_assignment[k]}
						elseif table_util.contains(mission_grammar.barrier_types, split_node[1]) then
							-- log.debug("barrier found, searching for next area")
							-- it's a barrier type, that means that after this should eventually come a single area
							current_area.nr_of_connections=current_area.nr_of_connections+1
							current_area[current_area.nr_of_connections] = {barriers={connected_node}}
							local next_node_id=k
							local done = false
							repeat
								-- so let's look for that area
								for connected_node_id,edge in pairs(graph.edges[next_node_id]) do
									local possible_next_node = table_util.split(graph.nodes[connected_node_id], ":")
									if edge == "undir_fw" or edge == "dir_fw" then
										-- log.debug("edge "..next_node_id.."-->"..connected_node_id.." "..edge)
										-- ofcourse only check in forward direction
										if table_util.contains(mission_grammar.area_types, possible_next_node[1]) then
											-- we found it, now we add it like any normal connection
											if area_assignment[connected_node_id] == nil then
												areas_assigned = areas_assigned +1
												area_assignment[connected_node_id] = areas_assigned
											end
											local connection = "twoway"
											if v == "dir_fw" then connection = "oneway" end
											current_area[current_area.nr_of_connections].type=connection
											current_area[current_area.nr_of_connections].areanumber=area_assignment[connected_node_id]
											done = true
										elseif table_util.contains(mission_grammar.barrier_types, possible_next_node[1]) then
											-- we found another barrier, okay add that to the list
											-- also update our current node
											next_node_id= connected_node_id
											-- we add a barrier to the list
											visited_nodes[connected_node_id]=true
											table.insert(current_area[current_area.nr_of_connections].barriers, graph.nodes[connected_node_id])
										end
									end
								end
							until done
							-- log.debug("next area found")
						elseif table_util.contains(mission_grammar.key_types, split_node[1]) then
							-- log.debug("key area mod found")
							-- a key type is a modifier for the area, not a connection
							visited_nodes[k]=true
							-- so we add the specific key type
							table.insert(current_area.contains_items, connected_node)
						elseif split_node[1] == "goal" or split_node[1] == "optionalgoal" then
							 current_area.nr_of_connections=current_area.nr_of_connections+1
							 table.insert(current_area, 1, {type="twoway", areanumber=split_node[1]})

						end
					end
				end
			end
		end
		area_details.nr_of_areas=areas_assigned
		mission_grammar.add_main_path_info( area_details, "start" )
		return area_details
	end
end

function mission_grammar.add_main_path_info( area_details, areanumber )
	if areanumber == "goal" then 
		area_details[areanumber].main=true
		return true 
	end
	for con_nr, con in ipairs(area_details[areanumber]) do
		if con.type == "twoway" then
			local is_main = mission_grammar.add_main_path_info( area_details, con.areanumber )
			if is_main then
				con.main = true
				area_details[areanumber].main=true
				return true
			else
				con.main = false
			end
		end
	end
	return false
end

function mission_grammar.update_grammar()
	-- body
end

return mission_grammar