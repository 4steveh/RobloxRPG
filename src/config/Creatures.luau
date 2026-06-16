--!strict
-- CREATURE CATALOG (Template C) — Bayou / Appalachia / Alaska hunting rosters. Representative, not
-- exhaustive: floor + signature/milestone + apex + ambiance + the §5 rares, enough to exercise every
-- schema branch (rarity, the Reward XOR, re-skins, packs, ambiance, milestone flags). Cash ranges are
-- ILLUSTRATIVE — computed from economy's band (Income(T)/ETPH × RarityMultiplier), not authored here;
-- the authoritative payout is economy's Payout() (Step 6).

local Enums = require("@src/types/Enums")
local Schema = require("@src/types/Schema")
local Ids = require("@src/types/Ids")

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
	conditions: Schema.SpawnConditions?,
	ambianceOnly: boolean?,
	packSize: number?,
	reskinOf: string?,
	isMilestoneTarget: boolean?,
	cash: { min: number, max: number }?, -- required for non-ambiance Common/Uncommon
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
		reward = reward,
		reskinOf = i.reskinOf,
		spawn = { location = i.spawnLocation, conditions = i.conditions },
		rare = i.rare,
		isMilestoneTarget = i.isMilestoneTarget,
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
		id = "bayou_wood_duck",
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
	}),
	creature({
		id = "bayou_swamp_rabbit",
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
	}),
	creature({
		id = "bayou_american_alligator",
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
		isMilestoneTarget = true, -- Bayou hunting conquest milestone
	}),
	creature({
		id = "bayou_leucistic_wood_duck",
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
	}),
	creature({
		id = "bayou_white_alligator",
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
		minArmorTierToSurvive = 1,
		coop = Co.soloTopGear,
		cash = { min = 34, max = 42 },
		spawnLocation = "old fields",
	}),
	creature({
		id = "appalachia_whitetail_deer",
		destinationId = D.Appalachia,
		name = "Whitetail Deer",
		tier = 2,
		rarity = Ra.Common,
		behavior = B.flees,
		health = 50,
		damageToPlayer = 0,
		speed = 78,
		minWeaponTierToKill = 1,
		minArmorTierToSurvive = 1,
		coop = Co.soloTopGear,
		cash = { min = 34, max = 42 },
		spawnLocation = "the Old Field and woodlot edges",
		conditions = { time = "dawn/dusk" },
	}),
	creature({
		id = "appalachia_coyote",
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
		conditions = { time = "dusk/night" },
	}),
	creature({
		id = "appalachia_wild_boar",
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
		isMilestoneTarget = true, -- Appalachia hunting conquest milestone
	}),
	creature({
		id = "appalachia_mountain_lion",
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
	}),
	creature({
		id = "appalachia_piebald_whitetail",
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
		minArmorTierToSurvive = 1,
		coop = Co.soloTopGear,
		conditions = { time = "dawn/dusk", weather = "clear" },
		rare = rareFields(250, "the first 'wait — that one's different' double-take; the entry-level trade chip"),
		spawnLocation = "the Old Field",
	}),
	creature({
		id = "appalachia_ghost_buck",
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
		minArmorTierToSurvive = 1,
		coop = Co.soloTopGear,
		conditions = { time = "dawn", weather = "clear" },
		rare = rareFields(1500, "white stag in gold dawn fog, the clean-kill flourish in slow-mo"),
		spawnLocation = "the Old Field",
	}),
	creature({
		id = "appalachia_black_catamount",
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
	}),

	-- ───────────────────────── ALASKA (Tier 4) ─────────────────────────
	creature({
		id = "alaska_arctic_hare",
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
	}),
	creature({
		id = "alaska_sitka_deer",
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
	}),
	creature({
		id = "alaska_caribou",
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
		-- Milestone reachability FALLBACK (RD-A), not the canonical milestone — see Bull Moose.
	}),
	creature({
		id = "alaska_bull_moose",
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
		isMilestoneTarget = true, -- Alaska hunting conquest milestone (T4-soloable, RD-A)
	}),
	creature({
		id = "alaska_grizzly_bear",
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
	}),
	creature({
		id = "alaska_cross_fox",
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
	}),
	creature({
		id = "alaska_spirit_moose",
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
	}),
	creature({
		id = "alaska_glacier_grizzly",
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
		conditions = { time = "low light", season = "salmon run", event = "Salmon Run" },
		rare = rareFields(2500, "the pale-gold giant rearing at the falls in the run — the marquee co-op kill"),
		spawnLocation = "Salmon Falls",
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
