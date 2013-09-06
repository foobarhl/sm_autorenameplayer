/*
 * sm_autorenameplayer.sp: Automatically rename players to their Steam Name if using a default name
 * Copyright (c) 2013 [foo] bar <foobarhl@gmail.com>
 *
 */

/* Notes:
 *
 * Needs EasyHTTP from
 * Needs JSON decoder from https://forums.alliedmods.net/showpost.php?p=1914836&postcount=10 - other versions may not decode properly and will corrupt player names
 */

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define STRING(%1) %1, sizeof(%1)

#include <EasyHTTP>
#include <smlib>
#include <json>

#define VERSION "0.92"

#define MAX_NAME_LEN 	32
#define MAX_BAD_NAMES	10

public Plugin:myinfo = {
	name = "Automatic Player Renamer",
	author = "[foo] bar",
	description = "Renames unnamed players",
	version = VERSION,
	url = "http://www.vag-clan.tk"
};

new Handle:g_cVarRenameUnnamedPlayers = INVALID_HANDLE;
new Handle:g_cVarPlayerInfoUrl = INVALID_HANDLE;
new Handle:g_cVarPlayerRenamedMessage = INVALID_HANDLE;
new Handle:g_cVarBadPlayerNames = INVALID_HANDLE;

new String:badNames[MAX_BAD_NAMES][MAX_NAME_LEN];

public OnPluginStart()
{
	CreateConVar("sm_autorenameplayer_version", VERSION, "The version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_PLUGIN|FCVAR_REPLICATED|FCVAR_SPONLY);

	g_cVarRenameUnnamedPlayers = CreateConVar("sm_autorenameplayer_enabled", "1", "Auto rename players who haven't changed their default name");
	g_cVarPlayerInfoUrl = CreateConVar("sm_autorenameplayer_infourl", "http://halflife.sixofour.tk/api/steam.php?s={STEAM_ID}&cx={CLIENT_ID}");
	g_cVarPlayerRenamedMessage = CreateConVar("sm_autorenameplayer_message", "Default player names are not allowed here.  Your player name has been set for you.", "Message to print to chat if a player is renamed");
	g_cVarBadPlayerNames = CreateConVar("sm_autorenameplayer_badnames", "HL2CTF_Player,Player", "Comma seperated list of default player names to auto rename. " );

	AutoExecConfig(true, "sm_autorenameplayer");
}

public OnConfigsExecuted()
{
	decl String:badPlayerNames[331];
        if(GetConVarBool(g_cVarRenameUnnamedPlayers)==true){
		HookEvent("player_spawn", Event_PlayerSpawn);
	}
	GetConVarString(g_cVarBadPlayerNames, badPlayerNames, sizeof(badPlayerNames));
	ExplodeString(badPlayerNames, ",", badNames, MAX_BAD_NAMES, MAX_NAME_LEN);
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new clientId = GetClientOfUserId(GetEventInt(event, "userid"));
	if(GetConVarBool(g_cVarRenameUnnamedPlayers)==true){
		checkClientName(clientId);
	}
}

checkClientName(client,force=0)	// default player names annoy foo bar
{
	if(IsFakeClient(client))
		return;

	decl String:steamId[32];
	if(GetClientAuthString(client, steamId, sizeof(steamId))==false){
		PrintToServer("Couldn't get Client Auth String for %d!", client);
	}

	decl String:playerName[MAX_NAME_LEN];

	GetClientName(client, playerName, sizeof(playerName));

	TrimString(playerName);

	for(new i=0; i < sizeof(badNames); i++){

		if(badNames[i][0]=='\0')
			break;
		PrintToServer("Check name '%s' = '%s'", badNames[i], playerName);
		if(StrContains(playerName, badNames[i], false) != -1 || playerName[0]=='\0'|| force){
//			LogToGame("Initiating auto rename of player %s/%d/%s", playerName, client, steamId);
			GetSteamData(client, steamId);
			break;
		}
	}
	return;
}

GetSteamData(clientId,String:steamId32[])
{
	new String:requestUrl[255];
	decl String:clientIds[20];

	IntToString(clientId, clientIds, sizeof(clientIds));

	GetConVarString(g_cVarPlayerInfoUrl, requestUrl, sizeof(requestUrl));
	ReplaceString(requestUrl, sizeof(requestUrl), "{STEAM_ID}", steamId32);
	ReplaceString(requestUrl, sizeof(requestUrl), "{CLIENT_ID}", clientIds);

	EasyHTTP(requestUrl, GetSteamData_Completed, clientId);
}


public GetSteamData_Completed(any:userid, const String:sQueryData[], bool:success, error)
{
	if(success==false) {
		PrintToServer("GetSteamData_Completed was failure");
		return;
	}

	new JSON:js = json_decode(sQueryData);

	if(js!= JSON_INVALID){
		new String:s32[50];
		new String:name[50];
		new clientId;
		json_get_string(js, "steamname", name, sizeof(name));
		json_get_string(js, "s32", s32, sizeof(s32));
		json_get_cell(js, "_cx", clientId);//string(js,"_cx", tmp, sizeof(tmp));

		decl String:testS32[20];

		if(IsClientConnected(clientId)){
			if(GetClientAuthString(clientId, testS32, sizeof(testS32))){
				if(StrEqual(s32, testS32)){

					SetClientInfo(clientId, "name", name);
					LogToGame("sm_autorenameplayer: Renamed client %d/%s to %s", clientId, s32, name);

					decl String:playerMsg[100];
					GetConVarString(g_cVarPlayerRenamedMessage, playerMsg, sizeof(playerMsg));
					if(playerMsg[0]!='\0'){
						PrintToChat(clientId, playerMsg);
					}



				} else {
					LogToGame("sm_autorenameplayer: Auth string mismatch %s != %s for client %d in name set.  Not doing anything", s32, testS32, clientId);
				}
			} else {
				LogToGame("sm_autorenameplayer: Can't get client auth string for %d in name set", clientId);
			}
		} else {
			LogToGame("sm_autorenameplayer: Client %d isn't connected in name set", clientId);
		}
		
	} else {
		PrintToServer("sm_autorenameplayer: JSON Data was invalid!");
	}
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
// Mark Socket natives as optional
	MarkNativeAsOptional("SocketIsConnected");
	MarkNativeAsOptional("SocketCreate");
	MarkNativeAsOptional("SocketBind");
	MarkNativeAsOptional("SocketConnect");
	MarkNativeAsOptional("SocketDisconnect");
	MarkNativeAsOptional("SocketListen");
	MarkNativeAsOptional("SocketSend");
	MarkNativeAsOptional("SocketSendTo");
	MarkNativeAsOptional("SocketSetOption");
	MarkNativeAsOptional("SocketSetReceiveCallback");
	MarkNativeAsOptional("SocketSetSendqueueEmptyCallback");
	MarkNativeAsOptional("SocketSetDisconnectCallback");
	MarkNativeAsOptional("SocketSetErrorCallback");
	MarkNativeAsOptional("SocketSetArg");
	MarkNativeAsOptional("SocketGetHostName");

	// Mark SteamTools natives as optional
	MarkNativeAsOptional("Steam_IsVACEnabled");
	MarkNativeAsOptional("Steam_GetPublicIP");
	MarkNativeAsOptional("Steam_RequestGroupStatus");
	MarkNativeAsOptional("Steam_RequestGameplayStats");
	MarkNativeAsOptional("Steam_RequestServerReputation");
	MarkNativeAsOptional("Steam_IsConnected");
	MarkNativeAsOptional("Steam_SetRule");
	MarkNativeAsOptional("Steam_ClearRules");
	MarkNativeAsOptional("Steam_ForceHeartbeat");
	MarkNativeAsOptional("Steam_AddMasterServer");
	MarkNativeAsOptional("Steam_RemoveMasterServer");
	MarkNativeAsOptional("Steam_GetNumMasterServers");
	MarkNativeAsOptional("Steam_GetMasterServerAddress");
	MarkNativeAsOptional("Steam_SetGameDescription");
	MarkNativeAsOptional("Steam_RequestStats");
	MarkNativeAsOptional("Steam_GetStat");
	MarkNativeAsOptional("Steam_GetStatFloat");
	MarkNativeAsOptional("Steam_IsAchieved");
	MarkNativeAsOptional("Steam_GetNumClientSubscriptions");
	MarkNativeAsOptional("Steam_GetClientSubscription");
	MarkNativeAsOptional("Steam_GetNumClientDLCs");
	MarkNativeAsOptional("Steam_GetClientDLC");
	MarkNativeAsOptional("Steam_GetCSteamIDForClient");
	MarkNativeAsOptional("Steam_SetCustomSteamID");
	MarkNativeAsOptional("Steam_GetCustomSteamID");
	MarkNativeAsOptional("Steam_RenderedIDToCSteamID");
	MarkNativeAsOptional("Steam_CSteamIDToRenderedID");
	MarkNativeAsOptional("Steam_GroupIDToCSteamID");
	MarkNativeAsOptional("Steam_CSteamIDToGroupID");
	MarkNativeAsOptional("Steam_CreateHTTPRequest");
	MarkNativeAsOptional("Steam_SetHTTPRequestNetworkActivityTimeout");
	MarkNativeAsOptional("Steam_SetHTTPRequestHeaderValue");
	MarkNativeAsOptional("Steam_SetHTTPRequestGetOrPostParameter");
	MarkNativeAsOptional("Steam_SendHTTPRequest");
	MarkNativeAsOptional("Steam_DeferHTTPRequest");
	MarkNativeAsOptional("Steam_PrioritizeHTTPRequest");
	MarkNativeAsOptional("Steam_GetHTTPResponseHeaderSize");
	MarkNativeAsOptional("Steam_GetHTTPResponseHeaderValue");
	MarkNativeAsOptional("Steam_GetHTTPResponseBodySize");
	MarkNativeAsOptional("Steam_GetHTTPResponseBodyData");
	MarkNativeAsOptional("Steam_WriteHTTPResponseBody");
	MarkNativeAsOptional("Steam_ReleaseHTTPRequest");
	MarkNativeAsOptional("Steam_GetHTTPDownloadProgressPercent");

	// Mark cURL natives as optional
	MarkNativeAsOptional("curl_easy_init");
	MarkNativeAsOptional("curl_easy_setopt_string");
	MarkNativeAsOptional("curl_easy_setopt_int");
	MarkNativeAsOptional("curl_easy_setopt_int_array");
	MarkNativeAsOptional("curl_easy_setopt_int64");
	MarkNativeAsOptional("curl_OpenFile");
	MarkNativeAsOptional("curl_httppost");
	MarkNativeAsOptional("curl_slist");
	MarkNativeAsOptional("curl_easy_setopt_handle");
	MarkNativeAsOptional("curl_easy_setopt_function");
	MarkNativeAsOptional("curl_load_opt");
	MarkNativeAsOptional("curl_easy_perform");
	MarkNativeAsOptional("curl_easy_perform_thread");
	MarkNativeAsOptional("curl_easy_send_recv");
	MarkNativeAsOptional("curl_send_recv_Signal");
	MarkNativeAsOptional("curl_send_recv_IsWaiting");
	MarkNativeAsOptional("curl_set_send_buffer");
	MarkNativeAsOptional("curl_set_receive_size");
	MarkNativeAsOptional("curl_set_send_timeout");
	MarkNativeAsOptional("curl_set_recv_timeout");
	MarkNativeAsOptional("curl_get_error_buffer");
	MarkNativeAsOptional("curl_easy_getinfo_string");
	MarkNativeAsOptional("curl_easy_getinfo_int");
	MarkNativeAsOptional("curl_easy_escape");
	MarkNativeAsOptional("curl_easy_unescape");
	MarkNativeAsOptional("curl_easy_strerror");
	MarkNativeAsOptional("curl_version");
	MarkNativeAsOptional("curl_protocols");
	MarkNativeAsOptional("curl_features");
	MarkNativeAsOptional("curl_OpenFile");
	MarkNativeAsOptional("curl_httppost");
	MarkNativeAsOptional("curl_formadd");
	MarkNativeAsOptional("curl_slist");
	MarkNativeAsOptional("curl_slist_append");
	MarkNativeAsOptional("curl_hash_file");
	MarkNativeAsOptional("curl_hash_string");

}