/**
 * vim: set ts=4 :
 * =============================================================================
 * Manage plugin based gamemodes and map rotations.
 * Riot Gamemode Manager (C)2022 Riotline.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */




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

// Rock the Game
public Action RTGCommand(int client, int args) {
	if (!client)
	{
		return Plugin_Handled;
	}
	
	AttemptRTG(client);

	return Plugin_Handled;
}

// Force a Gamemode/Map Change Server Vote
public Action InitiateRGMVote(int client, int args) {
	if(!IsVoteInProgress()){
		CPrintToChat(client, "%t %t", "ctag", "Gamemode Vote Start");
		DoGamemodeVote(false);
	} else {
		CPrintToChat(client, "%t %t", "ctag", "Vote In Progress");
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
				CPrintToChatAll("%t %t", "ctag", "RTG No Change");
			} else {
				if(!SetNextMap(s_ExplodedSelection[1])) {
					LogError("Map %s is an invalid map. Perhaps it was deleted from the maps folder.", s_ExplodedSelection[1]);
				} else {
					CPrintToChatAll("%t %t", "ctag", "Game Change", s_ExplodedSelection[0], s_ExplodedSelection[1]);
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
 

// Map part of the voting processes.
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
		char s_SelectedMap[2][256];
		ExplodeString(s_Map, "|", s_SelectedMap, sizeof(s_SelectedMap), sizeof(s_SelectedMap[]));
		GetArrayString(h_Maps, i, s_Map, sizeof(s_Map));
		if(StrEqual(s_SelectedMap[0], s_MapGamemode, false) && !StrEqual(s_Map, s_CurrentMap)){
			i_GamemodeMapCount++
		}
	}

	// if(i_GamemodeMapCount >= 5 && !StrEqual(s_CurrentGamemode, s_MapGamemode)){
	// 	i_GamemodeMapCount = 5;
	// } else if (i_GamemodeMapCount >= 5 && StrEqual(s_CurrentGamemode, s_MapGamemode)){
	// 	i_GamemodeMapCount = 4;
	// }

	if (i_GamemodeMapCount >= 5) {
		i_GamemodeMapCount = StrEqual(s_CurrentGamemode, s_MapGamemode) ? 4:5;
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
				CPrintToChatAll("%t %t", "ctag", "RTG Gamemode No Change");
				s_VotedGamemode = s_CurrentGamemode;
			} else {
				CPrintToChatAll("%t %t", "ctag", "RTG Gamemode Change", s_VotedGamemode);
			}
			DoMapVote(s_VotedGamemode);
		}
    }
}
 
// Initiate gamemode vote.
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
			LogError("%t Potential Infinite Loop. Breaking", "tag");
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
				LogError("%t Potential Infinite Loop. Breaking", "tag");
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