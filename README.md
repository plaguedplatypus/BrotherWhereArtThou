# Brother Where Art Thou

Barrows plugin that labels boss mounds, tracks kills, marks the hidden tunnel and slain sarcophagi, guides you through the crypt, and highlights the correct puzzle answer.

## Using the plugin

Open **Brother Where Art Thou** from the Plugin Hub ribbon before starting a Barrows run. The dock shows the brothers you have slain, your creature kill count, the marked tunnel brother, and your lifetime Linza kill count. It also shows whether Akrisae and Linza are unlocked. Hover over the gold info icon beside either name to see its quest requirement.

### On the surface

The plugin puts each boss's name above its mound spade. An icon beside the name shows that boss's incoming attack style: Melee, Ranged, or Magic. Akrisae shares Verac's mound after *Ritual of the Mahjarrat*; Linza shares Ahrim's after *Kindred Spirits*.

A slain boss gets a red X and a crossed-out name. Once the tunnel brother is known, its mound name and background turn gold, a pulsing yellow chevron appears above it, and **[Tunnel]** appears below it. The plugin can also identify the last eligible brother when all the others have been killed. Linza cannot lead underground.

Mound names appear only when in range of all six surface spades. They disappear underground or when the spades are out of range.

### In the crypts and tunnels

A red X marks each slain brother's sarcophagus, including in rooms with two sarcophagi. A translucent gold box, chevron, and **[Tunnel]** label mark the sarcophagus that leads underground when it is in view.

In the tunnels, a gold floor line leads through open doors to the chest-room puzzle door. It handles outer corridors that bypass a room, updates as you move, and extends through a corridor as its floor becomes visible. The line disappears after you enter the chest room.

### At the puzzle door

The correct answer turns bright green and a yellow chevron points to it. The plugin follows the answer if the game moves the choices.

### Runs and options

Use **Clear run** if you abandon a run before opening the chest. If the client cannot read a quest status, use **Show Akrisae** or **Show Linza** to control whether that boss appears. You can leave optional bosses alive.

After you use the Barrows chest and return to the surface, the plugin clears the tunnel choice and slain marks for the next run. The Linza count starts with the first kill the plugin observes.

The plugin hides the game's Barrows panel while active and restores its normal visibility when unloaded. It does not request chat access or send player data anywhere.

## How tracking works

The plugin reads the six original brothers' kill flags from `BARROWS_KILLS`. Akrisae uses `MAH5_KILLED_BARROWS_AKRISAE`, and Linza uses `SISTER_KILLED_LINZA`. If Akrisae's flag is unavailable, the plugin can infer his kill from the packed brother count.

The Linza counter increments once while her kill flag is set. A saved flag prevents the same kill from being counted again after a plugin reload or manual run clear. It resets only when the game clears her kill flag.

The plugin confirms a hidden tunnel from the dialog shown after searching a sarcophagus.

Surface labels find nearby locations with the **Dig-with** action and project each mound spade. The tunnel route uses the game's door states and visible floor. At the puzzle door, the plugin identifies the pattern and correct choice from the game's model IDs.
