extends RefCounted
# What each level asks of Nicole. The city is the same size every time (and a new
# neighbourhood is generated for every attempt at a new level); a level decides how
# much is in it, and how far away home is.
#
#  Level 1  A gentle walk home: a few cops to avoid, a few cars and skateboarders, and no
#           street people at all. Mostly about finding the way, with phone booths to call for
#           directions and squirrels to distract Stella.
#  Level 2  The full city: every cop, hobos, punks and zombies in the alleys, plenty of
#           traffic, and zombies that turn up if she dawdles. No working phone booths (nobody to
#           ask the way) and no squirrels. It looks different too: a cold teal cast, a thin fog,
#           a blackout (most windows dark, some street lights dead, more of them flickering).
#  Level 3  "Lights Out": level 2 with quieter roads (the dark is enough to deal with), more skateboarders, jumpier cops and a longer way home,
#           rain (streaks and puddles, thunder, and the rain hushes every noise a little) and the dark: the
#           world is nearly black except where a street light, a fire, a cop's torch or her own torch lights it.
#  Level 4+ Level 3 with the neighbourhood abandoned: boarded-up windows, graffiti, wrecked cars and
#           more quarantine barricades. (Wind and far-off sirens come in from level 2.)
#
# Keys:
#   cops      fraction of the patrols that are walked (0..1)
#   cop_sight how quickly cops notice her (1 = normal)
#   hobos     burn-barrel hobos on or off
#   punks     fraction of the usual punk pairs under street lights
#   zombies   fraction of the usual zombie groups in the alleys
#   linger    zombies come if she stands about
#   phones    some phone booths work (a call fills in the map around the booth); otherwise they are scenery
#   squirrels squirrels in the trees, which send Stella after them
# And the look (see LevelLook.gd; level 1 keeps the original warm night):
#   grade         colour multiplied over the whole world
#   fog           0 for none; 1 is a thin drifting mist
#   dark_windows  fraction of the lit windows that are out (a blackout)
#   dead_lamps    fraction of the street lights that are out
#   flicker_every one street light in this many flickers
#   window_light  colour of the windows that are still lit
#   nose          Stella catches the scent of home every so often: min and max seconds between (level 1 is
#                 the most generous; later levels are stingier, and once home is found she stops)
#   title         the level's name, on the card at the start
#   rain          0 for dry; 1 is steady rain (streaks, puddles, rain and thunder sounds)
#   noise_scale   how far noises carry (rain hushes them)
#   dressing      0 for tidy; 1 is boarded windows, graffiti, wrecked cars and more barricades
#   wind, sirens  the wind and the far-off sirens under the city's ambience
#   police        police cars cruising near her (PoliceCar.gd): none before level 3, then 2, 3, 4 and at most 4
#   darkness      0 for the usual night; 0.88 is Lights Out: the world is nearly black (12% bright) except
#                 where something lights it (LightMap.gd), and Nicole has a torch (F) that cops can see
#   clues         the one-time hints that explain what just happened (Clues.gd): levels 1 to 3 only, by then the rules are known
#   cars      driving cars kept near her (see TrafficDirector)
#   skaters   skateboarders kept near her
#   home_min  how far the front door is from the start, at least, in world units
#   home_max  and at most (level 1 keeps the house within a walk of 40-80 seconds)

const MAX_PLAIN_LEVEL := 2
const COLD := Color(0.80, 0.93, 0.96)  # the cold teal cast of level 2 and up
const TITLES := {3: "Lights Out", 4: "The Pound", 5: "Homeward Hound"}

static func for_level(n: int) -> Dictionary:
    if n <= 1:
        return {"level": 1, "cops": 0.4, "cop_sight": 0.85, "hobos": false, "punks": 0.0, "zombies": 0.0,
                "linger": false, "phones": true, "squirrels": true, "cars": 5, "skaters": 3, "home_min": 2400.0, "home_max": 4700.0,
                "grade": Color.WHITE, "fog": 0.0, "dark_windows": 0.0, "dead_lamps": 0.0, "flicker_every": 6, "window_light": Color("e8c56a"),
                "nose": Vector2(22.0, 38.0), "title": "Past Curfew", "rain": 0.0, "noise_scale": 1.0, "dressing": 0.0, "wind": false, "sirens": false, "clues": true, "darkness": 0.0, "police": 0}
    if n == 2:
        return {"level": 2, "cops": 1.0, "cop_sight": 1.0, "hobos": true, "punks": 1.0, "zombies": 1.0,
                "linger": true, "phones": false, "squirrels": false, "cars": 18, "skaters": 4, "home_min": 4500.0, "home_max": INF,
                "grade": COLD, "fog": 1.0, "dark_windows": 0.65, "dead_lamps": 0.3, "flicker_every": 4, "window_light": Color("d9e8b4"),
                "nose": Vector2(40.0, 65.0), "title": "Cold Nose", "rain": 0.0, "noise_scale": 1.0, "dressing": 0.0, "wind": true, "sirens": true, "clues": true, "darkness": 0.0, "police": 0}
    var extra: int = n - MAX_PLAIN_LEVEL
    return {"level": n, "cops": 1.0, "cop_sight": minf(1.0 + 0.06 * extra, 1.3), "hobos": true, "punks": 1.0, "zombies": 1.0,
            "linger": true, "phones": false, "squirrels": false, "cars": mini(8 + 2 * extra, 16), "skaters": mini(4 + extra, 8),
            "home_min": minf(4500.0 + 300.0 * extra, 6500.0), "home_max": INF,
            "grade": COLD.darkened(minf(0.05 * extra, 0.2)), "fog": minf(1.0 + 0.15 * extra, 1.6),
            "dark_windows": minf(0.65 + 0.04 * extra, 0.85), "dead_lamps": minf(0.3 + 0.04 * extra, 0.5),
            "flicker_every": 4, "window_light": Color("d9e8b4"),
            "nose": Vector2(55.0, 85.0), "title": TITLES[mini(n, 5)], "rain": minf(1.0 + 0.1 * maxi(extra - 1, 0), 1.3), "noise_scale": 0.75,
            "dressing": 1.0 if n >= 4 else 0.0, "wind": true, "sirens": true, "clues": n <= 3, "darkness": 0.88, "police": mini(2 + extra - 1, 4)}

# A steady 0..9 number for deciding which of a list of things stay (so the same things stay
# every time for a given tile): keep when it is below fraction * 10.
static func keeps(index: int, salt: int, fraction: float) -> bool:
    return float((index * 7 + salt * 3) % 10) < fraction * 10.0 - 0.001 or fraction >= 1.0
