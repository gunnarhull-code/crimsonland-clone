extends Node
## Level runner. Normal levels follow an authored timeline (timeline.csv): at
## each time a themed formation starts (SbSpawner.gd), and formations overlap.
## The level ends when every event has started, every sequence has finished
## and every monster is dead. Boss levels (5 and 10, from levels.csv) spawn the
## boss at once and its adds are its waves (spec 13.11): killing it early
## cancels unspawned adds. Levels with no timeline fall back to the old
## count-per-wave rows in levels.csv.

const PATH := "res://sandbox/levels.csv"
const Formations := preload("res://sandbox/SbFormations.gd")
const WAVE_DELAY := 2.0
const HP_MARKS := [0.75, 0.5, 0.25]

signal finished(cleared: bool)

var sb
var running := false
var level := 1
var status := "Idle"
var history: Array[String] = []

var _rows := {}
var _row := {}
var _t := 0.0
var _wave := 0
var _wave_timer := -1.0
var _boss = null
var _add_t := 0.0
var _marks_done := 0
var _kills0 := 0
var _dealt0 := 0.0
var _taken0 := 0.0
var _events: Array = []
var _ev_i := 0


func _ready() -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("SbWaves: could not open %s" % PATH)
		return
	var header := f.get_csv_line()
	while f.get_position() < f.get_length():
		var line := f.get_csv_line()
		if line.size() < 2 or line[0] == "":
			continue
		var row := {}
		for i in header.size():
			row[header[i]] = line[i] if i < line.size() else ""
		_rows[int(row["level"])] = row
	f.close()


func start(lvl: int) -> void:
	sb.clear_enemies()          # also calls stop() and cancels the spawner
	level = lvl
	sb.level = lvl
	_row = _rows.get(lvl, {})
	if _row.is_empty():
		status = "No data for level %d" % lvl
		return
	if sb.heal_on_level_start:
		sb.heal()
	sb.species_hits.clear()     # Adaptive Round resets each level
	sb.adaptive_extra = 0.0
	_t = 0.0
	_wave = 0
	_wave_timer = -1.0
	_boss = null
	_add_t = 0.0
	_marks_done = 0
	_ev_i = 0
	_events = [] if _row["boss"] != "" else Formations.timeline(lvl)
	_kills0 = sb.kills
	_dealt0 = sb.total_damage
	_taken0 = sb.player.damage_taken
	running = true
	if _row["boss"] != "":
		_spawn_boss()
	elif _events.is_empty():
		_spawn_wave()


func stop() -> void:
	sb.spawner.cancel()
	if running:
		running = false
		status = "Stopped"


## Cheat: jump the timeline forward so upcoming events start now.
func skip_time(seconds: float) -> void:
	if running:
		_t += seconds


func player_down() -> void:
	if not running:
		return
	running = false
	var left: int = sb.enemies.get_child_count()
	_finish("Level %d FAILED: you died after %.1fs with %d enemies left (%d kills)" % [level, _t, left, sb.kills - _kills0])
	finished.emit(false)


func _finish(text: String) -> void:
	status = text
	history.push_front(text)
	if history.size() > 6:
		history.pop_back()


# ------------------------------------------------------------- legacy waves --

func _spawn_wave() -> void:
	_wave += 1
	for sp in ["rat", "spider", "alien", "tick", "scrapper"]:
		var n := int(_row[sp + "s"])
		if n > 0:
			sb.spawn_enemies(sp, "base", n)


# -------------------------------------------------------------------- bosses --

func _spawn_boss() -> void:
	var made: Array = sb.spawn_enemies(_row["boss"], "boss", 1)
	if made.is_empty():
		return
	_boss = made[0]
	var mult := float(_row["boss_hp_mult"])
	_boss.max_hp *= mult
	_boss.hp = _boss.max_hp
	_boss.armor = maxf(_boss.armor, float(_row["armor"]))
	_add_t = float(_row["add_interval_sec"])


func _spawn_adds() -> void:
	var made: Array = sb.spawn_enemies(_row["add_species"], "base", int(_row["add_batch"]),
		_boss.global_position if is_instance_valid(_boss) else null)
	for e in made:
		e.armor = maxf(e.armor, float(_row["armor"]))


# ---------------------------------------------------------------------- tick --

func _physics_process(delta: float) -> void:
	if not running:
		return
	_t += delta
	var alive: int = sb.enemies.get_child_count()
	if _row["boss"] != "":
		_boss_tick(delta, alive)
		return
	if not _events.is_empty():
		while _ev_i < _events.size() and _t >= _events[_ev_i]["t"]:
			sb.spawner.begin(_events[_ev_i]["formation"], _events[_ev_i]["count"])
			_ev_i += 1
		status = "Level %d  %.0fs  sequences %d/%d (%d active)  enemies %d" % [level, _t, _ev_i, _events.size(), sb.spawner.active_count(), alive]
		if _ev_i >= _events.size() and sb.spawner.is_idle() and alive == 0:
			_complete()
		return
	status = "Level %d  wave %d/%d  enemies %d  %.0fs" % [level, _wave, int(_row["waves"]), alive, _t]
	if alive == 0:
		if _wave >= int(_row["waves"]):
			_complete()
		elif _wave_timer < 0.0:
			_wave_timer = WAVE_DELAY
	if _wave_timer >= 0.0:
		_wave_timer -= delta
		if _wave_timer < 0.0 and alive == 0:
			_spawn_wave()
			_wave_timer = -1.0


func _boss_tick(delta: float, alive: int) -> void:
	var boss_alive: bool = is_instance_valid(_boss) and not _boss.dead
	if boss_alive:
		if _row["add_trigger"] == "timer":
			_add_t -= delta
			if _add_t <= 0.0:
				_add_t = float(_row["add_interval_sec"])
				_spawn_adds()
		elif _marks_done < HP_MARKS.size() and _boss.hp / _boss.max_hp <= HP_MARKS[_marks_done]:
			_marks_done += 1
			_spawn_adds()
		status = "Level %d  %s boss  HP %d%%  enemies %d  %.0fs" % [level, _row["boss"], roundi(100.0 * _boss.hp / _boss.max_hp), alive, _t]
	elif alive == 0:
		_complete()
	else:
		status = "Level %d  boss dead, clearing %d  %.0fs" % [level, alive, _t]


func _complete() -> void:
	running = false
	_finish("Level %d CLEARED in %.1fs  (kills %d, damage dealt %d, damage taken %d)" % [
		level, _t, sb.kills - _kills0, int(sb.total_damage - _dealt0), int(sb.player.damage_taken - _taken0)])
	finished.emit(true)


## Cheat: wipe the level and count it as cleared.
func force_clear() -> void:
	if not running:
		return
	sb.clear_enemies()
	running = false
	_finish("Level %d skipped (cheat)" % level)
	finished.emit(true)
