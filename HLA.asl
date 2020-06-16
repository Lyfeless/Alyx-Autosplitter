state("hlvr")
{
    float startPos : "client.dll" , 0xED74C0;
    
    string256 map : "engine2.dll" , 0x544B00;
    int loading : "client.dll" , 0xF68058;
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
    settings.Add("chapters", false, "Split on Chapters");
	settings.SetToolTip("chapters", "Split on Chapter Transitions Instead of Per-Map");
    
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

update
{
    if(vars.waitForLoading && current.loading == 1)
    {
        timer.IsGameTimePaused = false;
        vars.waitForLoading = false;
    }    

    if(old.loading == 0 && current.loading == 1)
    {
        vars.tempMap = old.map;
    }
    
    if(current.map == "a1_intro_world")
        vars.latestMap = "a1_intro_world";
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
    if(old.loading == 1 && current.loading == 0)
    {
        if(vars.maps[current.map].Item1 == vars.maps[vars.tempMap].Item1 + 1)
        {
            if(vars.tempMap == vars.latestMap)
            {
                vars.latestMap = current.map;
                
                if(settings["chapters"])
                    return vars.maps[current.map].Item2 == vars.maps[vars.tempMap].Item2 + 1;
            
                return true;
            }
        }
    }
    
    return (current.map == "a5_ending" && current.startPos > -1000.0f && old.startPos < -2000.0f);
}

isLoading
{
    return (current.loading != 0);
}
