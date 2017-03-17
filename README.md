# History and intent
This project was part of a master thesis by Norbert Heijne. 
Many well known platforms at the time were not offering a proper ARPG kit that could freely be used for research and that could be fully customized.
The code in this repository is an attempt at creating such a platform. 

# Setup and usage

## How to play, things to know
- Download the repository and start solarus.exe to play
- Save files and logs are located in User settings/'UserName'/.solarus/dynamicZelda
- Controls can be altered in game

## Current used version of Solarus engine
- The game currently uses Solarus engine version 1.3
- The documentation for the engine can be found at: http://www.solarus-games.org/doc/1.3/
- The repository contains the editor as well as the engine

## Using the editor
- The editor requires java runtime.
- Load the same directory the editor is located in to edit the game assets
- It is recommended that assets be changed via this editor since it automatically updates the quest data files
- It is NOT recommended to edit the LUA code via the editor (some bugs exist which make it less than ideal)
- The editor also contains a memory leak (by opening many different assets) which can be resolved by restarting the editor

## Editing the LUA code
- All LUA files contain comments that explain what the purpose is of that particular file
- Any LUA file can be customized to change the flow of the game
- The generation algorithm starts in the map lua code. To learn more about the code follow the code from there onward.
- Use the console in game to call your own test functions (F12), the console is enabled if the data folder contains a file named 'Debug'.
- Console output is logged along side the save files

## Editing the engine
- Adding support for a machine learning library requires changes to the sourcecode of the engine (C++) and would require that the ML library be accessible via LUA functions
- The source code of the engine can be found at: http://www.solarus-games.org/development/source-code/

# TODO
- Comment code for easier usage
- Add list of editable functions and parameters and their locations in the LUA files
- Cleanup of code