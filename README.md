# pong_verilog

Classic pong, written in verilog, for desktop. 
Simulated using verilator, and C++ frontend handles keyboard, window, ui, rendering, audio using SDL3.

## Features

- 1-player mode — play against the Verilog AI.
- 2-player local mode — play against another person on the same keyboard.
- CPU vs CPU mode — watch the AI play.
- Four AI difficulty levels — Easy, Medium, Hard, and Insane.
- Smash mechanic with a charge meter.
- First-to-10 scoring.
## Controls

### Menus

| Key | Action |
|---|---|
| `W` / `S` or `↑` / `↓` | Move through menu options |
| `Enter` or `Space` | Select an option |
| `Esc` | Go back; from the title screen, quit |

### During a match

| Player | Move up | Move down | Smash |
|---|---|---|---|
| Player 1 (left) | `W` | `S` | `D` or `Space` |
| Player 2 (right) | `↑` | `↓` | `←` |

In 1-player mode, the arrow keys can also move Player 1; `←` triggers Player 1's smash.

| Key | Action |
|---|---|
| `P` | Pause / resume |
| `R` | Restart the match |
| `M` | Mute / unmute audio |
| `Esc` | Pause or return to the previous screen |

## How it works

| File | Purpose |
|---|---|
| `top.v` | Top-level Verilog module and signal integration |
| `ball_logic.v` | Ball movement and collision/gameplay logic |
| `paddle_logic.v` | Paddle movement logic |
| `ai_paddle.v` | AI paddle behavior and difficulty |
| `score_counter.v`, `score_display.v` | Scoring and score display logic |
| `smash_ctrl.v`, `meter_draw.v` | Smash mechanic and meter display |
| `netdraw.v`, `paddle_draw.v` | Game-field drawing logic |
| `beeper.v`, `music.v`, `music_rom.v` | Sound effects and music signals/data |
| `sim_main.cpp` | Verilator/SDL3 frontend and simulation loop |
| `ui.h` | Menus, HUD, and text rendering |
| `makefile` | Build and run targets |

## Build from source

I will write instructions for this later

## License

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**. See [LICENSE](LICENSE) for the full text.

