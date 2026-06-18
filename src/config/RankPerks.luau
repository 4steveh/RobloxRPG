--!strict
-- RANK PERK REGISTRY (progression §4). Hunter Rank / Angler Rank perks. The `category` enum is
-- identity | convenience — `power` is NOT a legal value (a power perk is a build-time schema error,
-- enforced both by the type system and by Validation.assertRankPerkCategory). Data-driven so LiveOps
-- adds perks without code. Magnitudes (radii, bonuses) are Step-6/economy's; this is the registry shape.

local Enums = require("../types/Enums")
local Schema = require("../types/Schema")

type RankPerk = Schema.RankPerk

local Cat = Enums.RankPerkCategory
local L = Enums.Loop

local rows: { RankPerk } = {
	{
		id = "hunter_title_tracker",
		name = "Tracker (rank title)",
		category = Cat.identity, -- pure status
		track = L.Hunting,
		description = "A rank title + Lodge flair. No balance effect.",
	},
	{
		id = "hunter_faster_field_dressing",
		name = "Faster Field Dressing",
		category = Cat.convenience, -- time-saving; never combat power
		track = L.Hunting,
		description = "Processes a kill faster. Saves time; grants no damage or survivability.",
	},
	{
		id = "hunter_wider_tracking_radius",
		name = "Wider Tracking Radius",
		category = Cat.convenience,
		track = L.Hunting,
		description = "Widens the rare-spawn detection radius. Helps you find, never win.",
	},
	{
		id = "angler_title_baitmaster",
		name = "Baitmaster (rank title)",
		category = Cat.identity,
		track = L.Fishing,
		description = "A rank title + badge. Pure status.",
	},
	{
		id = "angler_reduced_spook",
		name = "Reduced Spook Radius",
		category = Cat.convenience,
		track = L.Fishing,
		description = "Fish spook less easily. A convenience; never raises catch power or clears a gate.",
	},
}

return rows
