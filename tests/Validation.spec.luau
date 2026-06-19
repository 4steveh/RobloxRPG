--!strict
local Harness = require("@tests/harness")
local Catalog = require("@src/config/Catalog")
local Validation = require("@src/config/Validation")
local Profile = require("@src/logic/Profile")
local Schema = require("@src/types/Schema")

return function(t: Harness.T)
	t.section("Validation — no 'power' rank perks (no-pay-to-win, structural)")
	t.errs("category 'power' rejected at runtime", function()
		Validation.assertRankPerkCategory("power")
	end)
	t.test("category 'identity' accepted", function()
		Validation.assertRankPerkCategory("identity")
	end)
	t.test("category 'convenience' accepted", function()
		Validation.assertRankPerkCategory("convenience")
	end)

	t.section("Validation — disposition gated by artifact kind (DISPLAYED/SALVAGED are Trophy-only)")
	t.test("trophy may be HELD/DISPLAYED/ESCROWED/SALVAGED", function()
		Profile.newArtifact({ artifactId = "a1", owner = "u", kind = "trophy", disposition = "DISPLAYED", tradeable = false })
		Profile.newArtifact({ artifactId = "a2", owner = "u", kind = "trophy", disposition = "SALVAGED", tradeable = false })
	end)
	t.test("non-trophy (dog/mount/boat/cosmetic) may be HELD or ESCROWED", function()
		Profile.newArtifact({ artifactId = "a3", owner = "u", kind = "trackingDog", disposition = "HELD", tradeable = true })
		Profile.newArtifact({ artifactId = "a4", owner = "u", kind = "mount", disposition = "ESCROWED", tradeable = true })
	end)
	t.errs("non-trophy dog CANNOT be DISPLAYED", function()
		Profile.newArtifact({ artifactId = "a5", owner = "u", kind = "trackingDog", disposition = "DISPLAYED", tradeable = true })
	end)
	t.errs("non-trophy boat CANNOT be SALVAGED", function()
		Profile.newArtifact({ artifactId = "a6", owner = "u", kind = "boat", disposition = "SALVAGED", tradeable = true })
	end)
	t.ok("isDispositionLegal(trophy, SALVAGED) = true", Validation.isDispositionLegal("trophy", "SALVAGED"))
	t.ok("isDispositionLegal(mount, ESCROWED) = true", Validation.isDispositionLegal("mount", "ESCROWED"))
	t.ok("isDispositionLegal(cosmetic, DISPLAYED) = false", Validation.isDispositionLegal("cosmetic", "DISPLAYED") == false)

	t.section("Validation — Reward XOR boundary (rarity ↔ reward kind)")
	local goodCommon: Schema.Creature = {
		id = "spec_common", destinationId = "bayou", name = "Spec Common", tier = 1, rarity = "Common",
		ambianceOnly = false, behavior = "flees", packSize = nil, health = 10, damageToPlayer = 0, speed = 10,
		minWeaponTierToKill = 1, minArmorTierToSurvive = 0, coop = "soloTopGear",
		reward = { kind = "cash", cash = { min = 1, max = 2 } },
		reskinOf = nil, spawn = { location = "x", conditions = nil }, rare = nil, isMilestoneTarget = nil,
	}
	t.test("a Common with a Cash reward validates", function()
		Validation.assertCreature(goodCommon)
	end)
	t.errs("a Common with an ARTIFACT reward is rejected", function()
		local bad: Schema.Creature = table.clone(goodCommon)
		bad.reward = { kind = "artifact", artifact = { tradeable = true, displayableInLodge = true } }
		Validation.assertCreature(bad)
	end)
	t.errs("a Rare with a CASH reward is rejected (no Cash at mint)", function()
		local bad: Schema.Creature = table.clone(goodCommon)
		bad.rarity = "Rare"
		bad.rare = { spawnRate = 100, tradeable = true, displayableInLodge = true, reReleasePolicy = "NEVER", intendedContentMoment = "x" }
		bad.reward = { kind = "cash", cash = { min = 1, max = 2 } }
		Validation.assertCreature(bad)
	end)
	t.errs("an ambiance creature WITH a reward is rejected (grants nothing)", function()
		local bad: Schema.Creature = table.clone(goodCommon)
		bad.ambianceOnly = true
		Validation.assertCreature(bad)
	end)

	t.test("a valid typicalWeightKg range validates", function()
		local good: Schema.Creature = table.clone(goodCommon)
		good.typicalWeightKg = { min = 0.7, max = 1.1 }
		Validation.assertCreature(good)
	end)
	t.errs("typicalWeightKg with min <= 0 is rejected", function()
		local bad: Schema.Creature = table.clone(goodCommon)
		bad.typicalWeightKg = { min = 0, max = 1 }
		Validation.assertCreature(bad)
	end)
	t.errs("typicalWeightKg with max < min is rejected", function()
		local bad: Schema.Creature = table.clone(goodCommon)
		bad.typicalWeightKg = { min = 5, max = 2 }
		Validation.assertCreature(bad)
	end)

	t.section("Validation — tierInput cannot drift from category; cosmetics are balance-free")
	local goodWeapon = Catalog.equipment["weapon_lever_action_rifle"]
	t.test("a real gating weapon validates", function()
		Validation.assertEquipmentItem(goodWeapon)
	end)
	t.errs("a mount with tierInput=true is rejected (only weapon/armor/rod/reel gate)", function()
		local bad: Schema.EquipmentItem = {
			id = "bad_mount", name = "Bad Mount", category = "mount", tier = 3, availableAt = "KennelAndStable",
			cost = { cash = 1 }, tradeable = false, tierInput = true, cosmeticOnly = false,
			monetizationRoles = { "convenience" }, accessGrant = nil, notes = "",
		}
		Validation.assertEquipmentItem(bad)
	end)
	t.errs("a cosmetic with an accessGrant is rejected (cosmetics are balance-free)", function()
		local bad: Schema.EquipmentItem = {
			id = "bad_cosmetic", name = "Bad Cosmetic", category = "cosmetic", tier = 1, availableAt = "Outfitter",
			cost = { cash = 1 }, tradeable = false, tierInput = false, cosmeticOnly = true,
			monetizationRoles = { "identity" }, accessGrant = "coastal", notes = "",
		}
		Validation.assertEquipmentItem(bad)
	end)
	t.errs("an accessGrant on a non-vehicle is rejected", function()
		local bad: Schema.EquipmentItem = {
			id = "bad_access", name = "Bad Access", category = "dog", tier = 2, availableAt = "KennelAndStable",
			cost = { cash = 1 }, tradeable = false, tierInput = false, cosmeticOnly = false,
			monetizationRoles = { "convenience" }, accessGrant = "coastal", notes = "",
		}
		Validation.assertEquipmentItem(bad)
	end)

	t.section("Validation — a re-skin reuses its origin's behavior template (progression §6)")
	t.test("every catalog re-skin shares its origin's behavior", function()
		for _, c in Catalog.creatures do
			if c.reskinOf ~= nil then
				local origin = Catalog.creatures[c.reskinOf]
				assert(origin ~= nil, c.id .. ": reskinOf must resolve")
				Validation.assertCreatureReskin(c, Catalog)
			end
		end
	end)
	t.errs("a re-skin that changes behavior is rejected", function()
		local bad = table.clone(Catalog.creatures.appalachia_piebald_whitetail)
		bad.behavior = "aggressive" -- origin (whitetail) is `flees`
		Validation.assertCreatureReskin(bad, Catalog)
	end)

	t.section("Validation — Step 11 never-power guardrail: only tier gear may carry the power-progression role")
	do
		t.errs("a dog with the power-progression monetization role is rejected (convenience is never power)", function()
			local bad: Schema.EquipmentItem = {
				id = "bad_power_dog", name = "Bad Power Dog", category = "dog", tier = 2, availableAt = "KennelAndStable",
				cost = { cash = 1 }, tradeable = false, tierInput = false, cosmeticOnly = false,
				monetizationRoles = { "power-progression" }, accessGrant = nil, notes = "",
			}
			Validation.assertEquipmentItem(bad)
		end)
		t.errs("a mount with the power-progression monetization role is rejected", function()
			local bad: Schema.EquipmentItem = {
				id = "bad_power_mount", name = "Bad Power Mount", category = "mount", tier = 3, availableAt = "KennelAndStable",
				cost = { cash = 1 }, tradeable = false, tierInput = false, cosmeticOnly = false,
				monetizationRoles = { "power-progression" }, accessGrant = nil, notes = "",
			}
			Validation.assertEquipmentItem(bad)
		end)
		t.test("the authored Horse + Coastal Skiff + Coonhound validate cleanly (no false positive)", function()
			Validation.assertEquipmentItem(Catalog.equipment["mount_horse"])
			Validation.assertEquipmentItem(Catalog.equipment["vehicle_coastal_skiff"])
			Validation.assertEquipmentItem(Catalog.equipment["dog_coonhound"])
		end)
	end

	t.section("Validation — Step 14 pay-proof product guard (no power product; no item-grant tier gear)")
	do
		t.test("every authored product validates cleanly (no false positive)", function()
			for _, product in Catalog.products do
				Validation.assertProduct(product, Catalog)
			end
		end)
		-- the never-power role guard, extended from gear (Step 11) to the product catalog (Step 14)
		t.errs("a product carrying the power-progression role is rejected (no pay-to-win)", function()
			local bad: Schema.Product = {
				id = "bad_power_product", name = "Bad", kind = "devproduct", assetId = "rbxassetid://X",
				grant = { kind = "cash", amount = 100 }, role = "power-progression", notes = "",
			}
			Validation.assertProduct(bad, Catalog)
		end)
		-- a SAFE-kinded grant can still try to smuggle power two ways — both closed:
		t.errs("an item grant of TIER GEAR (a weapon) is rejected — real money never hands a power input", function()
			local bad: Schema.Product = {
				id = "bad_gear_product", name = "Bad Gear", kind = "gamepass", assetId = "rbxassetid://X",
				grant = { kind = "item", itemId = "weapon_lever_action_rifle" }, role = "convenience", notes = "",
			}
			Validation.assertProduct(bad, Catalog)
		end)
		t.errs("a cosmetic grant of a NON-cosmetic item is rejected (the balance-free guarantee)", function()
			local bad: Schema.Product = {
				id = "bad_cosmetic_product", name = "Bad Cosmetic", kind = "gamepass", assetId = "rbxassetid://X",
				grant = { kind = "cosmetic", itemId = "weapon_lever_action_rifle" }, role = "identity", notes = "",
			}
			Validation.assertProduct(bad, Catalog)
		end)
		t.errs("a product with no assetId placeholder is rejected (the binding must exist)", function()
			local bad: Schema.Product = {
				id = "bad_noasset", name = "Bad", kind = "devproduct", assetId = "",
				grant = { kind = "cash", amount = 100 }, role = "convenience", notes = "",
			}
			Validation.assertProduct(bad, Catalog)
		end)
	end
end
