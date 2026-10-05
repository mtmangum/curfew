extends RefCounted
# Cause plus one useful response; capture is separate from the shared life bar.
static func for_failure(title: String, source: String, detail: Dictionary = {}) -> String:
    if title == "CAUGHT":
        return "A cop caught you. Next time, break his line of sight and keep moving: sneaking is too slow once he is chasing."
    match source:
        "car":
            return "A car hit %s and emptied your life. Watch the road; wait for a gap before crossing." % ("Stella" if detail.get("stella", false) else "Nicole")
        "skater":
            return "A skateboarder hit you when your life was low. Give moving traffic room; pizza restores life."
        "punk":
            return "A punk hit you when your life was low. Give street people room; pizza restores life."
        "zombie":
            return "A zombie's attack emptied your life. Keep moving past them; pizza restores life."
        "hobo":
            return "A hobo held you until your life ran out. Walk away before he grabs you; pizza restores life."
        _:
            return "Your life ran out. Avoid street hits and look for pizza to restore life."
