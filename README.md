# SourceMod | Riot Gamemode Manager

Manage multiple gamemodes along with their respective maps with a _rock the vote_ style plugin. Create a fun mutli-gamemode experience for your server and community.

## Installation
1. Download latest release or source files
2. Extract all files into the 'sourcemod/' folder
3. Change the rgm.gamemodes.cfg file to include all your gamemodes and maps.
4. Restart your server or execute command `sm plugins load rgm`
5. Change the ConVars in the automatically generated config file in `/cfg/sourcemod`
4. ??
5. Profit!?!

## Commands
#### Admin Commands
Visit https://wiki.alliedmods.net/Overriding_Command_Access_(Sourcemod) for changing command permissions.
> `sm_forcergm` (`sm_frgm`) - Displays a menu with all available gamemodes and respective maps. [Default Perm: CONFIG]
> `sm_forcertg` (`sm_frtg`) - Forces a Rock the Game vote for all players on the server. [Default Perm: VOTE]
> `sm_reloadrgm` - Reload the Riot Gamemode Manager Config. [Default Perm: CONFIG]
> `sm_togglergm` - Toggle the Gamemode Manager status. [Default Perm: CONFIG] _\*Untested\*_
> `sm_rgmdebug` - Shows current status of the plugin [Default Perm: CONFIG] _\*Debugging Command\*_

#### Player Commands
> `sm_rtg` - Votes for Rock the Game. Alternatively players can type `rtg` in chat. (Mimics Rock the Vote)

## ConVars
> `rgm_rtg_initialdelay <seconds>` - Time (in seconds) before the first Rock the Game can be held. [Default: '45.0']
> `rgm_rtg_interval <seconds>` - Time (in seconds) after a failed RTG before another can be held. [Default: '240.0']
> `rgm_rtg_needed <ratio>` - Percentage of players needed to rock the game. (60% = 0.60) [Default: '0.60']
> `rgm_automapcycle <1/0>` - Automatically change the mapcycle.txt file to match the current gamemodes' maps [Default: 1].

## Source File Dependencies
Requires [More Colors](https://forums.alliedmods.net/showthread.php?t=185016) by [Dr.McKay](https://www.doctormckay.com/) to compile.

## Suggestions/Feedback/Issues

Don't hesistate to contact myself or submit an issue report for any concerns, queries or suggestions for this plugin!
Thanks!

