class_name HeroRoster
extends RefCounted


const HEROES: Array[Dictionary] = [
	{
		"name": "Kael",
		"player_scene": "res://scenes/actors/heroes/PlayerKael.tscn",
		"enemy_scene": "res://scenes/actors/heroes/EnemyKael.tscn",
		"color": Color(0.96, 0.42, 0.12),
		"stats": "5,000 HP \u00b7 180 ATK \u00b7 230 SPD",
		"skills": "Ember Fist \u00b7 Flame Bolts \u00b7 Cinder Blast \u00b7 Inferno Nova",
	},
	{
		"name": "Lorvath",
		"player_scene": "res://scenes/actors/heroes/PlayerLorvath.tscn",
		"enemy_scene": "res://scenes/actors/heroes/EnemyLorvath.tscn",
		"color": Color(0.36, 0.75, 0.4),
		"stats": "4,500 HP \u00b7 160 ATK \u00b7 190 SPD",
		"skills": "Raise Minions \u00b7 Skull Seeker \u00b7 Grave Clone \u00b7 Mass Revive",
	},
	{
		"name": "Zhalreth",
		"player_scene": "res://scenes/actors/heroes/PlayerZhalreth.tscn",
		"enemy_scene": "res://scenes/actors/heroes/EnemyZhalreth.tscn",
		"color": Color(0.45, 0.16, 0.65),
		"stats": "6,000 HP \u00b7 170 ATK \u00b7 205 SPD",
		"skills": "Shadow Dash \u00b7 Crippling Wave \u00b7 Bloodlust \u00b7 Dark Aura",
	},
	{
		"name": "Wallace",
		"player_scene": "res://scenes/actors/heroes/PlayerWallace.tscn",
		"enemy_scene": "res://scenes/actors/heroes/EnemyWallace.tscn",
		"color": Color(0.62, 0.05, 0.1),
		"stats": "5,500 HP \u00b7 170 ATK \u00b7 225 SPD",
		"skills": "Phase Dash \u00b7 Blood Whip \u00b7 Counter Stance \u00b7 Blood Vortex",
	},
	{
		"name": "Ren",
		"player_scene": "res://scenes/actors/heroes/PlayerRen.tscn",
		"enemy_scene": "res://scenes/actors/heroes/EnemyRen.tscn",
		"color": Color(0.32, 0.28, 0.72),
		"stats": "4,750 HP \u00b7 170 ATK \u00b7 240 SPD",
		"skills": "Shadow Spike \u00b7 Shade Snare \u00b7 Shadow Step \u00b7 Black Theater",
	},
	{
		"name": "Vrekor",
		"player_scene": "res://scenes/actors/heroes/PlayerVrekor.tscn",
		"enemy_scene": "res://scenes/actors/heroes/EnemyVrekor.tscn",
		"color": Color(0.9, 0.68, 0.2),
		"stats": "5,250 HP \u00b7 180 ATK \u00b7 200 SPD",
		"skills": "Bouncy Bomb \u00b7 Minefield \u00b7 Rocket Kick \u00b7 Grand Finale",
	},
	{
		"name": "Nyxara",
		"player_scene": "res://scenes/actors/heroes/PlayerNyxara.tscn",
		"enemy_scene": "res://scenes/actors/heroes/EnemyNyxara.tscn",
		"color": Color(0.5, 0.25, 0.8),
		"stats": "4,500 HP \u00b7 170 ATK \u00b7 205 SPD",
		"skills": "Void Shift \u00b7 Void Spikes \u00b7 Void Link \u00b7 Void Ball",
	},
	{
		"name": "Dorian",
		"player_scene": "res://scenes/actors/heroes/PlayerDorian.tscn",
		"enemy_scene": "res://scenes/actors/heroes/EnemyDorian.tscn",
		"color": Color(0.08, 0.55, 0.62),
		"stats": "6,200 HP \u00b7 165 ATK \u00b7 210 SPD",
		"skills": "Tidal Rush \u00b7 Crushing Wave \u00b7 Raging Tide \u00b7 Maelstrom",
	},
	{
		"name": "Gorred",
		"player_scene": "res://scenes/actors/heroes/PlayerGorred.tscn",
		"enemy_scene": "res://scenes/actors/heroes/EnemyGorred.tscn",
		"color": Color(0.8, 0.1, 0.22),
		"stats": "5,000 HP \u00b7 175 ATK \u00b7 245 SPD",
		"skills": "Blood Flurry \u00b7 Whirlwind \u00b7 Frenzy \u00b7 Blood Hunt",
	},
]

static func find_by_player_scene(scene_path: String) -> Dictionary:
	for entry in HEROES:
		if entry["player_scene"] == scene_path:
			return entry
	return {}

static func find_index_by_player_scene(scene_path: String) -> int:
	for i in HEROES.size():
		if HEROES[i]["player_scene"] == scene_path:
			return i
	return -1

static func random_picks(count: int, exclude: Array[int] = []) -> Array[Dictionary]:
	var pool: Array[int] = []
	for i in HEROES.size():
		if not exclude.has(i):
			pool.append(i)
	var picks: Array[Dictionary] = []
	while picks.size() < count and not pool.is_empty():
		var idx: int = pool[randi() % pool.size()]
		pool.erase(idx)
		picks.append(HEROES[idx])
	return picks
