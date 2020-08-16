state("hlvr")
{
    string256 map : "engine2.dll" , 0x544B00;
    int loading : "client.dll" , 0xF67F7C;
    
    //float mapTime : "server.dll" , 0x125f8e0, 0x0; 2838: this one is written by the game engine, doesn't respond to client-sided lag very much
	float mapTime : "client.dll" , 0xf67f94; 
    
	// 2838: moveFlag is the boolean that controls if the player can move or not
	int moveFlag : "server.dll" , 0x150E1D0, 0x78, 0x2e9c;
    
    // 2838: autoGrip is the boolean an entity at the end uses to control alyx's hand, specifically the one that controls its pose when you 
	// grab onto the cables. This boolean makes your hands stuck and is changed from 1 to 0 when the game ends.
	// an awesome quadruple offset pointer
	byte autoGrip : "server.dll", 0x143C630, 0x28, 0x28, 0xB4;
}

init
{
    vars.waitForLoading = true;
}

exit
{
    timer.IsGameTimePaused = true;
}

startup
{
    //SETTINGS
    settings.Add("chapters", false, "Split on Chapters");
	settings.SetToolTip("chapters", "Split on Chapter Transitions Instead of Per-Map");
    
    settings.Add("il", false, "IL Mode");
	settings.SetToolTip("il", "Only use when running ILs. Starts automatically on any map selected");
    
    //MAP DATA
    vars.latestMap = "a1_intro_world";
	
	vars.rate = 0.0f;
    
    vars.maps = new Dictionary<string, Tuple<int, int>>() { 
    //   MAP NAME                                             ID          CHAPTER
        {"a1_intro_world"               , new Tuple<int, int>(0         , 0         )},
        {"a1_intro_world_2"             , new Tuple<int, int>(1         , 0         )},
        
        {"a2_quarantine_entrance"       , new Tuple<int, int>(2         , 1         )},
        {"a2_pistol"                    , new Tuple<int, int>(3         , 1         )},
        {"a2_hideout"                   , new Tuple<int, int>(4         , 1         )},
        
        {"a2_headcrabs_tunnel"          , new Tuple<int, int>(5         , 2         )},
        {"a2_drainage"                  , new Tuple<int, int>(6         , 2         )},
        {"a2_train_yard"                , new Tuple<int, int>(7         , 2         )},
        
        {"a3_station_street"            , new Tuple<int, int>(8         , 3         )},
        
        {"a3_hotel_lobby_basement"      , new Tuple<int, int>(9         , 4         )},
        {"a3_hotel_underground_pit"     , new Tuple<int, int>(10        , 4         )},
        {"a3_hotel_interior_rooftop"    , new Tuple<int, int>(11        , 4         )},
        {"a3_hotel_street"              , new Tuple<int, int>(12        , 4         )},
        
        {"a3_c17_processing_plant"      , new Tuple<int, int>(13        , 5         )},
        
        {"a3_distillery"                , new Tuple<int, int>(14        , 6         )},
        
        {"a4_c17_zoo"                   , new Tuple<int, int>(15        , 7         )},
        
        {"a4_c17_tanker_yard"           , new Tuple<int, int>(16        , 8         )},
        
        {"a4_c17_water_tower"           , new Tuple<int, int>(17        , 9         )},
        {"a4_c17_parking_garage"        , new Tuple<int, int>(18        , 9         )},
        
        {"a5_vault"                     , new Tuple<int, int>(19        , 10        )},
        {"a5_ending"                    , new Tuple<int, int>(20        , 10        )},
        
        {"startup"                      , new Tuple<int, int>(-10       , -10       )}
    };
    
    vars.waitForLoading = false;
    
    //TIMER
    vars.currentTime = 0.0f;
}

update
{
    //fix for weird timing during game crash, might not be needed anymore
    if(vars.waitForLoading && current.loading >= 1)
    {
        timer.IsGameTimePaused = false;
        vars.waitForLoading = false;
    }
    
    //Set Current Time
	
	// 2838: 
	// the game has 2 states of loading: waiting for map load (state 1) and waiting for the player to press the trigger (state 2)
	// we'll only need to exclude state 1 as state 2 is when the game has finished loading in
	
	float delta = current.mapTime - old.mapTime;
	
	if (delta > 0.0f && current.loading != 1)
	{
		vars.currentTime += delta;
		vars.rate = current.mapTime - old.mapTime;
	}
}

start
{   
	vars.currentTime = 0.0f;
    //Normal Start Condition
    if(current.map == "a1_intro_world") {
        if (current.moveFlag == 0 && old.moveFlag == 1) 
		{
            vars.latestMap = "a1_intro_world";
            return true;
        }
        return false;
    }
    else if(settings["il"])
    {
        //IL Starts on any level
        bool ilstart = (old.loading == 1 && current.loading == 0);
        if (ilstart) { //latestmap has to be set or end split won't work
            vars.latestMap = current.map;
        }
        return ilstart;
    }
}

reset
{
    if(!settings["il"])
    {
        if(current.map == "a1_intro_world") {
            if (current.moveFlag == 0 && old.moveFlag == 1) {
                vars.latestMap = "a1_intro_world";
                vars.currentTime = 0.0f;
                return true;
            }
            return false;
        } 
    }
}

split
{
    //Only split if map is increasing
    if(vars.maps[current.map].Item1 == vars.maps[vars.latestMap].Item1 + 1)
    {
    	string oldMap = vars.latestMap;
        vars.latestMap = current.map;
        
        if(settings["chapters"])
            return (vars.maps[current.map].Item2 == vars.maps[oldMap].Item2 + 1);
		
        return true;
    }
    
    //Ending Conditional
	if (current.map == "a5_ending" && current.autoGrip == 0 && old.autoGrip == 1)
	{
		return true;
	}
}

isLoading { return true; }

gameTime { return TimeSpan.FromSeconds(vars.currentTime); }
