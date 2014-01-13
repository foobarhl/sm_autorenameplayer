sm_autorenameplayer
===================

Automatically rename "unnamed" players to use their Steam Profile name.

For the latest release, compiled binary w/source, and support:  purchase Auto Rename Player from www.foo-games.com.  

Configuration
-------------

Configuration: cfg/sourcemod/sm_autorenameplayer.cfg

> sm_autorenameplayer_enabled    : Enabled or not

> sm_autorenameplayer_infourl    : URL to a script that returns player info in JSON format

> sm_autorenameplayer_message    : Message to print to player chat if renamed

> sm_autorenameplayer_badnames   : Comma seperated list of "default" names to initiate an auto rename on.  Don't include spaces.



Player information PHP script
-----------------------------
In php/steam.php lives an example PHP script you can point this plugin to.   
It simply returns information about the specified SteamID in JSON.

