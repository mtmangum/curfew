extends RefCounted
# The level as plain data: one 2560x1440 district of blocks, avenues and lanes,
# repeated over a grid of tiles. LevelBuilder.gd turns this into the world; edit the
# numbers here to rearrange the streets, hazards and patrols.

# The world is a grid of these districts (TILE_MIN..TILE_MAX); odd columns are mirrored
# left-to-right so the city doesn't repeat exactly. The start is in the bottom-left
# tile of the play area and the house in the top-right one.
const TILE := Vector2(2560, 1440)
# The playable district is tiles (0..2, 0..1); the start is at the bottom-left of
# tile (0,1) and the house in tile (2,0). A column to the west and a row to the
# south are quiet outskirts (buildings, cars, lamps and bins, but no cops or
# cats), so the start has plenty of ground behind it. Tile coordinates can be
# negative; tile (0,0) sits at the world origin.
const TILE_MIN := Vector2i(-1, 0)
const TILE_MAX := Vector2i(2, 2)
const BASE_BUILDINGS := [
    Rect2(140, 120, 300, 170), Rect2(560, 100, 180, 220), Rect2(860, 180, 200, 140),
    Rect2(1420, 120, 300, 170), Rect2(1840, 100, 180, 220), Rect2(2140, 180, 200, 140),
    Rect2(160, 430, 280, 150), Rect2(560, 480, 240, 160), Rect2(920, 400, 240, 200),
    Rect2(1440, 430, 280, 150), Rect2(1840, 480, 240, 160), Rect2(2200, 400, 240, 200),
    Rect2(200, 800, 260, 170), Rect2(600, 830, 200, 150), Rect2(900, 780, 300, 200),
    Rect2(1300, 810, 240, 160), Rect2(1700, 790, 260, 190), Rect2(2040, 820, 180, 150),
    Rect2(2330, 780, 150, 200),
    Rect2(120, 1140, 320, 150), Rect2(520, 1160, 200, 160), Rect2(820, 1130, 280, 170),
    Rect2(1200, 1150, 240, 150), Rect2(1540, 1130, 300, 170), Rect2(1940, 1160, 200, 150),
    Rect2(2260, 1130, 240, 170),
    Rect2(2380, 0, 180, 110),
    # Infill for the big voids: shallow shops along the top strip (which make the
    # boulevards where tiles meet narrower), and buildings in the two plazas
    # either side of the north-south patrol street at x 1230-1250.
    Rect2(150, 14, 330, 38), Rect2(620, 14, 420, 38), Rect2(1340, 14, 380, 38), Rect2(1800, 14, 440, 38),
    Rect2(1105, 160, 80, 130), Rect2(1285, 170, 90, 130), Rect2(1295, 450, 100, 110),
]
# Each is a patrol route (the first point is where the cop starts).
const BASE_ROUTES := [
        [Vector2(80, 360), Vector2(500, 360)],
        [Vector2(900, 350), Vector2(1230, 350), Vector2(1230, 150)],
        [Vector2(1300, 360), Vector2(2100, 360), Vector2(2480, 360), Vector2(2480, 150)],
        [Vector2(80, 705), Vector2(1100, 705)],
        [Vector2(1300, 705), Vector2(2480, 705)],
        [Vector2(480, 720), Vector2(480, 1060), Vector2(1050, 1060)],
        [Vector2(1300, 1060), Vector2(2000, 1060), Vector2(2520, 1060)],
        [Vector2(1250, 420), Vector2(1250, 1000)],
        [Vector2(600, 1390), Vector2(1050, 1390)],
        [Vector2(1200, 1385), Vector2(2000, 1385), Vector2(2480, 1385)],
]
const BASE_PROPS := [Vector2(470, 500), Vector2(640, 400), Vector2(900, 385), Vector2(1120, 735), Vector2(1560, 400),
            Vector2(2050, 740), Vector2(1000, 1090), Vector2(1680, 1030), Vector2(2320, 1030),
            Vector2(350, 740), Vector2(760, 1355), Vector2(1900, 1350), Vector2(2400, 330)]
const BASE_VENTS := [[Vector2(330, 1375), 0.0], [Vector2(500, 385), 2.5], [Vector2(860, 520), 1.0], [Vector2(1080, 345), 4.0],
            [Vector2(700, 705), 3.0], [Vector2(1010, 1060), 1.5], [Vector2(1250, 880), 5.0], [Vector2(1600, 360), 2.0],
            [Vector2(1820, 705), 0.5], [Vector2(2200, 1060), 3.5], [Vector2(2000, 360), 6.0],
            [Vector2(1450, 1380), 4.5], [Vector2(2480, 500), 1.0]]
const BASE_FIRES := [Vector2(700, 370), Vector2(1700, 740), Vector2(850, 1030), Vector2(1900, 395)]
const BASE_CATS := [Vector2(520, 520), Vector2(980, 380), Vector2(1150, 700), Vector2(1700, 380), Vector2(600, 1080),
            Vector2(1900, 1070), Vector2(2300, 700),
            Vector2(300, 340), Vector2(780, 360), Vector2(1250, 560), Vector2(1450, 700), Vector2(2000, 380),
            Vector2(1300, 1090), Vector2(700, 1380), Vector2(2200, 1380)]
