extends RefCounted
# What each level asks of Nicole. The city is the same size every time (and a new
# neighbourhood is generated for every attempt at a new level); a level decides how
# much is in it, and how far away home is.
#
#  Level 1  A gentle walk home: a few cops to avoid, a few cars and skateboarders, and no
#           street people at all. Mostly about finding the way.
#  Level 2  The full city: every cop, hobos, punks and zombies in the alleys, plenty of
#           traffic, and zombies that turn up if she dawdles.
#  Level 3+ Level 2 with busier roads, more skateboarders, jumpier cops and a longer way home.
#
# Keys:
#   cops      fraction of the patrols that are walked (0..1)
#   cop_sight how quickly cops notice her (1 = normal)
#   hobos     burn-barrel hobos on or off
#   punks     fraction of the usual punk pairs under street lights
#   zombies   fraction of the usual zombie groups in the alleys
#   linger    zombies come if she stands about
#   cars      driving cars kept near her (see TrafficDirector)
#   skaters   skateboarders kept near her
#   home_min  how far the front door is from the start, at least, in world units
#   home_max  and at most (level 1 keeps the house within a walk of 40-80 seconds)

const MAX_PLAIN_LEVEL := 2

static func for_level(n: int) -> Dictionary:
    if n <= 1:
        return {"level": 1, "cops": 0.4, "cop_sight": 0.85, "hobos": false, "punks": 0.0, "zombies": 0.0,
                "linger": false, "cars": 5, "skaters": 3, "home_min": 2400.0, "home_max": 4700.0}
    if n == 2:
        return {"level": 2, "cops": 1.0, "cop_sight": 1.0, "hobos": true, "punks": 1.0, "zombies": 1.0,
                "linger": true, "cars": 18, "skaters": 4, "home_min": 4500.0, "home_max": INF}
    var extra: int = n - MAX_PLAIN_LEVEL
    return {"level": n, "cops": 1.0, "cop_sight": minf(1.0 + 0.06 * extra, 1.3), "hobos": true, "punks": 1.0, "zombies": 1.0,
            "linger": true, "cars": mini(18 + 2 * extra, 28), "skaters": mini(4 + extra, 8),
            "home_min": minf(4500.0 + 300.0 * extra, 6500.0), "home_max": INF}

# A steady 0..9 number for deciding which of a list of things stay (so the same things stay
# every time for a given tile): keep when it is below fraction * 10.
static func keeps(index: int, salt: int, fraction: float) -> bool:
    return float((index * 7 + salt * 3) % 10) < fraction * 10.0 - 0.001 or fraction >= 1.0
