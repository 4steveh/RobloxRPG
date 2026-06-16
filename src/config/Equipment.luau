--!strict
-- EQUIPMENT CATALOG — the MVL line, Tiers 1–4 (EQUIPMENT_MASTER §4). STRUCTURAL FIELDS ONLY.
-- NO stat numbers are transcribed: damage/DR/Pressure/drain are generated from the §1 curves at
-- consumption time (Steps 4–5), and armor has no item stat at all. `tierInput` is DERIVED from category
-- here so the "bait/tackle/vehicle/mount/dog/tool/cosmetic are never tier inputs" invariant cannot drift.

local Enums = require("@src/types/Enums")
local Schema = require("@src/types/Schema")

type EquipmentItem = Schema.EquipmentItem
type ItemId = string

local C = Enums.Category
local V = Enums.Vendor
local M = Enums.MonetizationRole
local W = Enums.WaterType

type ItemInput = {
	id: string,
	name: string,
	category: Enums.Category,
	tier: number,
	availableAt: Enums.Vendor,
	cost: Schema.Cost,
	tradeable: boolean,
	monetizationRole: Enums.MonetizationRole?,
	accessGrant: Enums.WaterType?,
	cosmeticOnly: boolean?,
	notes: string,
}

local function item(i: ItemInput): EquipmentItem
	return {
		id = i.id,
		name = i.name,
		category = i.category,
		tier = i.tier,
		availableAt = i.availableAt,
		cost = i.cost,
		tradeable = i.tradeable,
		tierInput = Enums.TIER_INPUT_CATEGORIES[i.category] == true, -- derived, never authored
		cosmeticOnly = i.cosmeticOnly or false,
		monetizationRole = i.monetizationRole,
		accessGrant = i.accessGrant,
		notes = i.notes,
	}
end

local function cash(n: number): Schema.Cost
	return { cash = n }
end

local rows: { EquipmentItem } = {
	-- ── §4.1 Hunting weapons (hitscan-with-settle — the only MVL weapon class, combat RD-D) ──
	item({
		id = "weapon_bolt_22",
		name = "Starter Rifle (Bolt .22)",
		category = C.weapon,
		tier = 1,
		availableAt = V.StarterLoadout,
		cost = cash(0),
		tradeable = false,
		monetizationRole = nil, -- free; onboarding
		notes = "Free starter weapon; clears Bayou floor; the ~60-second first-kill weapon.",
	}),
	item({
		id = "weapon_lever_action_rifle",
		name = "Lever-Action Rifle",
		category = C.weapon,
		tier = 2,
		availableAt = V.Outfitter,
		cost = cash(3000), -- c·Income(1)
		tradeable = false,
		monetizationRole = M.convenience, -- gear gate; real-money touch is grind-compression (pay-proof)
		notes = "First real-commitment weapon; contributes to EHT 2 → Appalachia.",
	}),
	item({
		id = "weapon_scoped_hunting_rifle",
		name = "Scoped Hunting Rifle",
		category = C.weapon,
		tier = 3,
		availableAt = V.Outfitter,
		cost = cash(5100), -- c·Income(2)
		tradeable = false,
		monetizationRole = M.convenience,
		notes = "Post-launch (Rockies) weapon; the T−1 reference that makes Alaska's floor comfortable.",
	}),
	item({
		id = "weapon_heavy_expedition_rifle",
		name = "Heavy Expedition Rifle",
		category = C.weapon,
		tier = 4,
		availableAt = V.Outfitter,
		cost = cash(8670), -- c·Income(3)
		tradeable = false,
		monetizationRole = M.convenience,
		notes = "MVL top hunting weapon; clears Alaska floor/mid + the moose milestone; does NOT solo the grizzly.",
	}),

	-- ── §4.2 Hunting armor (gates from Tier 2; DR is derived from the tier gap, never a raw stat) ──
	item({
		id = "armor_field_jacket",
		name = "Field Jacket",
		category = C.armor,
		tier = 2,
		availableAt = V.Outfitter,
		cost = cash(3000),
		tradeable = false,
		monetizationRole = M.convenience,
		notes = "First armor on the bill (Tier 1 has no armor cost). Survives the T2 mid (boar).",
	}),
	item({
		id = "armor_brush_guard_vest",
		name = "Brush Guard Vest",
		category = C.armor,
		tier = 3,
		availableAt = V.Outfitter,
		cost = cash(5100),
		tradeable = false,
		monetizationRole = M.convenience,
		notes = "Makes the T2 apex safe; clears Rockies.",
	}),
	item({
		id = "armor_expedition_parka",
		name = "Expedition Parka",
		category = C.armor,
		tier = 4,
		availableAt = V.Outfitter,
		cost = cash(8670),
		tradeable = false,
		monetizationRole = M.convenience,
		notes = "The legible 'of course you need this for Alaska' gate item; keeps the moose milestone survivable.",
	}),

	-- ── §4.3 Rods (armor-analog — Pressure → LandWindow) ──
	item({
		id = "rod_cane_starter",
		name = "Starter Cane Rod",
		category = C.rod,
		tier = 1,
		availableAt = V.StarterLoadout,
		cost = cash(0),
		tradeable = false,
		monetizationRole = nil,
		notes = "Free starter rod; lands all Bayou panfish/catfish; paired with the Starter Spincast Reel.",
	}),
	item({
		id = "rod_appalachia_bait",
		name = "Appalachia Bait Rod",
		category = C.rod,
		tier = 2,
		availableAt = V.TackleShop,
		cost = cash(3000),
		tradeable = false,
		monetizationRole = M.convenience,
		notes = "EFT 2 with the matching reel; lands the trophy bass.",
	}),
	item({
		id = "rod_mountain",
		name = "Mountain Rod",
		category = C.rod,
		tier = 3,
		availableAt = V.TackleShop,
		cost = cash(5100),
		tradeable = false,
		monetizationRole = M.convenience,
		notes = "Post-launch (Rockies) rod tier.",
	}),
	item({
		id = "rod_coastal_surf",
		name = "Coastal Surf Rod",
		category = C.rod,
		tier = 4,
		availableAt = V.TackleShop,
		cost = cash(8670),
		tradeable = false,
		monetizationRole = M.convenience,
		notes = "Headroom to land the king salmon milestone; first stat curve to reach the 1–100 cap (OQ-A).",
	}),

	-- ── §4.4 Reels (weapon-analog — Line Speed/Drag → FightTime) ──
	item({
		id = "reel_spincast_starter",
		name = "Starter Spincast Reel",
		category = C.reel,
		tier = 1,
		availableAt = V.StarterLoadout,
		cost = cash(0),
		tradeable = false,
		monetizationRole = nil,
		notes = "Free starter reel; the binding slot that caps the Bayou fish ladder.",
	}),
	item({
		id = "reel_baitcaster",
		name = "Baitcaster",
		category = C.reel,
		tier = 2,
		availableAt = V.TackleShop,
		cost = cash(3000),
		tradeable = false,
		monetizationRole = M.convenience,
		notes = "EFT 2 with the matching rod.",
	}),
	item({
		id = "reel_spinning",
		name = "Spinning Reel",
		category = C.reel,
		tier = 3,
		availableAt = V.TackleShop,
		cost = cash(5100),
		tradeable = false,
		monetizationRole = M.convenience,
		notes = "Post-launch (Rockies) reel tier.",
	}),
	item({
		id = "reel_coastal_lever_drag",
		name = "Coastal Lever-Drag",
		category = C.reel,
		tier = 4,
		availableAt = V.TackleShop,
		cost = cash(8670),
		tradeable = false,
		monetizationRole = M.convenience,
		notes = "Lands the king salmon milestone; the binding slot on the co-op-only giant halibut.",
	}),

	-- ── §4.5 Boats (access sink — gate water type via accessGrant, never power in shared water) ──
	item({
		id = "vehicle_jon_boat",
		name = "Jon Boat",
		category = C.vehicle,
		tier = 1,
		availableAt = V.BoatDealer,
		cost = cash(1500), -- feel-set placeholder, not a formula output (OQ-D)
		tradeable = false,
		monetizationRole = M.access,
		accessGrant = W.lake, -- opens lake/slow river; cosmetic convenience at MVL tiers 1–3
		notes = "Convenience only at MVL; Bayou/Appalachia fish are shore-accessible (no Boat required).",
	}),
	item({
		id = "vehicle_bass_boat",
		name = "Bass Boat",
		category = C.vehicle,
		tier = 3,
		availableAt = V.BoatDealer,
		cost = cash(6000), -- feel-set placeholder (OQ-D)
		tradeable = false,
		monetizationRole = M.access,
		accessGrant = W.lake,
		notes = "T3 lake convenience; opens nothing required.",
	}),
	item({
		id = "vehicle_coastal_skiff",
		name = "Coastal Skiff",
		category = C.vehicle,
		tier = 4,
		availableAt = V.BoatDealer,
		cost = cash(18000), -- ≈ b·Income(4); the marquee Alaska save-up
		tradeable = false,
		monetizationRole = M.access,
		accessGrant = W.coastal, -- THE MVL Boat gate: opens Alaska's coastal fishing sub-area (enforcement: Steps 5/11)
		notes = "Gates Alaska's coastal fishing sub-area (king salmon + halibut), NOT Alaska entry.",
	}),

	-- ── §4.6 Mounts (convenience — traversal/chase; never a tier input, never a gate) ──
	item({
		id = "mount_horse",
		name = "Horse",
		category = C.mount,
		tier = 3,
		availableAt = V.KennelAndStable,
		cost = cash(10200), -- ≈ mountMultiplier·GearCost_slot(3)
		tradeable = false,
		monetizationRole = M.convenience,
		notes = "First Mount; faster traversal + chase fleeing game. No combat/catch power.",
	}),
	item({
		id = "mount_snowmobile",
		name = "Snowmobile",
		category = C.mount,
		tier = 4,
		availableAt = V.KennelAndStable,
		cost = cash(10200),
		tradeable = false,
		monetizationRole = M.convenience,
		notes = "Alaska regional Mount reskin; chases fleeing caribou. Convenience, never a gate.",
	}),

	-- ── §4.7 Tracking Dogs (convenience + collectible identity) ──
	item({
		id = "dog_coonhound",
		name = "Coonhound",
		category = C.dog,
		tier = 2,
		availableAt = V.KennelAndStable,
		cost = cash(8000), -- ≈ dogMultiplier·GearCost_slot(T)
		tradeable = false,
		monetizationRole = M.convenience,
		notes = "Bayou breed; widens rare-spawn detection radius. Never a gate.",
	}),
	item({
		id = "dog_pointer",
		name = "Pointer",
		category = C.dog,
		tier = 2,
		availableAt = V.KennelAndStable,
		cost = cash(8000),
		tradeable = false,
		monetizationRole = M.convenience,
		notes = "Appalachia breed; finds rares / tracks wounded fleeing game.",
	}),
	item({
		id = "dog_husky",
		name = "Husky",
		category = C.dog,
		tier = 2,
		availableAt = V.KennelAndStable,
		cost = cash(8000),
		tradeable = false,
		monetizationRole = M.convenience,
		notes = "Alaska breed; convenience companion.",
	}),
	item({
		id = "dog_redbone_rare",
		name = "Rare Redbone Coonhound",
		category = C.dog,
		tier = 2,
		availableAt = V.KennelAndStable,
		cost = cash(0), -- rare breeds are P2P trade items, not shop-Cash priced (value flows to the Trading Post)
		tradeable = true, -- rare-breed dog → unique-artifact path (data-integrity RD1), but still tierInput=false
		monetizationRole = M.convenience,
		notes = "Rare breed; a tradeable unique artifact that can never enter a Gate (tradeable=true, tierInput=false).",
	}),

	-- ── §4.8 Bait & tackle (required-item yes/no only; never a tier input) + §4.10 tools ──
	item({
		id = "bait_cut_bait",
		name = "Cut Bait",
		category = C.bait,
		tier = 1,
		availableAt = V.TackleShop,
		cost = cash(10),
		tradeable = false,
		monetizationRole = nil, -- friction-free; auto-restocked
		notes = "Basic required-item for catfish; never a timer (auto-restocked).",
	}),
	item({
		id = "bait_fly",
		name = "Fly",
		category = C.bait,
		tier = 2,
		availableAt = V.TackleShop,
		cost = cash(10),
		tradeable = false,
		monetizationRole = nil,
		notes = "Basic required-item for trout (fly water).",
	}),
	item({
		id = "tackle_basic_ammo",
		name = "Basic Ammo",
		category = C.tackle,
		tier = 1,
		availableAt = V.Outfitter,
		cost = cash(10),
		tradeable = false,
		monetizationRole = nil,
		notes = "Effectively free; a player can never be blocked from the core loop by running out.",
	}),
	item({
		id = "bait_premium_lure",
		name = "Premium Lure",
		category = C.bait,
		tier = 1,
		availableAt = V.TackleShop,
		cost = cash(200),
		tradeable = false,
		monetizationRole = M.convenience, -- shortens TimeToBite; capped at Uncommon bias; never mandatory
		notes = "Convenience; never raises Legendary/Mythic rate; no fish catchable only with it.",
	}),
	item({
		id = "tackle_premium_ammo",
		name = "Premium Ammo",
		category = C.tackle,
		tier = 1,
		availableAt = V.Outfitter,
		cost = cash(200),
		tradeable = false,
		monetizationRole = M.convenience,
		notes = "Convenience settle edge; capped — never clears a gate the player's gear could not.",
	}),
	item({
		id = "tackle_ice_fishing_kit",
		name = "Ice-Fishing Kit",
		category = C.tackle,
		tier = 4,
		availableAt = V.TackleShop,
		cost = cash(800),
		tradeable = false,
		monetizationRole = M.convenience,
		notes = "Region-specific (Alaska); required-item for the seasonal Frozen Lake. Never a tier input.",
	}),
	item({
		id = "tool_snowshoes",
		name = "Snowshoes",
		category = C.tool,
		tier = 4,
		availableAt = V.Outfitter,
		cost = cash(600),
		tradeable = false,
		monetizationRole = M.convenience,
		notes = "Region-specific (Alaska); restores on-foot pace over snow. No combat/catch/survivability stat.",
	}),

	-- ── §4.9 Cosmetics (balance-free, evergreen inflation ballast) ──
	item({
		id = "cosmetic_wood_rifle_skin",
		name = "Wood Rifle Skin",
		category = C.cosmetic,
		tier = 1,
		availableAt = V.Outfitter,
		cost = cash(500),
		tradeable = false,
		monetizationRole = M.identity,
		cosmeticOnly = true,
		notes = "Identity; zero stats; standard Cash-priced skin.",
	}),
	item({
		id = "cosmetic_founders_skin",
		name = "Founder's Rifle Skin",
		category = C.cosmetic,
		tier = 1,
		availableAt = V.Outfitter,
		cost = { realMoney = { kind = Enums.RealMoneyKind.gamepass } }, -- exercises the real-money Cost leg
		tradeable = false,
		monetizationRole = M.identity,
		cosmeticOnly = true,
		notes = "Game-pass flagship cosmetic; identity only.",
	}),
	item({
		id = "cosmetic_rare_boat_livery",
		name = "Rare Boat Livery",
		category = C.cosmetic,
		tier = 1,
		availableAt = V.BoatDealer,
		cost = cash(0), -- a tradeable rare cosmetic — value flows P2P, not shop-Cash
		tradeable = true, -- tradeable cosmetic → unique-artifact path (data-integrity RD1)
		monetizationRole = M.identity,
		cosmeticOnly = true,
		notes = "Tradeable rare cosmetic; unique artifact; balance-free.",
	}),
}

-- Fold to an id→item map; reject duplicate ids at build time.
local catalog: { [ItemId]: EquipmentItem } = {}
for _, it in rows do
	if catalog[it.id] ~= nil then
		error("Equipment: duplicate item id '" .. it.id .. "'")
	end
	catalog[it.id] = it
end

return catalog
