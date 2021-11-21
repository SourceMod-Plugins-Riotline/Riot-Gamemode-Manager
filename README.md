# SourceMod | Riot Gamemode Manager
Version 1.0.0

(Only supported/tested games: Team Fortress 2)  
Manage multiple gamemodes along with their respective maps with a _rock the vote_ style voting system on top of a plugin manager. Create a fun mutli-gamemode experience for your server and community.

## Installation
1. Download latest release or source files
2. Extract all files into the 'sourcemod/' folder
3. Change the rgm.gamemodes.cfg file to include all your gamemodes and maps.
4. Restart your server or execute command `sm plugins load rgm`
5. Change the ConVars in the automatically generated config file in `/cfg/sourcemod`
6. ??
7. Profit!?!

!! NOTE !! mapcycle will be utilised by the plugin. This plugin will automatically change/edit the mapcycle file in order to ensure correct maps are loaded/listed when doing any map-related changes like a normal RTV vote. Altering the file without disabling this plugin will not work properly.

## Commands
#### Admin Commands
Visit https://wiki.alliedmods.net/Overriding_Command_Access_(Sourcemod) for changing command permissions.
> `sm_forcergm [gamemode] [map]` (`sm_frgm`) - Displays a menu with all available gamemodes and respective maps; alternatively will force a gamemode and map change when parameters are specified. [Default Perm: CONFIG]

> `sm_forcertg` (`sm_frtg`) - Forces a Rock the Game vote for all players on the server. [Default Perm: VOTE]

> `sm_reloadrgm` - Reload the Riot Gamemode Manager Config. [Default Perm: CONFIG]

> `sm_togglergm` - Toggle whether the Gamemode Manager is enabled or not. [Default Perm: CONFIG] _\*Untested\*_

> `sm_rgmdebug` - Shows current status of the plugin [Default Perm: CONFIG] _\*Debugging Command\*_

#### Player Commands
> `sm_rtg` - Votes for Rock the Game. Alternatively players can type `rtg` in chat. (Mimics Rock the Vote)

## ConVars
> `rgm_rtg_initialdelay <seconds>` - Time (in seconds) before the first Rock the Game can be held. [Default: '45.0']

> `rgm_rtg_interval <seconds>` - Time (in seconds) after a failed RTG before another can be held. [Default: '240.0']

> `rgm_rtg_needed <ratio>` - Percentage of players needed to rock the game. (60% = 0.60) [Default: '0.60']

> `rgm_automapcycle <1/0>` - Automatically change the mapcycle.txt file to match the current gamemodes' maps. [Default: '1']

> `rgm_defaultgamemode <gamemode>` - On server startup, automatically adjust the server to the specified gamemode. (Disabled: '') [Default: '']

> `rgm_hostnamechange <seconds>` - Adjust the delay for when the hostname (from gamemode config) should change after map change. [Default: 2.0]

## Source File Dependencies and Contributions
Requires [More Colors](https://forums.alliedmods.net/showthread.php?t=185016) by [Dr.McKay](https://www.doctormckay.com/) to compile.  
Thanks to 'thesupremecommander' for the original gamemode management system [Gamemode Manager](https://forums.alliedmods.net/showthread.php?p=2039152).

## Suggestions/Feedback/Issues

Don't hesistate to contact myself or submit an issue report for any concerns, queries or suggestions for this plugin!
Thanks!

