>**aliases.smx**  
Ready/Unready Aliases  
*Prints Ready! on chat*

<ins>Commands:</ins>
- "**sm_r**" / "**sm_ready**": Ready!
- "**sm_nr**": Not Ready!
---
>**autopause.smx**  
Auto pause on player crash

<ins>CVARS:</ins>
- "**autopause_enable**": Whether or not to automatically pause when a player crashes.
- "**autopause_force**": Whether or not to force pause when a player crashes.
- "**autopause_apdebug**": Whether or not to debug information.
---
>**autorecorder.smx**  
Automates SourceTV recording based on player count and time of day.  
http://forums.alliedmods.net/showthread.php?t=92072

<ins>Commands:</ins>

* **sm_record**: Starts a SourceTV demo
* **sm_stoprecord**: Stops recording the current SourceTV demo

<ins>CVARS:</ins>
* **sm_autorecord_enable**: Enable automatic recording
* **sm_autorecord_finishmap**: If 1, continue recording until the map ends
* **sm_autorecord_ignorebots**: Ignore bots in the player count
* **sm_autorecord_minplayers**: Minimum players on server to start recording
* **sm_autorecord_path**: Path to store recorded demos
* **sm_autorecord_timestart**: Hour in the day to start recording (0-23, -1 disables)
* **sm_autorecord_timestop**: Hour in the day to stop recording (0-23, -1 disables)

---

> **l4d_custom_commands.smx**  
[L4D & L4D2] New custom commands  
https://forums.alliedmods.net/showthread.php?t=133475

Current Commands on Left 4 Dead 1:  
<ins>Player Commands:</ins>
- "**sm_incapplayer**" (Incapacitate Player): Will Incapacitate a Survivor or Tank.
- "**sm_speedplayer**" (Set player speed): Will set a selected player's speed into a the given value.
- "**sm_sethpplayer**" (Set player health): Will set a player's health into the given value.
- "**sm_colorplayer**" (Set player color): Will set a player's color into the given value (Red, Green, Blue, Alpha*).
- "**sm_dontrush**" (Anti Rush Player) - Teleports the player to the beginning safe room
- "**sm_sizeplayer**" (Resize Player) - Will set a player's size into the given value. Works better on jockeys.
- "**sm_airstrike**" (Send airstrike) - Will send an airstrike attack to the selected player.
- "**sm_changehp**" (Switch Health Style) - Will switch a player's health between Permanent and Temporal.
- "**sm_godmode**" (God Mode) - Will enable or disable god mode in a player.
- "**sm_shakeplayer**" (Shake player) - Will shake a player's screen.
- "**sm_teleport**" (Teleport Player) - Teleports a player to your mouse postion.

**Transparency of the survivor*

<ins>Utility Commands:</ins>
- "**sm_ccrefresh**" - Refresh the admin menu to store all the items upon plugin unload, load or reload.

<ins>Server Commands:</ins>
- "**sm_setexplosion**" (Create explosion): Will create an explosion on your current position or cursor position.
- "**sm_l4drain**" (L4D1 Survivors Rain) - Will rain survivors. *[Caution: Will lag low performance computers]*

<ins>Not in the admin menu:</ins>
- "**sm_colortarget**" - Will apply a custom color to any entity with a model. (objects or players)
- "**sm_sizetarget**" - Will resize the target's model into the given value
- "**sm_cheat**" - Bypass any command and executes it
- "**sm_cmdplayer**" - Controls a player console
- "**sm_weaponrain**" - Will rain the desired weapon
- "**sm_bleedplayer**" - Force a player to bleed (HP wont be affected)
- "**sm_wipentity**" - Deletes all the entities with the given class name. (For weapons you must put 'weapon_' before its name, EX: weapon_adrenaline for adrenaline)
- "**sm_ignite**" (Ignite Player) - Will burn the player, adding a fire effect on him - Pending - Problems parenting the entity.
- "**sm_createparticle**" (Create Particle) - Creates a particle with the given name and will parent (or not) it.
- "**sm_setmodel**" - Sets a player model into the given model file.
- "**sm_setmodelentity**" - Sets all entities that match the given classname with the given model.
- "**sm_teleportent**" - Teleport the desired entities with the classname to your cursor position.
- "**sm_rcheat**" - Bypass and executes any server command.
- "**sm_grabentity**" - Grabs any looking entity allowing you to freely move it.
- "**sm_scanmodel**" - Scans any entity model, if possible. If the model property is not found the command will fail.

<ins>Current Commands on Left 4 Dead 2:</ins>  
-To obtain the full command list, please, type **!cchelp** on chat, and then check your console.

<ins>CVARS:</ins>  
- **l4d2_custom_commands_version**: Version of the plugin.
- **l4d2_custom_commands_explosion_radius**: Radius of the explosion.
- **l4d2_custom_commands_explosion_power**: Power of the explosion.
- **l4d2_custom_commands_explosion_duration**: Duration of the fire trace left by the explosion (Causes damage).
- **l4d2_custom_commands_rain_duration**: Duration of the Gnome Rain and l4d1 rain..
- **l4d2_custom_commands_rain_radius**: Radius of the Gnome Rain, l4d1 rain and air strike commands.
- **l4d2_custom_commands_menutype**: 0: Create a new admin menu category 1: Add commands to the default sourcemod categories

---
>**nodeathcamskip.smx**  
Block players skipping their death time by going spec  
https://github.com/SirPlease/L4D2-Competitive-Rework

CVARS:
* **deathcam_skip_announce**: If **1** (*default*), globally print an info about the player who tried to exploit.