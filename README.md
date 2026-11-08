# Brother Where Art Thou

Brother Where Art Thou helps you follow a Barrows run. Open it from the Plugin Hub ribbon before you start. Its dock shows the brothers and creatures you have slain, the known tunnel brother, your lifetime Barrows Brothers kill count, and the Linza kills this plugin has counted. It also shows whether the quests for Akrisae and Linza are complete.

<img src="https://image.modcdn.io/members/20c3/63901461/profilebrother/tunnel0.png" alt="Brother Where Art Thou dock showing Barrows run progress" width="213" height="388">

## Known Issues
- Currently waiting for live release for any known issues.

## Additions
- This is where planned additions will be listed.

## On the surface

Names appear above the six Barrows mound spades. Small Melee, Ranged, or Magic icons show each boss's incoming attack style. Slain bosses are crossed out. When the tunnel brother is known, that mound is marked in gold with a chevron and a **Tunnel** label. Akrisae and Linza appear when their required quests are complete.

<img src="https://image.modcdn.io/members/20c3/63901461/profilebrother/tunnel1.png" alt="Names and attack styles above the Barrows mounds" width="650" height="268">

## In the crypts and tunnels

Red crosses mark slain brothers' sarcophagi.

<img src="https://image.modcdn.io/members/20c3/63901461/profilebrother/tunnel3.png" alt="Red cross marking a slain brother's sarcophagus" width="350" height="350">

Once the tunnel sarcophagus is known, a gold box, chevron, and **Tunnel** label mark it when it is in view.

<img src="https://image.modcdn.io/members/20c3/63901461/profilebrother/tunnel4.png" alt="Gold box and Tunnel label marking the tunnel sarcophagus" width="350" height="350">

Underground, a flashing green chevron marks the next door on the route toward the chest-room puzzle. The marker updates as you move and disappears in the chest room.

## Puzzle help

The puzzle starts without an answer highlight. Try it yourself, or press **HELP** at the bottom right of the puzzle window to highlight the correct answer in green and show a yellow chevron. Help resets when the puzzle closes or changes. You still select the answer yourself.

## Loot and settings

Use the backpack button in the dock to open loot history.

- **Per Run** shows each recorded Barrows chest separately, newest first. Hover over a run heading to see which bosses were slain.
- **Combined** adds the saved item quantities together.

> Quick Loot bypasses this chest history, so open and claim from the chest normally if you want its rewards recorded.

<img src="https://image.modcdn.io/members/20c3/63901461/profilebrother/loot1.png" alt="Per Run loot history" width="350" height="350"> <img src="https://image.modcdn.io/members/20c3/63901461/profilebrother/loot2.png" alt="Combined loot history" width="350" height="350">

In the dock, use the settings button to show or hide combat style icons and Linza KC. Settings also let you clear this character's loot history or reset its Linza KC, with a confirmation click for each action.

The plugin hides the game's Barrows panel while active and restores it when unloaded. Run state, loot history, Linza KC, and settings are saved locally for each character display name. A name change starts a separate save.

> PrettyUI is required for the loot window; the Plugin Hub installs required dependencies.

## Contact and feedback

Bug reports and feedback are welcome on [Discord](https://discord.com/channels/1523582684109082645/1562407323618517113).

## EULA

This Plugin uses software licensed by Jagex to the developer under the terms of the Jagex End User Licence Agreement (EULA) found at [https://legal.jagex.com/docs/terms/eula](https://legal.jagex.com/docs/terms/eula) (and all terms incorporated into it by reference). The development and any use of the Plugin is at all times subject to the Jagex EULA.

## Permissions

This plugin requests no additional permissions.

## Data protection (case 1)

The plugin reads the character's display name, Barrows kill and creature counts, relevant quest status, nearby Barrows objects and door states, the puzzle interface, and rewards shown in the Barrows chest. It uses this information to display overlays and track runs.

The plugin stores the character's current run, loot item IDs and quantities, confirmed boss kills, Linza KC, and settings in the client's local plugin database under the character display name. The plugin does not send this information to an external service or use an HTTP endpoint.
