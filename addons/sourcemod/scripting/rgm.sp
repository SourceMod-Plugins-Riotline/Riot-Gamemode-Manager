#include <sourcemod>
#include <morecolors>

#pragma newdecls required

#define PLUGIN_VERSION "0.1.2-a.1"

Handle h_GlobalConfig = INVALID_HANDLE;
ConVar g_Debug, g_Toggle, g_StartupExec, g_NextMap, g_Cvar_InitialDelay, g_Cvar_Interval, g_Cvar_Needed, g_Cvar_AutoMapCycle;
char s_CurrentGamemode[128] = "";
char s_NextOption[256];
bool b_Debug;
bool b_Enabled = true;
bool b_RTGAllowed = false;
int i_Voters = 0;				// Total voters connected. Doesn't include fake clients.
int i_Votes = 0;				// Total number of "say rtg" votes
int i_VotesNeeded = 0;			// Necessary votes before map vote begins. (voters * percent_needed)
bool b_Voted[MAXPLAYERS+1] = {false, ...};
ArrayList h_Gamemodes, h_Maps;

// Thanks to thesupremecommander for some of the original code that was revamped here.
// Thanks to Alliedmodders for the base RTV code.

public Plugin myinfo =
{
	name = "Riot Gamemode Manager",
	author = "Riotline",
	description = "Manage plugin gamemodes and map rotations.",
	version = PLUGIN_VERSION,
	url = ""
};

//
// How do I ( ͡° ͜ʖ ͡°)?
//

public void OnPluginStart()
{
	g_Debug = CreateConVar("rgm_debug", "0", "turns on debugging and action logging", FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	g_Toggle = CreateConVar("rgm_enable", "1", "Enable Riot Gamemode Manager", FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	g_StartupExec = CreateConVar("rgm_exec", "", "Current Map's Startup Exec.", FCVAR_DONTRECORD);
	g_Cvar_InitialDelay = CreateConVar("rgm_rtg_initialdelay", "45.0", "Time (in seconds) before first RTG can be held", 0, true, 0.00);
	g_Cvar_Interval = CreateConVar("rgm_rtg_interval", "240.0", "Time (in seconds) after a failed RTG before another can be held", 0, true, 0.00);
	g_Cvar_Needed = CreateConVar("rgm_rtg_needed", "0.60", "Percentage of players needed to rock the game (Def 60%)", 0, true, 0.05, true, 1.0);
	g_Cvar_AutoMapCycle = CreateConVar("rgm_automapcycle", "1", "Automatically Update the MapCycle.txt file to match gamemode.", 0, true, 0.0, true, 1.0);

	AutoExecConfig(true, "rgm");
	
	HookConVarChange(g_Debug, ToggleDebugging);
	HookConVarChange(g_Toggle, ToggleRGMCvar);
	b_Debug = (GetConVarInt(g_Debug) ? true:false);
	b_Enabled = (GetConVarInt(g_Toggle) ? true:false);

	g_NextMap = FindConVar("sm_nextmap");

	RegConsoleCmd("sm_rtg", RTGCommand);

	RegAdminCmd("sm_forcergm", OpenGamemodeMenu, ADMFLAG_CONFIG, "Force Gamemode + Map Change.");
	RegAdminCmd("sm_frgm", OpenGamemodeMenu, ADMFLAG_CONFIG, "Force Gamemode + Map Change.");
	RegAdminCmd("sm_forcertg", InitiateRGMVote, ADMFLAG_VOTE, "Force a Rock The Game Vote");
	RegAdminCmd("sm_frtg", InitiateRGMVote, ADMFLAG_VOTE, "Force a Rock The Game Vote");

	RegAdminCmd("sm_reloadrgm", ReloadRGM, ADMFLAG_CONFIG, "Reload the Riot Gamemode Manager Config.")
	RegAdminCmd("sm_togglergm", ToggleRGM, ADMFLAG_CONFIG, "Toggle the Gamemode Manager.")
	//RegAdminCmd("sm_debugconfig", ConfigDebug, ADMFLAG_CONFIG, "Debug Config File");
	RegAdminCmd("sm_rgmdebug", RGMDebug, ADMFLAG_CONFIG, "Debug");

	h_Gamemodes = CreateArray(32);
	h_Maps = CreateArray(64);

	LoadRGMConfig();
	LoadTranslations("rgm.phrases.txt");
}

public void OnMapStart()
{
	char s_CurrentExec[PLATFORM_MAX_PATH];
	GetConVarString(g_StartupExec, s_CurrentExec, sizeof(s_CurrentExec));

	if(b_Enabled) {
		ServerCommand("exec \"%s\"", s_CurrentExec);
		SetConVarString(g_StartupExec, NULL_STRING, false, false);
		s_NextOption = NULL_STRING;
	}
	CreateTimer(g_Cvar_InitialDelay.FloatValue, Timer_DelayRTG, _, TIMER_FLAG_NO_MAPCHANGE);

	if(StrEqual(s_CurrentGamemode, "")){
		char s_CurrentMap[128];
		Handle h_MapCycleFile = OpenFile("cfg/mapcycle.txt", "w");

		GetCurrentMap(s_CurrentMap, sizeof(s_CurrentMap));
		WriteFileLine(h_MapCycleFile, s_CurrentMap); // Prevent any Map Cycle related issues.
		CloseHandle(h_MapCycleFile);
	}
}

public void OnMapEnd()
{
	char s_NextMap[128], s_Option[2][128];
	GetConVarString(g_NextMap, s_NextMap, sizeof(s_NextMap));
	PrintToServer("MAP END");

	if(b_Enabled) {
		ExplodeString(s_NextOption, "|", s_Option, sizeof(s_Option), sizeof(s_Option[]));
		PrintToServer("[RGM] Loading new gamemode and map. %s:%s", s_Option[0], s_Option[1]);
		if(StrEqual(s_NextMap, s_Option[1])){
			LoadGamemodeConfig(s_Option[0]);
			s_CurrentGamemode = s_Option[0];
		}
	}

	b_RTGAllowed = false;
	i_Voters = 0;
	i_Votes = 0;
	i_VotesNeeded = 0;
}

public void ToggleDebugging(Handle convar, const char[] oldValue, const char[] newValue) {
	if (StringToInt(newValue) == 0) {
		b_Debug = false; 
	} else b_Debug = true;
}

public void ToggleRGMCvar(Handle convar, const char[] oldValue, const char[] newValue) {
	if (StringToInt(newValue) == 0) {
		b_Enabled = false; 
	} else b_Enabled = true;
}

public void OnClientConnected(int client)
{
	if (!IsFakeClient(client))
	{
		i_Voters++;
		i_VotesNeeded = RoundToCeil(float(i_Voters) * g_Cvar_Needed.FloatValue);
	}
}

public void OnClientDisconnect(int client)
{	
	if (b_Voted[client])
	{
		i_Votes--;
		b_Voted[client] = false;
	}
	
	if (!IsFakeClient(client))
	{
		i_Voters--;
		i_VotesNeeded = RoundToCeil(float(i_Voters) * g_Cvar_Needed.FloatValue);
	}
	
	if (i_Votes && 
		i_Voters && 
		i_Votes >= i_VotesNeeded && 
		b_RTGAllowed ) 
	{
		StartRTG();
	}	
}

//**************************//
// Commands / Chat Triggers // 
//**************************//

// Rock the Game Chat Triggers ~ Taken from Rock the Vote
public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if (!client || IsChatTrigger())
	{
		return;
	}
	
	if (strcmp(sArgs, "rtg", false) == 0 || strcmp(sArgs, "rockthegame", false) == 0)
	{
		ReplySource old = SetCmdReplySource(SM_REPLY_TO_CHAT);
		
		AttemptRTG(client);
		
		SetCmdReplySource(old);
	}
}

public Action RTGCommand(int client, int args) {
	if (!client)
	{
		return Plugin_Handled;
	}
	
	AttemptRTG(client);

	return Plugin_Handled;
}

// Admin Gamemode Menu. Force Gamemode/Map Change
public Action OpenGamemodeMenu(int client, int args) {
	Handle h_Menu = CreateMenu(GamemodeMenu);
	SetMenuTitle(h_Menu, "[RGM] Select Gamemode");
	
	for(int i=0; i < GetArraySize(h_Gamemodes); i++)
	{
		char s_GamemodeSection[255];
		GetArrayString(h_Gamemodes, i, s_GamemodeSection, sizeof(s_GamemodeSection));
		AddMenuItem(h_Menu, s_GamemodeSection, s_GamemodeSection);
		PrintToChatAll(s_GamemodeSection);
	}
	SetMenuExitButton(h_Menu, true);
	DisplayMenu(h_Menu, client, 0);
	
	return Plugin_Handled;
}

// A Debugging Function/Command
public Action ConfigDebug(int client, int args) {
	Handle h_GMConfig = CloneHandle(h_GlobalConfig);
	DebugConfig(h_GMConfig);
	
	return Plugin_Handled;
}

// Another Debugging Command. Why do I have two commands. Very useless like me
public Action RGMDebug(int client, int args) {
	PrintToChat(client, "s_NextOption: %s", s_NextOption);
	PrintToChat(client, "s_CurrentGamemode: %s", s_CurrentGamemode);
	PrintToChat(client, "b_Enabled: %s", b_Enabled ? "true":"false");
	
	return Plugin_Handled;
}

// Reload Riot Gamemode Manager Configuration File
public Action ReloadRGM(int client, int args) {
	LoadRGMConfig();
	CPrintToChatAll("%t {white}Reloading Configuration File.", "tag");
	
	return Plugin_Handled;
}

// Toggle the Riot Gamemode Manager (Not Tested)
public Action ToggleRGM(int client, int args) {
	int oldValue = GetConVarInt(g_Toggle);
	if (oldValue == 1) {
		b_Enabled = false; 
	} else b_Enabled = true;
	
	return Plugin_Handled;
}

// Force a Gamemode/Map Change Server Vote
public Action InitiateRGMVote(int client, int args) {
	if(!IsVoteInProgress()){
		CPrintToChat(client, "%t %t", "tag", "Gamemode Vote Start");
		DoGamemodeVote(false);
	} else {
		CPrintToChat(client, "%t %t", "tag", "Vote In Progress");
	}

	return Plugin_Handled;
}


//****************//
// Menus / Voting //
//****************//

// Map Voting Part of the Gamemode Voting
public int MapVote(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        /* This is called after VoteEnd */
        delete menu;
    }
    else if (action == MenuAction_VoteEnd)
    {
        if(param1 >= 0){ 
			char s_VotedGame[128], s_ExplodedSelection[2][128];
			GetMenuItem(menu, param1, s_VotedGame, sizeof(s_VotedGame));
			ExplodeString(s_VotedGame, "|", s_ExplodedSelection, sizeof(s_ExplodedSelection), sizeof(s_ExplodedSelection[]));
			if(StrEqual(s_VotedGame, "No Change")){
				CPrintToChatAll("%t %t", "tag", "RTG No Change");
			} else {
				s_NextOption = s_VotedGame;
				if(!SetNextMap(s_ExplodedSelection[1])) {
					LogError("Map %s is an invalid map. Perhaps it was deleted from the maps folder.", s_ExplodedSelection[1]);
				} else {
					CPrintToChatAll("%t %t", "tag", "Game Change", s_ExplodedSelection[0], s_ExplodedSelection[1]);
					s_NextOption = s_VotedGame;
					DataPack d_VotedData;
					CreateDataTimer(3.0, Timer_MapChange, d_VotedData, TIMER_FLAG_NO_MAPCHANGE);
					WritePackString(d_VotedData, s_ExplodedSelection[0]);
					WritePackString(d_VotedData, s_ExplodedSelection[1]);
				}
			}
		}
    }
}
 
void DoMapVote(const char[] s_MapGamemode)
{
	if (IsVoteInProgress())
	{
		return;
	}
 
	Menu menu = new Menu(MapVote);
	SetMenuTitle(menu, "Vote for the next map! (%s)", s_MapGamemode);
	char s_ValidMaps[256] = "";
	int i_GamemodeMapCount;
	char s_CurrentMap[128];
	GetCurrentMap(s_CurrentMap, sizeof(s_CurrentMap));
	for(int i=0; i < GetArraySize(h_Maps); i++){
		char s_Map[256];
		GetArrayString(h_Maps, i, s_Map, sizeof(s_Map));
		if(StrContains(s_Map, s_MapGamemode) != -1 && StrContains(s_Map, s_CurrentMap) == -1){
			i_GamemodeMapCount++
		}
	}

	if(i_GamemodeMapCount >= 5 && !StrEqual(s_CurrentGamemode, s_MapGamemode)){
		i_GamemodeMapCount = 5;
	} else if (i_GamemodeMapCount >= 5 && StrEqual(s_CurrentGamemode, s_MapGamemode)){
		i_GamemodeMapCount = 4;
	}

	for(int i=0; i < i_GamemodeMapCount; i++){
		char s_Map[256], s_MapFilter[128];
		char s_SelectedMap[2][256];
		int i_ChosenMap = GetRandomInt(0, GetArraySize(h_Maps)-1);
		GetArrayString(h_Maps, i_ChosenMap, s_Map, sizeof(s_Map));
		ExplodeString(s_Map, "|", s_SelectedMap, sizeof(s_SelectedMap), sizeof(s_SelectedMap[]));
		Format(s_MapFilter, sizeof(s_MapFilter), "|%s|", s_SelectedMap[1]);
		if(StrContains(s_ValidMaps, s_MapFilter) != -1 || !StrEqual(s_MapGamemode, s_SelectedMap[0]) || StrEqual(s_CurrentMap, s_SelectedMap[1])){
			i--;
		} else {
			AddMenuItem(menu, s_Map, s_SelectedMap[1]);
			StrCat(s_ValidMaps, sizeof(s_ValidMaps), s_MapFilter);
		}
	}

	if(StrEqual(s_MapGamemode, s_CurrentGamemode)){
		AddMenuItem(menu, "No Change", "No Change");
	}
		
	SetMenuExitButton(menu, false);
	menu.DisplayVoteToAll(20);
}

// Gamemode Voting Part of the Voting Process
public int GamemodeVote(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        /* This is called after VoteEnd */
        delete menu;
    }
    else if (action == MenuAction_VoteEnd)
    {
        if(param1 >= 0){ 
			char s_VotedGamemode[128];
			GetMenuItem(menu, param1, s_VotedGamemode, sizeof(s_VotedGamemode));
			if(StrEqual(s_VotedGamemode, "No Change")){
				CPrintToChatAll("%t %t", "tag", "RTG Gamemode No Change");
				s_VotedGamemode = s_CurrentGamemode;
			} else {
				CPrintToChatAll("%t %t", "tag", "RTG Gamemode Change", s_VotedGamemode);
			}
			DoMapVote(s_VotedGamemode);
		}
    }
}
 
void DoGamemodeVote(bool b_NoChange = false)
{
	if (IsVoteInProgress())
	{
		return;
	}
	
	Menu menu = new Menu(GamemodeVote);
	SetMenuTitle(menu, "Vote for the next gamemode!");
	char s_ValidGamemodes[64] = "";
	int i_GamemodeCount = GetArraySize(h_Gamemodes);
	if(i_GamemodeCount > 4){
		i_GamemodeCount = 4;
	}
	if(!StrEqual(s_CurrentGamemode, "")){
		Format(s_ValidGamemodes, sizeof(s_ValidGamemodes), "|%s|", s_CurrentGamemode);
	}

	for(int j,i=0; i < i_GamemodeCount; i++,j++){
		if(j >= 100) {
			LogError("[RGM] Potential Infinite Loop. Breaking");
			break;
		}

		char s_Gamemode[256], s_GamemodeFilter[128];
		int i_ChosenGamemode = GetRandomInt(0, GetArraySize(h_Gamemodes)-1);
		GetArrayString(h_Gamemodes, i_ChosenGamemode, s_Gamemode, sizeof(s_Gamemode));

		Format(s_GamemodeFilter, sizeof(s_GamemodeFilter), "|%s|", s_Gamemode);
		if(StrContains(s_ValidGamemodes, s_GamemodeFilter) != -1){
			i--;
		} else {
			AddMenuItem(menu, s_Gamemode, s_Gamemode);
			StrCat(s_ValidGamemodes, sizeof(s_ValidGamemodes), s_GamemodeFilter);
		}
	}
	if(StrEqual(s_CurrentGamemode, "") || !b_NoChange){
		for(int j,i=0; i < 1; i++,j++){
			if(j >= 25) {
				LogError("[RGM] Potential Infinite Loop. Breaking");
				break;
			}

			char s_Gamemode[256], s_GamemodeFilter[128];
			int i_ChosenGamemode = GetRandomInt(0, GetArraySize(h_Gamemodes)-1);
			GetArrayString(h_Gamemodes, i_ChosenGamemode, s_Gamemode, sizeof(s_Gamemode));

			Format(s_GamemodeFilter, sizeof(s_GamemodeFilter), "|%s|", s_Gamemode);
			if(StrContains(s_ValidGamemodes, s_GamemodeFilter) != -1){
				i--;
			} else {
				AddMenuItem(menu, s_Gamemode, s_Gamemode);
				StrCat(s_ValidGamemodes, sizeof(s_ValidGamemodes), s_GamemodeFilter);
				break;
			}
		}
	} else if(b_NoChange){
		AddMenuItem(menu, "No Change", "No Change");
	}
		
	SetMenuExitButton(menu, false);
	menu.DisplayVoteToAll(20);
}

// Admin Gamemode Changing Menu
public int GamemodeMenu(Menu menu, MenuAction action, int param1, int param2) {
	if(action == MenuAction_Select) {
		// Show Map Menu
		char s_SelectedGamemode[255], s_Gamemode[255];
		Handle h_Menu = CreateMenu(MapMenu);
		Handle h_GMConfig = CloneHandle(h_GlobalConfig);

		GetMenuItem(menu, param2, s_SelectedGamemode, sizeof(s_SelectedGamemode));
		SetMenuTitle(h_Menu, "[RGM] Select Map (%s)", s_SelectedGamemode);
		KvRewind(h_GMConfig);
		KvGotoFirstSubKey(h_GMConfig);
		
		do {
			KvGetSectionName(h_GMConfig, s_Gamemode, sizeof(s_Gamemode));
			if(StrEqual(s_Gamemode, s_SelectedGamemode)) {
				if (b_Debug) {
					CPrintToChatAll("%t {white}Loading gamemode maps: %s", "tag", s_SelectedGamemode);
				}
				if(KvJumpToKey(h_GMConfig, "maps")){
					if(KvGotoFirstSubKey(h_GMConfig, false)){
						do {
							if(KvGetDataType(h_GMConfig, NULL_STRING) == KvData_String) {
								char s_GamemodeMap[256];
								char s_MapMenuItem[256];
								
								KvGetString(h_GMConfig, NULL_STRING, s_GamemodeMap, sizeof(s_GamemodeMap));
								Format(s_MapMenuItem, sizeof(s_MapMenuItem), "%s|%s", s_SelectedGamemode, s_GamemodeMap);
								AddMenuItem(h_Menu, s_MapMenuItem, s_GamemodeMap);
							}
						} while (KvGotoNextKey(h_GMConfig, false));
					} else {
						ReplyToCommand(param1, "%t No maps found for selected gamemode.", "tag");
					}
					KvGoBack(h_GMConfig);
				} else {
					PrintToServer("No Maps Key in Gamemode Config");
				}
				KvGoBack(h_GMConfig);
			}
		} while (KvGotoNextKey(h_GMConfig));
		SetMenuExitButton(h_Menu, true);
		DisplayMenu(h_Menu, param1, 20);
	} else if (action == MenuAction_End) {
		CloseHandle(menu);
	}
}

// Admin Map Changing Menu after the previous Gamemode Changing Menu
public int MapMenu(Menu menu, MenuAction action, int param1, int param2) {
	switch(action) {
		case MenuAction_Select:
		{
			char s_SelectedChange[128];
			char s_ExplodedSelection[2][128];
			GetMenuItem(menu, param2, s_SelectedChange, sizeof(s_SelectedChange));
			s_NextOption = s_SelectedChange;
			ExplodeString(s_SelectedChange, "|", s_ExplodedSelection, sizeof(s_ExplodedSelection), sizeof(s_ExplodedSelection[]))
			
			if(!SetNextMap(s_ExplodedSelection[1])) {
				LogError("Map %s is an invalid map. Perhaps it was deleted from the maps folder.", s_ExplodedSelection[1]);
			} else {
				CPrintToChatAll("%t %t", "tag", "Game Change", s_ExplodedSelection[0], s_ExplodedSelection[1]);
				DataPack d_VotedData;
				CreateDataTimer(3.0, Timer_MapChange, d_VotedData, TIMER_FLAG_NO_MAPCHANGE);
				WritePackString(d_VotedData, s_ExplodedSelection[0])
				WritePackString(d_VotedData, s_ExplodedSelection[1]);
			}
		}

		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

//*******************//
// Functions / Other //
//*******************//

// Function when user does RTG triggers
void AttemptRTG(int client)
{
	if (!b_RTGAllowed)
	{
		ReplyToCommand(client, "[SM] %t", "RTG Not Allowed");
		return;
	}
	
	if (b_Voted[client])
	{
		ReplyToCommand(client, "[SM] %t", "Already Voted", i_Votes, i_VotesNeeded);
		return;
	}	
	
	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	
	i_Votes++;
	b_Voted[client] = true;
	
	CPrintToChatAll("%t %t", "tag", "RTG Requested", name, i_Votes, i_VotesNeeded);
	
	if (i_Votes >= i_VotesNeeded)
	{
		StartRTG();
	}	
}

// Starts the Rock the Game Voting Process
void StartRTG()
{
	DoGamemodeVote(true);
	
	ResetRTG();
	
	b_RTGAllowed = false;
	CreateTimer(g_Cvar_Interval.FloatValue, Timer_DelayRTG, _, TIMER_FLAG_NO_MAPCHANGE);
}

void ResetRTG()
{
	i_Votes = 0;
			
	for (int i=1; i<=MAXPLAYERS; i++)
	{
		b_Voted[i] = false;
	}
}

// Load/Reload the Riot Game Manager Configuration File
void LoadRGMConfig() {
	// Load the Config File or Throw Error
	char s_ConfigPath[PLATFORM_MAX_PATH];
	
	BuildPath(Path_SM, s_ConfigPath, sizeof(s_ConfigPath), "configs/rgm_gamemodes.cfg");

	h_GlobalConfig = CreateKeyValues("Gamemodes");
	if (!FileToKeyValues(h_GlobalConfig, s_ConfigPath)) {
		SetFailState("Config could not be loaded!");
	}
	else {		
		if (b_Debug) {
			PrintToChatAll("Gamemode config loaded.");
		}
	}

	// Load Gamemodes into Global Gamemodes Array
	ClearArray(h_Gamemodes);
	ClearArray(h_Maps);
	Handle h_GMConfig = CloneHandle(h_GlobalConfig);
	KvRewind(h_GMConfig);
	KvGotoFirstSubKey(h_GMConfig, false);

	// Loop through Key Values (Gamemodes)
	do {
		char s_GamemodeSection[255];
		KvGetSectionName(h_GMConfig, s_GamemodeSection, sizeof(s_GamemodeSection));
		PushArrayString(h_Gamemodes, s_GamemodeSection);

		// Loop Through Maps Section
		if(KvJumpToKey(h_GMConfig, "maps"))
		{
			KvGotoFirstSubKey(h_GMConfig, false);
			do {
				char s_MapName[256];
				// Retrieve Map Name and Format as "Gamemode|Map" for later use.
				KvGetString(h_GMConfig, NULL_STRING, s_MapName, sizeof(s_MapName));
				Format(s_MapName, sizeof(s_MapName), "%s|%s", s_GamemodeSection, s_MapName);
				// Push to the Global Maps Dynamic Array
				PushArrayString(h_Maps, s_MapName);
			} while (KvGotoNextKey(h_GMConfig, false));
			KvGoBack(h_GMConfig);
		}
		KvGoBack(h_GMConfig);
	} while (KvGotoNextKey(h_GMConfig, false));
	KvRewind(h_GMConfig);
	CloseHandle(h_GMConfig);
}

// Debugging Function

void DebugConfig(Handle kv, bool recursive = false)
{
	do
	{
		char s_SectionName[64], s_SectionValue[128];
		// You can read the section/key name by using kv.GetSectionName here.
		KvGetSectionName(kv, s_SectionName, sizeof(s_SectionName));
		PrintToServer("%s:", s_SectionName);

		if (KvGotoFirstSubKey(kv, false))
		{
			DebugConfig(kv, true);
			KvGoBack(kv);
		}
		else
		{
			// Current key is a regular key, or an empty section.
			if (KvGetDataType(kv, NULL_STRING) != KvData_None)
			{
				KvGetSectionName(kv, s_SectionName, sizeof(s_SectionName));
				KvGetString(kv, NULL_STRING, s_SectionValue, sizeof(s_SectionValue));
				PrintToServer("~%s [%i]: %s", s_SectionName, KvGetDataType(kv, NULL_STRING), s_SectionValue);
			}
			else
			{
				// Found an empty sub section. It can be handled here if necessary.
				KvGetSectionName(kv, s_SectionName, sizeof(s_SectionName));
				PrintToServer("~%s [%i]: Empty", s_SectionName, KvGetDataType(kv, NULL_STRING));
			}
		}
	} while (KvGotoNextKey(kv, false));

	if(!recursive)
	{
		PrintToServer("[] Gamemode Array: []");
		for(int i = 0; i < GetArraySize(h_Gamemodes); i++){
			char s_GamemodeValue[128];
			GetArrayString(h_Gamemodes, i, s_GamemodeValue, sizeof(s_GamemodeValue));
			PrintToServer("%s", s_GamemodeValue);
		}
		PrintToServer("[] Map Array: []");
		for(int i = 0; i < GetArraySize(h_Maps); i++){
			char s_MapValue[128];
			GetArrayString(h_Maps, i, s_MapValue, sizeof(s_MapValue));
			PrintToServer("%s", s_MapValue);
		}
	}
}

// Load the specified gamemode's commands, plugins, and config files.
void LoadGamemodeConfig(const char[] s_Gamemode) {
	Handle h_GMConfig = CloneHandle(h_GlobalConfig);
	
	for (int i = 0; i < GetArraySize(h_Gamemodes); i++){
		KvRewind(h_GMConfig);
		char s_GamemodeOption[256];
		GetArrayString(h_Gamemodes, i, s_GamemodeOption, sizeof(s_GamemodeOption));
		if(b_Debug){
			PrintToServer("%s", s_GamemodeOption);
			PrintToServer("%s", s_Gamemode)
		}
		
		if (!StrEqual(s_Gamemode, s_GamemodeOption, false)) {
			KvJumpToKey(h_GMConfig, s_GamemodeOption);
			if (b_Debug) PrintToServer("Unloading gamemode: %s", s_GamemodeOption);
			if (KvJumpToKey(h_GMConfig, "disabled")) {
				KvGotoFirstSubKey(h_GMConfig, false);
				do {
					if (KvGetDataType(h_GMConfig, NULL_STRING) == KvData_String) {
						char s_ActionParameter[256], s_ActionType[64];
					
						KvGetSectionName(h_GMConfig, s_ActionType, sizeof(s_ActionType));
						KvGetString(h_GMConfig, NULL_STRING, s_ActionParameter, sizeof(s_ActionParameter));
						if(StrEqual(s_ActionType, "command", false)){
							ServerCommand("%s", s_ActionParameter);
						}
					}
				} while (KvGotoNextKey(h_GMConfig, false));
				KvGoBack(h_GMConfig);
			}
			KvRewind(h_GMConfig);
			KvJumpToKey(h_GMConfig, s_GamemodeOption);
			if (KvJumpToKey(h_GMConfig, "plugins")) {
				KvGotoFirstSubKey(h_GMConfig, false);
				
				do {
					if (KvGetDataType(h_GMConfig, NULL_STRING) == KvData_String) {
						char s_Plugin[PLATFORM_MAX_PATH], s_PluginPath[PLATFORM_MAX_PATH], s_DisabledPluginPath[PLATFORM_MAX_PATH];

						KvGetString(h_GMConfig, NULL_STRING, s_Plugin, sizeof(s_Plugin));
						BuildPath(Path_SM, s_PluginPath, sizeof(s_PluginPath), "plugins/%s", s_Plugin);

						BuildPath(Path_SM, s_DisabledPluginPath, sizeof(s_DisabledPluginPath), "plugins/disabled/%s", s_Plugin);
						
						ServerCommand("sm plugins unload %s", s_Plugin);
						
						if (FileExists(s_PluginPath)) {
							RenameFile(s_DisabledPluginPath, s_PluginPath);
						}
					}
				} while (KvGotoNextKey(h_GMConfig, false));
				KvGoBack(h_GMConfig);
			}
		}
	}
	
	KvRewind(h_GMConfig);
	
	if (KvJumpToKey(h_GMConfig, s_Gamemode)) {
		if (b_Debug) PrintToServer("Loading gamemode: %s", s_Gamemode);

		if (KvJumpToKey(h_GMConfig, "plugins")) {
			KvGotoFirstSubKey(h_GMConfig, false);
			
			do {
				if (KvGetDataType(h_GMConfig, NULL_STRING) == KvData_String) {
					char s_Plugin[PLATFORM_MAX_PATH];
					char s_PluginPath[PLATFORM_MAX_PATH];
					
					KvGetString(h_GMConfig, NULL_STRING, s_Plugin, sizeof(s_Plugin));
					BuildPath(Path_SM, s_PluginPath, sizeof(s_PluginPath), "plugins/%s", s_Plugin);
					
					char s_DisabledPluginPath[PLATFORM_MAX_PATH];
					BuildPath(Path_SM, s_DisabledPluginPath, sizeof(s_DisabledPluginPath), "plugins/disabled/%s", s_Plugin);
					if (b_Debug) PrintToServer("Attempting to move and enable plugin %s: %s -> %s", s_Plugin, s_DisabledPluginPath, s_PluginPath);
					
					if (FileExists(s_DisabledPluginPath)) {
						RenameFile(s_PluginPath, s_DisabledPluginPath);
					} else {
						PrintToServer("Failed to rename plugin file.");
					}
					
					ServerCommand("sm plugins load %s", s_Plugin);
				}
			} while (KvGotoNextKey(h_GMConfig, false));			
			KvGoBack(h_GMConfig);
		}
		KvRewind(h_GMConfig);
		KvJumpToKey(h_GMConfig, s_Gamemode);
		if (KvJumpToKey(h_GMConfig, "enabled")) {
			KvGotoFirstSubKey(h_GMConfig, false);
			do {
				if (KvGetDataType(h_GMConfig, NULL_STRING) == KvData_String) {
					char s_ActionParameter[256], s_ActionType[64];
				
					KvGetSectionName(h_GMConfig, s_ActionType, sizeof(s_ActionType));
					KvGetString(h_GMConfig, NULL_STRING, s_ActionParameter, sizeof(s_ActionParameter));
					if(StrEqual(s_ActionType, "command", false)){
						ServerCommand("%s", s_ActionParameter);
					} else if(StrEqual(s_ActionType, "config", false)){
						char s_Path[64] = "cfg/";
						StrCat(s_Path, sizeof(s_Path), s_ActionParameter);
						if (!FileExists(s_Path)) {
							PrintToServer("[RGM] Could not find config: %s", s_ActionParameter);
						} else {
							SetConVarString(g_StartupExec, s_ActionParameter, false, false);
						}
					}
				}
			} while (KvGotoNextKey(h_GMConfig, false));
			KvGoBack(h_GMConfig);
		}

		if(g_Cvar_AutoMapCycle.BoolValue){
			Handle h_MapCycleFile = OpenFile("cfg/mapcycle.txt", "w");
			for(int i; i < GetArraySize(h_Maps); i++){
				char s_CurrentMap[128], s_CurrentOption[2][128];
				GetArrayString(h_Maps, i, s_CurrentMap, sizeof(s_CurrentMap));
				ExplodeString(s_CurrentMap, "|", s_CurrentOption, sizeof(s_CurrentOption), sizeof(s_CurrentOption[]));
				if(StrContains(s_CurrentOption[0], s_Gamemode) >= 0){
					WriteFileLine(h_MapCycleFile, s_CurrentOption[1]);
				}
			}
			CloseHandle(h_MapCycleFile);
		}
	}
	
	KvRewind(h_GMConfig);
	CloseHandle(h_GMConfig);
}

//********//
// Timers //
//********//

public Action Timer_DelayRTG(Handle timer)
{
	b_RTGAllowed = true;
}

public Action Timer_MapChange(Handle timer, DataPack pack)
{
	char s_TimerMap[128], s_TimerGamemode[128];
	ResetPack(pack);
	ReadPackString(pack, s_TimerGamemode, sizeof(s_TimerGamemode));
	ReadPackString(pack, s_TimerMap, sizeof(s_TimerMap));
	LoadGamemodeConfig(s_TimerGamemode);
	s_CurrentGamemode = s_TimerGamemode;
	if(IsMapValid(s_TimerMap)) ForceChangeLevel(s_TimerMap, "Riot Gamemode Manager Map Change.");
}