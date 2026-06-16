--!strict
-- FISH CATALOG (Template D) — Bayou / Appalachia / Alaska + a Deep Sea fixture entry. Representative.
-- All fish grant a reward (no ambiance fish). Cash ranges are ILLUSTRATIVE (computed from economy's
-- band), not authored. The Reward XOR boundary is baked into the builder (Rare+ → artifact, no Cash).

local Enums = require("@src/types/Enums")
local Schema = require("@src/types/Schema")
local Ids = require("@src/types/Ids")

type Fish = Schema.Fish
type Reward = Schema.Reward
type RareFields = Schema.RareFields

local D = Ids.Destination
local W = Enums.WaterType
local Ra = Enums.Rarity

local function isRareOrAbove(rarity: Enums.Rarity): boolean
	return Enums.RarityRank[rarity] >= Enums.RARE_AND_ABOVE_RANK
end

type FishInput = {
	id: string,
	destinationId: Ids.DestinationId,
	name: string,
	tier: number,
	rarity: Enums.Rarity,
	typicalWeightKg: { min: number, max: number },
	recordWeightKg: number,
	fightDifficulty: number,
	minRodTier: number,
	minReelTier: number,
	waterType: Enums.WaterType,
	baitRequired: string?,
	spawnZones: { string }?, -- structured Step-3 water zones (Step 5 prerequisite)
	conditions: Schema.SpawnConditions?,
	isMilestoneTarget: boolean?,
	cash: { min: number, max: number }?,
	rare: RareFields?,
}

local function fish(i: FishInput): Fish
	local reward: Reward
	if isRareOrAbove(i.rarity) then
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
		typicalWeightKg = i.typicalWeightKg,
		recordWeightKg = i.recordWeightKg,
		fightDifficulty = i.fightDifficulty,
		minRodTier = i.minRodTier,
		minReelTier = i.minReelTier,
		baitRequired = i.baitRequired,
		waterType = i.waterType,
		spawnZones = i.spawnZones,
		reward = reward,
		spawn = { conditions = i.conditions },
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

local rows: { Fish } = {
	-- ───────────────────────── BAYOU (Tier 1) ─────────────────────────
	fish({
		id = "bayou_bluegill",
		destinationId = D.Bayou,
		name = "Bluegill",
		tier = 1,
		rarity = Ra.Common,
		typicalWeightKg = { min = 0.2, max = 0.5 },
		recordWeightKg = 0.8,
		fightDifficulty = 20,
		minRodTier = 1,
		minReelTier = 1,
		waterType = W.pond,
		baitRequired = "worms",
		spawnZones = { "channel_banks" }, -- shore-accessible panfish water
		cash = { min = 14, max = 20 },
		conditions = { time = "all day" },
	}),
	fish({
		id = "bayou_bullhead_catfish",
		destinationId = D.Bayou,
		name = "Bullhead Catfish",
		tier = 1,
		rarity = Ra.Common,
		typicalWeightKg = { min = 0.5, max = 2 },
		recordWeightKg = 3,
		fightDifficulty = 28,
		minRodTier = 1,
		minReelTier = 1,
		waterType = W.river,
		baitRequired = "cut bait",
		spawnZones = { "channel_banks" },
		cash = { min = 14, max = 20 },
	}),
	fish({
		id = "bayou_channel_catfish",
		destinationId = D.Bayou,
		name = "Channel Catfish",
		tier = 1,
		rarity = Ra.Uncommon,
		typicalWeightKg = { min = 2, max = 6 },
		recordWeightKg = 12,
		fightDifficulty = 32,
		minRodTier = 1,
		minReelTier = 1,
		waterType = W.river,
		baitRequired = "cut bait",
		spawnZones = { "channel_banks", "catfish_hole" },
		cash = { min = 24, max = 30 },
		conditions = { time = "dusk" },
	}),
	fish({
		id = "bayou_blue_catfish",
		destinationId = D.Bayou,
		name = "Blue Catfish",
		tier = 1,
		rarity = Ra.Uncommon,
		typicalWeightKg = { min = 4, max = 9 },
		recordWeightKg = 25,
		fightDifficulty = 34,
		minRodTier = 1,
		minReelTier = 1,
		waterType = W.river,
		baitRequired = "cut bait",
		spawnZones = { "catfish_hole", "channel_banks" }, -- the deep oxbow is the signature catch's home
		cash = { min = 24, max = 30 },
		conditions = { time = "dawn/dusk" },
		isMilestoneTarget = true, -- Bayou fishing conquest milestone
	}),
	fish({
		id = "bayou_albino_blue_catfish",
		destinationId = D.Bayou,
		name = "Albino Blue Catfish (the Pale Monster)",
		tier = 1,
		rarity = Ra.Legendary,
		typicalWeightKg = { min = 4, max = 9 },
		recordWeightKg = 25,
		fightDifficulty = 34,
		minRodTier = 1,
		minReelTier = 1,
		waterType = W.river,
		baitRequired = "cut bait",
		spawnZones = { "catfish_hole" }, -- rare/legendary catfish condition site
		conditions = { time = "night" },
		rare = rareFields(3500, "a huge ghost-pale catfish breaching at night"),
	}),
	fish({
		id = "bayou_leviathan",
		destinationId = D.Bayou,
		name = "The Bayou Leviathan (Old Cat of the Channel)",
		tier = 1,
		rarity = Ra.Mythic, -- the Bayou's 'white whale' (one Mythic per Destination)
		typicalWeightKg = { min = 20, max = 40 },
		recordWeightKg = 60,
		fightDifficulty = 34,
		minRodTier = 1,
		minReelTier = 1,
		waterType = W.river,
		baitRequired = "live sucker",
		spawnZones = { "catfish_hole" }, -- the deepest channel; storm-night condition site
		conditions = { time = "night", weather = "storm" },
		rare = rareFields(7500, "the screen-filling leviathan rising in a thunderstorm"),
	}),

	-- ───────────────────────── APPALACHIA (Tier 2) ─────────────────────────
	fish({
		id = "appalachia_bluegill",
		destinationId = D.Appalachia,
		name = "Bluegill / Panfish",
		tier = 2,
		rarity = Ra.Common,
		typicalWeightKg = { min = 0.2, max = 0.6 },
		recordWeightKg = 1,
		fightDifficulty = 30,
		minRodTier = 1,
		minReelTier = 1,
		waterType = W.pond,
		baitRequired = "worm",
		cash = { min = 40, max = 50 },
	}),
	fish({
		id = "appalachia_brook_trout",
		destinationId = D.Appalachia,
		name = "Brook Trout",
		tier = 2,
		rarity = Ra.Common,
		typicalWeightKg = { min = 0.3, max = 0.9 },
		recordWeightKg = 1.5,
		fightDifficulty = 38,
		minRodTier = 1,
		minReelTier = 1,
		waterType = W.river,
		baitRequired = "fly", -- basic required-item gate (never a tier input)
		cash = { min = 40, max = 50 },
		conditions = { time = "dawn", weather = "overcast" },
	}),
	fish({
		id = "appalachia_smallmouth_bass",
		destinationId = D.Appalachia,
		name = "Smallmouth Bass",
		tier = 2,
		rarity = Ra.Common,
		typicalWeightKg = { min = 0.5, max = 1.8 },
		recordWeightKg = 3,
		fightDifficulty = 50,
		minRodTier = 2,
		minReelTier = 2,
		waterType = W.river,
		cash = { min = 40, max = 50 },
	}),
	fish({
		id = "appalachia_trophy_largemouth_bass",
		destinationId = D.Appalachia,
		name = "Trophy Largemouth Bass",
		tier = 2,
		rarity = Ra.Uncommon,
		typicalWeightKg = { min = 2, max = 4 },
		recordWeightKg = 6,
		fightDifficulty = 60,
		minRodTier = 2,
		minReelTier = 2,
		waterType = W.lake,
		cash = { min = 66, max = 80 },
		conditions = { time = "low light" },
		isMilestoneTarget = true, -- Appalachia fishing conquest milestone
	}),
	fish({
		id = "appalachia_northern_pike",
		destinationId = D.Appalachia,
		name = "Northern Pike",
		tier = 2,
		rarity = Ra.Uncommon,
		typicalWeightKg = { min = 2, max = 5 },
		recordWeightKg = 8,
		fightDifficulty = 78,
		minRodTier = 2,
		minReelTier = 2,
		waterType = W.lake,
		cash = { min = 66, max = 80 },
	}),
	fish({
		id = "appalachia_record_muskie",
		destinationId = D.Appalachia,
		name = "Record Muskie",
		tier = 2,
		rarity = Ra.Uncommon, -- routine apex wall; pays Uncommon Cash directly (no artifact mint)
		typicalWeightKg = { min = 5, max = 9 },
		recordWeightKg = 12,
		fightDifficulty = 90,
		minRodTier = 3, -- snaps at T2 even maxed; T3 or T2 + co-op
		minReelTier = 3,
		waterType = W.lake,
		cash = { min = 66, max = 80 },
		conditions = { time = "dusk", weather = "overcast" },
	}),
	fish({
		id = "appalachia_tiger_muskie",
		destinationId = D.Appalachia,
		name = "Tiger Muskie",
		tier = 2,
		rarity = Ra.Legendary, -- a find: FD 58, landable at T2 (not the apex muskie's FD 90)
		typicalWeightKg = { min = 7, max = 9 },
		recordWeightKg = 12,
		fightDifficulty = 58,
		minRodTier = 2,
		minReelTier = 2,
		waterType = W.lake,
		baitRequired = "large bucktail",
		conditions = { time = "dusk", weather = "storm" },
		rare = rareFields(1500, "the storm-light hero catch — the fishing-side mirror of the Ghost Buck"),
	}),

	-- ───────────────────────── ALASKA (Tier 4) ─────────────────────────
	fish({
		id = "alaska_arctic_grayling",
		destinationId = D.Alaska,
		name = "Arctic Grayling",
		tier = 4,
		rarity = Ra.Common,
		typicalWeightKg = { min = 0.3, max = 1 },
		recordWeightKg = 2,
		fightDifficulty = 42,
		minRodTier = 3,
		minReelTier = 3,
		waterType = W.river, -- interior, shore-accessible (no Boat)
		baitRequired = "dry fly",
		cash = { min = 200, max = 250 },
	}),
	fish({
		id = "alaska_dolly_varden",
		destinationId = D.Alaska,
		name = "Dolly Varden / Rainbow Trout",
		tier = 4,
		rarity = Ra.Common,
		typicalWeightKg = { min = 0.8, max = 3 },
		recordWeightKg = 6,
		fightDifficulty = 52,
		minRodTier = 3,
		minReelTier = 3,
		waterType = W.river,
		cash = { min = 200, max = 250 },
	}),
	fish({
		id = "alaska_sockeye_salmon",
		destinationId = D.Alaska,
		name = "Sockeye Salmon",
		tier = 4,
		rarity = Ra.Uncommon,
		typicalWeightKg = { min = 2, max = 4 },
		recordWeightKg = 6,
		fightDifficulty = 58,
		minRodTier = 4,
		minReelTier = 4,
		waterType = W.river, -- interior river mouths (the shore-accessible face of the run)
		cash = { min = 330, max = 390 },
		conditions = { season = "Salmon Run", event = "Salmon Run" },
	}),
	fish({
		id = "alaska_rockfish_cod",
		destinationId = D.Alaska,
		name = "Pacific Rockfish / Cod",
		tier = 4,
		rarity = Ra.Common,
		typicalWeightKg = { min = 1, max = 5 },
		recordWeightKg = 12,
		fightDifficulty = 48,
		minRodTier = 4,
		minReelTier = 4,
		waterType = W.coastal, -- Boat-gated (Coastal Skiff)
		cash = { min = 200, max = 250 },
	}),
	fish({
		id = "alaska_lingcod",
		destinationId = D.Alaska,
		name = "Lingcod",
		tier = 4,
		rarity = Ra.Uncommon,
		typicalWeightKg = { min = 4, max = 12 },
		recordWeightKg = 20,
		fightDifficulty = 64,
		minRodTier = 4,
		minReelTier = 4,
		waterType = W.coastal,
		cash = { min = 330, max = 390 },
	}),
	fish({
		id = "alaska_king_salmon",
		destinationId = D.Alaska,
		name = "King (Chinook) Salmon",
		tier = 4,
		rarity = Ra.Uncommon,
		typicalWeightKg = { min = 8, max = 18 },
		recordWeightKg = 30,
		fightDifficulty = 68,
		minRodTier = 4,
		minReelTier = 4,
		waterType = W.coastal, -- Boat-gated: a pure fisher needs the Coastal Skiff to conquer via fishing
		baitRequired = "herring",
		cash = { min = 330, max = 390 },
		conditions = { season = "Salmon Run", event = "Salmon Run" },
		isMilestoneTarget = true, -- Alaska fishing conquest milestone (T4-soloable, Decision 7)
	}),
	fish({
		id = "alaska_giant_halibut",
		destinationId = D.Alaska,
		name = "Giant Halibut (the Barn Door)",
		tier = 4,
		rarity = Ra.Uncommon, -- coastal apex; co-op-only at MVL (no T5 reel); pays Uncommon salvage
		typicalWeightKg = { min = 70, max = 180 },
		recordWeightKg = 230,
		fightDifficulty = 98,
		minRodTier = 4,
		minReelTier = 5, -- does not exist at MVL → co-op-only
		waterType = W.coastal,
		cash = { min = 330, max = 390 },
	}),
	fish({
		id = "alaska_tyee_king",
		destinationId = D.Alaska,
		name = "Tyee King (record King Salmon)",
		tier = 4,
		rarity = Ra.Legendary,
		typicalWeightKg = { min = 20, max = 30 },
		recordWeightKg = 35,
		fightDifficulty = 68,
		minRodTier = 4,
		minReelTier = 4,
		waterType = W.coastal,
		baitRequired = "herring",
		conditions = { season = "Salmon Run", event = "Salmon Run" },
		rare = rareFields(1500, "the chrome-bright giant king breaching in the run"),
	}),
	fish({
		id = "alaska_ghost_of_the_gulf",
		destinationId = D.Alaska,
		name = "Ghost of the Gulf (colossal Halibut)",
		tier = 4,
		rarity = Ra.Mythic, -- Alaska's 'white whale'; co-op-only (a Mythic that is also a wall)
		typicalWeightKg = { min = 200, max = 300 },
		recordWeightKg = 350,
		fightDifficulty = 100,
		minRodTier = 4,
		minReelTier = 5,
		waterType = W.coastal,
		baitRequired = "large cut bait",
		conditions = { weather = "storm" },
		rare = rareFields(9000, "the colossal halibut surfacing in a storm-tossed Gulf as a party hauls together"),
	}),

	-- ───────────────────────── DEEP SEA (Tier 7 — fishing-only fixture) ─────────────────────────
	fish({
		id = "deepsea_marlin",
		destinationId = D.DeepSea,
		name = "Blue Marlin",
		tier = 7,
		rarity = Ra.Uncommon,
		typicalWeightKg = { min = 80, max = 180 },
		recordWeightKg = 400,
		fightDifficulty = 95,
		minRodTier = 7,
		minReelTier = 7,
		waterType = W.deepSea,
		cash = { min = 2000, max = 2500 },
	}),
}

local catalog: { [string]: Fish } = {}
for _, f in rows do
	if catalog[f.id] ~= nil then
		error("Fish: duplicate id '" .. f.id .. "'")
	end
	catalog[f.id] = f
end

return catalog
