# Harvest / Catch Result Card — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a screenshot-worthy "field-journal plaque" that renders the committed authoritative outcome of every hunt/catch (species, weight, rarity, shot, cash/XP, NEW!, rare-trophy + MOUNT IT), per `docs/superpowers/specs/SYS_harvest_screen.md` (v1 LOCKED decisions).

**Architecture:** Surface the already-computed-but-discarded `RewardPipeline.Result` to the client by threading the commit return through the Gauntlet substrate (Seam A), then render it in a new Studio-only `client/HarvestCard.luau`. The substrate stays reward-agnostic (result typed `any?`, cast at the Studio caller). Weight is a cosmetic server-rolled value; "NEW!" is rares-only (Tier A, no migration). Headless work is TDD-gated by `./run-tests.sh`; the client/render work is Studio-playtest + `screen_capture` verified.

**Tech Stack:** Luau (strict for `src/`, nonstrict for `client/`), the headless test harness (`tests/run.luau`), `luau-analyze`, `rojo`, Roblox Studio MCP for playtest verification.

## Global Constraints

- **Run all commands from the git root: `/home/toor/claude/RobloxRPG/RobloxRPG`** (the nested dir).
- **The DoD gate is `./run-tests.sh`** — 4 gates: (1) `luau-analyze --!strict` on every headless module, (2) unit tests, (3) negative fixtures must FAIL analysis, (4) `rojo build` succeeds. It must be green after every headless task.
- **Headless / Studio split:** `src/config`, `src/logic`, `src/server/**` (except `*.server.luau`) are `--!strict`, NO Roblox globals, unit-tested. `*.server.luau`, `*.client.luau`, `client/**` are Studio-only, excluded from gates 1–2, verified by playtest + `screen_capture`.
- **Server-authoritative, no client mint:** the card RENDERS committed values only; weight is server-rolled; "MOUNT IT" routes the `mountTrophy` intent back through the gauntlet. The client asserts nothing.
- **Substrate vs operations:** the Gauntlet (`src/server/authority/`) must NOT depend on a combat/fishing operation module — the result slot is typed `any?`, not `RewardPipeline.Result?`.
- **Closed enums live once** (`src/types/Enums.luau`); render rarity from `Enums.Rarity`, no string synonyms.
- **Weight is cosmetic** — it must never feed `Economy.payout` (keyed `tier+rarity+destinationId+loop`) or any ledger entry.
- **Commits:** the owner has asked that nothing be committed to git without their go-ahead. Treat each "Commit" step as gated on owner confirmation; if executing on the default branch, branch first.

---

## File Structure

| File | New/Modify | Responsibility |
|---|---|---|
| `src/server/authority/Gauntlet.luau` | Modify | Seam A: `commit` returns `any?`; `HandleResult.result`; `handle` captures + returns it |
| `src/server/combat/FireHandler.luau` | Modify | `commit` returns its `RewardPipeline.Result` |
| `src/server/fishing/CatchHandler.luau` | Modify | `commit` returns its `RewardPipeline.Result` |
| `src/types/Schema.luau` | Modify | Add optional `Creature.typicalWeightKg` |
| `src/config/Validation.luau` | Modify | Validate `typicalWeightKg` shape when present |
| `src/config/Creatures.luau` | Modify | `CreatureInput` + builder pass-through + author kg ranges |
| `src/logic/Harvest.luau` | **Create** | Pure helpers: `kgToLb`, `rollWeightKg`, `isRecord`, `timesSourced` |
| `tests/Harvest.spec.luau` | **Create** | Unit tests for the pure helpers |
| `tests/run.luau` | Modify | Register `Harvest.spec` |
| `src/server/world/WorldServer.server.luau` | Modify | Assemble + send the `{projection, harvest}` envelope; add `LodgeRequest` wire |
| `client/HarvestCard.luau` | **Create** | The plaque renderer |
| `client/FireController.client.luau` | Modify | Read envelope; hybrid card/toast |
| `client/FishingController.client.luau` | Modify | Read envelope; hybrid card/toast; pass authoritative name to Feel |
| `client/Net.luau` | Modify | Add `lodge = ev("LodgeRequest")` |

---

## Task 1: Seam A — thread the commit result through the Gauntlet substrate

**Files:**
- Modify: `src/server/authority/Gauntlet.luau` (L24 `commit` type, L36 `HandleResult`, L85–99 `handle`)
- Test: `tests/Gauntlet.spec.luau`

**Interfaces:**
- Produces: `Gauntlet.IntentHandler.commit: (ctx: Ctx) -> any?` and `Gauntlet.HandleResult.result: any?` — later tasks read `r.result` and the two reward handlers return a value.

- [ ] **Step 1: Write the failing test** — append a new section to `tests/Gauntlet.spec.luau` before the final `end`:

```lua
	t.section("Gauntlet — a handler's commit return is threaded onto HandleResult.result")
	do
		local rreg = Gauntlet.new()
		Gauntlet.register(rreg, {
			intent = "resultTest",
			critical = true,
			simulate = nil,
			authority = function(): (boolean, string?)
				return true, nil
			end,
			commit = function(_ctx: Gauntlet.Ctx): any?
				return { cash = 42, tag = "from-commit" }
			end,
		})
		local p = Util.mkProfile(Catalog, {})
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		local r = Gauntlet.handle(rreg, { intent = "resultTest", playerId = 1, payload = {} }, session, deps)
		t.ok("the commit return is surfaced on r.result", r.ok and (r.result :: any).cash == 42 and (r.result :: any).tag == "from-commit")

		-- a handler that returns nothing → r.result is nil (the equip path, non-critical)
		local p2 = Util.mkProfile(Catalog, { weapon = 2, armor = 4 })
		table.insert(p2.inventory.commodities, { instanceId = "ci-heavy2", catalogId = "weapon_heavy_expedition_rifle", intraLevel = 0, equipped = false })
		local s2: Gauntlet.Session = { playerId = 1, profile = p2, live = true }
		local r2 = Gauntlet.handle(reg, { intent = "equip", playerId = 1, payload = { commodityInstanceId = "ci-heavy2" } }, s2, deps)
		t.ok("a void-commit handler leaves r.result nil", r2.ok and r2.result == nil)
	end
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `cd /home/toor/claude/RobloxRPG/RobloxRPG && luau tests/run.luau`
Expected: FAIL — `r.result` is nil for the resultTest handler (the field does not exist yet), and/or analyze error that `HandleResult` has no `result`.

- [ ] **Step 3: Implement Seam A in `src/server/authority/Gauntlet.luau`**

Change the `commit` field type (L24):
```lua
	commit: (ctx: Ctx) -> any?, -- step 4: apply the mutation(s) in one no-yield section; may return an opaque result (e.g. RewardPipeline.Result) for the caller to surface — the substrate stays reward-agnostic
```

Change `HandleResult` (L36):
```lua
export type HandleResult = { ok: boolean, reason: string?, projection: Replication.Projection?, result: any? }
```

Rewrite the commit+replicate region of `M.handle` (L83–99) to capture and return the value:
```lua
	-- 4 + 5. Atomic commit + persist. Critical mutations commit-as-a-unit inside a Transaction so a
	-- failed write reverts cleanly; non-critical mutations commit and ride the dirty-flag autosave.
	local committed: any? = nil
	if handler.critical then
		local txn = Transaction.run(session.profile, function()
			committed = handler.commit(ctx)
		end, deps.saveFn)
		if not txn.ok then
			incr(deps, "gauntlet.persist_failed")
			return { ok = false, reason = "persist_failed" }
		end
	else
		committed = handler.commit(ctx)
		deps.markDirty()
	end
	-- 6. Replicate — a fresh read-only projection. The opaque commit result rides alongside it.
	incr(deps, "gauntlet.handled:" .. request.intent)
	return { ok = true, projection = Replication.buildProjection(session.profile, deps.config), result = committed }
```

- [ ] **Step 4: Run the full gate, verify green (proves ALL handlers still typecheck under the widened contract)**

Run: `cd /home/toor/claude/RobloxRPG/RobloxRPG && ./run-tests.sh`
Expected: PASS — gate 1 (`luau-analyze --!strict`) green across every handler (EquipHandler, Shop, Display, Travel, Trade, EventReward, FireHandler, CatchHandler — all compile, void commits assignable to `(Ctx) -> any?`); gate 2 includes the new Gauntlet assertions.
**If a specific handler fails analysis** (unexpected): add an explicit `return nil` at the end of that handler's `commit`. Do not change the `any?` typing.

- [ ] **Step 5: Commit** (owner-gated)

```bash
git add src/server/authority/Gauntlet.luau tests/Gauntlet.spec.luau
git commit -m "feat(harvest): thread commit result through the gauntlet (Seam A)"
```

---

## Task 2: Reward handlers return their RewardPipeline.Result

**Files:**
- Modify: `src/server/combat/FireHandler.luau` (commit, ~L109–134), `src/server/fishing/CatchHandler.luau` (commit, ~L133–163)
- Test: `tests/FireHandler.spec.luau`, `tests/CatchHandler.spec.luau`

**Interfaces:**
- Consumes: `Gauntlet.HandleResult.result` (Task 1).
- Produces: on a successful fire/catch, `r.result` is the `RewardPipeline.Result` (`{ ambiance, cash, boostCash, mintedArtifactId, rankXP, conquestNewlySet, cleanKillMoment }`).

- [ ] **Step 1: Write the failing tests**

In `tests/FireHandler.spec.luau`, inside the existing first section ("a valid lethal shot drives the reward pipeline end-to-end"), after the existing `t.ok(... r.projection ...)` assertion, add:
```lua
			t.ok("the RewardPipeline.Result is surfaced on r.result (routine kill)", r.result ~= nil and (r.result :: any).cash > 0 and (r.result :: any).rankXP > 0 and (r.result :: any).mintedArtifactId == nil and (r.result :: any).boostCash == 0)
```

In `tests/CatchHandler.spec.luau`, inside the first section ("a valid landed fish drives the reward pipeline end-to-end"), after the projection assertion, add:
```lua
			t.ok("the RewardPipeline.Result is surfaced on r.result (routine catch)", r.result ~= nil and (r.result :: any).cash > 0 and (r.result :: any).rankXP > 0 and (r.result :: any).mintedArtifactId == nil)
```

And in the Frozen-Lake section, after `t.ok("an artifact was minted ...")`, add a rare-branch assertion:
```lua
		t.ok("the rare burbot result carries the mint + zero cash (XOR) on r.result", (rBurbot.result :: any).mintedArtifactId ~= nil and (rBurbot.result :: any).cash == 0 and (rBurbot.result :: any).cleanKillMoment ~= nil)
```

- [ ] **Step 2: Run, verify failure**

Run: `cd /home/toor/claude/RobloxRPG/RobloxRPG && luau tests/run.luau`
Expected: FAIL — `r.result` is nil (the commits don't return yet).

- [ ] **Step 3: Implement — return the result from each commit**

In `src/server/combat/FireHandler.luau`, at the END of the `commit` function (after the `if result.conquestNewlySet then ... end` block, L133), add:
```lua
				return result
```

In `src/server/fishing/CatchHandler.luau`, at the END of the `commit` function (after the `if result.conquestNewlySet then ... end` block, L162), add:
```lua
				return result
```

- [ ] **Step 4: Run the gate, verify green**

Run: `cd /home/toor/claude/RobloxRPG/RobloxRPG && ./run-tests.sh`
Expected: PASS — both reward specs see the threaded result; all gates green.

- [ ] **Step 5: Commit** (owner-gated)

```bash
git add src/server/combat/FireHandler.luau src/server/fishing/CatchHandler.luau tests/FireHandler.spec.luau tests/CatchHandler.spec.luau
git commit -m "feat(harvest): reward handlers return their RewardPipeline.Result"
```

---

## Task 3: Cosmetic creature weight — schema field, validation, authored data

**Files:**
- Modify: `src/types/Schema.luau` (`Creature` type, ~L106–135), `src/config/Validation.luau` (`assertCreature`), `src/config/Creatures.luau` (`CreatureInput` + `creature` builder + per-creature data)
- Test: `tests/Validation.spec.luau`

**Interfaces:**
- Produces: `Schema.Creature.typicalWeightKg: { min: number, max: number }?` (optional, cosmetic). Fish already carry `typicalWeightKg`/`recordWeightKg` (`Schema.Fish` L146–147) — no fish change needed.

- [ ] **Step 1: Write the failing test** — add a section to `tests/Validation.spec.luau`:

```lua
	t.section("Validation — Creature.typicalWeightKg shape (cosmetic, optional)")
	do
		local base = Catalog.creatures.bayou_wood_duck
		local good = table.clone(base) :: any
		good.typicalWeightKg = { min = 0.7, max = 1.1 }
		t.ok("a valid weight range passes", pcall(function() V.assertCreature(good) end))
		local bad1 = table.clone(base) :: any
		bad1.typicalWeightKg = { min = 0, max = 1 }
		t.ok("min <= 0 is rejected", not pcall(function() V.assertCreature(bad1) end))
		local bad2 = table.clone(base) :: any
		bad2.typicalWeightKg = { min = 5, max = 2 }
		t.ok("max < min is rejected", not pcall(function() V.assertCreature(bad2) end))
	end
```

(If `tests/Validation.spec.luau` does not already `require` `V`/Catalog the same way, mirror its existing top-of-file requires — it already tests `V.assertCreature`.)

- [ ] **Step 2: Run, verify failure**

Run: `cd /home/toor/claude/RobloxRPG/RobloxRPG && luau tests/run.luau`
Expected: FAIL — `assertCreature` does not yet check `typicalWeightKg`, so `bad1`/`bad2` wrongly pass.

- [ ] **Step 3a: Add the optional field to `src/types/Schema.luau`**

In the `export type Creature = {` block, add before the closing `}` (alongside the other optional fields):
```lua
	typicalWeightKg: { min: number, max: number }?, -- cosmetic per-catch weight range (lb shown on the harvest card); never a payout input
```

- [ ] **Step 3b: Validate the shape in `src/config/Validation.luau`**

In `V.assertCreature`, before the final `end`, add:
```lua
	if c.typicalWeightKg ~= nil then
		assert(c.typicalWeightKg.min > 0 and c.typicalWeightKg.max >= c.typicalWeightKg.min,
			c.id .. ": typicalWeightKg must have 0 < min <= max")
	end
```

- [ ] **Step 3c: Thread the field through `src/config/Creatures.luau`**

In the `CreatureInput` type, add:
```lua
	typicalWeightKg: { min: number, max: number }?, -- cosmetic weight range (non-ambiance huntables)
```

In the `creature(i)` builder's returned table, add (alongside `spawnZones = i.spawnZones,`):
```lua
		typicalWeightKg = i.typicalWeightKg,
```

- [ ] **Step 3d: Author realistic kg ranges for every NON-ambiance creature**

Read the 27 creature inputs in `src/config/Creatures.luau`. For each creature whose `ambianceOnly` is not true, add a `typicalWeightKg = { min = X, max = Y }` field using a realistic range in **kg** for that real-world species (leave ambiance creatures without it — the card omits weight gracefully). Use these for the known Bayou/Appalachia/Alaska species and estimate the rest from the species name:

| Species (by name) | kg range |
|---|---|
| Wood Duck / small fowl | `{ min = 0.5, max = 1.0 }` |
| Bobcat / small predator | `{ min = 6, max = 16 }` |
| White-tailed / Sika Deer | `{ min = 35, max = 90 }` |
| Wild Boar | `{ min = 50, max = 140 }` |
| American Alligator | `{ min = 140, max = 360 }` |
| Black Bear | `{ min = 90, max = 250 }` |
| Grizzly / Brown Bear | `{ min = 180, max = 450 }` |
| Moose / Elk | `{ min = 270, max = 600 }` |
| Wolf / Coyote | `{ min = 15, max = 55 }` |

For any species not listed, pick a plausible adult-weight range; the only hard rule is `0 < min <= max` (Validation + Catalog self-validation enforce it).

- [ ] **Step 4: Run the gate, verify green**

Run: `cd /home/toor/claude/RobloxRPG/RobloxRPG && ./run-tests.sh`
Expected: PASS — `Catalog.luau` self-validates on require (a bad range would fail the require), the new Validation assertions pass, all gates green.

- [ ] **Step 5: Commit** (owner-gated)

```bash
git add src/types/Schema.luau src/config/Validation.luau src/config/Creatures.luau tests/Validation.spec.luau
git commit -m "feat(harvest): cosmetic creature weight (schema + validation + data)"
```

---

## Task 4: Pure harvest helpers — `src/logic/Harvest.luau`

**Files:**
- Create: `src/logic/Harvest.luau`, `tests/Harvest.spec.luau`
- Modify: `tests/run.luau` (register the spec)

**Interfaces:**
- Produces:
  - `Harvest.kgToLb(kg: number): number` — pounds, rounded to 0.1.
  - `Harvest.rollWeightKg(min: number, max: number, u: number): number` — `u ∈ [0,1]`, biased toward `min` so big weights are rare.
  - `Harvest.isRecord(weightKg: number, recordWeightKg: number, threshold: number): boolean`.
  - `Harvest.timesSourced(profile: Schema.PlayerData, sourceId: string): number` — count of artifacts whose `provenance.sourceId == sourceId` (Tier-A NEW: first ever ⇒ `== 1` after a mint).

- [ ] **Step 1: Write the failing spec** — create `tests/Harvest.spec.luau`:

```lua
--!strict
local Harness = require("@tests/harness")
local Harvest = require("@src/logic/Harvest")

return function(t: Harness.T)
	t.section("Harvest.kgToLb — pounds rounded to 0.1")
	do
		t.eq("10 kg → 22.0 lb", Harvest.kgToLb(10), 22.0)
		t.eq("rounds to one decimal", Harvest.kgToLb(1), 2.2)
	end

	t.section("Harvest.rollWeightKg — in range, biased low")
	do
		t.eq("u=0 → min", Harvest.rollWeightKg(10, 20, 0), 10)
		t.eq("u=1 → max", Harvest.rollWeightKg(10, 20, 1), 20)
		t.ok("u=0.5 is below the midpoint (biased to min)", Harvest.rollWeightKg(10, 20, 0.5) < 15)
		local w = Harvest.rollWeightKg(10, 20, 0.5)
		t.ok("stays within [min,max]", w >= 10 and w <= 20)
	end

	t.section("Harvest.isRecord — near the record")
	do
		t.ok("0.95*record is a record at threshold 0.95", Harvest.isRecord(95, 100, 0.95))
		t.ok("below threshold is not a record", not Harvest.isRecord(94, 100, 0.95))
	end

	t.section("Harvest.timesSourced — counts artifacts by source species")
	do
		local profile: any = { artifacts = {
			a1 = { provenance = { sourceId = "bayou_x" } },
			a2 = { provenance = { sourceId = "bayou_x" } },
			a3 = { provenance = { sourceId = "bayou_y" } },
			a4 = { provenance = {} },
		} }
		t.eq("two of bayou_x", Harvest.timesSourced(profile, "bayou_x"), 2)
		t.eq("one of bayou_y", Harvest.timesSourced(profile, "bayou_y"), 1)
		t.eq("none of bayou_z", Harvest.timesSourced(profile, "bayou_z"), 0)
	end
end
```

- [ ] **Step 2: Register + run, verify failure**

Add to the `specs` table in `tests/run.luau` (near the other `logic` specs, e.g. after `require("@tests/Spawner.spec"),`):
```lua
	require("@tests/Harvest.spec"),
```
Run: `cd /home/toor/claude/RobloxRPG/RobloxRPG && luau tests/run.luau`
Expected: FAIL — `@src/logic/Harvest` does not exist.

- [ ] **Step 3: Implement `src/logic/Harvest.luau`**

```lua
--!strict
-- Pure helpers for the harvest/catch result card (SYS_harvest_screen). Zero Roblox globals, zero content
-- literals (thresholds are passed in). The RANDOM source stays in Studio (WorldServer passes math.random()
-- as `u`); the math here is deterministic + unit-tested.

local Schema = require("../types/Schema")

type PlayerData = Schema.PlayerData

local M = {}

-- kilograms → pounds, rounded to one decimal (Gone Hunting's "[201.7 lb]" idiom).
function M.kgToLb(kg: number): number
	return math.floor(kg * 2.2046 * 10 + 0.5) / 10
end

-- A weight roll biased toward `min` (u*u for u∈[0,1]) so heavy specimens / records feel rare.
function M.rollWeightKg(min: number, max: number, u: number): number
	local c = math.clamp(u, 0, 1)
	return min + (max - min) * c * c
end

-- Is this catch at/near the species record? `threshold` ∈ (0,1] (e.g. 0.95).
function M.isRecord(weightKg: number, recordWeightKg: number, threshold: number): boolean
	return recordWeightKg > 0 and weightKg >= recordWeightKg * threshold
end

-- How many of the player's artifacts came from this source species (Tier-A "NEW!": after a mint, == 1 ⇒ first).
function M.timesSourced(profile: PlayerData, sourceId: string): number
	local n = 0
	for _, a in profile.artifacts do
		if a.provenance.sourceId == sourceId then
			n += 1
		end
	end
	return n
end

return M
```

- [ ] **Step 4: Run the gate, verify green**

Run: `cd /home/toor/claude/RobloxRPG/RobloxRPG && ./run-tests.sh`
Expected: PASS — Harvest.spec green; gate 1 confirms the module is `--!strict` clean with no Roblox globals.

- [ ] **Step 5: Commit** (owner-gated)

```bash
git add src/logic/Harvest.luau tests/Harvest.spec.luau tests/run.luau
git commit -m "feat(harvest): pure harvest helpers (kgToLb/rollWeightKg/isRecord/timesSourced)"
```

---

## Task 5: WorldServer — assemble + send the harvest envelope

**Files:**
- Modify: `src/server/world/WorldServer.server.luau` (kill fire ~L860–866; landed fire ~L983–988; add a `buildHarvest` helper + a `Harvest` require near the other requires ~L17–45)

**Interfaces:**
- Consumes: `r.result` (`RewardPipeline.Result`, Tasks 1–2), `Harvest.*` (Task 4), `Schema.Creature.typicalWeightKg` (Task 3), `Catalog.fish[id].typicalWeightKg/recordWeightKg`.
- Produces: the kill/landed 4th arg is now `{ projection = r.projection, harvest = <table> }` (consumed by Task 7). Adds `RECORD_THRESHOLD = 0.95` local.

> This is Studio-only: no unit test. Verification is `rojo build` (gate 4) + the Task 9 playtest. `WorldServer.server.luau` already requires `@src` modules via relative paths.

- [ ] **Step 1: Add the `Harvest` require** near the other `require("../...")` lines at the top of `WorldServer.server.luau` (e.g. beside the `Combat`/`Fishing` requires):

```lua
local Harvest = require("../../logic/Harvest")
```

- [ ] **Step 2: Add the `buildHarvest` helper** (place it after the requires / near the other top-level helpers, before the `fireRequest` block ~L792):

```lua
local RECORD_THRESHOLD = 0.95
-- Assemble the result-card payload from the committed RewardPipeline.Result + the catalog row. Cosmetic
-- weight is rolled here (Studio owns randomness); every value of record is read from the authoritative result.
local function buildHarvest(loop, targetId, row, result, profile, shotZone)
	local res = result or {}
	local weightKg, isRecord = nil, false
	if row.typicalWeightKg ~= nil then
		weightKg = Harvest.rollWeightKg(row.typicalWeightKg.min, row.typicalWeightKg.max, math.random())
		if row.recordWeightKg ~= nil then
			isRecord = Harvest.isRecord(weightKg, row.recordWeightKg, RECORD_THRESHOLD)
		end
	end
	local minted = res.mintedArtifactId
	local isNew = minted ~= nil and Harvest.timesSourced(profile, targetId) == 1
	return {
		loop = loop,
		targetId = targetId,
		name = row.name,
		rarity = row.rarity,
		tier = row.tier,
		weightLb = if weightKg ~= nil then Harvest.kgToLb(weightKg) else nil,
		isRecord = isRecord,
		shotZone = shotZone, -- "vital" | "limb" | "body" | nil (hunting only)
		cash = res.cash or 0,
		boostCash = res.boostCash or 0,
		rankXP = res.rankXP or 0,
		isNew = isNew,
		mintedArtifactId = minted,
		cleanKillMoment = res.cleanKillMoment,
		conquest = res.conquestNewlySet == true,
	}
end
```

- [ ] **Step 3: Send the envelope at the KILL fire site** — replace the `fireRequest:FireClient(plr, "kill", rayHitTargetId, r.projection)` line (~L863) and its TODO comment with:

```lua
			local harvest = buildHarvest("Hunting", rayHitTargetId, Catalog.creatures[rayHitTargetId], r.result, session.profile, zone)
			fireRequest:FireClient(plr, "kill", rayHitTargetId, { projection = r.projection, harvest = harvest })
```

- [ ] **Step 4: Send the envelope at the LANDED fire site** — replace the `castRequest:FireClient(plr, "landed", fishId, r.projection)` line (~L986) and its TODO comment with:

```lua
				local harvest = buildHarvest("Fishing", fishId, Catalog.fish[fishId], r.result, session.profile, nil)
				castRequest:FireClient(plr, "landed", fishId, { projection = r.projection, harvest = harvest })
```

- [ ] **Step 5: Verify the project still builds**

Run: `cd /home/toor/claude/RobloxRPG/RobloxRPG && rojo build default.project.json --output /tmp/wildworld.rbxlx && echo BUILD_OK`
Expected: `BUILD_OK` (gate 4). Full `./run-tests.sh` must also remain green (headless untouched).

- [ ] **Step 6: Commit** (owner-gated)

```bash
git add src/server/world/WorldServer.server.luau
git commit -m "feat(harvest): assemble + send the harvest envelope from both fire sites"
```

---

## Task 6: `client/HarvestCard.luau` — the plaque renderer

**Files:**
- Create: `client/HarvestCard.luau`

**Interfaces:**
- Consumes: `Hud.gui` + `Hud.button` (factory), `Net.lodge` (added in Task 8 — guard for nil so this task lands independently), the `harvest` envelope shape (Task 5).
- Produces: `HarvestCard.show(harvest)` — renders the plaque; auto-dismiss + cancel-on-next via a token. Consumed by Task 7.

> Studio-only, `--!nonstrict`, excluded from gates 1–2. Verified by `rojo build` + Task 9 playtest/screen_capture.

- [ ] **Step 1: Create `client/HarvestCard.luau`**

```lua
--!nonstrict
-- STUDIO-ONLY. The harvest / catch result "field-journal plaque" (SYS_harvest_screen). Renders ONLY the
-- server-sent `harvest` envelope; asserts nothing. Routine vs rare branches on mintedArtifactId (the Reward
-- XOR). Auto-dismisses; a rapid second catch cancels the prior card. "MOUNT IT" routes the mountTrophy intent
-- through the server (Net.lodge), which the gauntlet validates — the card never mints or changes disposition.
local Hud = require(script.Parent:WaitForChild("Hud"))

local M = {}

-- rarity-keyed accent (closed Enums.Rarity values; word + tier carry meaning too, so color is not load-bearing)
local RARITY_COLOR = {
	Common = Color3.fromRGB(220, 220, 205),
	Uncommon = Color3.fromRGB(150, 200, 140),
	Rare = Color3.fromRGB(110, 165, 215),
	Epic = Color3.fromRGB(180, 130, 220),
	Legendary = Color3.fromRGB(235, 195, 110),
	Mythic = Color3.fromRGB(150, 235, 225),
}
local BONE = Color3.fromRGB(235, 235, 220)

local function lbl(parent, text, pos, size, textSize, color, bold, center)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	l.TextSize = textSize
	l.TextColor3 = color or BONE
	l.TextXAlignment = if center then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
	l.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	l.TextStrokeTransparency = 0.2 -- legibility over bright sky/snow/water
	l.Text = text
	l.Parent = parent
	return l
end

local token = 0

function M.show(harvest)
	token += 1
	local mine = token
	-- destroy any prior card
	local old = Hud.gui:FindFirstChild("HarvestCard")
	if old then old:Destroy() end

	local rarity = harvest.rarity or "Common"
	local accent = RARITY_COLOR[rarity] or BONE
	local isRare = harvest.mintedArtifactId ~= nil

	local card = Instance.new("Frame")
	card.Name = "HarvestCard"
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 0.72, 24) -- lower-center, above the action bar + tension gauge; settles up
	card.Size = UDim2.fromOffset(420, if isRare then 250 else 196)
	card.BackgroundColor3 = Color3.fromRGB(28, 24, 18) -- OPAQUE (not the 0.35 HUD panels) for contrast
	card.BackgroundTransparency = 0.04
	card.BorderSizePixel = 0
	card.Parent = Hud.gui
	local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0, 8) corner.Parent = card
	local stroke = Instance.new("UIStroke") stroke.Color = accent stroke.Thickness = 2 stroke.Transparency = 0.2 stroke.Parent = card
	local scale = Instance.new("UIScale") scale.Scale = math.clamp(Hud.gui.AbsoluteSize.Y / 800, 0.8, 1.3) scale.Parent = card

	-- species name (headline) + rarity rule
	lbl(card, string.upper(harvest.name or "?"), UDim2.fromOffset(16, 14), UDim2.fromOffset(388, 30), 26, accent, true, true)
	local rule = Instance.new("Frame")
	rule.Position = UDim2.fromOffset(40, 50) rule.Size = UDim2.fromOffset(340, 2)
	rule.BackgroundColor3 = accent rule.BackgroundTransparency = 0.3 rule.BorderSizePixel = 0 rule.Parent = card

	-- rarity · tier line + NEW!
	local meta = string.format("%s · Tier %d", string.upper(rarity), harvest.tier or 0)
	lbl(card, meta, UDim2.fromOffset(16, 60), UDim2.fromOffset(300, 20), 15, accent, false, false)
	if harvest.isNew then
		lbl(card, "NEW!", UDim2.new(1, -76, 0, 60), UDim2.fromOffset(60, 20), 15, Color3.fromRGB(255, 230, 120), true, true)
	end

	local y = 88
	local function statRow(name, value, valueColor)
		lbl(card, name, UDim2.fromOffset(16, y), UDim2.fromOffset(160, 22), 16, Color3.fromRGB(180, 180, 165), false, false)
		lbl(card, value, UDim2.fromOffset(180, y), UDim2.fromOffset(224, 22), 18, valueColor or BONE, true, false)
		y += 26
	end

	if harvest.weightLb ~= nil then
		statRow("WEIGHT", string.format("%.1f lb", harvest.weightLb) .. (if harvest.isRecord then "   ★ RECORD" else ""), if harvest.isRecord then Color3.fromRGB(255, 230, 120) else BONE)
	end
	if harvest.shotZone == "vital" then
		statRow("SHOT", "◇ HEADSHOT", Color3.fromRGB(150, 230, 140))
	end

	if isRare then
		if harvest.cleanKillMoment then
			lbl(card, '"' .. harvest.cleanKillMoment .. '"', UDim2.fromOffset(16, y), UDim2.fromOffset(388, 22), 15, accent, false, true) y += 26
		end
		lbl(card, "✶ ADDED TO COLLECTION ✶", UDim2.fromOffset(16, y), UDim2.fromOffset(388, 22), 16, accent, true, true) y += 30
		local mountBtn = Hud.button({ name = "MountBtn", text = "MOUNT IT", parent = card, anchor = Vector2.new(0, 1), position = UDim2.new(0, 16, 1, -12), size = UDim2.fromOffset(180, 44), color = Color3.fromRGB(70, 95, 60) })
		local keepBtn = Hud.button({ name = "KeepBtn", text = "Keep in Bag", parent = card, anchor = Vector2.new(1, 1), position = UDim2.new(1, -16, 1, -12), size = UDim2.fromOffset(170, 44), color = Color3.fromRGB(50, 50, 46) })
		mountBtn.Activated:Connect(function()
			local Net = require(script.Parent:WaitForChild("Net"))
			if Net.lodge ~= nil then
				Net.lodge:FireServer(harvest.mintedArtifactId)
				mountBtn.Text = "MOUNTED ✓"
				mountBtn.Active = false
			end
		end)
		keepBtn.Activated:Connect(function() if token == mine then card:Destroy() end end)
	else
		statRow("CATCH", "$ " .. tostring(harvest.cash), Color3.fromRGB(150, 230, 140))
		if harvest.boostCash and harvest.boostCash > 0 then
			statRow("BOOST", "+$ " .. tostring(harvest.boostCash), Color3.fromRGB(120, 210, 255))
		end
		if harvest.rankXP and harvest.rankXP > 0 then
			statRow(if harvest.loop == "Fishing" then "ANGLER XP" else "HUNTER XP", "+" .. tostring(harvest.rankXP))
		end
	end

	-- auto-dismiss (rare cards dwell longer); cancel if a newer card supersedes
	task.delay(if isRare then 6 else 3.5, function()
		if token == mine and card.Parent then card:Destroy() end
	end)
end

return M
```

- [ ] **Step 2: Verify the project builds**

Run: `cd /home/toor/claude/RobloxRPG/RobloxRPG && rojo build default.project.json --output /tmp/wildworld.rbxlx && echo BUILD_OK`
Expected: `BUILD_OK`.

- [ ] **Step 3: Commit** (owner-gated)

```bash
git add client/HarvestCard.luau
git commit -m "feat(harvest): the harvest-card plaque renderer"
```

---

## Task 7: Wire the controllers to the envelope (hybrid card/toast)

**Files:**
- Modify: `client/FireController.client.luau` (L51–60 kill/hit branches), `client/FishingController.client.luau` (L98–104 landed branch)

**Interfaces:**
- Consumes: the `{ projection, harvest }` envelope (Task 5), `HarvestCard.show` (Task 6).

> Studio-only. Hybrid policy: full card on rare (`mintedArtifactId`) / record (`isRecord`) / new (`isNew`); else a lightweight `+$x Name` toast.

- [ ] **Step 1: Hunting — update `client/FireController.client.luau`**

Add the require near the top (after the `Feel` require, ~L12):
```lua
local HarvestCard = require(script.Parent:WaitForChild("HarvestCard"))
```

Replace the `if kind == "kill" then ... ` block (L52–55) with:
```lua
	if kind == "kill" then
		local h = extra.harvest
		Hud.applyProjection(extra.projection)
		if h.mintedArtifactId or h.isRecord or h.isNew then
			HarvestCard.show(h)
		else
			Hud.toast("+$" .. tostring(h.cash) .. "  " .. tostring(h.name), Color3.fromRGB(150, 230, 140))
		end
		Feel.onKill(extra.projection)
```

(The `elseif kind == "hit"` branch keeps its scalar `extra` — unchanged.)

- [ ] **Step 2: Fishing — update `client/FishingController.client.luau`**

Add the require near the top (after the `Feel` require, ~L8):
```lua
local HarvestCard = require(script.Parent:WaitForChild("HarvestCard"))
```

Replace the `elseif kind == "landed" then ...` block (L98–103) with:
```lua
	elseif kind == "landed" then
		lastFightReply = os.clock()
		resetToIdle()
		local h = extra.harvest
		Hud.applyProjection(extra.projection)
		if h.mintedArtifactId or h.isRecord or h.isNew then
			HarvestCard.show(h)
		else
			Hud.toast("+$" .. tostring(h.cash) .. "  " .. tostring(h.name), Color3.fromRGB(150, 230, 140))
		end
		Feel.onLanded(fishId, h.name) -- pass the AUTHORITATIVE name (FishingFeel no longer derives via gsub)
```

> Note for the executor: `FishingFeel.onLanded` currently takes `(fishId, extra)` where `extra` was the projection. Passing `h.name` (a string) is the intended new contract; if `FishingFeel.onLanded` reads fields off its 2nd arg, adjust it to treat a string as the display name (small Studio edit in `client/FishingFeel.luau`).

- [ ] **Step 3: Verify build**

Run: `cd /home/toor/claude/RobloxRPG/RobloxRPG && rojo build default.project.json --output /tmp/wildworld.rbxlx && echo BUILD_OK`
Expected: `BUILD_OK`.

- [ ] **Step 4: Commit** (owner-gated)

```bash
git add client/FireController.client.luau client/FishingController.client.luau client/FishingFeel.luau
git commit -m "feat(harvest): wire controllers to the harvest envelope (hybrid card/toast)"
```

---

## Task 8: "MOUNT IT" wire — `LodgeRequest` remote + `Net.lodge`

**Files:**
- Modify: `src/server/world/WorldServer.server.luau` (add a `LodgeRequest` RemoteEvent routing the `mountTrophy` intent), `client/Net.luau` (expose it)

**Interfaces:**
- Consumes: the registered `mountTrophy` handler (`DisplayHandler.mountHandler`, payload `{ artifactId: string }`, already registered at WorldServer L166).
- Produces: `Net.lodge` (a RemoteEvent), consumed by `HarvestCard` (Task 6).

> Studio-only. The `mountTrophy` intent exists and is gauntlet-validated (slots/disposition/ownership); it simply had no client wire. This adds the minimal wire so the card's MOUNT IT works.

- [ ] **Step 1: Add the server wire** in `WorldServer.server.luau` (near the other request-remote blocks, e.g. after the `travelRequest` block ~L1032):

```lua
-- Lodge: the harvest card's "MOUNT IT" routes the mountTrophy intent (HELD→DISPLAYED CAS, slot-gated) through
-- the gauntlet. Server-authoritative: the client sends only the artifactId; the gauntlet validates + transitions.
local lodgeRequest = Instance.new("RemoteEvent")
lodgeRequest.Name = "LodgeRequest"
lodgeRequest.Parent = ReplicatedStorage
lodgeRequest.OnServerEvent:Connect(function(plr, artifactId)
	local session = sessionService.sessions[plr.UserId]
	if session == nil or type(artifactId) ~= "string" then
		return
	end
	local r = Gauntlet.handle(registry, { intent = "mountTrophy", playerId = plr.UserId, payload = { artifactId = artifactId } }, session, gauntletDeps(plr))
	lodgeRequest:FireClient(plr, r.ok, artifactId, r.reason)
end)
```

- [ ] **Step 2: Expose it in `client/Net.luau`** — add to the returned table:

```lua
	lodge = ev("LodgeRequest"),
```

- [ ] **Step 3: Verify build**

Run: `cd /home/toor/claude/RobloxRPG/RobloxRPG && rojo build default.project.json --output /tmp/wildworld.rbxlx && echo BUILD_OK`
Expected: `BUILD_OK`.

- [ ] **Step 4: Commit** (owner-gated)

```bash
git add src/server/world/WorldServer.server.luau client/Net.luau
git commit -m "feat(harvest): LodgeRequest wire so MOUNT IT mounts the trophy"
```

---

## Task 9: Studio playtest verification (the Studio-half DoD)

**Files:** none (verification only)

> Per CLAUDE.md, Studio-only code is verified by playtest, not headless. Use the Roblox Studio MCP against the connected `WildWorld.rbxl`.

- [ ] **Step 1: Confirm headless is still green**

Run: `cd /home/toor/claude/RobloxRPG/RobloxRPG && ./run-tests.sh`
Expected: all 4 gates PASS (headless was only touched by Tasks 1–4, which are tested; gate 4 confirms the Studio files still sync).

- [ ] **Step 2: Boot a playtest and exercise each branch**

Start play (`start_stop_play` is_start=true). Then, via the MCP, perform/observe:
- A **routine** catch/kill → a lightweight `+$x Name` toast (no card).
- A **first-time (NEW) rare** kill → the gold trophy card with the moment headline, "ADDED TO COLLECTION", and MOUNT IT.
- Tap **MOUNT IT** → the button reads "MOUNTED ✓"; confirm the artifact's disposition is `DISPLAYED` (inspect the profile / Lodge wall).

- [ ] **Step 3: Capture the screenshots and check against the spec mockups**

Use `screen_capture` to grab the routine card and the rare trophy card. Confirm: opaque panel + readable text over the scene (legibility), rarity-keyed accent, weight in lb, headshot chip on a vital kill, NEW!/RECORD badges, and that the rare card never shows "$0".

- [ ] **Step 4: Note results** (and any follow-ups) in the README playtest checklist if appropriate. Stop play (`start_stop_play` is_start=false).

---

## Self-Review

- **Spec coverage:** §1 trigger → Task 5; §2 fields (name/weight/rarity/shot/cash/XP/NEW/XOR) → Tasks 2–6; §3 visual treatment + MOUNT IT → Tasks 6, 8; §4 client seam (Seam A + envelope + host) → Tasks 1, 5, 6, 7; §5 HUD-legibility → Task 6 (opaque panel, UIStroke, UIScale, placement above gauge); §6 invariants → enforced by Seam A typing (Task 1), cosmetic weight (Task 3), server-routed mount (Task 8); §8 resolved decisions (Seam A / Tier A / lb fish+creatures / hybrid) → Tasks 1, 6, 3, 7.
- **Placeholder scan:** the only judgment task is Task 3 step 3d (weight authoring), bounded by a concrete table + the Validation/self-validation gate — not a code placeholder.
- **Type consistency:** envelope field names are identical across Task 5 (producer) and Tasks 6–7 (consumers): `loop, name, rarity, tier, weightLb, isRecord, shotZone, cash, boostCash, rankXP, isNew, mintedArtifactId, cleanKillMoment, conquest`. `r.result` (`any?`) is produced in Task 1, returned in Task 2, read in Task 5. `Net.lodge` produced in Task 8, consumed (nil-guarded) in Task 6.
- **Open follow-ups (out of v1 scope, noted):** a full Lodge browser UI; the `conquest` banner render (envelope carries it; Task 6 can add a banner later); Tier-B bestiary (`profile.seen`); the trait row (weather/trait spec).
