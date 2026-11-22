# Tolu game: project notes

Godot 4.7, GL Compatibility renderer, 2D. Start screen: character select, then map select, then the fight.

## Files

- `project.godot`: project settings. Main scene is `scenes/select.tscn`.
- `icon.svg`: default Godot icon.
- `scenes/select.tscn`: character select screen (uses `scripts/select.gd`).
- `scenes/map_select.tscn`: map select screen (uses `scripts/map_select.gd`).
- `scenes/main.tscn`: the fight (uses `scripts/main.gd`). Almost everything is built in code.
- `scripts/roster.gd`: fighter names and colors, map names, each player's choice, and keyboard bindings.
- `scripts/select.gd`: character select logic and previews.
- `scripts/map_select.gd`: map select logic (either player can scroll and confirm).
- `scripts/main.gd`: the fight. Builds maps, camera, HUD, win screen, and the fall-off check.
- `scripts/fighter.gd`: one fighter. Movement, jumping, punches, kicks, cooldowns, blocking, health, knockback.
- `scripts/figure.gd`: draws the character from shapes and animates its limbs.
- `*.uid` files: created by Godot. Don't edit them.
- `.godot/`: Godot's cache. Safe to delete; Godot rebuilds it.

## Controls

- Player 1: A/D move, W jump, J punch, N kick.
- Player 2: Left/Right move, Up jump, K punch, M kick.
- Escape: go back one screen (not during the win screen).

## Current features

- 10 fighters, all the same figure in different colors (names and colors in `roster.gd`).
- 3 maps: Classic Arena (has a pit in the middle, falling in loses), Endless Thailand (endless floor and scrolling backdrop), Elevator (small room with walls).
- Camera follows the midpoint of the two fighters on the classic and Thailand maps.
- Blocking: standing still or walking back blocks. Blocked hits do no damage.
- Punch cooldown 0.3s, kick cooldown 0.7s.
- Win screen shows the winner's name, then returns to character select after 3 seconds.

## Ideas for next time

- Replace the shape figure with sprites or animations (the figure states are in `figure.gd`).
- Real backward walk animation.
- A round system (best of 3) instead of one knockout.
- Sound effects and hit sparks.
