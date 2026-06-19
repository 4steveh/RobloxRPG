--!strict
-- CREATURE CATALOG (Template C) — Bayou / Appalachia / Alaska hunting rosters. Representative, not
-- exhaustive: floor + signature/milestone + apex + ambiance + the §5 rares, enough to exercise every
-- schema branch (rarity, the Reward XOR, re-skins, packs, ambiance, milestone flags). Cash ranges are
-- ILLUSTRATIVE — computed from economy's band (Income(T)/ETPH × RarityMultiplier), not authored here;
-- the authoritative payout is economy's Payout() (Step 6).

local Enums = require("../types/Enums")
local Schema = require("../types/Schema")
local Ids = require("../types/Ids")

type Creature = Schema.Creature
type Reward = Schema.Reward
type RareFields = Schema.RareFields

local D = Ids.Destination
local B = Enums.Behavior
local Co = Enums.Coop
local Ra = Enums.Rarity

local function isRareOrAbove(rarity: Enums.Rarity): boolean
	return Enums.RarityRank[rarity] >= Enums.RARE_AND_ABOVE_RANK
end

type CreatureInput = {
	id: string,
	destinationId: Ids.DestinationId,
	name: string,
	tier: number,
	rarity: Enums.Rarity,
	behavior: Enums.Behavior,
	health: number,
	damageToPlayer: number,
	speed: number,
	minWeaponTierToKill: number,
	minArmorTierToSurvive: number,
	coop: Enums.Coop,
	spawnLocation: string,
	spawnZones: { string }?, -- structured Step-3 zone ids (target species; Step 4)
	escapeWindowSeconds: number?, -- TimeToFlee (escape-bounded KillWindow, Step 4)
	attackIntervalSeconds: number?, -- survival-bounded DPS interval (Step 4)
	conditions: Schema.SpawnConditions?,
	ambianceOnly: boolean?,
	packSize: number?,
	reskinOf: string?,
	isMilestoneTarget: boolean?,
	cash: { min: number, max: number }?, -- required for non-ambiance Common/Uncommon
	typicalWeightKg: { min: number, max: number }?, -- cosmetic per-catch weight range (harvest card)
	rare: RareFields?, -- required for Rare-and-above (its tradeable/displayable drive the mint)
}

-- Builder bakes the Reward XOR boundary in: ambiance→nil, Rare+→artifact (from rare fields), else→cash.
local function creature(i: CreatureInput): Creature
	local reward: Reward? = nil
	if i.ambianceOnly then
		assert(i.cash == nil and i.rare == nil, i.id .. ": ambiance grants nothing (no cash, no rare)")
	elseif isRareOrAbove(i.rarity) then
		local r = assert(i.rare, i.id .. ": Rare-and-above must carry Template-E rare fields")
		reward = { kind = "artifact", artifact = { tradeable = r.tradeable, displayableInLodge = r.displayableInLodge } }
	else
		local c = assert(i.cash, i.id .. ": Common/Uncommon must carry a cash range")
		reward = { kind = "cash", cash = c }
	end
	return {
		id = i.id,
		destinationId = i.destinationId,
		name = i.name,
		tier = i.tier,
		rarity = i.rarity,
		ambianceOnly = i.ambianceOnly or false,
		behavior = i.behavior,
		packSize = i.packSize,
		health = i.health,
		damageToPlayer = i.damageToPlayer,
		speed = i.speed,
		minWeaponTierToKill = i.minWeaponTierToKill,
		minArmorTierToSurvive = i.minArmorTierToSurvive,
		coop = i.coop,
		spawnZones = i.spawnZones,
		escapeWindowSeconds = i.escapeWindowSeconds,
		attackIntervalSeconds = i.attackIntervalSeconds,
		reward = reward,
		reskinOf = i.reskinOf,
		spawn = { location = i.spawnLocation, conditions = i.conditions },
		rare = i.rare,
		isMilestoneTarget = i.isMilestoneTarget,
		typicalWeightKg = i.typicalWeightKg,
	}
end

local function rareFields(spawnRate: number, moment: string): RareFields
	return {
		spawnRate = spawnRate,
		tradeable = true,
		displayableInLodge = true,
		reReleasePolicy = "NEVER",
		intendedContentMoment = moment,
	}
end

local rows: { Creature } = {
	-- ───────────────────────── BAYOU (Tier 1) ─────────────────────────
	creature({
		id = "bayou_great_egret",
		destinationId = D.Bayou,
		name = "Great Egret",
		tier = 1,
		rarity = Ra.Common,
		behavior = B.passive,
		ambianceOnly = true,
		health = 0,
		damageToPlayer = 0,
		speed = 45,
		minWeaponTierToKill = 0,
		minArmorTierToSurvive = 0,
		coop = Co.soloTopGear,
		spawnLocation = "channel edges and shallows",
		conditions = { time = "daylight" },
	}),
	creature({
		id = "bayou_painted_turtle",
		destinationId = D.Bayou,
		name = "Painted Turtle",
		tier = 1,
		rarity = Ra.Common,
		behavior = B.passive,
		ambianceOnly = true,
		health = 0,
		damageToPlayer = 0,
		speed = 20,
		minWeaponTierToKill = 0,
		minArmorTierToSurvive = 0,
		coop = Co.soloTopGear,
		spawnLocation = "logs and reed beds",
		conditions = { time = "daylight" },
	}),
	creature({
		id = "bayou_songbird",
		destinationId = D.Bayou,
		name = "Songbird",
		tier = 1,
		rarity = Ra.Common,
		behavior = B.passive,
		ambianceOnly = true,
		health = 0,
		damageToPlayer = 0,
		speed = 50,
		minWeaponTierToKill = 0,
		minArmorTierToSurvive = 0,
		coop = Co.soloTopGear,
		spawnLocation = "reed beds and cypress",
		conditions = { time = "daylight" },
	}),
	creature({
		id = "bayou_wood_duck",
		typicalWeightKg = { min = 0.5, max = 1.0 },
		destinationId = D.Bayou,
		name = "Wood Duck (flock)",
		tier = 1,
		rarity = Ra.Common,
		behavior = B.flees,
		packSize = 6,
		health = 15,
		damageToPlayer = 0,
		speed = 50,
		minWeaponTierToKill = 1,
		minArmorTierToSurvive = 0,
		coop = Co.soloTopGear,
		cash = { min = 10, max = 15 },
		spawnLocation = "reed-edge of the Sunny Levee",
		spawnZones = { "sunny_levee" },
		escapeWindowSeconds = 4, -- TimeToFlee after flush (LOC §3); ceil(15/18)=1 shot ≤ 4/1.5
	}),
	creature({
		id = "bayou_swamp_rabbit",
		typicalWeightKg = { min = 1.5, max = 2.5 },
		destinationId = D.Bayou,
		name = "Swamp Rabbit",
		tier = 1,
		rarity = Ra.Common,
		behavior = B.flees,
		health = 22,
		damageToPlayer = 0,
		speed = 55,
		minWeaponTierToKill = 1,
		minArmorTierToSurvive = 0,
		coop = Co.soloTopGear,
		cash = { min = 10, max = 15 },
		spawnLocation = "Sunny Levee dry ground",
		spawnZones = { "sunny_levee", "reed_edges" },
		escapeWindowSeconds = 5, -- TimeToFlee on the break (LOC §3); ceil(22/18)=2 shots ≤ 5/1.5
	}),
	creature({
		id = "bayou_nutria",
		typicalWeightKg = { min = 4, max = 9 },
		destinationId = D.Bayou,
		name = "Nutria",
		tier = 1,
		rarity = Ra.Common,
		behavior = B.flees, -- iconic Louisiana swamp rodent; slow, the easiest floor target
		health = 30, -- ceil(30/18)=2 shots on the starter (floor band)
		damageToPlayer = 0, -- non-lethal
		speed = 35,
		minWeaponTierToKill = 1,
		minArmorTierToSurvive = 0,
		coop = Co.soloTopGear,
		cash = { min = 10, max = 15 },
		spawnLocation = "water's-edge reeds, daylight",
		spawnZones = { "reed_edges" },
		escapeWindowSeconds = 6, -- the slowest fleer (LOC §3)
	}),
	creature({
		id = "bayou_american_alligator",
		typicalWeightKg = { min = 140, max = 360 },
		destinationId = D.Bayou,
		name = "American Alligator",
		tier = 1,
		rarity = Ra.Uncommon,
		behavior = B.aggressive, -- telegraphed lunge, but clamped non-lethal at Tier 1
		health = 48,
		damageToPlayer = 0, -- raw 15, clamped non-lethal (combat §4) — represented as 0 threat at MVL
		speed = 40,
		minWeaponTierToKill = 1,
		minArmorTierToSurvive = 0,
		coop = Co.soloTopGear,
		cash = { min = 18, max = 24 },
		spawnLocation = "channel banks and Cottonmouth Slough",
		spawnZones = { "channel_banks", "cottonmouth_slough" },
		-- survival-bounded IN FORM but Bayou-wide non-lethal → KillWindow effectively unbounded; the
		-- encounter is a 3-shot placement check under a lunge telegraph (LOC §3). attackInterval = stagger anim.
		attackIntervalSeconds = 3,
		isMilestoneTarget = true, -- Bayou hunting conquest milestone
	}),
	creature({
		id = "bayou_leucistic_wood_duck",
		typicalWeightKg = { min = 0.5, max = 1.0 },
		destinationId = D.Bayou,
		name = "Leucistic Wood Duck (the Pale Drake)",
		tier = 1,
		rarity = Ra.Rare,
		behavior = B.flees,
		reskinOf = "bayou_wood_duck",
		health = 15,
		damageToPlayer = 0,
		speed = 50,
		minWeaponTierToKill = 1,
		minArmorTierToSurvive = 0,
		coop = Co.soloTopGear,
		conditions = { time = "dawn" },
		rare = rareFields(900, "one ghost-white duck in a flock of brown — the first rarity moment"),
		spawnLocation = "Sunny Levee reed-edge dawn flocks",
		spawnZones = { "sunny_levee" },
		escapeWindowSeconds = 4, -- shares the wood-duck escape profile (a find, not a harder fight, LOC §5)
	}),
	creature({
		id = "bayou_white_alligator",
		typicalWeightKg = { min = 140, max = 360 },
		destinationId = D.Bayou,
		name = "White Alligator (the Ghost Gator)",
		tier = 1,
		rarity = Ra.Legendary,
		behavior = B.aggressive,
		reskinOf = "bayou_american_alligator",
		health = 48,
		damageToPlayer = 0,
		speed = 40,
		minWeaponTierToKill = 1,
		minArmorTierToSurvive = 0,
		coop = Co.soloTopGear,
		conditions = { time = "dawn or dusk", weather = "fog" },
		rare = rareFields(2500, "the pale gator surfacing silently out of the fog — the Bayou's signature clip"),
		spawnLocation = "Cottonmouth Slough",
		spawnZones = { "cottonmouth_slough" },
		attackIntervalSeconds = 3, -- shares the gator's 3-shot, non-lethal profile (a find, not a wall, LOC §5)
	}),

	-- ───────────────────────── APPALACHIA (Tier 2) ─────────────────────────
	creature({
		id = "appalachia_gray_squirrel",
		destinationId = D.Appalachia,
		name = "Gray Squirrel",
		tier = 2,
		rarity = Ra.Common,
		behavior = B.flees,
		ambianceOnly = true,
		health = 0,
		damageToPlayer = 0,
		speed = 60,
		minWeaponTierToKill = 0,
		minArmorTierToSurvive = 0,
		coop = Co.soloTopGear,
		spawnLocation = "woodlots",
	}),
	creature({
		id = "appalachia_eastern_cottontail",
		typicalWeightKg = { min = 0.9, max = 1.8 },
		destinationId = D.Appalachia,
		name = "Eastern Cottontail",
		tier = 2,
		rarity = Ra.Common,
		behavior = B.flees,
		reskinOf = "bayou_swamp_rabbit", -- "bigger & meaner" re-skin; balanced at its displayed tier
		health = 30,
		damageToPlayer = 0,
		speed = 70,
		minWeaponTierToKill = 1,
		minArmorTierToSurvive = 0, -- non-threat fleer: armor is n/a (LOC_02 §3)
		coop = Co.soloTopGear,
		cash = { min = 34, max = 42 },
		spawnLocation = "old fields",
		spawnZones = { "old_field" }, -- Appalachia shell zone (Task 1.3)
		escapeWindowSeconds = 4, -- TimeToFlee, warier re-skin of the Bayou rabbit (LOC_02 §3)
	}),
	creature({
		id = "appalachia_whitetail_deer",
		typicalWeightKg = { min = 45, max = 100 },
		destinationId = D.Appalachia,
		name = "Whitetail Deer",
		tier = 2,
		rarity = Ra.Common,
		behavior = B.flees,
		health = 50,
		damageToPlayer = 0,
		speed = 78,
		minWeaponTierToKill = 1,
		minArmorTierToSurvive = 0, -- non-threat fleer: armor is n/a (LOC_02 §3)
		coop = Co.soloTopGear,
		cash = { min = 34, max = 42 },
		spawnLocation = "the Old Field and woodlot edges",
		spawnZones = { "old_field" }, -- Appalachia shell zone (Task 1.3)
		escapeWindowSeconds = 4.5, -- TimeToFlee (LOC_02 §3, worked H50 floor): ceil(50/18)=3 shots ≤ 4.5/1.5
		conditions = { time = "dawn/dusk" },
	}),
	creature({
		id = "appalachia_coyote",
		typicalWeightKg = { min = 9, max = 20 },
		destinationId = D.Appalachia,
		name = "Coyote (pack)",
		tier = 2,
		rarity = Ra.Common,
		behavior = B.pack,
		packSize = 4,
		health = 30,
		damageToPlayer = 22,
		speed = 72,
		minWeaponTierToKill = 2,
		minArmorTierToSurvive = 3, -- solo as a pack; or T2 + a duo (the co-op tutorial)
		coop = Co.duo,
		cash = { min = 34, max = 42 },
		spawnLocation = "draws and creek-bottoms",
		spawnZones = { "creek_bottoms" }, -- Appalachia shell zone (Task 1.3)
		attackIntervalSeconds = 2.0, -- survival-bounded DPS interval (LOC_02 §3)
		conditions = { time = "dusk/night" },
	}),
	creature({
		id = "appalachia_wild_boar",
		typicalWeightKg = { min = 50, max = 140 },
		destinationId = D.Appalachia,
		name = "Wild Boar",
		tier = 2,
		rarity = Ra.Uncommon,
		behavior = B.aggressive,
		health = 88,
		damageToPlayer = 40,
		speed = 55,
		minWeaponTierToKill = 2,
		minArmorTierToSurvive = 2,
		coop = Co.soloTopGear,
		cash = { min = 55, max = 66 },
		spawnLocation = "brushy mid-slopes and oak ridges",
		spawnZones = { "oak_ridges" }, -- Appalachia shell zone (Task 1.3)
		attackIntervalSeconds = 3.0, -- survival-bounded DPS interval (LOC_02 §3)
		isMilestoneTarget = true, -- Appalachia hunting conquest milestone
	}),
	creature({
		id = "appalachia_mountain_lion",
		typicalWeightKg = { min = 40, max = 80 },
		destinationId = D.Appalachia,
		name = "Mountain Lion (Catamount)",
		tier = 2,
		rarity = Ra.Uncommon, -- routine apex wall; NOT an artifact mint (only Rare+ mint)
		behavior = B.aggressive,
		health = 100,
		damageToPlayer = 76,
		speed = 88,
		minWeaponTierToKill = 3, -- solo only at T3; co-op at T2
		minArmorTierToSurvive = 3,
		coop = Co.party,
		cash = { min = 55, max = 66 },
		spawnLocation = "Lookout Ridge",
		spawnZones = { "lookout_ridge" }, -- Appalachia shell zone (Task 1.3)
		attackIntervalSeconds = 2.7, -- survival-bounded DPS interval (LOC_02 §3)
	}),
	creature({
		id = "appalachia_piebald_whitetail",
		typicalWeightKg = { min = 45, max = 100 },
		destinationId = D.Appalachia,
		name = "Piebald Whitetail",
		tier = 2,
		rarity = Ra.Rare,
		behavior = B.flees,
		reskinOf = "appalachia_whitetail_deer",
		health = 50,
		damageToPlayer = 0,
		speed = 78,
		minWeaponTierToKill = 1,
		minArmorTierToSurvive = 0, -- non-threat fleer: armor is n/a (LOC_02 §3)
		coop = Co.soloTopGear,
		conditions = { time = "dawn/dusk", weather = "clear" },
		rare = rareFields(250, "the first 'wait — that one's different' double-take; the entry-level trade chip"),
		spawnLocation = "the Old Field",
		spawnZones = { "old_field" }, -- Appalachia shell zone (Task 1.3)
		escapeWindowSeconds = 4.5, -- shares the whitetail escape profile (a find, not a harder fight, LOC_02 §5)
	}),
	creature({
		id = "appalachia_ghost_buck",
		typicalWeightKg = { min = 45, max = 100 },
		destinationId = D.Appalachia,
		name = "Ghost Buck (Albino Whitetail)",
		tier = 2,
		rarity = Ra.Legendary,
		behavior = B.flees,
		reskinOf = "appalachia_whitetail_deer",
		health = 50,
		damageToPlayer = 0,
		speed = 78,
		minWeaponTierToKill = 1,
		minArmorTierToSurvive = 0, -- non-threat fleer: armor is n/a (LOC_02 §3)
		coop = Co.soloTopGear,
		conditions = { time = "dawn", weather = "clear" },
		rare = rareFields(1500, "white stag in gold dawn fog, the clean-kill flourish in slow-mo"),
		spawnLocation = "the Old Field",
		spawnZones = { "old_field" }, -- Appalachia shell zone (Task 1.3)
		escapeWindowSeconds = 4.5, -- shares the whitetail escape profile (a find, not a harder fight, LOC_02 §5)
	}),
	creature({
		id = "appalachia_black_catamount",
		typicalWeightKg = { min = 40, max = 80 },
		destinationId = D.Appalachia,
		name = "Black Catamount (Melanistic Mountain Lion)",
		tier = 2,
		rarity = Ra.Mythic, -- the region's 'white whale'; a rare that is ALSO a wall (apex profile)
		behavior = B.aggressive,
		reskinOf = "appalachia_mountain_lion",
		health = 100,
		damageToPlayer = 76,
		speed = 88,
		minWeaponTierToKill = 3,
		minArmorTierToSurvive = 3,
		coop = Co.party,
		conditions = { time = "night", weather = "heavy fog" },
		rare = rareFields(6000, "green eyeshine in the fog, then the cat in the beam — the rarest early clip"),
		spawnLocation = "Lookout Ridge",
		spawnZones = { "lookout_ridge" }, -- Appalachia shell zone (Task 1.3)
		attackIntervalSeconds = 2.7, -- shares the catamount's profile (a find, not a harder wall, LOC_02 §5)
	}),

	-- ───────────────────────── ALASKA (Tier 4) ─────────────────────────
	creature({
		id = "alaska_arctic_hare",
		typicalWeightKg = { min = 3, max = 5 },
		destinationId = D.Alaska,
		name = "Arctic Hare",
		tier = 4,
		rarity = Ra.Common,
		behavior = B.flees,
		reskinOf = "bayou_swamp_rabbit", -- the literal 'rabbits in Alaska, but bigger' example (01)
		health = 45,
		damageToPlayer = 0,
		speed = 80,
		minWeaponTierToKill = 3,
		minArmorTierToSurvive = 0,
		coop = Co.soloTopGear,
		cash = { min = 160, max = 190 },
		spawnLocation = "tundra and snowfields",
		spawnZones = { "tundra_flats" }, -- Alaska shell zone (Task 2.4, LOC_04 §3)
		escapeWindowSeconds = 3.0, -- TimeToFlee (LOC_04 §3)
	}),
	creature({
		id = "alaska_sitka_deer",
		typicalWeightKg = { min = 30, max = 55 },
		destinationId = D.Alaska,
		name = "Sitka Black-tailed Deer",
		tier = 4,
		rarity = Ra.Common,
		behavior = B.flees,
		health = 70,
		damageToPlayer = 0,
		speed = 76,
		minWeaponTierToKill = 3,
		minArmorTierToSurvive = 0,
		coop = Co.soloTopGear,
		cash = { min = 160, max = 190 },
		spawnLocation = "spruce edges and lower slopes",
		spawnZones = { "spruce_riverbottom" }, -- Alaska shell zone (Task 2.4, LOC_04 §3)
		escapeWindowSeconds = 3.5, -- TimeToFlee (LOC_04 §3)
	}),
	creature({
		id = "alaska_caribou",
		typicalWeightKg = { min = 80, max = 180 },
		destinationId = D.Alaska,
		name = "Caribou",
		tier = 4,
		rarity = Ra.Uncommon,
		behavior = B.flees,
		packSize = 9,
		health = 100,
		damageToPlayer = 0,
		speed = 82,
		minWeaponTierToKill = 4,
		minArmorTierToSurvive = 0,
		coop = Co.soloTopGear,
		cash = { min = 260, max = 300 },
		spawnLocation = "the Tundra Flats",
		spawnZones = { "tundra_flats" }, -- Alaska shell zone (Task 2.4, LOC_04 §3)
		escapeWindowSeconds = 4.0, -- TimeToFlee (LOC_04 §3)
		-- Milestone reachability FALLBACK (RD-A), not the canonical milestone — see Bull Moose.
	}),
	creature({
		id = "alaska_bull_moose",
		typicalWeightKg = { min = 350, max = 600 },
		destinationId = D.Alaska,
		name = "Bull Moose",
		tier = 4,
		rarity = Ra.Uncommon,
		behavior = B.aggressive,
		health = 100,
		damageToPlayer = 45,
		speed = 58,
		minWeaponTierToKill = 4,
		minArmorTierToSurvive = 4,
		coop = Co.soloTopGear,
		cash = { min = 260, max = 300 },
		spawnLocation = "spruce edges and river-bottoms of the Tundra Flats",
		spawnZones = { "spruce_riverbottom", "tundra_flats" }, -- Alaska shell zones (Task 2.4, LOC_04 §3)
		attackIntervalSeconds = 3.0, -- survival-bounded DPS interval (LOC_04 §3)
		isMilestoneTarget = true, -- Alaska hunting conquest milestone (T4-soloable, RD-A)
	}),
	creature({
		id = "alaska_grizzly_bear",
		typicalWeightKg = { min = 180, max = 450 },
		destinationId = D.Alaska,
		name = "Grizzly Bear",
		tier = 4,
		rarity = Ra.Uncommon, -- routine apex; co-op-only at MVL (no T5 gear); NOT an artifact mint
		behavior = B.aggressive,
		health = 100,
		damageToPlayer = 85,
		speed = 80,
		minWeaponTierToKill = 5, -- does not exist at MVL → co-op-only
		minArmorTierToSurvive = 5,
		coop = Co.party,
		cash = { min = 260, max = 300 },
		spawnLocation = "Salmon Falls",
		spawnZones = { "salmon_falls" }, -- Alaska shell zone (Task 2.4, LOC_04 §3)
		attackIntervalSeconds = 2.5, -- survival-bounded DPS interval (LOC_04 §3)
	}),
	creature({
		id = "alaska_cross_fox",
		typicalWeightKg = { min = 4, max = 7 },
		destinationId = D.Alaska,
		name = "Cross Fox",
		tier = 4,
		rarity = Ra.Rare,
		behavior = B.flees,
		health = 40,
		damageToPlayer = 0,
		speed = 70,
		minWeaponTierToKill = 3,
		minArmorTierToSurvive = 0,
		coop = Co.soloTopGear,
		conditions = { weather = "clear cold", season = "winter coat" },
		rare = rareFields(300, "the silver-black fox against the snow — this tier's first trade chip"),
		spawnLocation = "tundra edges",
		spawnZones = { "tundra_flats" }, -- Alaska shell zone (Task 2.4, LOC_04 §3)
		escapeWindowSeconds = 3.5, -- TimeToFlee (LOC_04 §3)
	}),
	creature({
		id = "alaska_spirit_moose",
		typicalWeightKg = { min = 350, max = 600 },
		destinationId = D.Alaska,
		name = "Spirit Moose (Piebald/Albino Bull Moose)",
		tier = 4,
		rarity = Ra.Legendary,
		behavior = B.flees, -- shares the moose profile but is a find, takeable solo
		reskinOf = "alaska_bull_moose",
		health = 100,
		damageToPlayer = 45,
		speed = 58,
		minWeaponTierToKill = 4,
		minArmorTierToSurvive = 4,
		coop = Co.soloTopGear,
		conditions = { time = "dawn/dusk", season = "autumn rut" },
		rare = rareFields(1500, "the ghost-white bull stepping out of dark spruce at first light"),
		spawnLocation = "Tundra Flats spruce edges",
		spawnZones = { "spruce_riverbottom" }, -- Alaska shell zone (Task 2.4, LOC_04 §3)
		escapeWindowSeconds = 4.0, -- TimeToFlee; spirit_moose is flees, NOT aggressive (LOC_04 §3)
	}),
	creature({
		id = "alaska_glacier_grizzly",
		typicalWeightKg = { min = 180, max = 450 },
		destinationId = D.Alaska,
		name = "Glacier Grizzly (blonde color-phase)",
		tier = 4,
		rarity = Ra.Legendary, -- a rare that is ALSO a wall (shares the co-op-only apex profile)
		behavior = B.aggressive,
		reskinOf = "alaska_grizzly_bear",
		health = 100,
		damageToPlayer = 85,
		speed = 80,
		minWeaponTierToKill = 5,
		minArmorTierToSurvive = 5,
		coop = Co.party,
		-- Step 13: season cased "Salmon Run" to match the salmon-run fish + the LiveOps Salmon Run event's
		-- imposed world.season (a single world.season satisfies only one casing). LOC_04 §9: the run "draws
		-- grizzlies to Salmon Falls … the co-op apex becomes live" — so the seasonal event genuinely revives it.
		conditions = { time = "low light", season = "Salmon Run", event = "Salmon Run" },
		rare = rareFields(2500, "the pale-gold giant rearing at the falls in the run — the marquee co-op kill"),
		spawnLocation = "Salmon Falls",
		spawnZones = { "salmon_falls" }, -- Alaska shell zone (Task 2.4, LOC_04 §3)
		attackIntervalSeconds = 2.5, -- shares the grizzly apex profile (LOC_04 §3)
	}),
}

local catalog: { [string]: Creature } = {}
for _, c in rows do
	if catalog[c.id] ~= nil then
		error("Creatures: duplicate id '" .. c.id .. "'")
	end
	catalog[c.id] = c
end

return catalog
