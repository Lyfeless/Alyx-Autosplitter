// HLVR AUTO SPLITTER 
// VERSION 2.7 - OCTOBER 15 2021
// CREDITS: 
    // Lyfeless and DerkO for starting the project, initial load removal and splitting code
    // 2838 for Auto-Start, Auto-End, entity list, sigscanning and memory injection shenanigans
    // Ero for a way to renaming splits
// IF THIS SPLITTER BREAKS FOR YOU PLEASE DO MENTION IN #source2-general IN THE SOURCERUNS DISCORD (it's probably 2838's fault)

state("hlvr") { }

startup
{
#region DEBUG SPEW

    // DEBUG SPEW
    var dictDebugSwitches = new Dictionary<string, bool>()
    {
        {"DISABLE",             true},
        {"ALL",                 true},
        {"[ACHIEVEMENTS]",      true},
        {"[GAMESTATE]",         false},
        {"[TIMER]",             false},
        {"[SIGSCANNING]",       true},
        {"[GAME INFO]",         false},
        {"[ENTFINDING]",        true},
    };

    Action<string> prints = (msg) =>
    {
        if (dictDebugSwitches["DISABLE"]) goto eof;

        if (!dictDebugSwitches["ALL"])
            foreach (string type in dictDebugSwitches.Keys)
            {
                if (msg.Contains(type) && !dictDebugSwitches[type])
                    goto eof;
            }

        print("[ALYX ASL] " + msg);

        eof:
        ;
    };
    
    vars.print = prints;

#endregion

#region SETTINGS

    //SETTINGS  
    settings.Add("start/reset", true, "Auto Start and Reset");
    settings.Add("manualreset", false, "Disable Auto-Resetting", "start/reset");
    settings.Add("il", false, "IL Mode", "start/reset");
    settings.SetToolTip("il", "Starts the timer automatically on any map selected");

    settings.Add("split", true, "Auto Split");
    settings.Add("split-type1", true, "Split on detected map change", "split");
    settings.Add("changelevelsplit", true, "Use new method for detecting splits", "split-type1");
    settings.SetToolTip("changelevelsplit", "Splits on detected game changelevel, works with campaign mods that change maps through changelevel triggers");
    settings.Add("split-type2", false, "Split on Chapters", "split");
    settings.SetToolTip("split-type2", "Split on Chapter transitions instead of Per-Map");
    settings.Add("split-type3", false, "Split on getting achievements", "split");
    settings.Add("split-type4", false, "Split on collecting enough resins", "split");
    settings.SetToolTip("split-type4", "Splits on collecting the maximum possible number of resin in a level");

    settings.Add("resinexclude", true, "Ignore certain practically unobtainable resin in splitting logic", "split-type4");
    settings.SetToolTip("resinexclude", 
    "Some resin are technically obtainable, however due to map design they aren't normally obtainable , usually due to them being beind a map change trigger\n" + 
    "Since resin splitting depends on absolutely all resin being obtained within a map, these can cause the logic to break");
    settings.Add("resinexclude-a2_headcrabs_tunnel", false, "1 resin in a2_headcrabs_tunnel", "resinexclude");
    settings.SetToolTip("resinexclude-a2_headcrabs_tunnel", "The resin hidden under a bucket on the other side of the changelevel trigger, could be missed if the runner exits the map without knowing");
    settings.Add("resinexclude-a3_hotel_lobby_basement", true, "1 resin in a3_hotel_lobby_basement", "resinexclude");
    settings.SetToolTip("resinexclude-a3_hotel_lobby_basement", "The resin hidden behind the buckets behind the changelevel trigger");
    settings.Add("resinexclude-a3_hotel_street", true, "2 resin in a3_hotel_street", "resinexclude");
    settings.SetToolTip("resinexclude-a3_hotel_street", "The resin in the floor down to which the player enters and immediately changelevel");

    settings.Add("splitsrename", false, "Dynamically rename current splits depending on splitting context", "split");
    settings.Add("splitsrename-type1", true, "Rename according to last map's name upon changing level", "splitsrename");
    settings.Add("splitsrename-type3", true, "Rename to obtained achievement", "splitsrename");
    settings.Add("splitsrename-type4", false, "Rename according to number of resin upon collecting enough", "splitsrename");

#endregion

#region MAP DATA
    //MAP DATA
    vars.listVisitedMaps = new List<string>();
    vars.listSplitResinMaps = new List<string>();
#endregion

#region DICTIONARIES
    vars.dictMaps = new Dictionary<string, Tuple<int, int, int>>() 
    { 
    //   MAP NAME                                                  ID          CHAPTER     MINIMUM RESIN
        {"a1_intro_world"               , new Tuple<int, int, int>(0         , 0         , 0         )},
        {"a1_intro_world_2"             , new Tuple<int, int, int>(1         , 0         , 0         )},
        
        {"a2_quarantine_entrance"       , new Tuple<int, int, int>(2         , 1         , 0         )},
        {"a2_pistol"                    , new Tuple<int, int, int>(3         , 1         , 0         )},
        {"a2_hideout"                   , new Tuple<int, int, int>(4         , 1         , 0         )},
        
        {"a2_headcrabs_tunnel"          , new Tuple<int, int, int>(5         , 2         , 1         )},
        {"a2_drainage"                  , new Tuple<int, int, int>(6         , 2         , 0         )},
        {"a2_train_yard"                , new Tuple<int, int, int>(7         , 2         , 0         )},
        
        {"a3_station_street"            , new Tuple<int, int, int>(8         , 3         , 0         )},
        
        {"a3_hotel_lobby_basement"      , new Tuple<int, int, int>(9         , 4         , 1         )},
        {"a3_hotel_underground_pit"     , new Tuple<int, int, int>(10        , 4         , 0         )},
        {"a3_hotel_interior_rooftop"    , new Tuple<int, int, int>(11        , 4         , 0         )},
        {"a3_hotel_street"              , new Tuple<int, int, int>(12        , 4         , 2         )},
        
        {"a3_c17_processing_plant"      , new Tuple<int, int, int>(13        , 5         , 0         )},
        
        {"a3_distillery"                , new Tuple<int, int, int>(14        , 6         , 0         )},
        
        {"a4_c17_zoo"                   , new Tuple<int, int, int>(15        , 7         , 0         )},
        
        {"a4_c17_tanker_yard"           , new Tuple<int, int, int>(16        , 8         , 0         )},
        
        {"a4_c17_water_tower"           , new Tuple<int, int, int>(17        , 9         , 0         )},
        {"a4_c17_parking_garage"        , new Tuple<int, int, int>(18        , 9         , 0         )},
        
        {"a5_vault"                     , new Tuple<int, int, int>(19        , 10        , 0         )},
        {"a5_ending"                    , new Tuple<int, int, int>(20        , 10        , 0         )},
        
        {"startup"                      , new Tuple<int, int, int>(-10       , -10       , 0         )}
    };

    vars.dictAchNames = new Dictionary<string, string>()
    {
        // ACHIEVEMENT API NAME                     ACTUAL NAME
        {"TRACK_A1_INTRO_WORLD_2",                  "Hit and Run"},
        {"TRACK_A2_QUARANTINE_ENTRANCE",            "Quaranta Giorni"},
        {"SIDE_GLOBAL_BREAK_BOTTLES",               "Mazel Tov"},
        {"SIDE_FEED_SNARK",                         "Good Grub"},
        {"SIDE_HL2_PLAYGROUND",                     "On a Roll"},
        {"SIDE_RUSSELL_SCENE",                      "Little Slugger"},
        {"SIDE_CATCH_AMMO_CLIP",                    "Mag-Snagger"},
        {"TRACK_A2_HIDEOUT",                        "Sustenance"},
        {"SIDE_SQUEEZE_HC_HEART",                   "Freshly Squeezed"},
        {"TRACK_A2_HEADCRABS_TUNNEL",               "Zombie with a Shotgun"},
        {"TRACK_A2_DRAINAGE",                       "Xen Garden"},
        {"TRACK_A2_TRAIN_YARD",                     "Off the Rails"},
        {"TRACK_A3_STATION_STREET",                 "Checking In"},
        {"TRACK_A3_HOTEL_LOBBY_BASEMENT",           "Heart-Breaker Hotel"},
        {"TRACK_A3_HOTEL_UNDERGROUND_PIT",          "Surface Tension"},
        {"TRACK_A3_HOTEL_INTERIOR_ROOFTOP",         "Unbonded"},
        {"TRACK_A3_HOTEL_STREET",                   "Cord-Cutter"},
        {"TRACK_A3_C17_PROCESSING_PLANT",           "Blast From the Past"},
        {"TRACK_A3_DISTILLERY_NOKILLBZ",            "Sound Strategy"},
        {"TRACK_A3_DISTILLERY_KILLBZ",              "Flat Note"},
        {"SIDE_CATCH_FALLING_BOTTLE",               "Hold Your Liquor"},
        {"TRACK_A4_C17_ZOO",                        "Sea Level"},
        {"TRACK_A4_C17_TANKER_YARD",                "Triple Bypass"},
        {"TRACK_A4_C17_WATER_TOWER",                "High Water March"},
        {"TRACK_A4_C17_PARKING_GARAGE",             "Textbook Jinxing"},
        {"TRACK_A5_VAULT",                          "Point Extraction"},
        {"TRACK_A5_ENDING",                         "Consequences"},
        {"TRAINING_LOOT_ZOMBIE",                    "Dead Giveaway"},
        {"TRAINING_BREAK_ITEM_CRATE",               "Smash and Grab"},
        {"TRAINING_KILL_SOLDIER_WITH_GASTANK",      "Pro-Pain"},
        {"SKILL_KILL_CHARGER_WHILE_SHIELD_UP",      "Indirect Approach"},
        {"TRAINING_LOOT_LIVING_SOLDIER",            "Combine Harvester"},
        {"TRAINING_STEAL_XEN_GRENADE",              "Xen Lootism"},
        {"SIDE_HACK_TRIPMINE",                      "Safe Trip"},
        {"SKILL_GGENEMY_GRENADE_MID_FLIGHT",        "Deadliest Catch"},
        {"SIDE_CLOSE_TO_BLIND_ZOMBIE",              "Near-Jeff Experience"},
        {"SIDE_BRING_RUSSELL_VODKA",                "Team Spirit"},
        {"HIDDEN_CARRY_GNOME",                      "Gnome Vault of My Own"}
    };
    
    vars.signOnStates = new Dictionary<int, string>() 
    {
    //   SIGN ON STATE          NAME
        {0,                    "None"},
        {1,                    "Challenge"},
        {2,                    "Connected"},
        {3,                    "New"},
        {4,                    "Prespawn"},
        {5,                    "Spawn"},
        {6,                    "Full"},
        {7,                    "ChangeLevel"},
    };

#endregion

#region TIMER / SESSION
    //TIMER
    vars.flCurrentTime = 0.0f;
    vars.bMapStart = false;
    
    vars.TimerModel = new TimerModel { CurrentState = timer };

    Func<string> PrintTimeInfo = () => 
    {
        return vars.flCurrentTime + " timer time, " + vars.mwMapTime.Current + " internal time & " + vars.mwAccumTime.Current + " save file time";
    };

    vars.PrintTimeInfo = PrintTimeInfo;
    
    vars.mwAutogrip1 = new MemoryWatcher<byte>(IntPtr.Zero);
    vars.mwAutogrip2 = new MemoryWatcher<byte>(IntPtr.Zero);

    Action OnSessionStart = () => 
    {
        vars.print("[GAMESTATE] Session began at " + vars.PrintTimeInfo());

        if (vars.mwMap.Current == "a5_ending")
        {
            // do both hands to really make sure we don't miss
            vars.mwAutogrip1 = new MemoryWatcher<byte>(new DeepPointer(vars.GetEntFromName("g_release_hand1", true), 0x878, 0xb4));
            vars.mwAutogrip2 = new MemoryWatcher<byte>(new DeepPointer(vars.GetEntFromName("g_release_hand2", true), 0x878, 0xb4));
        }
    };

    Action OnSessionEnd = () => 
    {
        vars.print("[GAMESTATE] Session ended at " + vars.PrintTimeInfo());
        
        if (vars.mwMap.Current == "a5_ending")
        {
            vars.mwAutogrip1 = new MemoryWatcher<byte>(IntPtr.Zero);
            vars.mwAutogrip2 = new MemoryWatcher<byte>(IntPtr.Zero);
        }
        vars.bMapStart = false;
    };

    vars.OnSessionStart = OnSessionStart;
    vars.OnSessionEnd = OnSessionEnd;

    vars.TimerStartHandler = (EventHandler)((s, e) => 
    {
        vars.print("[TIMER] Timer began at " + vars.PrintTimeInfo());

        vars.flCurrentTime = 0.0f;
        vars.iAchBrokenBottles = 0;
        vars.listVisitedMaps.Clear();
        vars.listSplitResinMaps.Clear();
        vars.listAchObtained.Clear();

        if (vars.mwMap.Current == "a5_ending")
        {
            // do both hands to really make sure we don't miss
            vars.mwAutogrip1 = new MemoryWatcher<byte>(new DeepPointer(vars.GetEntFromName("g_release_hand1", true), 0x878, 0xb4));
            vars.mwAutogrip2 = new MemoryWatcher<byte>(new DeepPointer(vars.GetEntFromName("g_release_hand2", true), 0x878, 0xb4));
        }
    });

    vars.TimerSplitHandler = (EventHandler)((s, e) => 
    {
        vars.print("[TIMER] Timer split at " + vars.PrintTimeInfo());
    });

    timer.OnStart += vars.TimerStartHandler;
    timer.OnSplit += vars.TimerSplitHandler;

#endregion

    vars.listInjections = new List<Tuple<IntPtr, byte[], byte[]>>();

#region ACHIEVEMENTS
    // ACHIEVEMENT CODE
    vars.ptrAchievement = IntPtr.Zero;
    vars.iAchBrokenBottles = 0;
    vars.listAchObtained = new List<string>();
#endregion
}

init
{

#region FUNCTIONS
    // hla accesses static data not by using absolute pointers but using an offset off to the very next instruction instead
    // so we'll have to specify the size of the instruction
    Func<IntPtr, int, int, IntPtr> GetPointerFromOpcode = (ptr, trgOperandOffset, totalSize) =>
    {
        int offset = memory.ReadValue<int>(ptr + trgOperandOffset, 4);
        if (offset == 0)
            return IntPtr.Zero; 
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

    Func<string, ProcessModuleWow64Safe> GetModule = (moduleName) =>
    {
        return modules.FirstOrDefault(x => x.ModuleName.ToLower() == moduleName);
    };

    Func<string, SignatureScanner> GetSignatureScanner = (moduleName) =>
    {
        ProcessModuleWow64Safe proc = GetModule(moduleName);
        Thread.Sleep(1000);
        if (proc == null)
            throw new Exception(moduleName + " isn't loaded!");
        return new SignatureScanner(game, proc.BaseAddress, proc.ModuleMemorySize);
    };


    vars.listInjections.Clear();
    Action<IntPtr, byte[], byte[]> InjectionListAdd = (ptr, bytesOrig, bytesNew) =>
    {
        game.VirtualProtect(ptr, bytesNew.Length, MemPageProtect.PAGE_EXECUTE_READWRITE);
        vars.listInjections.Add(new Tuple<IntPtr, byte[], byte[]>(ptr, bytesNew, bytesOrig));
    };
    Action InjectionListExecute = () =>
    {
        foreach (Tuple<IntPtr, byte[], byte[]> injection in vars.listInjections)
            if (injection.Item1 != IntPtr.Zero)
                game.WriteBytes(injection.Item1, injection.Item2);
    };

#endregion

#region SIGSCANNING
    var sigEntList          =   new SigScanTarget(6,    "40 ?? 48 ?? ?? ??", 
                                                        "48 ?? ?? ?? ?? ?? ??", // MOV RAX,qword ptr [DAT_1814e3bc0]
                                                        "8b ?? 48 ?? ?? ?? ?? ?? ?? 48 ?? ?? ff ?? ?? ?? ?? ?? 4c ?? ??");
    var sigLoading          =   new SigScanTarget(18,   "B2 01 C6 05 ?? ?? ?? ?? 01 48 8B 01 FF 90 ?? ?? ?? ??", 
                                                        "C7 05 ?? ?? ?? ?? 01 00 00 00", // MOV dword ptr [DAT_180f67f7c],0x1 
                                                        "0F 28 74 24 40 48 83 C4 50 5B");
    var sigInLvlTrans       =   new SigScanTarget(30,   "F3 0F 11 05 ?? ?? ?? ?? E8 ?? ?? ?? ?? 48 8B 86 ?? ?? ?? ?? 48 8D 0D ?? ?? ?? ?? 48 85 C0",
                                                        "C6 05 ?? ?? ?? ?? 01"); // MOV byte ptr [DAT_180e8916c],0x1)
    var sigBuildNum         =   new SigScanTarget(4,    "48 83 ec ??",
                                                        "8b 05 ?? ?? ?? ??", // MOV EAX,dword ptr [0x18053ef54]
                                                        "33 ff 85 c0 0f ?? ?? ?? ?? 00 48 89 5c 24 30 8b df 48 89 74 24 38");
    var sigMapTime          =   new SigScanTarget(11,   "F3 0F 58 ?? 48 8B 05 ?? ?? ?? ??",
                                                        "F3 0F 11 ?? ?? ?? ?? ??", // this
                                                        "48 85 C0 74 ?? 80 38 00 74 ??");
    var sigMapTimeNoVr      =   new SigScanTarget(0,    "4C 8B 05 ?? ?? ?? ??", // MOV R8,qword ptr [0x18125f8e0]
                                                        "48 8D 0D ?? ?? ?? ?? 48 8B 05 ?? ?? ?? ?? 41 B1 01");
    var sigMapName          =   new SigScanTarget(7,    "48 8B 97 ?? ?? ?? ??", 
                                                        "48 8D 0D ?? ?? ?? ??", // LEA RCX,[0x180544a00]
                                                        "48 8B 5C 24 ??");
    var sigNoVr             =   new SigScanTarget(0,    "48 8B 0D ?? ?? ?? ??", // MOV RCX,qword ptr [0x180e5e928]
                                                        "48 8B DA 48 85 C9 0F 84 ?? ?? ?? ?? 48 8B 01");
    var sigSignOnState      =   new SigScanTarget(0,    "48 8B 05 ?? ?? ?? ??", // MOV RAX,qword ptr [signOnState base]
                                                        "48 8B D9 48 8D 0D ?? ?? ?? ?? FF 90 ?? ?? ?? ?? 48 85 C0 74 ?? 4C 8B 00");

    var swProfiler = Stopwatch.StartNew();
    
    // 2838: init process scanners (looks ugly but makes it so it doesn't take 10 seconds to scan)
    var scannerClient = GetSignatureScanner("client.dll");
    var scannerServer = GetSignatureScanner("server.dll");
    var scannerEngine = GetSignatureScanner("engine2.dll");

    IntPtr ptrNoVr              = GetPointerFromOpcode(scannerClient.Scan(sigNoVr), 3, 7);
    // this pointer doesn't seem to be initialized whenever the game is in novr
    bool bIsNoVr = new DeepPointer(ptrNoVr).Deref<IntPtr>(game) == IntPtr.Zero;
    
    IntPtr ptrEntList           = GetPointerFromOpcode(scannerServer.Scan(sigEntList), 3, 7);
    IntPtr ptrLoading           = GetPointerFromOpcode(scannerClient.Scan(sigLoading), 2, 10); 
    IntPtr ptrInLvlTrans        = GetPointerFromOpcode(scannerClient.Scan(sigInLvlTrans), 2, 7);
    IntPtr ptrBuildNum          = GetPointerFromOpcode(scannerEngine.Scan(sigBuildNum), 2, 6);
    IntPtr ptrMapTime           = (bIsNoVr) ? GetPointerFromOpcode(scannerServer.Scan(sigMapTimeNoVr), 3, 7) : GetPointerFromOpcode(scannerClient.Scan(sigMapTime), 4, 8);
    IntPtr ptrMapName           = GetPointerFromOpcode(scannerEngine.Scan(sigMapName), 3, 7) + 0x100;
    IntPtr ptrSignOnState       = GetPointerFromOpcode(scannerEngine.Scan(sigSignOnState), 3, 7) + 0x218;
    
    ReportPointer(ptrEntList, "entList");
    ReportPointer(ptrInLvlTrans, "inLvlTrans");
    ReportPointer(ptrBuildNum, "buildNum");
    ReportPointer(ptrLoading, "loading");
    ReportPointer(ptrMapTime, "mapTime");
    ReportPointer(ptrMapName, "mapName");
    ReportPointer(ptrNoVr, "noVr");
    ReportPointer(ptrSignOnState, "signOnState base");

#endregion

#region ACHIEVEMENT INJECTION
    var scannerAI = new SignatureScanner(game, scannerServer.Address, scannerServer.Size);
    IntPtr ptrAIScannerEnd = scannerServer.Address + scannerServer.Size;
    IntPtr ptrAchievement = IntPtr.Zero;

    // find cvar string pointer, the cvar in particular is stat_tracker_dump_stats, a non-functional / disabled command
    IntPtr ptrAICVarString = scannerAI.Scan(new SigScanTarget("737461745F747261636B65725F64756D705F7374617473"));
    ReportPointer(ptrAICVarString, "achievement stuff - string ptr");
    if (ptrAICVarString == IntPtr.Zero)
        goto skipachieve;

    // find the reference to that string
    var sigStringRef = new SigScanTarget(7, "4C 8D 05 ?? ?? ?? ?? 48 8D 15 ?? ?? ?? ?? 48 8D 0D ?? ?? ?? ??");
    bool bAICVarFound = false;
    int iAIScannerSize = scannerServer.Size;
    IntPtr ptrCVarDataField = IntPtr.Zero;
    while (!bAICVarFound)
    {
        sigStringRef.OnFound = (f_proc, f_scanner, f_ptr) =>
        {
            if (GetPointerFromOpcode(f_ptr, 3, 7) == ptrAICVarString)
                bAICVarFound = true;
            return f_ptr;
        };
        ptrCVarDataField = scannerAI.Scan(sigStringRef);
        iAIScannerSize = (int)((long)ptrAIScannerEnd - (long)ptrCVarDataField - 0x1);
        if (iAIScannerSize <= 20)
            break;
        scannerAI = new SignatureScanner(game, ptrCVarDataField + 0x1, iAIScannerSize);
    }

    // from there get its data field and use that as the base for injecting new code
    ptrAchievement = GetPointerFromOpcode(ptrCVarDataField + 0x7, 3, 7);
    ReportPointer(ptrAchievement, "achievement stuff - injection codespace");
    if (ptrAchievement == IntPtr.Zero)
        goto skipachieve;

    // find the instruction at the beginning of the function which handles achievements
    IntPtr ptrAIFunc1 = scannerServer.Scan(new SigScanTarget("FF 50 ?? 84 C0 0F 85 ?? ?? ?? ?? 48 8B 03"));
    ReportPointer(ptrAIFunc1, "achievement stuff - general achievement handling function");
    if (ptrAIFunc1 == IntPtr.Zero)
        goto skipachieve;

    // find the instruction at the beginning of the function which handles special event queueing
    IntPtr ptrAIFunc2 = scannerServer.Scan(new SigScanTarget("40 57 48 83 EC 20 48 8B 41 ?? 48 8B F9 48 83 C1 10"));
    ReportPointer(ptrAIFunc2, "achievement stuff - special event evaluation function");
    if (ptrAIFunc2 == IntPtr.Zero)
        goto skipachieve;


    // begin assembling commands
    IntPtr ptrAIBegin = ptrAchievement + 0x8;
    
    // figure out offsets for the asm instructions, we cant WriteJumpInstruction because allocation crashes the game

    // offset between stored pointer location and first instruction, should always be 8
    int off1 = (int)((long)(ptrAchievement) - (long)(ptrAIBegin + 0x7));
    byte[] off1Bytes = BitConverter.GetBytes(off1);
    // offset for the jump from the end of our injected code back to the original function
    int off2 = (int)((long)(ptrAIFunc1 + 0x5) - (long)(ptrAIBegin + 0x11));
    byte[] off2Bytes = BitConverter.GetBytes(off2);
    // offset for the jump from the original function to our injected code
    int off3 = (int)((long)ptrAIBegin - (long)(ptrAIFunc1 + 0x5));
    byte[] off3Bytes = BitConverter.GetBytes(off3);

    // prepare byte arrays for writing 

    byte[] arrAIFunc1New = new byte[] 
    {
        // mov      [ptrAIBegin],rcx
        0x48, 0x89, 0x0D, off1Bytes[0], off1Bytes[1], off1Bytes[2], off1Bytes[3],
        // call     qword ptr [rax+28]
        0xFF, 0x50, 0x28,
        // test     al, al                                        
        0x84, 0xc0,
        // jump     ptrAIFunc1 + 0x5
        0xe9, off2Bytes[0], off2Bytes[1], off2Bytes[2], off2Bytes[3],
    };                
    
    byte[] jmpBytes = new byte[] 
    {
        // jump     ptrAIBegin
        0xe9, off3Bytes[0], off3Bytes[1], off3Bytes[2], off3Bytes[3]
    }; 

    byte[] arrAIFunc2New = new byte[] 
    {
        // mov        al, 01
        0xB0, 0x01,            
        // ret                                                        
        0xC3
    }; 

    // store to injection list
    InjectionListAdd(ptrAIFunc1, memory.ReadBytes(ptrAIFunc1, 5), jmpBytes);
    InjectionListAdd(ptrAIFunc2, memory.ReadBytes(ptrAIFunc2, 3), arrAIFunc2New);
    InjectionListAdd(ptrAIBegin, memory.ReadBytes(ptrAIBegin, 55), arrAIFunc1New);

    // inject
    InjectionListExecute();

    // inititialize
    memory.WriteBytes(ptrAchievement, BitConverter.GetBytes(0xFFFFFFFFFFFFFFFF));

    goto complete;

skipachieve:
    vars.print("Achievement splitting code failed to inject!");

complete:
    vars.ptrAchievement = ptrAchievement;
    swProfiler.Stop();
    vars.print("[SIGSCANNING] Signature scanning done in " + swProfiler.ElapsedMilliseconds * 0.001f + " seconds");

#endregion

    int buildnum = memory.ReadValue<int>(ptrBuildNum);
    vars.print("[GAME INFO] Game is build number " + buildnum);    
    vars.print("[GAME INFO] Game is running in " + ((bIsNoVr) ? "No VR" : "VR") + " mode");

#region SETTING UP WATCHLIST
    vars.mwLoading          = new MemoryWatcher<int>(ptrLoading);
    vars.mwMapTime          = (bIsNoVr) ? new MemoryWatcher<float>(new DeepPointer(ptrMapTime, 0x0)) : new MemoryWatcher<float>(ptrMapTime);
    vars.mwInLvlTrans       = new MemoryWatcher<byte>(ptrInLvlTrans);
    vars.mwEntList          = new MemoryWatcher<IntPtr>(new DeepPointer(ptrEntList));
    vars.mwMoveFlag         = new MemoryWatcher<byte>(new DeepPointer(ptrEntList, 0x18, 0x78, 0x2e9c));
    vars.mwMap              = new StringWatcher(ptrMapName, 120);
    vars.mwSignOnState      = new MemoryWatcher<byte>(new DeepPointer(ptrSignOnState, 0x1e0, 0x0, 0x50));
    vars.mwAccumTime        = new MemoryWatcher<int>(new DeepPointer(ptrEntList, 0x20b8, 0x68));
    vars.mwResinCount       = new MemoryWatcher<int>(new DeepPointer(ptrEntList, 0x18, 0x78, 0x2cf0));
    
    vars.mwlMaster = new MemoryWatcherList() 
    {
        vars.mwLoading,
        vars.mwMapTime,
        vars.mwInLvlTrans,
        vars.mwEntList,
        vars.mwMoveFlag,
        vars.mwMap,
        vars.mwSignOnState,
        vars.mwAccumTime,
        vars.mwResinCount
    };

#endregion

#region ENTITY LIST FUNCTIONS
    
    const int entInfoSize = 120;
    const float minDistDelta = 1 / 1000f;
    
    Func<int, IntPtr> GetEntPtrFromIndex = (index) =>
    {
        // the game splits the entity pointer list into blocks with seemingly a certain size
        // this function is taken from the game's decompiled code

        int block = 24 + (index >> 9) * 8;
        int pos = (index & 511) * entInfoSize;
        
        IntPtr blockPtr = memory.ReadPointer((IntPtr)vars.mwEntList.Current + block);

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
        // 2838: theorectically the index can go all the way up to 32768 but it never does even on the biggest of dictMaps
        for (int i = 0; i <= 20000; i++)
        {
            IntPtr entPtr = GetEntPtrFromIndex(i);
            if (entPtr != IntPtr.Zero)
            {
                if (GetNameFromPtr(entPtr, isTargetName) == name) return entPtr;
                else continue;
            }
        }
        return IntPtr.Zero;
    };

    Func<IntPtr, Vector3f> GetPosFromPtr = (entPtr) =>
    {
        DeepPointer posDP = new DeepPointer(entPtr, 0x1a0, 0x108);
        IntPtr posPtr;
        posDP.DerefOffsets(game, out posPtr);
        return memory.ReadValue<Vector3f>(posPtr);
    };


    Func<float, float, float, IntPtr> GetEntFromPos = (x, y, z) =>
    {
        var prof = Stopwatch.StartNew();
        Vector3f targetPos = new Vector3f(x, y, z);
        // 2838: theorectically the index can go all the way up to 32768 but it never does even on the biggest of maps
        for (int i = 0; i <= 20000; i++)
        {
            IntPtr entPtr = GetEntPtrFromIndex(i);
            if (entPtr != IntPtr.Zero)
            {
                if (GetPosFromPtr(entPtr).Distance(targetPos) <= minDistDelta) return entPtr;
                else continue;
            }
        }
        return IntPtr.Zero;
    };

    Func<bool> CheckResin = () =>
    {
        switch ((string)vars.mwMap.Current)
        {
            case "a3_hotel_underground_pit":
            {
                // one of the resin is a template, which is only spawned when a particular trigger is hit
                if (GetEntFromPos(1504f, -1496f, 408f) != IntPtr.Zero) return false;
                break;
            }
            default:
                break;
        }

        int j = 0;

        int limit = vars.dictMaps[vars.mwMap.Current.ToLower()].Item3;
        if (!(limit > 0 && settings["resinexclude-" + vars.mwMap.Current.ToLower()]))
            limit = 0;

        for (int i = 0; i <= 20000; i++)
        {
            IntPtr entPtr = GetEntPtrFromIndex(i);
            string name = GetNameFromPtr(entPtr, false);
            if (entPtr != IntPtr.Zero && name == "item_hlvr_crafting_currency_small") j++;

            if (j > limit)
                return false;
        }
        return true;
    };
    
    vars.GetEntFromName = GetEntFromName;
    vars.GetEntPtrFromIndex = GetEntPtrFromIndex;
    vars.GetNameFromPtr = GetNameFromPtr;
    vars.CheckResin = CheckResin;
#endregion

    vars.OnSessionStart();

#region SPLITTING
    Action<string> RenameCurrentSplit = (newName) => 
    {
        timer.Run[timer.CurrentSplitIndex].Name = newName;
    };

    // split types:
    // 1    map transition
    // 2    chapter change
    // 3    achievement
    // 4    resin collection
    Func<int, int> Split = (type) =>
    {
        if (type == -1 || !settings["split"] || vars.TimerModel.CurrentState.CurrentPhase != TimerPhase.Running)
            return 0;

        if (settings["splitsrename-type" + type])
            switch(type)
            {
                case 1:
                {
                    RenameCurrentSplit(vars.mwMap.Current);
                    break;
                }
                case 3:
                {
                    if (vars.listAchObtained.Count > 0)
                        RenameCurrentSplit(vars.dictAchNames[vars.listAchObtained[vars.listAchObtained.Count - 1]]);
                    break;
                }
                case 4:
                {
                    RenameCurrentSplit(vars.mwResinCount.Current + " resin");
                    break;
                }
            }

        if (settings["split-type" + type])
            vars.TimerModel.Split();

        return 0;
    };
    vars.Split = Split;
#endregion
}

update
{
    vars.mwlMaster.UpdateAll(game);

    if (vars.mwSignOnState.Changed)
    {
        vars.print("[GAMESTATE] Game state changed from " + vars.signOnStates[vars.mwSignOnState.Old] + " to " + vars.signOnStates[vars.mwSignOnState.Current]);
        if (vars.mwSignOnState.Current == 6)
            vars.OnSessionStart();
        else if (vars.mwSignOnState.Old == 6)
            vars.OnSessionEnd();
    }

    if (vars.mwMap.Changed)
        vars.print("[GAMESTATE] Map changed from " + vars.mwMap.Old + " to " + vars.mwMap.Current);
    
    if (vars.mwMap.Current == "a5_ending")
    {
        vars.mwAutogrip1.Update(game);
        vars.mwAutogrip2.Update(game);
    }

    // 2838: 
    // the game has 2 states of loading: waiting for map load (state 1) and waiting for the player to press the trigger (state 2)
    // we'll only need to exclude state 1 as state 2 is when the game has finished loading in
    
    float delta = vars.mwMapTime.Current - vars.mwMapTime.Old;
    if (delta > 0.0f && vars.mwLoading.Current != 1 && vars.mwInLvlTrans.Current == 0)
        vars.flCurrentTime += delta;

#region CHECK START
    Func<bool> CheckStart = () =>
    {
        // starting conditional
        if (vars.mwMap.Current == "a1_intro_world") 
            return (vars.mwMoveFlag.Current == 0 && vars.mwMoveFlag.Old == 1);
        else if ((vars.mwMap.Current != "startup") && settings["il"])
        {
            if (vars.bMapStart)
            {
                // wait for pause screen to be cleared
                if (vars.mwLoading.Changed && vars.mwLoading.Old == 2 && vars.mwLoading.Current != 1)
                {
                    vars.bMapStart = false;
                    vars.print("[TIMER] IL splitting enabled, starting from unpause");
                    return true;
                }
                return false;
            }
            // check if the map has just started fresh (accumulated time is 0)
            vars.bMapStart = (vars.mwSignOnState.Changed && vars.mwSignOnState.Current == 4 && vars.mwAccumTime.Current == 0);
            return false;
        }
        return false;
    };

    if (CheckStart() && settings["start/reset"])
    {
        if (!settings["manualreset"] || vars.TimerModel.CurrentState.CurrentPhase != TimerPhase.Running)
        {
            vars.TimerModel.Reset();
            vars.TimerModel.Start();
        }
    }
#endregion

#region CHECK SPLIT
    Func<int> CheckSplit = () =>
    {
        if (vars.mwMap.Current == "startup" || vars.mwMap.Current == "")
            return -1;

        if (settings["changelevelsplit"])
        {
            if (vars.mwMap.Changed && !vars.listVisitedMaps.Contains(vars.mwMap.Current))
            {
                // HACKHACK: intro_world_2 is transitioned from a generic map command, so just add an edge case here
                if (vars.mwMap.Old == "a1_intro_world" && vars.mwMap.Current == "a1_intro_world_2")
                {
                    vars.listVisitedMaps.Add(vars.mwMap.Current);
                    return 1;
                }

                if (vars.mwSignOnState.Current == 7)
                {
                    vars.listVisitedMaps.Add(vars.mwMap.Current);
                    vars.print("[GAMESTATE] Map changelevel event from " + vars.mwMap.Old + " to " + vars.mwMap.Current);

                    if (settings["split-type2"] && vars.dictMaps[vars.mwMap.Current.ToLower()].Item2 == vars.dictMaps[vars.mwMap.Old.ToLower()].Item2 + 1)
                    {
                        vars.print("[GAMESTATE] Chapter change!");
                        return 1;
                    }
                    else return 2;
                }
            }
        }
        else 
        {
            //Only split if map / chapter is increasing
            if (!settings["split-type2"]) 
                if (vars.dictMaps[vars.mwMap.Current.ToLower()].Item1 == vars.dictMaps[vars.mwMap.Old.ToLower()].Item1 + 1)
                    return 1;
            else if (settings["split-type1"] && vars.dictMaps[vars.mwMap.Current.ToLower()].Item2 == vars.dictMaps[vars.mwMap.Old.ToLower()].Item2 + 1)
                return 1;
        } 

        // check resin
        if (settings["split-type4"] && vars.mwResinCount.Changed && vars.mwSignOnState.Current == 6)
            if (!vars.listSplitResinMaps.Contains(vars.mwMap.Current) && vars.CheckResin())
            {
                vars.listSplitResinMaps.Add(vars.mwMap.Current);
                return 4;
            }

        // check achievements
        if (vars.ptrAchievement != IntPtr.Zero)
        {
            if (memory.ReadValue<ulong>((IntPtr)vars.ptrAchievement) != 0xFFFFFFFFFFFFFFFF)
            {
                IntPtr stringPtr; 
                new DeepPointer((IntPtr)vars.ptrAchievement, 0x8, 0x0).DerefOffsets(game, out stringPtr);
                string achievement = memory.ReadString(stringPtr, 256);
                try
                {
                    if (!vars.listAchObtained.Contains(achievement))
                    {
                        vars.print("[ACHIEVEMENTS] Got achievement " + achievement + " (" + vars.dictAchNames[achievement] + ")");
                        switch(achievement)
                        {
                            case "SIDE_GLOBAL_BREAK_BOTTLES":
                            {
                                vars.iAchBrokenBottles++;
                                vars.print("[ACHIEVEMENTS] Mazel Tov progress: " + vars.iAchBrokenBottles + " / 50");
                                if (vars.iAchBrokenBottles < 50)
                                    return -1;
                                break;
                            }
                            case "GLOBAL_GNOME_ALONE":
                                return -1;
                                                                
                            default:
                                break;
                        }
                        vars.listAchObtained.Add(achievement);
                        return 3;
                    }
                }
                finally
                {
                    memory.WriteBytes((IntPtr)vars.ptrAchievement, BitConverter.GetBytes(0xFFFFFFFFFFFFFFFF));
                }
            }
        }    

        //Ending Conditional
        if (vars.mwMap.Current == "a5_ending" && vars.mwLoading.Current == 0)
        {
            return ((vars.mwAutogrip1.Current == 0 && vars.mwAutogrip1.Old == 1) 
            || (vars.mwAutogrip2.Current == 0 && vars.mwAutogrip2.Old == 1)) ? 1 : -1;
        }

        return -1;
    };
#endregion

    vars.Split(CheckSplit());

}

start { }

reset { }

split { }

isLoading { return true; }

shutdown 
{
    timer.OnStart -= vars.TimerStartHandler;
    timer.OnSplit -= vars.TimerSplitHandler;

    foreach (Tuple<IntPtr, byte[], byte[]> injection in vars.listInjections)
        if (injection.Item1 != IntPtr.Zero)
            game.WriteBytes(injection.Item1, injection.Item3);

    vars.print("Exiting");
}

gameTime { return TimeSpan.FromSeconds(vars.flCurrentTime); }