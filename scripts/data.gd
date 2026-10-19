extends Node
## Alle Spielwerte an einem Ort: Völker, Zeitalter, Einheiten, Gebäude, Konter.

const TILE := 16
const MAP_W := 96
const MAP_H := 96
const CARRY := 10.0
const POP_MAX := 200
const START_RES := {"food": 200, "wood": 200, "gold": 100, "stone": 200}

const RES := ["food", "wood", "gold", "stone"]
const RES_NAMES := {"food": "Nahrung", "wood": "Holz", "gold": "Gold", "stone": "Stein"}
const RES_SHORT := {"food": "N", "wood": "H", "gold": "G", "stone": "S"}
const RES_COLORS := {"food": Color("e05050"), "wood": Color("a0703a"), "gold": Color("f0c840"), "stone": Color("a8a8b0")}
# Ressourcen-Typ -> Art des Vorkommens auf der Karte
const RES_KIND := {"food": "berry", "wood": "tree", "gold": "gold", "stone": "stone"}

const AGES := [
	{"name": "Dunkle Zeit", "cost": {}, "time": 0.0},
	{"name": "Feudalzeit", "cost": {"food": 500}, "time": 35.0},
	{"name": "Burgzeit", "cost": {"food": 800, "gold": 200}, "time": 50.0},
	{"name": "Imperialzeit", "cost": {"food": 1000, "gold": 800}, "time": 65.0},
	{"name": "Moderne", "cost": {"food": 1500, "gold": 1200, "stone": 300}, "time": 80.0},
]

# Je Zeitalter über dem Freischalt-Zeitalter steigt eine Einheit eine Stufe auf.
const TIER_PREFIX := ["", "Veteran-", "Elite-", "Meister-", "Hightech-"]

# range 0 = Nahkampf. Werte in Kacheln bzw. Sekunden.
const UNITS := {
	"villager": {"hp": 25.0, "atk": 3.0, "armor": 0.0, "range": 0.0, "cd": 2.0, "speed": 2.2, "sight": 5.0, "cost": {"food": 50}, "time": 10.0, "age": 0},
	"spear": {"hp": 45.0, "atk": 4.0, "armor": 1.0, "range": 0.0, "cd": 2.0, "speed": 2.3, "sight": 6.0, "cost": {"food": 35, "wood": 25}, "time": 14.0, "age": 0},
	"archer": {"hp": 30.0, "atk": 4.0, "armor": 0.0, "range": 4.5, "cd": 2.0, "speed": 2.4, "sight": 7.0, "cost": {"wood": 25, "gold": 45}, "time": 16.0, "age": 1},
	"cavalry": {"hp": 100.0, "atk": 7.0, "armor": 2.0, "range": 0.0, "cd": 1.9, "speed": 3.5, "sight": 7.0, "cost": {"food": 60, "gold": 75}, "time": 22.0, "age": 2},
	"siege": {"hp": 140.0, "atk": 25.0, "armor": 4.0, "range": 5.5, "cd": 5.0, "speed": 1.3, "sight": 7.0, "cost": {"wood": 160, "gold": 135}, "time": 30.0, "age": 3},
}

# Schere-Stein-Papier: Speer > Reiter > Schützen > Speer. Belagerung > Gebäude.
const BONUS := {
	"spear": {"cavalry": 3.0},
	"cavalry": {"archer": 2.5, "siege": 2.0},
	"archer": {"spear": 2.0, "villager": 1.5},
	"siege": {"*": 0.5},
}
const VS_BUILDING := {"villager": 0.5, "spear": 0.8, "archer": 0.25, "cavalry": 0.6, "siege": 4.0, "tower": 0.5}

const COUNTER_TEXT := {
	"villager": "Sammelt Ressourcen, baut und repariert Gebäude.",
	"spear": "Stark gegen Reiter. Schwach gegen Schützen.",
	"archer": "Stark gegen Speerträger. Schwach gegen Reiter.",
	"cavalry": "Stark gegen Schützen und Belagerung. Schwach gegen Speerträger.",
	"siege": "Zerstört Gebäude und Mauern. Schwach gegen Reiter.",
}

const FACTIONS := {
	"mammals": {
		"name": "Säugetiere",
		"desc": "Zähe Pelzträger aus den Tälern.\n+20% Nahrung sammeln\nReiter +20% Lebenspunkte",
		"units": {"villager": "Feldmaus", "spear": "Dachs-Speerträger", "archer": "Fuchs-Schütze", "cavalry": "Wolfsreiter", "siege": "Bären-Rammbock"},
		"bnames": {"town_center": "Großer Bau"},
		"shot": Color("e0d0a0"),
	},
	"aliens": {
		"name": "Aliens",
		"desc": "Gestrandete Sternenreisende.\nEinheiten +15% Tempo\nSchützen +1 Reichweite",
		"units": {"villager": "Arbeitsdrohne", "spear": "Plasmalanzer", "archer": "Strahlenschütze", "cavalry": "Schwebereiter", "siege": "Dreibein-Koloss"},
		"bnames": {"town_center": "Landekapsel"},
		"shot": Color("70f0ff"),
	},
	"plants": {
		"name": "Lebende Pflanzen",
		"desc": "Ein erwachter Urwald.\n+25% Holz sammeln, Gebäude heilen sich\nSpeerträger 25% billiger",
		"units": {"villager": "Keimling", "spear": "Dornenwächter", "archer": "Sporenschleuderer", "cavalry": "Käferreiter", "siege": "Wurzel-Ramme"},
		"bnames": {"town_center": "Mutterbaum"},
		"shot": Color("b8f060"),
	},
}

const BUILDINGS := {
	"town_center": {"name": "Dorfzentrum", "size": 3, "hp": 2400.0, "cost": {"wood": 275, "stone": 100}, "time": 90.0, "age": 0, "pop": 10, "drop": ["food", "wood", "gold", "stone"], "trains": ["villager"], "attack": {"atk": 5.0, "range": 6.0, "cd": 2.0}},
	"house": {"name": "Haus", "size": 2, "hp": 550.0, "cost": {"wood": 25}, "time": 15.0, "age": 0, "pop": 5},
	"mill": {"name": "Mühle", "size": 2, "hp": 600.0, "cost": {"wood": 100}, "time": 20.0, "age": 0, "drop": ["food"]},
	"camp": {"name": "Lager", "size": 2, "hp": 600.0, "cost": {"wood": 100}, "time": 20.0, "age": 0, "drop": ["wood", "gold", "stone"]},
	"farm": {"name": "Farm", "size": 2, "hp": 300.0, "cost": {"wood": 60}, "time": 10.0, "age": 0, "walkable": true, "food": 300.0},
	"barracks": {"name": "Kaserne", "size": 3, "hp": 1200.0, "cost": {"wood": 175}, "time": 35.0, "age": 0, "trains": ["spear"]},
	"range": {"name": "Schießstand", "size": 3, "hp": 1200.0, "cost": {"wood": 175}, "time": 35.0, "age": 1, "trains": ["archer"]},
	"stable": {"name": "Stall", "size": 3, "hp": 1200.0, "cost": {"wood": 175}, "time": 35.0, "age": 2, "trains": ["cavalry"]},
	"workshop": {"name": "Werkstatt", "size": 3, "hp": 1500.0, "cost": {"wood": 200, "gold": 50}, "time": 40.0, "age": 3, "trains": ["siege"]},
	"palisade": {"name": "Palisade", "size": 1, "hp": 250.0, "cost": {"wood": 3}, "time": 4.0, "age": 0, "wall": true},
	"wall": {"name": "Steinmauer", "size": 1, "hp": 1800.0, "cost": {"stone": 5}, "time": 6.0, "age": 1, "wall": true},
	"gate": {"name": "Tor", "size": 1, "hp": 1500.0, "cost": {"stone": 20}, "time": 10.0, "age": 1, "wall": true, "gate": true},
	"tower": {"name": "Wachturm", "size": 1, "hp": 1000.0, "cost": {"wood": 25, "stone": 100}, "time": 25.0, "age": 1, "attack": {"atk": 6.0, "range": 7.0, "cd": 2.0}},
}
const BUILD_ORDER := ["house", "farm", "mill", "camp", "barracks", "range", "stable", "workshop", "palisade", "wall", "gate", "tower", "town_center"]

const MAP_SIZES := [
	{"name": "Klein", "size": 96},
	{"name": "Mittel", "size": 128},
	{"name": "Groß", "size": 160},
]
const DIFFICULTY := [
	{"name": "Leicht", "think": 1.7, "gather": 0.8, "attack": 520.0},
	{"name": "Normal", "think": 1.0, "gather": 1.0, "attack": 330.0},
	{"name": "Schwer", "think": 0.6, "gather": 1.25, "attack": 240.0},
]

# Forschung: "at" = Gebäude, in dem geforscht wird; "req" = vorherige Technologie
const TECHS := {
	"loom": {"name": "Webstuhl", "desc": "Arbeiter +15 LP und +1 Rüstung", "cost": {"gold": 50}, "time": 20.0, "age": 0, "at": "town_center"},
	"wheelbarrow": {"name": "Schubkarre", "desc": "Arbeiter +10% Tempo, tragen 5 mehr", "cost": {"food": 175, "wood": 50}, "time": 30.0, "age": 1, "at": "town_center"},
	"handcart": {"name": "Handkarren", "desc": "Arbeiter +10% Tempo, tragen 5 mehr", "cost": {"food": 300, "wood": 200}, "time": 40.0, "age": 2, "at": "town_center", "req": "wheelbarrow"},
	"masonry": {"name": "Mauerwerk", "desc": "Alle Gebäude und Mauern +20% LP", "cost": {"wood": 175, "stone": 150}, "time": 40.0, "age": 2, "at": "town_center"},
	"tower_arrows": {"name": "Turmgeschütze", "desc": "Türme und Dorfzentrum +3 Angriff", "cost": {"food": 200, "wood": 150}, "time": 35.0, "age": 2, "at": "town_center"},
	"gunpowder": {"name": "Schießpulver", "desc": "Alle Militäreinheiten +20% Angriff", "cost": {"food": 400, "gold": 400}, "time": 60.0, "age": 4, "at": "town_center"},
	"double_axe": {"name": "Doppelaxt", "desc": "Holz sammeln +20%", "cost": {"food": 100, "wood": 50}, "time": 20.0, "age": 1, "at": "camp"},
	"bow_saw": {"name": "Bügelsäge", "desc": "Holz sammeln +20%", "cost": {"food": 150, "wood": 100}, "time": 30.0, "age": 2, "at": "camp", "req": "double_axe"},
	"gold_mining": {"name": "Goldbergbau", "desc": "Gold sammeln +20%", "cost": {"food": 100, "wood": 75}, "time": 25.0, "age": 1, "at": "camp"},
	"stone_mining": {"name": "Steinbruch", "desc": "Stein sammeln +20%", "cost": {"food": 100, "wood": 75}, "time": 25.0, "age": 1, "at": "camp"},
	"horse_collar": {"name": "Schweres Joch", "desc": "Farmen +25% Ertrag, neue Farmen +150 Nahrung", "cost": {"food": 75, "wood": 75}, "time": 20.0, "age": 1, "at": "mill"},
	"crop_rotation": {"name": "Fruchtwechsel", "desc": "Farmen +25% Ertrag, neue Farmen +150 Nahrung", "cost": {"food": 250, "wood": 200}, "time": 40.0, "age": 3, "at": "mill", "req": "horse_collar"},
	"forging": {"name": "Schmiedekunst", "desc": "Nahkampfeinheiten +2 Angriff", "cost": {"food": 150}, "time": 30.0, "age": 1, "at": "barracks"},
	"scale_armor": {"name": "Schuppenpanzer", "desc": "Alle Militäreinheiten +1 Rüstung", "cost": {"food": 150, "gold": 100}, "time": 35.0, "age": 2, "at": "barracks"},
	"fletching": {"name": "Befiederung", "desc": "Schützen +1 Angriff und +1 Reichweite", "cost": {"food": 100, "wood": 50}, "time": 30.0, "age": 1, "at": "range"},
	"barding": {"name": "Rossharnisch", "desc": "Reiter +25% LP", "cost": {"food": 150, "gold": 100}, "time": 35.0, "age": 2, "at": "stable"},
	"ballistics": {"name": "Ballistik", "desc": "Belagerung +25% Angriff und +1 Reichweite", "cost": {"wood": 300, "gold": 175}, "time": 45.0, "age": 3, "at": "workshop"},
}

## Konfiguration bzw. Spielstand, der nach einem Szenen-Neustart geladen wird.
var pending: Dictionary = {}

const GATHER := {"berry": 0.6, "farm": 0.5, "tree": 0.55, "gold": 0.5, "stone": 0.48}


func unit_tier(kind: String, age: int) -> int:
	if kind == "villager":
		return 0
	return clampi(age - int(UNITS[kind]["age"]), 0, 4)


func unit_name(kind: String, faction: String, age: int) -> String:
	return TIER_PREFIX[unit_tier(kind, age)] + str(FACTIONS[faction]["units"][kind])


func unit_stats(kind: String, faction: String, age: int, techs: Dictionary = {}) -> Dictionary:
	var s: Dictionary = UNITS[kind].duplicate(true)
	var tier := unit_tier(kind, age)
	s["hp"] = float(s["hp"]) * (1.0 + 0.3 * tier)
	s["atk"] = float(s["atk"]) * (1.0 + 0.25 * tier)
	s["armor"] = float(s["armor"]) + floorf(tier * 0.5)
	match faction:
		"mammals":
			if kind == "cavalry":
				s["hp"] = float(s["hp"]) * 1.2
		"aliens":
			s["speed"] = float(s["speed"]) * 1.15
			if kind == "archer":
				s["range"] = float(s["range"]) + 1.0
	var military := kind != "villager"
	if kind == "villager":
		if techs.has("loom"):
			s["hp"] = float(s["hp"]) + 15.0
			s["armor"] = float(s["armor"]) + 1.0
		for t in ["wheelbarrow", "handcart"]:
			if techs.has(t):
				s["speed"] = float(s["speed"]) * 1.1
	if techs.has("forging") and military and float(UNITS[kind]["range"]) == 0.0:
		s["atk"] = float(s["atk"]) + 2.0
	if techs.has("scale_armor") and military:
		s["armor"] = float(s["armor"]) + 1.0
	if techs.has("fletching") and kind == "archer":
		s["atk"] = float(s["atk"]) + 1.0
		s["range"] = float(s["range"]) + 1.0
	if techs.has("barding") and kind == "cavalry":
		s["hp"] = float(s["hp"]) * 1.25
	if techs.has("ballistics") and kind == "siege":
		s["atk"] = float(s["atk"]) * 1.25
		s["range"] = float(s["range"]) + 1.0
	if techs.has("gunpowder") and military:
		s["atk"] = float(s["atk"]) * 1.2
	s["tier"] = tier
	return s


func carry_cap(techs: Dictionary) -> float:
	var c := CARRY
	for t in ["wheelbarrow", "handcart"]:
		if techs.has(t):
			c += 5.0
	return c


func farm_food(techs: Dictionary) -> float:
	var f: float = BUILDINGS["farm"]["food"]
	for t in ["horse_collar", "crop_rotation"]:
		if techs.has(t):
			f += 150.0
	return f


func building_hp(kind: String, techs: Dictionary) -> float:
	var h: float = BUILDINGS[kind]["hp"]
	return h * 1.2 if techs.has("masonry") else h


func unit_cost(kind: String, faction: String) -> Dictionary:
	var c: Dictionary = UNITS[kind]["cost"].duplicate()
	if faction == "plants" and kind == "spear":
		for k in c:
			c[k] = int(round(float(c[k]) * 0.75))
	return c


func building_cost(kind: String, _faction: String) -> Dictionary:
	return BUILDINGS[kind]["cost"].duplicate()


func building_name(kind: String, faction: String) -> String:
	var over: Dictionary = FACTIONS[faction]["bnames"]
	if over.has(kind):
		return str(over[kind])
	return str(BUILDINGS[kind]["name"])


func gather_rate(faction: String, kind: String, techs: Dictionary = {}) -> float:
	var r: float = GATHER[kind]
	var boosts := {"tree": ["double_axe", "bow_saw"], "gold": ["gold_mining"], "stone": ["stone_mining"], "farm": ["horse_collar", "crop_rotation"]}
	for t in boosts.get(kind, []):
		if techs.has(t):
			r *= 1.25 if kind == "farm" else 1.2
	if faction == "mammals" and (kind == "berry" or kind == "farm"):
		r *= 1.2
	if faction == "plants" and kind == "tree":
		r *= 1.25
	return r


func cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in RES:
		if cost.has(k):
			parts.append("%d%s" % [int(cost[k]), RES_SHORT[k]])
	return " ".join(parts)
