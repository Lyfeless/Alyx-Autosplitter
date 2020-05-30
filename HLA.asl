/*
full values incase shit be cray-cray

Loading:
F8 69 ?? ?? ?? 7F 00 00 40 6B ?? ?? ?? 7F 00 00 40 6B ?? ?? ?? 7F 00 00 F0 34 ?? ?? ?? 7F 00 00 A8 0F ?? ?? ?? 7F 00 00 90 55 ?? ?? ?? 7F 00 00 60 6E ?? ?? ?? 7F 00 00 00 00 00

Map:
58 F1 ?? ?? ?? 7F 00 00 ?? ?? ?? ?? ?? 7F 00 00 01 00 00 00 00 00 00 00 ?? 69 ?? ?? ?? 7F 00 00 57 E4 ?? ?? ?? 7F 00 00 ?? 00 00 00 00 00 00 00 10 F2 ?? ?? ?? 7F 00 00 ?? 4C ?? ?? ?? 7F 00 00 AC 03 ?? ?? ?? 7F 00 00 ?? 01 ?? ?? ??

Pos:
90 2A ?? ?? ?? 7F 00 00 B0 50 ?? ?? ?? 7F 00 00 E0 2B ?? ?? ?? 7F 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 FF FF FF FF FF FF FF FF FF FF FF FF 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 A0 0F
*/

state("hlvr") { }

startup
{
    vars.logFileName = "ALYX.log";

    vars.watchers = new MemoryWatcherList();
    
    //Signatures
    vars.loadingTarget = new SigScanTarget(-20, "F8 69 ?? ?? ?? 7F 00 00 40 6B");
    vars.mapTarget = new SigScanTarget(-256, "58 F1 ?? ?? ?? 7F 00 00 ?? ?? ?? ?? ?? 7F 00 00 01 00 00 00 00 00 00 00 ?? 69");
    vars.ZPosTarget = new SigScanTarget(112, "90 2A ?? ?? ?? 7F 00 00 B0 50 ?? ?? ?? 7F");

    //Settings
    settings.Add("chapters", false, "Split on Chapters");
	settings.SetToolTip("chapters", "Split on Chapter Transitions Instead of Per-Map");
    
    settings.Add("il", false, "IL Mode");
	settings.SetToolTip("il", "Only use when running ILs. Starts automatically on any map selected");
    
    //Map Data
    vars.tempMap = "";
    vars.latestMap = "";
    
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
    vars.Log = (Action<string>)( myString => {
        vars.logwriter = File.AppendText(vars.logFileName);
        vars.logwriter.WriteLine(myString); 
        vars.logwriter.Close();
    });
    
    vars.waitForLoading = true;
    
    ProcessModuleWow64Safe clientModule = modules.SingleOrDefault(m => m.FileName.Contains("win64\\client.dll"));
    if (clientModule == null) {
		Thread.Sleep(10);
        throw new Exception("client.dll module not found");
	}
    
    ProcessModuleWow64Safe engineModule = modules.SingleOrDefault(m => m.FileName.Contains("engine2.dll"));
    if (engineModule == null) {
		Thread.Sleep(10);
        throw new Exception("engine2.dll module not found");
	}
    
    var clientScanner = new SignatureScanner(game, clientModule.BaseAddress,clientModule.ModuleMemorySize);
    var engineScanner = new SignatureScanner(game, engineModule.BaseAddress,engineModule.ModuleMemorySize);
    
    var loadingAddr = clientScanner.Scan(vars.loadingTarget);
    var mapAddr = engineScanner.Scan(vars.mapTarget);
    var ZPosAddr = clientScanner.Scan(vars.ZPosTarget);
    
    var addresses = new IntPtr[]
	{
		loadingAddr,
        mapAddr,
        ZPosAddr
	};
	if (addresses.Any(o => (ulong)o <= 100))
		throw new Exception("Failed to find all addresses.");
    
    vars.loading = new MemoryWatcher<int>(loadingAddr);
    vars.map = new StringWatcher(mapAddr, 100);
    vars.ZPos = new MemoryWatcher<float>(ZPosAddr);
    
    vars.watchers.Clear();
    vars.watchers.AddRange(new MemoryWatcher[]
    {
        vars.loading,
        vars.map,
        vars.ZPos
    });
}

exit
{
    timer.IsGameTimePaused = true;
}

update
{
    vars.watchers.UpdateAll(game);
    
    if(vars.waitForLoading && vars.loading.Current == 1)
    {
        timer.IsGameTimePaused = false;
        vars.waitForLoading = false;
    }
    
    if(vars.map.Current == "a1_intro_world")
        vars.latestMap = "a1_intro_world";
}

start
{
    if(settings["il"])
    {
        if(vars.map.Current == "a1_intro_world")
            return (vars.ZPos.Current > 100.0f);
        else
        {
            if (vars.loading.Old == 1 && vars.loading.Current == 0)
            {
                vars.latestMap = vars.map.Current;
                return true;
            }
            return false;
        }
    }
    else
    {
        if(vars.map.Current == "a1_intro_world")
            if(vars.loading.Old == 1 && vars.loading.Current == 0)
                return (vars.ZPos.Current > 100.0f);
            else
                return (vars.ZPos.Current > 100.0f && vars.ZPos.Old < -1000.0f);
    }
}

reset
{
    if(!settings["il"])
    {
        if(vars.map.Current == "a1_intro_world")
            if(vars.loading.Old == 1 && vars.loading.Current == 0)
                return (vars.ZPos.Current > 100.0f);
            else
                return (vars.ZPos.Current > 100.0f && vars.ZPos.Old < -1000.0f);
    }
}

split
{
    /*
    if(vars.loading.Old == 1 && vars.loading.Current == 0)
    {
        if(vars.maps[vars.map.Current].Item1 == vars.maps[vars.tempMap].Item1 + 1)
        {
            if(vars.tempMap == vars.latestMap)
            {
                vars.latestMap = vars.map.Current;
                
                if(settings["chapters"])
                    return vars.maps[vars.map.Current].Item2 == vars.maps[vars.tempMap].Item2 + 1;
            
                return true;
            }
        }
    }
    */
    
    if(vars.map.Current != vars.map.Old && vars.map.Current != "a1_intro_world")
    {
        if(vars.maps[vars.map.Current].Item1 == vars.maps[vars.map.Old].Item1 + 1)
        {
            if(vars.map.Old == vars.latestMap)
            {
                vars.latestMap = vars.map.Current;
                
                if(settings["chapters"])
                    return vars.maps[vars.map.Current].Item2 == vars.maps[vars.map.Old].Item2 + 1;
                
                return true;
            }
        }
    }
    
    return (vars.map.Current == "a5_ending" && vars.ZPos.Current > -1000.0f && vars.ZPos.Old < -2000.0f);
}

isLoading
{
    return (vars.loading.Current != 0);
}
