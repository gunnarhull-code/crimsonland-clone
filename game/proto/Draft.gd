extends RefCounted
## The upgrade draft (spec 13.15). Pick number N is made before level N.
##   unlock pick  = 1 + round(8 * w)
##   draw weight  = 0.1^w * (1 + w * ((N - 1) / 9) * 4)
## Chained upgrades (a `requires` entry) are only offered once the prerequisite
## is owned. Cards in one offer are all different; owned upgrades can still be
## offered, since stacking them is the core idea.
## Constants are the spec's tunables.

const Up := preload("res://sandbox/SbUpgrades.gd")

const WEIGHT_BASE := 0.1
const LATE_BOOST := 4.0
const UNLOCK_SPAN := 8.0
const RUN_PICKS := 10


static func unlock_pick(id: String) -> int:
	return 1 + roundi(UNLOCK_SPAN * Up.weight(id))


static func draw_weight(id: String, pick_no: int) -> float:
	var w := Up.weight(id)
	return pow(WEIGHT_BASE, w) * (1.0 + w * (float(pick_no - 1) / (RUN_PICKS - 1)) * LATE_BOOST)


## Upgrades that can be offered at this pick, given what is owned.
static func pool(owned: Dictionary, pick_no: int) -> Array:
	var out: Array = []
	for row in Up.all():
		var id: String = row["id"]
		if unlock_pick(id) > pick_no:
			continue
		var req: String = row.get("requires", "")
		if req != "" and owned.get(req, 0) <= 0:
			continue
		out.append(id)
	return out


## `count` different upgrade ids, drawn by weight without replacement.
static func offer(owned: Dictionary, pick_no: int, count: int = 3) -> Array:
	var candidates := pool(owned, pick_no)
	var picked: Array = []
	while picked.size() < count and not candidates.is_empty():
		var total := 0.0
		for id in candidates:
			total += draw_weight(id, pick_no)
		var roll := randf() * total
		var chosen: String = candidates[candidates.size() - 1]
		for id in candidates:
			roll -= draw_weight(id, pick_no)
			if roll <= 0.0:
				chosen = id
				break
		picked.append(chosen)
		candidates.erase(chosen)
	return picked


## Chance (0..1) that a given upgrade shows up on at least one card at this pick,
## approximated as count * its share of the pool's weight. For the cheat menu.
static func offer_chance(id: String, owned: Dictionary, pick_no: int, count: int = 3) -> float:
	var total := 0.0
	var mine := 0.0
	for p in pool(owned, pick_no):
		var w := draw_weight(p, pick_no)
		total += w
		if p == id:
			mine = w
	return 0.0 if total <= 0.0 or mine <= 0.0 else minf(1.0, count * mine / total)
