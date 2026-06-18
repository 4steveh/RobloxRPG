--!strict
-- FISH CATALOG (Template D) — Bayou / Appalachia / Alaska + a Deep Sea fixture entry. Representative.
-- All fish grant a reward (no ambiance fish). Cash ranges are ILLUSTRATIVE (computed from economy's
-- band), not authored. The Reward XOR boundary is baked into the builder (Rare+ → artifact, no Cash).

local Enums = require("../types/Enums")
local Schema = require("../types/Schema")
local Ids = require("../types/Ids")
local FishBuilder = require("./FishBuilder")

type Fish = Schema.Fish

local D = Ids.Destination
local W = Enums.WaterType
local Ra = Enums.Rarity

-- The XOR-enforcing builder is SHARED (FishBuilder) so LiveOps event-introduced fish build the same way.
local fish = FishBuilder.fish
local rareFields = FishBuilder.rareFields

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
		spawnZones = { "mill_pond" },
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
		spawnZones = { "hollow_creek" },
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
		spawnZones = { "hollow_creek", "mill_pond" },
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
		spawnZones = { "mill_pond" },
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
		minRodTier = 3, -- rod-bound snap at T2 (LandWindow≈5.2 ≪ FightTime≈20.4); comfortably 3 (LOC_02 §3)
		minReelTier = 2, -- reel2 lands it at rod3: FightTime 20.45 ≤ LandWindow 27.2
		waterType = W.lake,
		spawnZones = { "mill_pond" },
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
		spawnZones = { "mill_pond" },
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
		spawnZones = { "mill_pond" },
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
		spawnZones = { "interior_river" },
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
		spawnZones = { "interior_river" },
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
		spawnZones = { "interior_river" },
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
		spawnZones = { "coastal_inlet" },
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
		spawnZones = { "coastal_inlet" },
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
		spawnZones = { "coastal_inlet" },
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
		-- max=80 (not 180): the Step-5 rule uses typicalWeightKg.max as representativeWeight for StaminaToLand.
		-- max=180 overstated the fight (stamina 931, solo FightTime>LandWindow AND co-op FightTime>LandWindow → wall).
		-- EQUIPMENT_MASTER §4.4 / LOC_04 §4 work the halibut at stamina 441 ≈ weight 80: solo FightTime 45.6 > 37.2
		-- (throws) AND a partyCap=4 party FightTime 18.3 ≤ 37.2 (lands) → co-op-soluble, not a wall. (recordWeightKg
		-- stays at 230 — the "barn door" legend is real; that's the all-time record, not the typical fight weight.)
		typicalWeightKg = { min = 70, max = 80 },
		recordWeightKg = 230,
		fightDifficulty = 98,
		minRodTier = 4,
		minReelTier = 5, -- does not exist at MVL → co-op-only
		waterType = W.coastal,
		spawnZones = { "open_gulf" },
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
		spawnZones = { "coastal_inlet" },
		conditions = { season = "Salmon Run", event = "Salmon Run" },
		rare = rareFields(1500, "the chrome-bright giant king breaching in the run"),
	}),
	fish({
		id = "alaska_ghost_of_the_gulf",
		destinationId = D.Alaska,
		name = "Ghost of the Gulf (colossal Halibut)",
		tier = 4,
		-- Co-op-only by the same minReelTier=5 mechanism as the giant_halibut; its colossal weight (200–300 kg)
		-- is intentional flavor (the 'white whale' legend) and is excluded from the co-op-soluble band because
		-- it is Mythic (RARE+) — the band asserts only non-rare fish. Weight is NOT changed here.
		rarity = Ra.Mythic, -- Alaska's 'white whale'; co-op-only (a Mythic that is also a wall)
		typicalWeightKg = { min = 200, max = 300 },
		recordWeightKg = 350,
		fightDifficulty = 100,
		minRodTier = 4,
		minReelTier = 5,
		waterType = W.coastal,
		baitRequired = "large cut bait",
		spawnZones = { "open_gulf" },
		conditions = { weather = "storm" },
		rare = rareFields(9000, "the colossal halibut surfacing in a storm-tossed Gulf as a party hauls together"),
	}),

	-- NOTE: the FROZEN LAKE catches (alaska_lake_whitefish + alaska_burbot) are NOT in the base catalog — they
	-- are GENUINELY-NEW scarcity INTRODUCED by the Winter Freeze event (config/LiveOps.luau `mintsFish`, RD1b),
	-- merged into config.fish by Catalog with a clone-evasion collision check (a new id must not pre-exist here).

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
