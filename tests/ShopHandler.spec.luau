--!strict
-- Step 6 (economy) — the Outfitter / Tackle Shop gear sinks as server-authoritative gauntlet handlers.
-- Buy debits GearCostSlot(T) + mints an entry commodity (the new commodity-mint primitive); upgrade debits
-- the IntraTierClimb step + increments intraLevel (never changing EHT/EFT). The client asserts no price,
-- balance, or ownership. The shop UI + the felt "earned upgrade" pacing are Studio.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local Economy = require("@src/logic/Economy")
local EHT = require("@src/logic/EffectiveTier")
local Ledger = require("@src/server/ledger/Ledger")
local Gauntlet = require("@src/server/authority/Gauntlet")
local ShopHandler = require("@src/server/shop/ShopHandler")

return function(t: Harness.T)
	local function newReg(): Gauntlet.Registry
		local reg = Gauntlet.new()
		Gauntlet.register(reg, ShopHandler.buyHandler({ idGen = Fakes.newIdGenerator(), telemetry = Fakes.newTelemetry() }))
		Gauntlet.register(reg, ShopHandler.upgradeHandler({ idGen = Fakes.newIdGenerator(), telemetry = Fakes.newTelemetry() }))
		return reg
	end
	local function deps(saveOk: boolean): Gauntlet.Deps
		return {
			config = Catalog,
			now = 100,
			saveFn = function()
				return saveOk
			end,
			markDirty = function() end,
			telemetry = Fakes.newTelemetry(),
		}
	end
	local function handle(p: any, intent: string, payload: any, saveOk: boolean): Gauntlet.HandleResult
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		return Gauntlet.handle(newReg(), { intent = intent, playerId = 1, payload = payload }, session, deps(saveOk))
	end

	t.section("ShopHandler — buy a Tier-2 gating slot: debits GearCostSlot + mints an (unequipped) commodity")
	do
		local p = Util.mkProfile(Catalog, { weapon = 1, rod = 1, reel = 1, ledger = { 5000 } })
		local before = #p.inventory.commodities
		local r = handle(p, "buy", { itemId = "weapon_lever_action_rifle" }, true)
		t.ok("the buy succeeds", r.ok)
		t.eq("debited GearCostSlot(2) = 3000 (balance 5000 → 2000)", Ledger.balanceOf(p.cash), 2000)
		t.eq("a new commodity was minted", #p.inventory.commodities, before + 1)
		t.ok("the new T2 weapon is NOT equipped (buy ≠ equip) → EHT still 1 until equipped", EHT.effectiveHuntingTier(p, Catalog) == 1)
	end

	t.section("ShopHandler — buy rejects an already-owned slot (idempotency: no double-debit, no duplicate mint)")
	do
		-- 9000 Cash affords TWO buys (2x3000), so the second is rejected on OWNERSHIP, not funds — this is the
		-- guard against a double-click / replayed packet double-debiting + minting a duplicate gating commodity.
		local p = Util.mkProfile(Catalog, { weapon = 1, rod = 1, reel = 1, ledger = { 9000 } })
		local first = handle(p, "buy", { itemId = "weapon_lever_action_rifle" }, true)
		t.ok("the first buy succeeds", first.ok)
		local ownedAfterFirst = #p.inventory.commodities
		local balanceAfterFirst = Ledger.balanceOf(p.cash)
		local second = handle(p, "buy", { itemId = "weapon_lever_action_rifle" }, true)
		t.ok("a second buy of the SAME slot is rejected: already_owned", second.ok == false and second.reason == "already_owned")
		t.eq("no second debit (a double-tap / replay cannot drain Cash)", Ledger.balanceOf(p.cash), balanceAfterFirst)
		t.eq("no duplicate commodity minted", #p.inventory.commodities, ownedAfterFirst)
	end

	t.section("ShopHandler — insufficient funds rejects with NO partial state")
	do
		local p = Util.mkProfile(Catalog, { weapon = 1, rod = 1, reel = 1, ledger = { 100 } })
		local before = #p.inventory.commodities
		local r = handle(p, "buy", { itemId = "weapon_lever_action_rifle" }, true)
		t.ok("rejected: insufficient funds", r.ok == false and r.reason == "insufficient_funds")
		t.eq("no Cash debited", Ledger.balanceOf(p.cash), 100)
		t.eq("no commodity minted", #p.inventory.commodities, before)
	end

	t.section("ShopHandler — buy is atomic: a failed write-through leaves no orphan Cash/gear")
	do
		local p = Util.mkProfile(Catalog, { weapon = 1, rod = 1, reel = 1, ledger = { 5000 } })
		local before = #p.inventory.commodities
		local r = handle(p, "buy", { itemId = "weapon_lever_action_rifle" }, false)
		t.ok("a failed persist returns persist_failed", r.ok == false and r.reason == "persist_failed")
		t.eq("Cash reverted (no orphan debit)", Ledger.balanceOf(p.cash), 5000)
		t.eq("no orphan commodity", #p.inventory.commodities, before)
	end

	t.section("ShopHandler — non-gating items are not sold here (deferred to Steps 11/14)")
	do
		local p = Util.mkProfile(Catalog, { weapon = 1, rod = 1, reel = 1, ledger = { 5000 } })
		t.ok("bait is not a gating slot → rejected", handle(p, "buy", { itemId = "bait_cut_bait" }, true).ok == false)
		t.ok("the free StarterLoadout weapon is not sold (it's the free grant)", handle(p, "buy", { itemId = "weapon_bolt_22" }, true).ok == false)
	end

	t.section("ShopHandler — upgrade intra-tier: debits the step + increments intraLevel; EHT UNCHANGED")
	do
		local p = Util.mkProfile(Catalog, { weapon = 2, armor = 2, rod = 1, reel = 1, ledger = { 5000 } })
		t.eq("EHT is 2 before the upgrade", EHT.effectiveHuntingTier(p, Catalog), 2)
		local r = handle(p, "upgrade", { commodityInstanceId = "ci1" }, true) -- ci1 = the T2 weapon
		t.ok("the upgrade succeeds", r.ok)
		t.eq("debited IntraTierUpgradeCost(2, entry→mid) = 1870 (5000 → 3130)", Ledger.balanceOf(p.cash), 3130)
		t.ok("the commodity's intraLevel incremented to 1 (mid)", (function()
			for _, c in p.inventory.commodities do
				if c.instanceId == "ci1" then
					return c.intraLevel == 1
				end
			end
			return false
		end)())
		t.eq("EHT UNCHANGED by an intra-tier upgrade (never gates)", EHT.effectiveHuntingTier(p, Catalog), 2)
	end

	t.section("ShopHandler — upgrade rejects an already-maxed commodity")
	do
		local p = Util.mkProfile(Catalog, { weapon = 2, armor = 2, rod = 1, reel = 1, ledger = { 9999 } })
		for _, c in p.inventory.commodities do
			if c.instanceId == "ci1" then
				c.intraLevel = 2 -- already maxed
			end
		end
		t.ok("a maxed commodity cannot be upgraded further", handle(p, "upgrade", { commodityInstanceId = "ci1" }, true).ok == false)
	end
end
