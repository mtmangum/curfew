Leash Walk — minimal Godot prototype

Overview
- Top-down prototype: control Nicole (player) while the dog (Stella) can be attracted to lures by clicking.
- Simple leash constraint enforces a maximum leash length; dog pulls when it chases lures.

Requirements
- Godot Engine 4.x (4.0+ recommended)

Run
1. Open the `leash-walk` folder in Godot.
2. Run the `res://scenes/Main.tscn` scene.

Controls
- Move: arrow keys or WASD (`ui_up`, `ui_down`, `ui_left`, `ui_right`).
- Click: spawn a lure at the mouse position; the dog will run to it.

NPCs
- `squirrel`: medium attraction, hops around briefly before despawning.
- `pigeon`: low attraction, short-lived.
- `pizza`: high attraction, longer-lived.

An automatic spawner adds NPCs near the camera over time.

Next steps
- Replace placeholder drawing with sprites from `sidescroller`.
- Implement proper leash physics (forces), dog personality states, and spawnable NPCs (squirrels/pigeons/pizza).
