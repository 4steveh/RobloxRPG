--!strict
-- THE REAL-MONEY PRODUCT CATALOG (Step 14 — SYS_economy §7 / EQUIPMENT_MASTER §4.8–4.9). Config-driven:
-- a new pack/pass is a config ROW, not code. Each product maps to a Roblox asset id (a PLACEHOLDER — Steve
-- binds the real ids in Studio), a GRANT (the closed pay-proof union — Cash | item | cosmetic | multiplier),
-- and a monetization ROLE. Validation.assertProduct runs on load (via Catalog) and rejects any product that
-- carries the `power-progression` role or whose grant could hand a power input — so this catalog is
-- structurally non-pay-to-win. The asset-id binding + the store UI are Studio; this is the headless half.
--
-- WHY no "skip the grind to unlock" / "buy the rare" / "buy the milestone" product exists here: it is
-- UNREPRESENTABLE. ProductGrant has no conquest/tier variant (Schema), so such a row cannot be written.

local Enums = require("../types/Enums")
local Schema = require("../types/Schema")

type Product = Schema.Product
type ProductGrant = Schema.ProductGrant

local K = Enums.RealMoneyKind
local R = Enums.MonetizationRole
local Mult = Enums.CashMultiplier

-- A placeholder Roblox asset id. The real numeric ids are bound in Studio (Out of scope — platform).
local function placeholder(id: string): string
	return "rbxassetid://PLACEHOLDER_" .. id
end

local rows: { Product } = {
	-- ── §7 currency packs (dev product — the Cash faucet; non-pay-to-win by the pay-proof property: bought
	-- Cash hits the SAME milestone wall idle Cash does). Injected as an idempotent `currencypack` ledger entry.
	{
		id = "pack_cash_small",
		name = "Pouch of Cash",
		kind = K.devproduct,
		assetId = placeholder("pack_cash_small"),
		grant = { kind = "cash", amount = 5000 } :: ProductGrant,
		role = R.convenience, -- grind-compression, never a milestone
		notes = "Small currency pack; compresses the grind, never the milestone (a whale still downs the boar).",
	},
	{
		id = "pack_cash_large",
		name = "Strongbox of Cash",
		kind = K.devproduct,
		assetId = placeholder("pack_cash_large"),
		grant = { kind = "cash", amount = 30000 } :: ProductGrant,
		role = R.convenience,
		notes = "Large currency pack; same pay-proof rules — re-exits via sinks; Cash is not a tradeable leg.",
	},

	-- ── §7 the 2x Cash boost (dev product — a TIME-LIMITED active-income multiplier). Applied at the active
	-- kill/catch grant only; metered separately; never advances a gate (touches Cash, not the conquest set).
	{
		id = "boost_2x_cash",
		name = "2× Cash Boost (1h)",
		kind = K.devproduct,
		assetId = placeholder("boost_2x_cash"),
		grant = { kind = "multiplier", multiplier = Mult.boost2x } :: ProductGrant,
		role = R.convenience,
		notes = "Time-limited 2× on ACTIVE income; idle/daily/salvage/milestone are untouched (§7).",
	},

	-- ── §7 VIP (game pass — a small PERSISTENT active-income multiplier; same rules + metering as the boost).
	{
		id = "vip_pass",
		name = "VIP Pass",
		kind = K.gamepass,
		assetId = placeholder("vip_pass"),
		grant = { kind = "multiplier", multiplier = Mult.vip } :: ProductGrant,
		role = R.convenience,
		notes = "Persistent small active-income multiplier; re-granted idempotently on login (ownership).",
	},

	-- ── §E game-pass Boat tier — a FASTER PATH TO OWNERSHIP of an existing Boat. The Boat still gates ACCESS,
	-- not power (Step 11): the same access grant bought a different way. Grant = the existing Coastal Skiff item.
	{
		id = "gamepass_coastal_skiff",
		name = "Coastal Skiff (Game Pass)",
		kind = K.gamepass,
		assetId = placeholder("gamepass_coastal_skiff"),
		grant = { kind = "item", itemId = "vehicle_coastal_skiff" } :: ProductGrant,
		role = R.access, -- a Boat is ACCESS, never a tier/power input
		notes = "A faster path to the Coastal Skiff (access to Alaska's coastal sub-area); never power.",
	},

	-- ── §E game-pass flagship cosmetic — balance-free identity (the high-margin skin, §4.9). No stats.
	{
		id = "gamepass_founders_skin",
		name = "Founder's Rifle Skin (Game Pass)",
		kind = K.gamepass,
		assetId = placeholder("gamepass_founders_skin"),
		grant = { kind = "cosmetic", itemId = "cosmetic_founders_skin" } :: ProductGrant,
		role = R.identity, -- balance-free identity; revenue, not a Cash sink
		notes = "Game-pass flagship cosmetic; balance-free (cosmeticOnly); does not remove Cash (not a sink).",
	},

	-- ── §A premium consumables (dev-product PACKS — the convenience consumable's real-money leg; the Cash leg
	-- is the existing Tackle Shop / Outfitter buy). Grant = a fungible stack. Capped ≤ Uncommon STRUCTURALLY.
	{
		id = "devproduct_premium_lure_pack",
		name = "Premium Lure Pack (×25)",
		kind = K.devproduct,
		assetId = placeholder("devproduct_premium_lure_pack"),
		grant = { kind = "item", itemId = "bait_premium_lure", quantity = 25 } :: ProductGrant,
		role = R.convenience, -- routine-grind compression only; never mandatory; cannot reach the moat-rares
		notes = "A stack of premium lure; shortens routine TimeToBite + ≤Uncommon bias; never a rare-roll input.",
	},
	{
		id = "devproduct_premium_ammo_pack",
		name = "Premium Ammo Pack (×50)",
		kind = K.devproduct,
		assetId = placeholder("devproduct_premium_ammo_pack"),
		grant = { kind = "item", itemId = "tackle_premium_ammo", quantity = 50 } :: ProductGrant,
		role = R.convenience,
		notes = "A stack of premium ammo; a small settle edge; never clears a gate the player's gear could not.",
	},
}

-- Fold to an id→product map; reject duplicate ids at build time (mirrors Equipment/Decor).
local catalog: Schema.ProductCatalog = {}
for _, p in rows do
	if catalog[p.id] ~= nil then
		error("Monetization: duplicate product id '" .. p.id .. "'")
	end
	catalog[p.id] = p
end

return catalog
