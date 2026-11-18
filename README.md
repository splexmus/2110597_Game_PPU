# Five Sealed Rooms

A turn-based medieval dungeon RPG in Verilog-2005. Clear the Gate, Bone Hall, Crypt, Iron Keep, and Throne Room to win. Room tiles are generated as compact stone walls, pillars, arches, windows, banners, cracked paving, and a throne-room carpet. The existing door, chest, torch, and barrel sprites came from the supplied props PNG; the knight, five enemies, and 5×7 font remain in their existing ROMs.

## Play

Use the existing serial Gamepad Pmod on `ui_in[6]` (data), `[5]` (clock), and `[4]` (latch). The existing receiver samples rising clock edges and commits a 12-bit packet on the rising latch edge. Buttons are active high; `12'hfff` means no controller. VGA uses the original Tiny VGA Pmod pin mapping and a 25.175 MHz clock.

| Button | Action |
| --- | --- |
| A | Start, attack, enter the next cleared room, or replay after victory/defeat |
| B | Guard immediately |
| Y or X | Use a potion immediately |
| Start | Restart the run from any screen |

Release a button before pressing it again. Holding a button does not repeat turns. Each action has its own button; directional buttons do nothing. Inputs during either action animation are ignored; Start can interrupt an animation to restart. If action buttons arrive together, B has priority over potion, then A.

- Start with **30 HP and 5 potions**. Enemy HP across the five rooms is **6, 9, 12, 15, 20**. Each enemy bar starts full and shrinks in proportion to its own maximum HP.
- Hit deals **4 + room index** damage (4 through 8).
- Guard counters for **3 damage** and reduces the next enemy hit to **1**.
- A potion restores up to **12 HP** and spends a turn. Full-health or empty-potion attempts spend nothing.
- Enemy damage starts at **4 through 8**, depending on the room. Heavy hits deal **8 through 16** damage. Attacks alternate between normal and double damage; the HUD announces **STRIKE / HEAVY** before your action. Each player/enemy action lasts 13 video frames (about 0.22 seconds); damage lands once at the middle impact frame.
- A lethal player attack/counter prevents retaliation. Clearing a room grants **4 HP** and increases attack when you enter the next room. Defeating the fifth enemy wins; zero HP loses.

The starter's scrolling/forced-win/forced-loss TODO was replaced by room progression and combat. B and Y are gameplay actions.

## VGA Playground

Open the repository in the [VGA Playground](https://vga-playground.com/?repo=https://github.com/splexmus/2110597_Game_PPU).

## Combat animation

Both combatants bob while idle. Attacks use forward, impact, and recovery positions; enemies face left toward the hero. The defending combatant braces and recoils, while a B-button guard holds a shield and shows a cyan barrier during the enemy strike. Guard's counterattack is shown as a shield bash. Potion use shows a green healing cross.

Enemy defensive poses are visual reactions; damage rules are unchanged. The hero also braces against unguarded hits, but only B reduces incoming damage. Damage/healing is committed once at the impact frame. Finishing hits complete their recovery before the cleared-room, victory, or defeat screen appears.

The RTL reuses the existing sprite pixels with pose overlays and coordinate offsets. Animation counters update during vertical blanking, so actors do not shift midway through a frame. No extra sprite-frame ROM or video buffer is allocated.

## Graphics and memory

The physical raster is **640×480**, with 800 clocks per line and 525 lines per frame. The game renders at **160×120**, with exact 4× nearest-neighbor scaling. Combat footer text starts at logical rows 94, 102, and 110, leaving space below the final line. START, WIN, and GAMEOVER cover the full display with black behind their text. The five rooms use blue stone, ash stone, teal crypt walls, purple keep walls, and a carpeted throne room.

There is exactly **one writable 160×6-bit scanline buffer (960 bits / 120 bytes)**. There is no full-frame pixel RAM and no second scanline buffer. The background is a tile map, rather than a stored image of the screen.

Each physical row requests the next row's logical pixels at horizontal positions **638–797**. Background and sprite ROMs have a one-clock read latency; composition writes the scanline at **639–798**. At the first write, the VGA reader has already finished with column 0 and is reading column 159. The last write finishes before the next active row. Vertical line 524 prepares row 0 of the next frame. On reset, output stays black until the first complete line has been prepared; no bulk RAM reset is needed. Game-state updates happen at the beginning of vertical blank to avoid tearing.

| File | Contents | Bits |
| --- | --- | ---: |
| `data/bg_tiles.mem` | 16 tiles × 16×16 pixels, RGB222 | 24,576 |
| `data/room_maps.mem` | Five 10×5 maps of 4-bit tile IDs | 1,000 |
| `data/sprites.mem` | Ten 16×24 sprites, opacity + RGB222 | 26,880 |
| `data/font.mem` | 128 ASCII slots × eight 5-bit rows | 5,120 |

RGB222 uses `RR GG BB` from most to least significant bits. Sprite bit 6 is opacity, so opaque black/white remain usable. ROM contents are fixed assets, not writable video buffers. `data/rom_preview.png` shows the atlas; tile 0 is at the left and sprites are hero, slime, skeleton, wraith, knight, boss, door, chest, torch, barrel.

## Generate and run checks

From this directory, with Python 3 and Icarus Verilog (`iverilog` and `vvp`) installed:

```sh
python3 -m pip install -r test/requirements.txt
python3 scripts/mem_gen.py --background-only
python3 scripts/mem_gen.py --background-only --check
iverilog -g2005 -s tt_um_vga_example -o /tmp/dungeon.vvp src/*.v
python3 test/test.py
```

Run `python3 test/test.py` from the repository root; it runs `vvp` with `src/` as its working directory. Background generation and the tests work without the original PNGs: they preserve and validate the existing sprite/font ROMs. To rebuild sprites and font too, restore `data/sprite_rom/Medieval_props_free.png` and run `python3 scripts/mem_gen.py` without `--background-only`. The game itself only needs the four committed `.mem` files. For a manual simulation, use `(cd src && vvp /tmp/dungeon.vvp)` with a suitable testbench. ROM filenames are literal `../data/*.mem` paths: [VGA Playground's GitHub loader](https://github.com/TinyTapeout/vga-playground/blob/main/src/github/loadProject.ts) resolves them relative to `src/` and does not discover filenames passed through Verilog parameters. Keep all four `.mem` files in `data/` and commit them together with the RTL. Do not change the paths to `data/*.mem`, which would make Playground request `src/data/*.mem`.

After pushing updates, reopen the Playground repository URL (or use `&ref=<commit SHA>` to select the exact revision); an already loaded editor does not fetch new ROM files when you edit a filename. `info.yaml` already lists every RTL source.

The tests use the actual serial controller receiver, cover five-room victory, defeat/restarts, health boundaries, guard, potion exhaustion, ignored direction buttons, held/short presses, and normal/heavy damage in every room. The tests verify both a winning guard strategy and an attack-only defeat, impact timing, idle motion, held guard, finishing-hit recovery, and restart during an animation. A second bench checks nine full VGA frames for timing, blanking, and unknown pixels. Python checks ROM pixels against the captured raster, text and health bars, distinct room maps, exact 4× scaling, and every pixel of the three full-screen black overlays. A third bench renders 70 animation keyframes through the same line buffer, checking poses for all five enemies and that scenery stays unchanged. Captures, contact sheets, and `animation_room1.gif` through `animation_room5.gif` are written to `test/output/`; frame-sized image storage exists only in these host-side tests.

Synthesis, placement, timing closure, FPGA programming, and physical VGA/controller testing are not covered. In particular, the starter's `1x1` Tiny Tapeout tile setting is **not a verified fit** for these ROMs; physical implementation must establish the required area and how memories are mapped.
