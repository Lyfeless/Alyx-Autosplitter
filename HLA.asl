// HLVR AUTO SPLITTER 
// VERSION 2.3 -- MAR 20 2021
// CREDITS: 
	// Lyfeless and DerkO for starting the project, initial load removal and splitting code
	// 2838 for Auto-Start, Auto-End, entity list and sigscanning shenanigans
// IF THIS SPLITTER BREAKS FOR YOU PLEASE DO MENTION IN #source2-general IN THE SOURCERUNS DISCORD (it's probably 2838's fault)

state("hlvr") { }

init
{
	// hla accesses static data not by using absolute pointers but using an offset off to the very next instruction instead
	// so we'll have to specify the size of the instruction
    Func<IntPtr, int, int, IntPtr> GetPointerFromOpcode = (ptr, trgOperandOffset, totalSize) =>
	{
		byte[] bytes = memory.ReadBytes(ptr + trgOperandOffset, 4);
		if (bytes == null)
		{
			return IntPtr.Zero; 
		}
		Array.Reverse(bytes);
		int offset = Convert.ToInt32(BitConverter.ToString(bytes).Replace("-",""),16);
		IntPtr actualPtr = IntPtr.Add((ptr + totalSize), offset);
		return actualPtr;
	};

	Action<IntPtr, string> ReportPointer = (ptr, name) => 
	{
		if (ptr == IntPtr.Zero)
			vars.print("[SIGSCANNING] " + name + " ptr was NOT found!!");
		else
			vars.print("[SIGSCANNING] " + name + " ptr was found at " + ptr.ToString("X"));
	};
	
#region SIGNATURE SCANNING
	vars.sigentList 	=	new SigScanTarget(6, 	"40 ?? 48 ?? ?? ??", 
													"48 ?? ?? ?? ?? ?? ??", // MOV RAX,qword ptr [DAT_1814e3bc0]
													"8b ?? 48 ?? ?? ?? ?? ?? ?? 48 ?? ?? ff ?? ?? ?? ?? ?? 4c ?? ??");
	vars.sigloading 	=	new SigScanTarget(18, 	"B2 01 C6 05 ?? ?? ?? ?? 01 48 8B 01 FF 90 ?? ?? ?? ??", 
													"C7 05 ?? ?? ?? ?? 01 00 00 00", // MOV dword ptr [DAT_180f67f7c],0x1 
													"0F 28 74 24 40 48 83 C4 50 5B");
	vars.siginLvlTrans 	=	new SigScanTarget(30, 	"F3 0F 11 05 ?? ?? ?? ?? E8 ?? ?? ?? ?? 48 8B 86 ?? ?? ?? ?? 48 8D 0D ?? ?? ?? ?? 48 85 C0",
													"C6 05 ?? ?? ?? ?? 01"); // MOV byte ptr [DAT_180e8916c],0x1)
	vars.sigbuildNum	=	new SigScanTarget(4,	"48 83 ec ??",
													"8b 05 ?? ?? ?? ??", // MOV EAX,dword ptr [0x18053ef54]
													"33 ff 85 c0 0f ?? ?? ?? ?? 00 48 89 5c 24 30 8b df 48 89 74 24 38");
	vars.sigmapTime		=	new SigScanTarget(11,	"F3 0F 58 ?? 48 8B 05 ?? ?? ?? ??",
													"F3 0F 11 ?? ?? ?? ?? ??", // this
													"48 85 C0 74 ?? 80 38 00 74 ??");
	vars.sigmapTimenoVr	=	new SigScanTarget(0,	"4C 8B 05 ?? ?? ?? ??", // MOV R8,qword ptr [0x18125f8e0]
													"48 8D 0D ?? ?? ?? ?? 48 8B 05 ?? ?? ?? ?? 41 B1 01");
	vars.sigmapName		=	new SigScanTarget(7,	"48 8B 97 ?? ?? ?? ??", 
													"48 8D 0D ?? ?? ?? ??", // LEA RCX,[0x180544a00]
													"48 8B 5C 24 ??");
	vars.signoVr		=	new SigScanTarget(0,	"48 8B 0D ?? ?? ?? ??", // MOV RCX,qword ptr [0x180e5e928]
													"48 8B DA 48 85 C9 0F 84 ?? ?? ?? ?? 48 8B 01");
	vars.sigSignOnState	=	new SigScanTarget(0,	"48 8B 05 ?? ?? ?? ??", // MOV RAX,qword ptr [signOnState base]
													"48 8B D9 48 8D 0D ?? ?? ?? ?? FF 90 ?? ?? ?? ?? 48 85 C0 74 ?? 4C 8B 00");

	var profiler = Stopwatch.StartNew();
	
	// 2838: init process scanners (looks ugly but makes it so it doesn't take 10 seconds to scan)
	ProcessModuleWow64Safe client = modules.FirstOrDefault(x => x.ModuleName.ToLower() == "client.dll");
	ProcessModuleWow64Safe server = modules.FirstOrDefault(x => x.ModuleName.ToLower() == "server.dll");
	ProcessModuleWow64Safe engine = modules.FirstOrDefault(x => x.ModuleName.ToLower() == "engine2.dll");
	if (client == null || engine == null || server == null)
	{
		Thread.Sleep(1000);
		vars.print("[SIGSCANNING] All modules aren't yet loaded! Waiting 1 second until next try");
        throw new Exception();
	}
	var clientScanner = new SignatureScanner(game, client.BaseAddress, client.ModuleMemorySize);
	var engineScanner = new SignatureScanner(game, engine.BaseAddress, engine.ModuleMemorySize);
	var serverScanner = new SignatureScanner(game, server.BaseAddress, server.ModuleMemorySize);
	
	IntPtr ptrnoVr			= GetPointerFromOpcode(clientScanner.Scan(vars.signoVr), 3, 7);
	// this pointer doesn't seem to be initialized whenever the game is in novr
	bool isnoVr = new DeepPointer(ptrnoVr).Deref<IntPtr>(game) == IntPtr.Zero;
	
	IntPtr ptrentList 		= GetPointerFromOpcode(serverScanner.Scan(vars.sigentList), 3, 7);
	IntPtr ptrloading		= GetPointerFromOpcode(clientScanner.Scan(vars.sigloading), 2, 10); 
	IntPtr ptrinLvlTrans	= GetPointerFromOpcode(clientScanner.Scan(vars.siginLvlTrans), 2, 7);
	IntPtr ptrbuildNum		= GetPointerFromOpcode(engineScanner.Scan(vars.sigbuildNum), 2, 6);
	IntPtr ptrmapTime 		= (isnoVr) ? GetPointerFromOpcode(serverScanner.Scan(vars.sigmapTimenoVr), 3, 7) : GetPointerFromOpcode(clientScanner.Scan(vars.sigmapTime), 4, 8);
	IntPtr ptrmapName 		= GetPointerFromOpcode(engineScanner.Scan(vars.sigmapName), 3, 7) + 0x100;
	IntPtr ptrSignOnState	= GetPointerFromOpcode(engineScanner.Scan(vars.sigSignOnState), 3, 7) + 0x218;
	
	ReportPointer(ptrentList, "entList");
	ReportPointer(ptrinLvlTrans, "inLvlTrans");
	ReportPointer(ptrbuildNum, "buildNum");
	ReportPointer(ptrloading, "loading");
	ReportPointer(ptrmapTime, "mapTime");
	ReportPointer(ptrmapName, "mapName");
	ReportPointer(ptrnoVr, "noVr");
	ReportPointer(ptrSignOnState, "signOnState base");
	
	profiler.Stop();
	vars.print("[SIGSCANNING] Signature scanning done in " + profiler.ElapsedMilliseconds * 0.001f + " seconds");

#endregion

	int buildnum = memory.ReadValue<int>(ptrbuildNum);
	vars.print("[GAME INFO] Game is build number " + buildnum);	
	vars.print("[GAME INFO] Game is running in " + ((isnoVr) ? "No VR" : "VR") + " mode");
	
#region SETTING UP WATCHLIST
	// 2838: some of these offsets should be sigscanned...
	vars.loading 		= new MemoryWatcher<int>(ptrloading);
	vars.mapTime 		= (isnoVr) ? new MemoryWatcher<float>(new DeepPointer(ptrmapTime, 0x0)) : new MemoryWatcher<float>(ptrmapTime);
	vars.inLvlTrans 	= new MemoryWatcher<byte>(ptrinLvlTrans);
	vars.entList		= new MemoryWatcher<IntPtr>(new DeepPointer(ptrentList));
	vars.moveFlag 		= new MemoryWatcher<byte>(new DeepPointer(ptrentList, 0x18, 0x78, 0x2e9c));
	vars.map			= new StringWatcher(ptrmapName, 120);
	vars.signOnState	= new MemoryWatcher<byte>(new DeepPointer(ptrSignOnState, 0x1e0, 0x0, 0x50));
	vars.accumTime		= new MemoryWatcher<int>(new DeepPointer(ptrentList, 0x20b8, 0x68));
	
	vars.watchIt = new MemoryWatcherList() {
		vars.loading,
		vars.mapTime,
		vars.inLvlTrans,
		vars.entList,
		vars.moveFlag,
		vars.map,
		vars.signOnState,
		vars.accumTime
	};
#endregion
	
#region ENTITY LIST FUNCTIONS
	
	int entInfoSize = 120;
	
	Func<int, IntPtr> GetEntPtrFromIndex = (index) =>
	{
		// the game splits the entity pointer list into blocks with seemingly a certain size
		// this function is taken from the game's decompiled code

		int block = 24 + (index >> 9) * 8;
		int pos = (index & 511) * entInfoSize;
		
		DeepPointer DPentPtr = new DeepPointer(vars.entList.Current + block, 0x0);
		IntPtr blockPtr = IntPtr.Zero;
		DPentPtr.DerefOffsets(game, out blockPtr);
		
		IntPtr entPtr = blockPtr + pos;
		return entPtr;
	};
	
	Func<IntPtr, bool, string> GetNameFromPtr = (entPtr, isTargetName) =>
	{
		DeepPointer nameptr = new DeepPointer(entPtr, 0x10, (isTargetName) ? 0x18 : 0x20, 0x0);
		string name = "";
		nameptr.DerefString(game, 128, out name);
		return name;
	};
	
	// 2838: EXTREMELY expensive, do NOT call frequently!!!!
	Func<string, bool, IntPtr> GetEntFromName = (name, isTargetName) =>
	{
		var prof = Stopwatch.StartNew();
		// 2838: theorectically the index can go all the way up to 32768 but it never does even on the biggest of maps
		for (int i = 0; i <= 20000; i++)
		{
			IntPtr entPtr = GetEntPtrFromIndex(i);
			if (entPtr != IntPtr.Zero)
			{
				if (GetNameFromPtr(entPtr, isTargetName) == name)
				{
					prof.Stop();
					vars.print("[ENTFINDING] Successfully found " + name + "'s pointer after " + prof.ElapsedMilliseconds * 0.001f + " seconds, index #" + i);
					return entPtr;
				}
				else
				{
					continue;
				}
			}
			prof.Stop();
			vars.print("ENTFINDING] Can't find " + name + "'s pointer! Time spent: " + prof.ElapsedMilliseconds * 0.001f + " seconds");
		}
		
		return IntPtr.Zero;
	};
	
	// 2838: not a necessary function but imma just put this here in case someone finds a use for it
	Func<IntPtr, string> printPosFromPtr = (entPtr) =>
	{
		DeepPointer posDP = new DeepPointer(entPtr, 0x1a0, 0x108);
		IntPtr posPtr;
		posDP.DerefOffsets(game, out posPtr);
		float xPos; memory.ReadValue<float>(posPtr, out xPos);
		float yPos; memory.ReadValue<float>(posPtr + 0x4, out yPos);
		float zPos; memory.ReadValue<float>(posPtr + 0x8, out zPos);
		
		string pos = xPos + " " + yPos + " " + zPos;
		
		return pos;
	};
	
	vars.GetEntFromName = GetEntFromName;
	vars.GetEntPtrFromIndex = GetEntPtrFromIndex;
	vars.GetNameFromPtr = GetNameFromPtr;
	vars.printPosFromPtr = printPosFromPtr;	
#endregion

	vars.OnSessionStart();
}

startup
{
    //SETTINGS
    settings.Add("chapters", false, "Split on Chapters");
	settings.SetToolTip("chapters", "Split on Chapter Transitions Instead of Per-Map");
    
    settings.Add("il", false, "IL Mode");
	settings.SetToolTip("il", "Only used when running ILs. Starts automatically on any map selected");

	settings.Add("changelevelsplit", true, "Use new method of splitting");
	settings.SetToolTip("changelevelsplit", " Splits on detected game changelevel, works with campaign mods that change maps through changelevel triggers");

    //MAP DATA
	vars.visitedMaps = new List<string>();
    
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
	
	vars.signOnStates = new Dictionary<int, string>() {
	//	SIGN ON STATE		NAME
		{0,					"None"},
		{1,					"Challenge"},
		{2,					"Connected"},
		{3,					"New"},
		{4,					"Prespawn"},
		{5,					"Spawn"},
		{6,					"Full"},
		{7,					"ChangeLevel"},
	};
    
    vars.waitForLoading = false;
    
    //TIMER
    vars.currentTime = 0.0f;
	vars.mapStart = false;
	
	//END STUFF 
	vars.autoGripDP1 = new MemoryWatcher<byte>(IntPtr.Zero);
	vars.autoGripDP2 = new MemoryWatcher<byte>(IntPtr.Zero);

	Action OnSessionStart = () => {
		vars.print("[GAMESTATE] Session began at " + vars.currentTime + " timer time, " + vars.mapTime.Current + " internal time & " + vars.accumTime.Current + " save file time");

		if (vars.map.Current == "a5_ending")
		{
			// do both hands to really make sure we don't miss
			vars.autoGripDP1 = new MemoryWatcher<byte>(new DeepPointer(vars.GetEntFromName("g_release_hand1", true), 0x878, 0xb4));
			vars.autoGripDP2 = new MemoryWatcher<byte>(new DeepPointer(vars.GetEntFromName("g_release_hand2", true), 0x878, 0xb4));
		}
	};

	Action OnSessionEnd = () => {
		vars.print("[GAMESTATE] Session ended at " + vars.currentTime + " timer time, " + vars.mapTime.Current + " internal time & " + vars.accumTime.Current + " save file time");
		
		if (vars.map.Current == "a5_ending")
		{
			vars.autoGripDP1 = new MemoryWatcher<byte>(IntPtr.Zero);
			vars.autoGripDP2 = new MemoryWatcher<byte>(IntPtr.Zero);
		}
		vars.mapStart = false;
	};

	Action<string> prints = (msg) =>
	{
		print("[ALYX ASL] " + msg);
	};

	vars.print = prints;

	vars.OnSessionStart = OnSessionStart;
	vars.OnSessionEnd = OnSessionEnd;

	vars.TimerStartHandler = (EventHandler)((s, e) => {
    	vars.print("[TIMER] Timer began at " + vars.currentTime + " timer time, " + vars.mapTime.Current + " internal time & " + vars.accumTime.Current + " save file time");

		if (vars.map.Current == "a5_ending")
		{
			// do both hands to really make sure we don't miss
			vars.autoGripDP1 = new MemoryWatcher<byte>(new DeepPointer(vars.GetEntFromName("g_release_hand1", true), 0x878, 0xb4));
			vars.autoGripDP2 = new MemoryWatcher<byte>(new DeepPointer(vars.GetEntFromName("g_release_hand2", true), 0x878, 0xb4));
		}
    });

	timer.OnStart += vars.TimerStartHandler;
}

update
{
	vars.watchIt.UpdateAll(game);

	if (vars.signOnState.Changed)
	{
		vars.print("[GAMESTATE] Game state changed from " + vars.signOnStates[vars.signOnState.Old] + " to " + vars.signOnStates[vars.signOnState.Current]);
		if (vars.signOnState.Current == 6)
			vars.OnSessionStart();
		else if (vars.signOnState.Old == 6)
			vars.OnSessionEnd();
	}

	if (vars.map.Changed)
	{
		vars.print("[GAMESTATE] Map changed from " + vars.map.Old + " to " + vars.map.Current);
	}
	
	if (vars.map.Current == "a5_ending")
	{
		vars.autoGripDP1.Update(game);
		vars.autoGripDP2.Update(game);
	}
	
	// 2838: 
	// the game has 2 states of loading: waiting for map load (state 1) and waiting for the player to press the trigger (state 2)
	// we'll only need to exclude state 1 as state 2 is when the game has finished loading in
	
	float delta = vars.mapTime.Current - vars.mapTime.Old;
	
	if (delta > 0.0f && vars.loading.Current != 1 && vars.inLvlTrans.Current == 0)
	{
		vars.currentTime += delta;
	}
	
}

start
{   
	vars.currentTime = 0.0f;
	vars.visitedMaps.Clear();

    //Normal Start Condition

    if (vars.map.Current == "a1_intro_world") {
        return (vars.moveFlag.Current == 0 && vars.moveFlag.Old == 1);
    }
    else if ((vars.map.Current != "startup") && settings["il"])
	{
		if (vars.mapStart)
		{
			if (vars.loading.Changed && vars.loading.Old == 2 && vars.loading.Current != 1)
			{
				vars.mapStart = false;
				vars.print("[TIMER] IL splitting enabled, starting from unpause");
				return true;
			}
			return false;
		}
		vars.mapStart = (vars.signOnState.Changed && vars.signOnState.Current == 4 && vars.accumTime.Current == 0);

		return false;
	}
}

reset
{
	vars.visitedMaps.Clear();

	if ((vars.map.Current != "startup" && vars.map.Current != "a1_intro_world") && settings["il"] )
	{
		vars.mapStart = (vars.signOnState.Changed && vars.signOnState.Current == 4 && vars.accumTime.Current == 0);
		return vars.mapStart;
	}
	else if (vars.map.Current == "a1_intro_world")
    {
		if (vars.moveFlag.Old == 0 && vars.moveFlag.Current == 1) 
		{
			vars.currentTime = 0.0f;
			return true;
        } 
		return false;
    }
}

split
{
    //Ending Conditional
	if (vars.map.Current == "a5_ending" && vars.loading.Current == 0)
	{
        return (vars.autoGripDP1.Current == 0 && vars.autoGripDP1.Old == 1) 
		|| (vars.autoGripDP2.Current == 0 && vars.autoGripDP2.Old == 1);
	}

	if (settings["changelevelsplit"])
	{
		if (vars.signOnState.Current == 7)
		{
			if (vars.map.Changed && vars.map.Current != "startup" 
			&& !vars.visitedMaps.Contains(vars.map.Current))
			{
				vars.visitedMaps.Add(vars.map.Current);

				vars.print("[GAMESTATE] Map changelevel event from " + vars.map.Old + " to " + vars.map.Current);

				if (settings["chapters"] && vars.maps[vars.map.Current.ToLower()].Item2 == vars.maps[vars.map.Old.ToLower()].Item2 + 1)
				{
					vars.print("[GAMESTATE] Chapter change!");
					return true;
				}
				else return (!settings["chapters"]);
			}
		}
	}
	//Only split if map is increasing
    else 
	{
		if (!settings["chapters"]) 
			return (vars.maps[vars.map.Current.ToLower()].Item1 == vars.maps[vars.map.Old.ToLower()].Item1 + 1);
		else return vars.maps[vars.map.Current.ToLower()].Item2 == vars.maps[vars.map.Old.ToLower()].Item2 + 1;
	} 
}

isLoading { return true; }

shutdown {
    timer.OnStart -= vars.TimerStartHandler;

	vars.print("Exiting");
}

gameTime { return TimeSpan.FromSeconds(vars.currentTime); }