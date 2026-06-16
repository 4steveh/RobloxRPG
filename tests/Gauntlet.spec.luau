--!strict
local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Gauntlet = require("@src/server/authority/Gauntlet")
local EquipHandler = require("@src/server/authority/handlers/EquipHandler")
local Replication = require("@src/server/authority/Replication")
local Balance = require("@src/logic/Balance")
local Fakes = require("@src/server/persistence/Fakes")

return function(t: Harness.T)
	local reg = Gauntlet.new()
	Gauntlet.register(reg, EquipHandler)
	local dirty = false
	local saved = false
	local deps: Gauntlet.Deps = {
		config = Catalog,
		now = 1,
		saveFn = function()
			saved = true
			return true
		end,
		markDirty = function()
			dirty = true
		end,
		telemetry = Fakes.newTelemetry(),
	}

	t.section("Gauntlet — a client ASSERTION is rejected (no route exists)")
	do
		local session: Gauntlet.Session = { playerId = 1, profile = Util.mkProfile(Catalog, {}), live = true }
		local r = Gauntlet.handle(reg, { intent = "setBalance", playerId = 1, payload = { amount = 999999 } }, session, deps)
		t.ok("an unregistered intent (a client assertion) is rejected at routing", r.ok == false and r.reason == "unknown_intent")
	end

	t.section("Gauntlet — authenticity: a request for another player is rejected")
	do
		local session: Gauntlet.Session = { playerId = 1, profile = Util.mkProfile(Catalog, {}), live = true }
		local r = Gauntlet.handle(reg, { intent = "equip", playerId = 2, payload = {} }, session, deps)
		t.ok("playerId mismatch rejected", r.ok == false and r.reason == "not_authenticated")
	end

	t.section("Gauntlet — equip runs the full 6-step gauntlet end-to-end")
	do
		local p = Util.mkProfile(Catalog, { weapon = 2, armor = 4 }) -- ci1=weapon T2, ci2=armor T4
		table.insert(p.inventory.commodities, { instanceId = "ci-heavy", catalogId = "weapon_heavy_expedition_rifle", intraLevel = 0, equipped = false })
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		dirty = false
		local r = Gauntlet.handle(reg, { intent = "equip", playerId = 1, payload = { commodityInstanceId = "ci-heavy" } }, session, deps)
		t.ok("equip succeeds", r.ok)
		t.ok("equipped.weapon now points at the new commodity (stable instanceId)", p.equipped.weapon == "ci-heavy")
		t.ok("the previously-equipped weapon is unflagged", (function()
			for _, c in p.inventory.commodities do
				if c.instanceId == "ci1" then
					return c.equipped == false
				end
			end
			return false
		end)())
		t.ok("non-critical → marked dirty (not write-through)", dirty == true)
		t.ok("a read-only projection is returned, EHT reflects the new T4 weapon + T4 armor", r.projection ~= nil and (r.projection :: any).eht == 4)
	end

	t.section("Gauntlet — equip authority rejects non-owned / non-equippable")
	do
		local p = Util.mkProfile(Catalog, { weapon = 2 })
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		local r1 = Gauntlet.handle(reg, { intent = "equip", playerId = 1, payload = { commodityInstanceId = "ci-nope" } }, session, deps)
		t.ok("equipping a non-owned commodity is rejected", r1.ok == false and r1.reason == "not_owned")
		table.insert(p.inventory.commodities, { instanceId = "ci-bait", catalogId = "bait_cut_bait", intraLevel = 0, equipped = false })
		local r2 = Gauntlet.handle(reg, { intent = "equip", playerId = 1, payload = { commodityInstanceId = "ci-bait" } }, session, deps)
		t.ok("equipping a non-equippable category (bait) is rejected", r2.ok == false and r2.reason == "not_equippable")
	end

	t.section("Gauntlet — a CRITICAL handler whose write-through FAILS reverts + returns persist_failed")
	do
		local creg = Gauntlet.new()
		Gauntlet.register(creg, {
			intent = "criticalTest",
			critical = true,
			simulate = nil,
			authority = function(): (boolean, string?)
				return true, nil
			end,
			commit = function(ctx: Gauntlet.Ctx)
				ctx.profile.conqueredDestinations["bayou"] = true
			end,
		})
		local p = Util.mkProfile(Catalog, {})
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		local failingDeps: Gauntlet.Deps = {
			config = Catalog,
			now = 1,
			saveFn = function()
				return false
			end, -- write-through fails
			markDirty = function() end,
			telemetry = nil,
		}
		local r = Gauntlet.handle(creg, { intent = "criticalTest", playerId = 1, payload = {} }, session, failingDeps)
		t.ok("a failed write-through returns persist_failed", r.ok == false and r.reason == "persist_failed")
		t.ok("the critical mutation was REVERTED via Transaction (no orphan conquest)", p.conqueredDestinations["bayou"] == nil)
		t.ok("no projection is returned on a failed persist", r.projection == nil)
	end

	t.section("Replication — the projection is a read-only server-computed shadow")
	do
		local p = Util.mkProfile(Catalog, { weapon = 2, ledger = { 500 } })
		local proj = Replication.buildProjection(p, Catalog)
		t.eq("projection balance reflects the ledger", proj.balance, 500)
		-- editing the shadow must change nothing server-side
		proj.balance = 999999
		proj.unlockedDestinations["alaska"] = true
		t.eq("authoritative balance unchanged by editing the shadow", Balance.balanceOf(p), 500)
		t.ok("authoritative unlocked set unchanged", p.unlockedDestinations["alaska"] == nil)
	end
end
