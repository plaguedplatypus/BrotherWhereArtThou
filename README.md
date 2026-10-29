# Brother Where Art Thou

Barrows plugin that labels boss mounds, tracks kills, marks the hidden tunnel and slain sarcophagi, points out the next tunnel door, and offers puzzle help on request.

## Using the plugin

Open **Brother Where Art Thou** from the Plugin Hub ribbon before starting a Barrows run. The dock shows the brothers you have slain, your creature kill count, the marked tunnel brother, your lifetime Barrows Brothers kill count, and your Linza kill count. It also shows Akrisae's and Linza's quest status. Hover over the gold info icon beside either name to see its quest requirement. Use the backpack button in the bottom-left corner to open a separate loot window. The cog in the bottom-right corner opens settings in the dock and becomes a back arrow there.

The Plugin Hub also installs PrettyUI, which provides the loot window, tabs, and scrollbars.

### On the surface

The plugin puts each boss's name above its mound spade. An icon beside the name shows that boss's incoming attack style: Melee, Ranged, or Magic. Akrisae shares Verac's mound after *Ritual of the Mahjarrat*; Linza shares Ahrim's after *Kindred Spirits*.

A slain boss gets a crossed-out name and, when combat icons are shown, a red X over its icon. Once the tunnel brother is known, its mound name and background turn gold, a pulsing yellow chevron appears above it, and **[Tunnel]** appears below it. The plugin can also identify the last eligible brother when all the others have been killed. Linza cannot lead underground.

Mound names appear only when in range of all six surface spades. They disappear underground or when the spades are out of range.

### In the crypts and tunnels

A red X marks each slain brother's sarcophagus, including in rooms with two sarcophagi. A translucent gold box, chevron, and **[Tunnel]** label mark the sarcophagus that leads underground when it is in view.

In the tunnels, a flashing green chevron marks the next door on the route to the chest-room puzzle. It updates as you move, including in the outer corridors that bypass a room. The marker disappears after you enter the chest room.

### At the puzzle door

Try the sequence yourself first. If you want the answer, click **HELP** in the bottom-right corner of the puzzle window. The correct answer then turns bright green and a yellow chevron points to it. The plugin follows the answer if the game moves the choices. Help resets when the puzzle closes or changes.

### Runs and options

Akrisae appears when the game reports *Ritual of the Mahjarrat* complete, and Linza appears when it reports *Kindred Spirits* complete. The overview shows **Unlocked** or **Missing quest** for each boss, or **Unknown** until the game supplies the quest status. You can leave optional bosses alive.

The loot window saves the rewards shown in the Barrows chest. It opens on the **Per run** tab, listing each chest separately with the newest run first. Each run shows **Linza Run** when Linza was the only boss slain, or **Brothers slain: N/total** otherwise. The total is six, seven, or eight depending on which optional bosses were unlocked. Hover over a run heading to see all eight names, with confirmed kills crossed out. Quick Loot bypasses this chest history.

The **Combined** tab shows one inventory with each item shown once, plus the number of saved runs. Item quantities increase as new loot is recorded. Large counts are shortened in the slots; hover over an item to see its name and full quantity. Items wrap onto another row when needed. Use the mouse wheel or scrollbar to browse the list. You can move and resize the window. Rewards remain listed after you bank or take them. In settings, click **Clear loot**, then **Confirm Clear?**, to erase this character's saved loot history.

In settings, **Show Linza KC** controls whether the count appears on the overview. **Show combat styles** controls the Melee, Ranged, and Magic icons beside surface mound names. Both options are on by default. Click **Reset Linza KC**, then **Confirm Reset?**, to set the saved count to zero. If Linza's current kill flag is still active, that kill will not be counted again.

After you use the Barrows chest and return to the surface, the plugin clears the tunnel choice and slain marks for the next run. The Linza count starts with the first kill the plugin observes.

The plugin hides the game's Barrows panel while active and restores its normal visibility when unloaded. The current run, loot history, Linza KC, and settings are kept separately by character display name. A name change starts a new save under the new name. The plugin does not request extra permissions or send player data anywhere.

## How tracking works

The plugin reads the six original brothers' kill flags from `BARROWS_KILLS`. Akrisae uses `MAH5_KILLED_BARROWS_AKRISAE`, and Linza uses `SISTER_KILLED_LINZA`. If Akrisae's flag is unavailable, the plugin can infer his kill from the packed brother count.

The lifetime Barrows Brothers KC comes from the game's `BSLAY_KILLS_BARROWS` counter and `BSLAY_PRESTIGE_BARROWS` prestige count. Each completed prestige represents 60,000 kills. This is separate from the number of brothers or creatures slain in the current run and does not need a manual reset.

The Linza counter increments once while her kill flag is set. A saved flag prevents the same kill from being counted again after a plugin reload or count reset. It resets only when the game clears her kill flag.

The plugin confirms a hidden tunnel from the dialog shown after searching a sarcophagus.

Surface labels find nearby locations with the **Dig-with** action and project each mound spade. The tunnel door marker uses the game's door states and floor height. When you press **HELP** at the puzzle door, the plugin identifies the pattern and correct choice from the game's model IDs.
