state("hlvr")
{
    float startPos : "client.dll" , 0xE9A030;
    string256 map : "engine2.dll" , 0x544B00;
    int loading : "client.dll" , 0xF67F7C;
}

startup
{
	vars.logFileName = "ALYX.log";
	vars.maxFileSize = 4000000;
	
	vars.ChaptersSettingName = "Split on chapters";
	vars.LoggingSettingName = "Debug Logging";
	
    settings.Add(vars.ChaptersSettingName, false, "Split on Chapters");
	settings.SetToolTip(vars.ChaptersSettingName, "Split on Chapter Transitions Instead of Per-Map");
	settings.Add(vars.LoggingSettingName, true);
	settings.SetToolTip(vars.LoggingSettingName, "Log files help solve auto-splitting issues");
	
    
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
}

init
{
    vars.waitForLoading = true;
	
	vars.timerSecondOLD = -1;
	vars.timerSecond = 0;
	vars.timerMinuteOLD = -1;
	vars.timerMinute = 0;
	
	// If the logging setting is checked, this function logs game info to a log file.
	// If the file reaches max size, it will delete the oldest entries.
	vars.Log = (Action<string>)( myString => {
		
		if(settings[vars.LoggingSettingName]){
			
			vars.logwriter = File.AppendText(vars.logFileName);
			
			print(myString);
			vars.logwriter.WriteLine(myString); 
			
			vars.logwriter.Close();
			
			if((new FileInfo(vars.logFileName)).Length > vars.maxFileSize){
				string[] lines = File.ReadAllLines(vars.logFileName);
				File.WriteAllLines(vars.logFileName, lines.Skip(lines.Length/8).ToArray());
			}
		}
		else{
			if(File.Exists(vars.logFileName)){
				File.Delete(vars.logFileName);
			}
		}
	});
	
	// If a second/minute has passed, log important values.
	vars.PeriodicLogging = (Action)( () => {
		vars.timerMinute = timer.CurrentTime.RealTime.Value.Minutes;
	
		if(vars.timerMinute != vars.timerMinuteOLD){
			vars.timerMinuteOLD = vars.timerMinute;
			
			vars.Log("TimeOfDay: " + DateTime.Now.ToString() + "\n" +
			"settings[vars.ChaptersSettingName]: " + settings[vars.ChaptersSettingName].ToString() + "\n");
		}
		
		vars.timerSecond = timer.CurrentTime.RealTime.Value.Seconds;
	
		if(vars.timerSecond != vars.timerSecondOLD){
			vars.timerSecondOLD = vars.timerSecond;
			
			vars.Log("RealTime: "+timer.CurrentTime.RealTime.Value.ToString(@"hh\:mm\:ss") + "\n" +
			"GameTime: "+timer.CurrentTime.GameTime.Value.ToString(@"hh\:mm\:ss") + "\n" +
			"CurrentSplitIndex: "+timer.CurrentSplitIndex.ToString() + "\n" +
			"loading: " + current.loading.ToString() + "\n" +
			"map: " + current.map.ToString() + "\n" +
			"startPos: " + current.startPos.ToString() + "\n");
		}
	});
}

update
{
    if(vars.waitForLoading && current.loading == 1)
    {
        timer.IsGameTimePaused = false;
        vars.waitForLoading = false;
    }
}

start
{
    if(current.map == "a1_intro_world")
        if(old.loading == 1 && current.loading == 0)
            return (current.startPos > 200.0f);
        else
            return (current.startPos > 200.0f && old.startPos < -1000.0f);
}

reset
{
    if(current.map == "a1_intro_world")
        if(old.loading == 1 && current.loading == 0)
            return (current.startPos > 200.0f);
        else
            return (current.startPos > 200.0f && old.startPos < -1000.0f);
}

split
{	
	vars.PeriodicLogging();

	if(vars.maps[current.map].Item1 == vars.maps[old.map].Item1 + 1)
	{
		if(settings[vars.ChaptersSettingName])
			return vars.maps[current.map].Item2 == vars.maps[old.map].Item2 + 1;
		return true;
	}
    
    return (current.map == "a5_ending" && current.startPos > -1000.0f && old.startPos < -2000.0f);
}

isLoading
{
    return (current.loading != 0);
}
