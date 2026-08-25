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
>**langselect.smx**  
A plugin that allows players to select the language they want SourceMod to translate text into. Translations must be provided by plugins for this to have any effect on them.  
https://forums.alliedmods.net/showthread.php?p=2785962

<ins>Commands:</ins>
* **sm_language** / **sm_lang <Country Code>**: Set your own SourceMod translation language.  
* **sm_lang** / **sm_language**: Not specifying a country code will open the menu.  
* **sm_getlanguage** / **sm_getlang** <Target>: Get a player's SourceMod translation language.  
* **sm_setlanguage** / **sm_setlang <Target> <Country Code>**: Set a player's SourceMod translation language.  
* **sm_resetlanguage** / **sm_resetlang <Target>: **Reset a player's SourceMod translation language.

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

---
>**kether_prophunt.smx**  
[L4D2] Kether Prop Hunt  
Versus-based hide-and-seek gamemode for the `prophunt` cfgogl matchmode. Survivors are "Hunters" (seekers). Infected spawn as attack-disabled Hunters and use **+use** to disguise as a world prop (model swap + a non-solid visual child prop), then try to survive the round without being found. Only active while the `prophunt` matchmode is loaded.

<ins>Commands:</ins>
- "**sm_hunt**": Volunteer to be picked as a Hunter next round (fairness-queue rotation still applies).
- "**sm_prop**": Open the disguise menu - the fallback/admin path for picking a prop when aiming isn't precise enough.
- "**sm_lock**": Toggle your rotation/position lock once disguised (blocked over an active `trigger_hurt`).
- "**sm_taunt**": Play a voluntary special-infected sound (has a cooldown, see `ph_taunt_cooldown`).
- "**sm_ph**": Show the current round number, phase and Props remaining.
- "**sm_ph_forceround**" *(admin, `ADMFLAG_CHANGEMAP`)*: Force-end the current round.

<ins>CVARS:</ins>
- **ph_hunters**: Number of Hunters (survivor slots) selected each round. The rest of the connected players are Props. *(default 4, 1-8)*
- **ph_hide_time**: Seconds Hunters are frozen and blinded at the start of a round while Props hide. *(default 45)*
- **ph_round_time**: Seconds a round lasts once the seek phase starts. Props still alive when it expires win the round. *(default 240)*
- **ph_round_end_delay**: Seconds to show the round-end scoreline before starting the next round. *(default 8)*
- **ph_guaranteed_hunter_turns**: Rounds a client is guaranteed to stay a Prop after having been a Hunter, before being eligible again. *(default 3)*
- **ph_prop_min_size** / **ph_prop_max_size**: Minimum/maximum prop bounding-box diagonal (Hammer units) a Prop is allowed to disguise as. *(default 20 / 260)*
- **ph_prop_select_distance**: Maximum distance (Hammer units) to a prop for +use to select it. *(default 180)*
- **ph_prop_change_limit**: Times a Prop may re-pick a disguise per round. 0 = unlimited. *(default 0)*
- **ph_proplock_enabled**: 1 = Props may lock their rotation/position in place (bound to `sm_lock`/+reload). *(default 1)*
- **ph_auto_freeze_time**: Seconds a disguised Prop must stand still before being auto-locked in place. 0 = disabled. *(default 5)*
- **ph_thirdperson**: 1 = Props automatically get a third-person camera while disguised. *(default 1)*
- **ph_cue_interval**: Seconds between forced special-infected sound cues, so Props can't camp silently forever. 0 = disabled. *(default 45)*
- **ph_cue_warn_fraction**: Fraction of `ph_cue_interval` at which a chat/hint warning is sent before the forced cue plays. *(default 0.5)*
- **ph_taunt_enabled**: 1 = Props may voluntarily taunt (play a special infected sound) with `sm_taunt`. *(default 1)*
- **ph_taunt_cooldown**: Seconds between voluntary taunts from the same Prop. *(default 10)*
- **ph_hp_hunter_dec**: HP a Hunter loses for every shot fired. *(default 5)*
- **ph_hp_hunter_inc**: HP a Hunter regains for landing a hit on a Prop. *(default 15)*
- **ph_hp_hunter_bonus**: Bonus HP a Hunter regains for eliminating a Prop. *(default 40)*
- **ph_hide_blood**: 1 = Suppress blood decals/particles when a Hunter hits a Prop. *(default 1)*
- **ph_anticheat_kick**: 1 = Kick Hunters found with `r_staticpropinfo` enabled (reveals static prop names/bounds client-side). *(default 1)*