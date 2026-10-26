# Brother Where Art Thou

Barrows plugin that labels boss mounds, tracks kills, marks the hidden tunnel and slain sarcophagi, guides you through the crypt, and highlights the correct puzzle answer.

## Using the plugin

Open **Brother Where Art Thou** from the Plugin Hub ribbon before starting a Barrows run. The dock shows the brothers you have slain, your creature kill count, the marked tunnel brother, your lifetime Barrows Brothers kill count, and your Linza kill count. It also shows Akrisae's quest status and Linza's quest or manual display status. Hover over the gold info icon beside either name to see its quest requirement. Use the cog in the bottom-right corner to open settings, then the back arrow in the same spot to return to the run overview.

### On the surface

The plugin puts each boss's name above its mound spade. An icon beside the name shows that boss's incoming attack style: Melee, Ranged, or Magic. Akrisae shares Verac's mound after *Ritual of the Mahjarrat*; Linza shares Ahrim's after *Kindred Spirits*.

A slain boss gets a crossed-out name and, when combat icons are shown, a red X over its icon. Once the tunnel brother is known, its mound name and background turn gold, a pulsing yellow chevron appears above it, and **[Tunnel]** appears below it. The plugin can also identify the last eligible brother when all the others have been killed. Linza cannot lead underground.

Mound names appear only when in range of all six surface spades. They disappear underground or when the spades are out of range.

### In the crypts and tunnels

A red X marks each slain brother's sarcophagus, including in rooms with two sarcophagi. A translucent gold box, chevron, and **[Tunnel]** label mark the sarcophagus that leads underground when it is in view.

In the tunnels, a gold floor line leads through open doors to the chest-room puzzle door. It handles outer corridors that bypass a room, updates as you move, and extends through a corridor as its floor becomes visible. The line disappears after you enter the chest room.

### At the puzzle door

The correct answer turns bright green and a yellow chevron points to it. The plugin follows the answer if the game moves the choices.

### Runs and options

Akrisae appears when the game reports *Ritual of the Mahjarrat* complete. **Show Linza** is always available in settings. Linza follows *Kindred Spirits* until you change her toggle; your choice is then saved for that character and takes precedence over quest detection. The overview shows **Shown** or **Hidden** for a manual Linza choice, and **Unlocked** or **Missing quest** when following a quest. You can leave optional bosses alive.

In settings, **Show Linza KC** controls whether the count appears on the overview. **Show combat styles** controls the Melee, Ranged, and Magic icons beside surface mound names. Both options are on by default. Click **Reset Linza KC**, then **Confirm**, to set the saved count to zero. If Linza's current kill flag is still active, that kill will not be counted again.

After you use the Barrows chest and return to the surface, the plugin clears the tunnel choice and slain marks for the next run. The Linza count starts with the first kill the plugin observes.

The plugin hides the game's Barrows panel while active and restores its normal visibility when unloaded. Saved runs, Linza KC, and settings are kept separately by character display name. A name change starts a new save under the new name. The old shared save is left untouched because the plugin cannot tell which character owns it. The plugin does not request extra permissions or send player data anywhere.

## How tracking works

The plugin reads the six original brothers' kill flags from `BARROWS_KILLS`. Akrisae uses `MAH5_KILLED_BARROWS_AKRISAE`, and Linza uses `SISTER_KILLED_LINZA`. If Akrisae's flag is unavailable, the plugin can infer his kill from the packed brother count.

The lifetime Barrows Brothers KC comes from the game's `BSLAY_KILLS_BARROWS` counter and `BSLAY_PRESTIGE_BARROWS` prestige count. Each completed prestige represents 60,000 kills. This is separate from the number of brothers or creatures slain in the current run and does not need a manual reset.

The Linza counter increments once while her kill flag is set. A saved flag prevents the same kill from being counted again after a plugin reload or count reset. It resets only when the game clears her kill flag.

The plugin confirms a hidden tunnel from the dialog shown after searching a sarcophagus.

Surface labels find nearby locations with the **Dig-with** action and project each mound spade. The tunnel route uses the game's door states and visible floor. At the puzzle door, the plugin identifies the pattern and correct choice from the game's model IDs.
