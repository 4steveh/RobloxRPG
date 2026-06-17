# Wild World — Step 8: The Lodge & Trophy Hall — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Lodge hub + Trophy Hall as a *view over `disposition == DISPLAYED` artifacts* (no parallel store), with the salvage / display / take-down / slot-and-decor-sink flows that *call* the existing CAS + ledger primitives, the `isOnboardingComplete` Lodge-arrival routing branch, and the one-server bootstrap consolidating the per-step `.server` slices into a single login owner.

**Architecture:** A thin-but-rigorous headless core (pure `TrophyHall` view + four server-authoritative gauntlet handlers + the arrival branch + the count-based slot/decor schema) held to full data-integrity discipline on the salvage path (atomic via `Transaction`, idempotent via the CAS precondition, server-authoritative), plus a large Studio bulk (the consolidated `WorldServer.server.luau`, the Lodge interior, trophy rendering) verified by a manual checklist. **The Trophy Hall stores nothing** — it is `filter(profile.artifacts, DISPLAYED)`. **Step 8 reuses, never reimplements**, `ArtifactStore.transition` (the §4 CAS), `Economy.salvageFloor`, `profile.artifacts`, `Onboarding.isOnboardingComplete`, the `Ledger`, the `Gauntlet`, and `Transaction`.

**Tech Stack:** Luau (`--!strict` headless modules; `.server.luau` Studio glue), Rojo, the headless harness (`tests/run.luau` + `tests/harness.luau`), `./run-tests.sh` as the DoD gate.

## Global Constraints

- **The Trophy Hall is a VIEW, not a store.** `filter(profile.artifacts, disposition == DISPLAYED)`. Persist NO parallel `trophyWall` list. One source of truth: the artifact record + its provenance. (SYS_data_integrity §4; SYS_lodge_trophy §2 / build notes.)
- **Call the CAS; never reimplement disposition.** Mount = `ArtifactStore.transition(profile, id, "HELD", "DISPLAYED")`; take-down = `transition(id, "DISPLAYED", "HELD")`; salvage = `transition(id, "HELD"|"DISPLAYED", "SALVAGED")`. Do NOT touch `ArtifactStore.luau`'s edge set, race defense, or kind-gating. Do NOT build `HELD → ESCROWED` (trading owns escrow → Step 12).
- **Salvage is atomic + idempotent + terminal.** Transition + `salvageFloor` credit commit in ONE `Transaction` (gauntlet `critical = true`); the CAS precondition prevents double-credit; `SALVAGED` has no exit edge.
- **Server-authority throughout.** The client issues intents (`"salvage"`, `"mountTrophy"`, `"buySlot"`, `"placeDecor"`); the server validates + mutates from authoritative state. A client claiming a display, slot, or decor ownership has no route.
- **Slots/decor are `tradeable = false` typed-owned, count/flag based.** No `instanceId`, no `equipped`, no `artifactId` (a slot/decor with an `artifactId` is a build-time schema error). Decor is **balance-free**: there is no stats field, so balance-free *is* the zero-stat guarantee — enforced by identity-only monetization + Cash-priced + `tradeable=false` at load.
- **Every sink is one atomic validated ledger append**, tagged for the evergreen-sink telemetry (the §9 canary: `evergreen-sink share of endgame Cash`).
- **HELD-then-choose holds.** A minted rare stays `HELD`; "Mount it" is a UI beat on top of the unchanged primitive; dismissing it is a no-op; NO auto-display path.
- **Displayed trophies grant NO non-cosmetic benefit, ever.** Pure status.
- `--!strict` clean; Rojo-syncable; **`./run-tests.sh` ALL GREEN** is the headless bar; Steps 1–7 stay green. The one-server bootstrap + Lodge interior + rendering are **Studio**, enumerated honestly (unchecked).
- **Run all commands from the git root `/home/toor/claude/RobloxRPG/RobloxRPG/`** (the nested dir, not the outer wrapper). Branch per step.

## Decisions made where the spec said resolve-or-flag (honor these; they are flagged in the README task)

1. **Slot/decor representation:** a new `PlayerData.lodge: LodgeState = { boughtSlots: number, ownedDecor: {[ItemId]: number}, placements: {DecorPlacement} }`. `boughtSlots` is a plain count (the escalating price keys on it); `ownedDecor` is the count map; `placements` is cosmetic layout. All count/flag based, no `artifactId`. Total slots = `tuning.lodge.baseTrophySlots + boughtSlots`.
2. **Slot economy numbers (flagged as economy's to ratify post-soft-launch, like Step 7's daily amounts):** `Tuning.lodge.baseTrophySlots = 8`, `slotExpansionBase = 5000`, `slotExpansionGrowth = 1.5` (escalating, **uncapped** — no `maxTrophySlots`). `Economy.slotExpansionPrice(config, boughtSlots) = round(base · growth^boughtSlots)`.
3. **Lodge arrival representation:** the Lodge is the hub, NOT a `requiredTier==0` Destination. `Arrival` gains a `kind: "lodge" | "destination"` discriminator; `Shells.lodge = { zoneId, anchor }` is the hub arrival data. A funnel-`COMPLETE` player resolves to the Lodge; a first-time player to the Bayou root (unchanged).
4. **Instancing model (UNRESOLVED — flagged, not silently baked):** MVL builds the player's **own-Lodge** Trophy Hall + all flows (instancing-agnostic). `Tuning.lodge.visitInstancingMode = "ownInstance"`. The visit/social topology (shared-lobby vs visit-on-invite) is deferred to the server-model + moderation pass; recommend shared-lobby + visit-on-invite **after** confirming the mobile render budget. No visit path is built.
5. **Trophy plaque weight-kg is a Studio rendering detail.** The artifact `Provenance` stores `sourceId` + `mintedAt`, not a per-catch weight. The headless `TrophyHall.plaque` exposes what is derivable (what/where/when/rarity/tier from provenance + `targetIndex`); the rendered kg label derives from the source's weight data in Studio.

---

## File Structure

**Create (headless `--!strict`):**
- `src/config/Decor.luau` — the starter MVL decor/theme/framing catalog (Cash-priced, balance-free, `tradeable=false`).
- `src/logic/TrophyHall.luau` — the pure view: `displayed`, `countDisplayed`, `totalSlots`, `slotUsage`, `plaque`.
- `src/server/lodge/SalvageHandler.luau` — the `"salvage"` gauntlet handler (critical; transition→SALVAGED + salvageFloor credit, atomic, idempotent).
- `src/server/lodge/DisplayHandler.luau` — the `"mountTrophy"` / `"takeDownTrophy"` handlers (critical; CAS mount/take-down + slot-capacity gate).
- `src/server/lodge/LodgeShopHandler.luau` — the `"buySlot"` / `"buyDecor"` / `"placeDecor"` handlers (the evergreen Cash sink).
- `tests/Lodge.spec.luau` — `Economy.slotExpansionPrice`; lodge profile fields; decor catalog loads + `assertDecorItem` balance-free rejection.
- `tests/TrophyHall.spec.luau` — the view (filter DISPLAYED, plaque from provenance, slot usage, derived-not-stored).
- `tests/SalvageHandler.spec.luau` — atomic credit, no-orphan, idempotent CAS, DISPLAYED→SALVAGED one transition.
- `tests/DisplayHandler.spec.luau` — mount/take-down, capacity gate, non-trophy reject, no direct trade path.
- `tests/LodgeShopHandler.spec.luau` — slot/decor sink: debit+grant atomic, insufficient-funds no partial, escalating slot price, evergreen-tagged.

**Create (Studio-only `.server.luau`, NOT headless-analyzed):**
- `src/server/world/WorldServer.server.luau` — the consolidated single login owner: ONE `SessionService`, ONE gauntlet registry (every handler registered), the Bayou world + the Lodge interior + service fixtures, both spawners + both flows, arrival placement via `resolveArrival`.

**Modify (headless):**
- `src/types/Enums.luau` — add `DecorKind` (closed-enum-lives-once).
- `src/types/Schema.luau` — add `DecorItem`/`DecorCatalog`, `DecorPlacement`/`LodgeState`, `PlayerData.lodge`, `Config.decor`.
- `src/config/Tuning.luau` — add `Tuning.lodge`.
- `src/config/Validation.luau` — add `assertDecorItem` + validate `config.decor`.
- `src/config/Catalog.luau` — join `Decor` into `Config.decor`.
- `src/logic/Economy.luau` — add `slotExpansionPrice`.
- `src/logic/Profile.luau` — `freshProfile` seeds `lodge`.
- `src/config/Shells.luau` — add `Shells.lodge` (the hub arrival anchor).
- `src/server/ArrivalService.luau` — the `isOnboardingComplete` Lodge branch + the `kind` discriminator.
- `src/server/authority/Replication.luau` — add the `trophyHall` view to the projection.
- `tests/util.luau` — `mkProfile` seeds `lodge`.
- `tests/Arrival.spec.luau` — assert the Lodge branch + `kind`.
- `tests/run.luau` — register the 5 new specs.
- `README.md` — the Step-8 section + module map + deferred table + DoD status.

**Delete (Studio consolidation — these each stand up their own `SessionService`; they cannot coexist):**
- `src/server/world/BayouBlockout.server.luau`
- `src/server/world/HuntingService.server.luau`
- `src/server/world/FishingService.server.luau`

---

## Task 1: Schema + tuning foundation (lodge state, decor types, slot price)

**Files:**
- Modify: `src/types/Enums.luau` (add `DecorKind`)
- Modify: `src/types/Schema.luau` (add `DecorItem`/`DecorCatalog`, `DecorPlacement`/`LodgeState`, `PlayerData.lodge`, `Config.decor`)
- Modify: `src/config/Tuning.luau` (add `Tuning.lodge`)
- Modify: `src/logic/Economy.luau` (add `slotExpansionPrice`)
- Modify: `src/logic/Profile.luau` (`freshProfile` seeds `lodge`)
- Modify: `tests/util.luau` (`mkProfile` seeds `lodge`)
- Test: `tests/Lodge.spec.luau` (new; the slot-price + profile-field half — the decor half lands in Task 2)
- Modify: `tests/run.luau` (register `Lodge.spec`)

**Interfaces:**
- Produces: `Schema.LodgeState`, `Schema.DecorPlacement`, `Schema.DecorItem`, `Schema.DecorCatalog`; `PlayerData.lodge: LodgeState`; `Config.decor: DecorCatalog`; `Enums.DecorKind`; `Tuning.lodge = { baseTrophySlots: number, slotExpansionBase: number, slotExpansionGrowth: number, visitInstancingMode: string }`; `Economy.slotExpansionPrice(config: Config, boughtSlots: number): number`.
- Note: `Config.decor` is referenced by Task 2 (Catalog wiring). This task adds the *type* field; Task 2 populates it. To keep the suite green between tasks, this task also wires a placeholder `decor = {}` into `Catalog.luau` is **NOT** needed — do Task 2's Catalog edit here is avoided; instead, add `decor` to the `Config` type AND wire `Catalog.luau`'s `decor = require(...Decor)` in Task 2. **Between Task 1 and Task 2 the suite will fail to type-check `Catalog` (missing `decor`).** Therefore: in this task, add the `Config.decor` field AND a temporary `decor = {}` in `Catalog.luau` so the suite stays green; Task 2 replaces `{}` with the real catalog. (Documented inline so the reviewer expects it.)

- [ ] **Step 1: Add `DecorKind` to Enums** — `src/types/Enums.luau`, before the final `return table.freeze(Enums)`:

```luau
-- Lodge decor SKU kind (SYS_lodge_trophy §3). A closed set; decor is identity-only, balance-free.
export type DecorKind = "decor" | "theme" | "framing"
Enums.DecorKind = table.freeze({
	decor = "decor" :: DecorKind, -- furniture/wall/lighting/rugs/fixture skins
	theme = "theme" :: DecorKind, -- cohesive room re-skin set (the high-value identity unit)
	framing = "framing" :: DecorKind, -- per-trophy plaque/frame/mount-quality upgrade
})
```

- [ ] **Step 2: Add the decor + lodge types to Schema** — `src/types/Schema.luau`. Add the `DecorKind` type alias near the other enum aliases (after `type RealMoneyKind = Enums.RealMoneyKind`):

```luau
type DecorKind = Enums.DecorKind
```

  After the `EquipmentItem` block (before the `Reward` block), add the decor SKU type:

```luau
-- ─────────────────────────────────────────────────────────────────────────────
-- DecorItem (SYS_lodge_trophy §3 — the evergreen inflation ballast). A typed-owned cosmetic commodity:
-- Cash-priced, balance-free (NO stats field → balance-free by construction; identity-only monetization),
-- tradeable=false (a tradeable decor would be the rare-cosmetic ARTIFACT path — out of scope here / Step 11+).
-- A decor SKU with an artifactId is a build-time schema error (the type carries none).
-- ─────────────────────────────────────────────────────────────────────────────
export type DecorItem = {
	id: ItemId,
	name: string,
	kind: DecorKind,
	cost: Cost, -- the Cash leg (the sink); real-money decor is Step 14, rejected at load by assertDecorItem
	tradeable: boolean, -- MUST be false (typed-owned); asserted at load
	monetizationRoles: { MonetizationRole }, -- identity-only (balance-free); asserted at load
	notes: string,
}
export type DecorCatalog = { [ItemId]: DecorItem }
```

  After the `Provenance`/`Artifact` block (before `LedgerLoop`), add the lodge state types:

```luau
-- ─────────────────────────────────────────────────────────────────────────────
-- Lodge state (Step 8) — the player's count-based typed-owned slots/decor + decor layout. DISTINCT from
-- the instance-based `inventory.commodities` (gear): no instanceId, no equipped, no artifactId. Persisted
-- as part of the whole-profile atomic write (§1 — never split across desyncable keys). The Trophy Hall is
-- NOT here — it is a VIEW over `artifacts` where disposition==DISPLAYED (TrophyHall.luau), never stored.
-- ─────────────────────────────────────────────────────────────────────────────
export type DecorPlacement = { itemId: ItemId, slotKey: string } -- where an owned decor sits (cosmetic-only)
export type LodgeState = {
	boughtSlots: number, -- escalating-price slot expansions purchased; total slots = baseTrophySlots + boughtSlots
	ownedDecor: { [ItemId]: number }, -- count-based typed-owned decor/theme/framing (tradeable=false, no artifactId)
	placements: { DecorPlacement }, -- per-player decor layout (cosmetic; no economy/anti-dupe weight)
}
```

  In `PlayerData`, add the `lodge` field (after `daily: DailyState,`):

```luau
	-- ── Step-8 Lodge state (count-based slots/decor + decor layout; the Trophy Hall is a VIEW, not here) ──
	lodge: LodgeState,
```

  In `Config`, add the decor catalog (after `rankPerks: { RankPerk },`):

```luau
	decor: DecorCatalog,
```

- [ ] **Step 3: Add `Tuning.lodge`** — `src/config/Tuning.luau`, after the `Tuning.economy` block (before `Tuning.vehicles`):

```luau
-- §lodge (Step 8 — SYS_lodge_trophy §2/§3 + economy §9). The Trophy-Hall slot economy + the instancing
-- mode. baseTrophySlots is SYS_lodge_trophy's free baseline (~6–10); the slot price is ESCALATING and
-- UNCAPPED (the unbounded evergreen sink economy §9 requires — no maxTrophySlots). The ABSOLUTE Cash
-- numbers are economy's to ratify post-soft-launch (same deferral as Step 7's daily amounts); the MODEL
-- (escalating, uncapped) is fixed here. visitInstancingMode is the FLAGGED open decision (own-instance vs
-- shared-lobby vs visit-on-invite) — MVL builds own-Lodge only; the visit topology is deferred to the
-- server-model + moderation pass (README), never silently baked.
Tuning.lodge = table.freeze({
	baseTrophySlots = 8, -- free baseline display slots at Lodge start (tune vs first-expansion timing)
	slotExpansionBase = 5000, -- Cash cost of the 1st bought slot (illustrative; economy ratifies)
	slotExpansionGrowth = 1.5, -- each expansion costs growth× the previous — escalating, uncapped
	visitInstancingMode = "ownInstance", -- FLAGGED: own-Lodge MVL; shared-lobby/visit-on-invite deferred
})
```

- [ ] **Step 4: Add `Economy.slotExpansionPrice`** — `src/logic/Economy.luau`, after `salvageFloor` (before the daily-quest section):

```luau
-- §9 evergreen sink (Step 8): the Cash cost of the (boughtSlots+1)-th Trophy-Hall display slot. ESCALATING
-- and UNCAPPED (the unbounded inflation-ballast property) — base · growth^boughtSlots. Integer Cash (no
-- float drift). The absolute numbers are economy's to ratify; the escalating-uncapped shape is fixed.
function M.slotExpansionPrice(config: Config, boughtSlots: number): number
	local l = config.tuning.lodge
	return round(l.slotExpansionBase * l.slotExpansionGrowth ^ boughtSlots)
end
```

- [ ] **Step 5: Seed `lodge` in `freshProfile`** — `src/logic/Profile.luau`, in the returned table, after `daily = { ... },`:

```luau
		-- Step 8: a new player starts with the free baseline slots (derived: base + 0 bought), no decor, empty layout.
		lodge = { boughtSlots = 0, ownedDecor = {}, placements = {} },
```

- [ ] **Step 6: Seed `lodge` in the test profile builder** — `tests/util.luau`, in the returned table, after `daily = { ... },`:

```luau
		lodge = { boughtSlots = 0, ownedDecor = {}, placements = {} },
```

- [ ] **Step 7: Add a temporary `decor = {}` to Catalog so the suite stays green between Task 1 and Task 2** — `src/config/Catalog.luau`, in the `Catalog: Config = { ... }` literal, add (after `rankPerks = RankPerks,`):

```luau
	decor = {}, -- TEMP (Task 1): replaced by the real Decor catalog in Task 2; keeps Config complete meanwhile
```

- [ ] **Step 8: Write the failing test** — create `tests/Lodge.spec.luau`:

```luau
--!strict
-- Step 8 (Lodge & Trophy Hall) — the count-based slot/decor SCHEMA + the escalating slot-expansion price.
-- (The decor CATALOG load + the balance-free assertion are added in Task 2; the Trophy Hall view, the
-- salvage/display/sink flows, and the arrival branch have their own specs.)

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Economy = require("@src/logic/Economy")
local Profile = require("@src/logic/Profile")

return function(t: Harness.T)
	t.section("Lodge — freshProfile + mkProfile seed the count-based lodge state (slots 0, no decor, empty layout)")
	do
		local fresh = Profile.freshProfile(Catalog)
		t.ok("freshProfile has lodge state", fresh.lodge ~= nil)
		t.eq("no bought slots at start", fresh.lodge.boughtSlots, 0)
		t.eq("no owned decor at start", next(fresh.lodge.ownedDecor), nil)
		t.eq("empty decor layout at start", #fresh.lodge.placements, 0)
		local mk = Util.mkProfile(Catalog, {})
		t.ok("mkProfile also carries lodge state", mk.lodge ~= nil and mk.lodge.boughtSlots == 0)
	end

	t.section("Lodge — slotExpansionPrice is escalating + uncapped (base · growth^boughtSlots)")
	do
		t.eq("the 1st bought slot (boughtSlots 0) = base 5000", Economy.slotExpansionPrice(Catalog, 0), 5000)
		t.eq("the 2nd (boughtSlots 1) = round(5000·1.5) = 7500", Economy.slotExpansionPrice(Catalog, 1), 7500)
		t.eq("the 3rd (boughtSlots 2) = round(5000·1.5^2) = 11250", Economy.slotExpansionPrice(Catalog, 2), 11250)
		t.ok("strictly escalating (each costs more than the last — the unbounded sink)",
			Economy.slotExpansionPrice(Catalog, 5) > Economy.slotExpansionPrice(Catalog, 4))
	end
end
```

- [ ] **Step 9: Register the spec** — `tests/run.luau`, add to the `specs` table (after the Step-7 block):

```luau
	-- Step 8 (Lodge & Trophy Hall)
	require("@tests/Lodge.spec"),
```

- [ ] **Step 10: Run the suite + strict check**

Run: `./run-tests.sh 2>&1 | tail -20`
Expected: ALL GREEN ✓ (Steps 1–7 unchanged; the new Lodge section passes; `decor = {}` keeps `Config` complete).

- [ ] **Step 11: Commit**

```bash
cd /home/toor/claude/RobloxRPG/RobloxRPG
git add -A && git commit -m "Step 8 (1/10): lodge schema + tuning + slotExpansionPrice

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Decor catalog + balance-free validation

**Files:**
- Create: `src/config/Decor.luau`
- Modify: `src/config/Validation.luau` (add `assertDecorItem` + validate `config.decor`)
- Modify: `src/config/Catalog.luau` (replace `decor = {}` with the real catalog)
- Modify: `tests/Lodge.spec.luau` (add the catalog-load + balance-free-rejection sections)

**Interfaces:**
- Consumes: `Schema.DecorItem`/`DecorCatalog`, `Enums.DecorKind`, `Enums.MonetizationRole` (Task 1).
- Produces: `Decor` (the catalog, an `{[ItemId]: DecorItem}`); `Validation.assertDecorItem(d: DecorItem)`; `Config.decor` populated.

- [ ] **Step 1: Write the failing test** — append to `tests/Lodge.spec.luau` inside the `return function(t)` body, and add the `Validation` require at the top:

  Add the require at the top (with the other requires):

```luau
local Validation = require("@src/config/Validation")
local Enums = require("@src/types/Enums")
```

  Append these sections:

```luau
	t.section("Decor — the catalog loads, is non-empty, and every SKU is Cash-priced + balance-free")
	do
		local n = 0
		for id, d in Catalog.decor do
			n += 1
			t.ok(id .. ": id matches the key", d.id == id)
			t.ok(id .. ": Cash-priced (no real-money decor at MVL — Step 14)", (d.cost :: any).cash ~= nil)
			t.ok(id .. ": typed-owned (tradeable=false)", d.tradeable == false)
		end
		t.ok("the starter MVL decor catalog is non-empty (the sink must function)", n > 0)
	end

	t.section("Decor — assertDecorItem rejects a NON-balance-free SKU (the existing cosmetic discipline)")
	do
		t.errs("a decor with a non-identity (power-progression) role is rejected at load", function()
			Validation.assertDecorItem({
				id = "decor_bad", name = "Bad", kind = Enums.DecorKind.decor,
				cost = { cash = 100 }, tradeable = false,
				monetizationRoles = { Enums.MonetizationRole.powerProgression }, notes = "illegal",
			})
		end)
		t.errs("a real-money-priced decor is rejected here (real-money decor is Step 14)", function()
			Validation.assertDecorItem({
				id = "decor_rm", name = "RM", kind = Enums.DecorKind.decor,
				cost = { realMoney = { kind = Enums.RealMoneyKind.gamepass } }, tradeable = false,
				monetizationRoles = { Enums.MonetizationRole.identity }, notes = "illegal here",
			})
		end)
		t.errs("a tradeable decor is rejected here (tradeable = the rare-cosmetic artifact path)", function()
			Validation.assertDecorItem({
				id = "decor_tr", name = "Tr", kind = Enums.DecorKind.decor,
				cost = { cash = 100 }, tradeable = true,
				monetizationRoles = { Enums.MonetizationRole.identity }, notes = "illegal here",
			})
		end)
	end
```

- [ ] **Step 2: Run to verify it fails**

Run: `luau tests/run.luau 2>&1 | grep -iE "Lodge|assertDecorItem|decor" | head` then `./run-tests.sh 2>&1 | tail -5`
Expected: failures / strict-check errors — `Catalog.decor` is empty (`n > 0` fails) and `Validation.assertDecorItem` does not exist yet.

- [ ] **Step 3: Add `assertDecorItem` + validate `config.decor`** — `src/config/Validation.luau`. After `assertRankPerkCategory` (before `assertArtifact`), add:

```luau
-- Decor balance-free guarantee (SYS_lodge_trophy §3 / EQUIPMENT_MASTER §6 — extends the cosmetic check).
-- A DecorItem has NO stats/accessGrant/tierInput field, so balance-free is by construction; this enforces
-- the rest: identity-ONLY monetization, Cash-priced (real-money decor is Step 14), tradeable=false (a
-- tradeable cosmetic routes to the rare-cosmetic ARTIFACT path, not the typed-owned sink). The runtime
-- assertion also guards data-driven / LiveOps-added decor SKUs.
function V.assertDecorItem(d: DecorItem)
	assert((d.cost :: any).cash ~= nil, d.id .. ": decor must be Cash-priced (real-money decor is Step 14)")
	assert(d.tradeable == false, d.id .. ": Step-8 decor is the typed-owned path (tradeable=false; a tradeable cosmetic is the artifact path)")
	for _, role in d.monetizationRoles do
		assert(Enums.MonetizationRoleSet[role] == true, d.id .. ": illegal monetization role '" .. tostring(role) .. "'")
		assert(role == Enums.MonetizationRole.identity, d.id .. ": decor is identity-only / balance-free (the zero-stat guarantee)")
	end
end
```

  Add the `DecorItem` type alias near the top type aliases (after `type Artifact = Schema.Artifact`):

```luau
type DecorItem = Schema.DecorItem
```

  In `validateConfig`, after the `rankPerks` loop (before the Destinations block), add:

```luau
	for _, d in config.decor do
		V.assertDecorItem(d)
	end
```

- [ ] **Step 4: Create the decor catalog** — `src/config/Decor.luau`:

```luau
--!strict
-- DECOR catalog (Step 8) — the starter MVL Lodge decor/theme/framing SKUs: SYS_economy §9's PRIMARY
-- evergreen inflation ballast. Cash-priced, balance-free (identity-only monetization; NO stats field),
-- tradeable=false typed-owned commodities. This is the SEED catalog; the ongoing SKU cadence is the LiveOps
-- SLA (Step 13, SYS_liveops_calendar) and the full table is EQUIPMENT_MASTER §4.9's. A malformed SKU fails
-- the require via Catalog → Validation.assertDecorItem.

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")
local Ids = require("@src/types/Ids")

type DecorItem = Schema.DecorItem
local K = Enums.DecorKind
local M = Enums.MonetizationRole

local function cash(n: number): Schema.Cost
	return { cash = n }
end

local rows: { DecorItem } = {
	{
		id = "decor_rustic_rug" :: Ids.ItemId,
		name = "Rustic Bayou Rug",
		kind = K.decor,
		cost = cash(500),
		tradeable = false,
		monetizationRoles = { M.identity },
		notes = "Standard Cash-priced floor decor; identity only.",
	},
	{
		id = "decor_lantern_set" :: Ids.ItemId,
		name = "Hanging Lantern Set",
		kind = K.decor,
		cost = cash(750),
		tradeable = false,
		monetizationRoles = { M.identity },
		notes = "Wall/lighting decor; identity only.",
	},
	{
		id = "theme_bayou_cabin" :: Ids.ItemId,
		name = "Rustic Bayou Cabin Theme",
		kind = K.theme,
		cost = cash(6000),
		tradeable = false,
		monetizationRoles = { M.identity },
		notes = "Cohesive room re-skin — the high-value identity unit; the natural regional/seasonal drop.",
	},
	{
		id = "theme_alaska_lodge" :: Ids.ItemId,
		name = "Alaska Expedition Lodge Theme",
		kind = K.theme,
		cost = cash(9000),
		tradeable = false,
		monetizationRoles = { M.identity },
		notes = "Cohesive room re-skin; identity only.",
	},
	{
		id = "framing_brass_plaque" :: Ids.ItemId,
		name = "Brass Trophy Plaque",
		kind = K.framing,
		cost = cash(1200),
		tradeable = false,
		monetizationRoles = { M.identity },
		notes = "Per-trophy framing upgrade — spend on a trophy you already own; additive flair, never a fix for a cheap default.",
	},
	{
		id = "framing_mythic_frame" :: Ids.ItemId,
		name = "Mythic Display Frame",
		kind = K.framing,
		cost = cash(3000),
		tradeable = false,
		monetizationRoles = { M.identity },
		notes = "Premium per-trophy frame; identity only.",
	},
}

local catalog: { [Ids.ItemId]: DecorItem } = {}
for _, d in rows do
	if catalog[d.id] ~= nil then
		error("Decor: duplicate decor id '" .. d.id .. "'")
	end
	catalog[d.id] = d
end

return catalog
```

- [ ] **Step 5: Wire the real catalog into Catalog** — `src/config/Catalog.luau`. Add the require (with the other config requires):

```luau
local Decor = require("@src/config/Decor")
```

  Replace the temporary `decor = {},` line in the `Catalog: Config = { ... }` literal with:

```luau
	decor = Decor,
```

- [ ] **Step 6: Run the suite**

Run: `./run-tests.sh 2>&1 | tail -20`
Expected: ALL GREEN ✓ (the decor catalog loads + self-validates; the three balance-free rejections pass via `t.errs`; the negative fixtures still fail as required).

- [ ] **Step 7: Commit**

```bash
cd /home/toor/claude/RobloxRPG/RobloxRPG
git add -A && git commit -m "Step 8 (2/10): decor catalog + balance-free validation

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: The Trophy Hall view (a query, not a structure)

**Files:**
- Create: `src/logic/TrophyHall.luau`
- Test: `tests/TrophyHall.spec.luau`
- Modify: `tests/run.luau` (register `TrophyHall.spec`)

**Interfaces:**
- Consumes: `Schema.PlayerData`/`Artifact`/`Config`, `Enums.Disposition`, `config.targetIndex`, `config.creatures`/`config.fish`.
- Produces:
  - `TrophyHall.displayed(profile: PlayerData): { Artifact }` — `filter(artifacts, DISPLAYED)`, deterministic order by `artifactId`.
  - `TrophyHall.countDisplayed(profile: PlayerData): number`
  - `TrophyHall.totalSlots(profile: PlayerData, config: Config): number` — `baseTrophySlots + boughtSlots`.
  - `TrophyHall.slotUsage(profile, config): { used: number, total: number }`
  - `TrophyHall.Plaque` type + `TrophyHall.plaque(config: Config, artifact: Artifact): Plaque` — provenance-derived (what/where/when/loop/tier/rarity); weight-kg is Studio.
- Used by: `DisplayHandler` (Task 5, slot-capacity gate via `countDisplayed`/`totalSlots`), `Replication` (Task 8, the projection's `trophyHall` view).

- [ ] **Step 1: Write the failing test** — create `tests/TrophyHall.spec.luau`:

```luau
--!strict
-- Step 8 — the Trophy Hall is a VIEW over disposition==DISPLAYED artifacts, NOT a stored structure. These
-- assert: the filter returns exactly the displayed set; the plaque reads the artifact's provenance (one
-- source of truth, never re-entered); slot usage is derived; and there is NO parallel "trophyWall" list on
-- the profile (the wall is computed, never persisted).

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local ArtifactStore = require("@src/server/artifacts/ArtifactStore")
local TrophyHall = require("@src/logic/TrophyHall")

return function(t: Harness.T)
	local function mintTrophy(p, idGen, sourceId, now)
		return ArtifactStore.mint(p, { kind = "trophy", tradeable = true, owner = "u1", sourceId = sourceId, validatingEventId = "ev" }, idGen, now)
	end

	t.section("TrophyHall — displayed() is filter(artifacts, DISPLAYED); HELD/SALVAGED are not on the wall")
	do
		local p = Util.mkProfile(Catalog, {})
		local idGen = Fakes.newIdGenerator()
		local a = mintTrophy(p, idGen, "bayou_white_alligator", 1000) -- Legendary hunting
		local b = mintTrophy(p, idGen, "bayou_leviathan", 1001) -- Mythic fishing
		mintTrophy(p, idGen, "bayou_leucistic_wood_duck", 1002) -- stays HELD
		t.eq("nothing displayed at mint (held-then-choose)", TrophyHall.countDisplayed(p), 0)
		assert(ArtifactStore.transition(p, a.artifactId, "HELD", "DISPLAYED").ok)
		assert(ArtifactStore.transition(p, b.artifactId, "HELD", "DISPLAYED").ok)
		local wall = TrophyHall.displayed(p)
		t.eq("exactly the two DISPLAYED trophies are on the wall", #wall, 2)
		t.ok("both wall entries have DISPLAYED disposition", wall[1].disposition == "DISPLAYED" and wall[2].disposition == "DISPLAYED")
		-- take one down → it leaves the view immediately (re-render from authoritative state)
		assert(ArtifactStore.transition(p, a.artifactId, "DISPLAYED", "HELD").ok)
		t.eq("taking one down removes it from the view (no stale wall)", TrophyHall.countDisplayed(p), 1)
	end

	t.section("TrophyHall — the plaque reads the artifact's provenance (one source of truth, not re-entered)")
	do
		local p = Util.mkProfile(Catalog, {})
		local idGen = Fakes.newIdGenerator()
		local a = mintTrophy(p, idGen, "bayou_leviathan", 4242) -- Mythic fishing
		assert(ArtifactStore.transition(p, a.artifactId, "HELD", "DISPLAYED").ok)
		local pl = TrophyHall.plaque(Catalog, a)
		t.eq("what: the source species name (from the catalog, via provenance.sourceId)", pl.what, Catalog.fish["bayou_leviathan"].name)
		t.eq("where: the source's home Destination (derived, not stored on the wall)", pl.where, "bayou")
		t.eq("when: the artifact's mintedAt (provenance, not re-entered)", pl.when, 4242)
		t.eq("loop derived from the target index", pl.loop, "Fishing")
		t.eq("rarity derived from the target index", pl.rarity, "Mythic")
	end

	t.section("TrophyHall — slot usage is derived (base + bought); the wall is NOT a persisted list")
	do
		local p = Util.mkProfile(Catalog, {})
		local idGen = Fakes.newIdGenerator()
		t.eq("total slots = baseTrophySlots + boughtSlots (8 + 0)", TrophyHall.totalSlots(p, Catalog), 8)
		p.lodge.boughtSlots = 2
		t.eq("buying 2 slots raises the total to 10", TrophyHall.totalSlots(p, Catalog), 10)
		local a = mintTrophy(p, idGen, "bayou_white_alligator", 1)
		assert(ArtifactStore.transition(p, a.artifactId, "HELD", "DISPLAYED").ok)
		local usage = TrophyHall.slotUsage(p, Catalog)
		t.ok("slotUsage reports used/total from authoritative state", usage.used == 1 and usage.total == 10)
		t.ok("the profile has NO parallel trophyWall structure (the wall is a view, not a store)", (p :: any).trophyWall == nil and (p.lodge :: any).trophyWall == nil)
	end
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `luau tests/run.luau 2>&1 | tail -5`
Expected: error — `TrophyHall` module does not exist.

- [ ] **Step 3: Create the view module** — `src/logic/TrophyHall.luau`:

```luau
--!strict
-- THE TROPHY HALL AS A VIEW (SYS_lodge_trophy §2 / build notes; SYS_data_integrity §4). The Hall stores
-- NOTHING: it is filter(profile.artifacts, disposition == DISPLAYED). The one authoritative record per
-- trophy is the artifact + its provenance — there is no parallel "trophyWall" list, hence no desync/dupe
-- surface between inventory and wall. Display/un-display/salvage are §4 CAS transitions (ArtifactStore);
-- this module only READS state. Pure: zero content literals, zero mutation.

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")

type PlayerData = Schema.PlayerData
type Artifact = Schema.Artifact
type Config = Schema.Config

local M = {}

local D = Enums.Disposition

-- displayed(profile): the wall — every artifact whose disposition == DISPLAYED, in a deterministic order
-- (by artifactId) so the render is stable. Computed, never stored.
function M.displayed(profile: PlayerData): { Artifact }
	local ids: { string } = {}
	for id, a in profile.artifacts do
		if a.disposition == D.DISPLAYED then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	local out: { Artifact } = {}
	for _, id in ids do
		table.insert(out, profile.artifacts[id])
	end
	return out
end

function M.countDisplayed(profile: PlayerData): number
	local n = 0
	for _, a in profile.artifacts do
		if a.disposition == D.DISPLAYED then
			n += 1
		end
	end
	return n
end

-- totalSlots = baseTrophySlots + boughtSlots (derived; uncapped — no maxTrophySlots at MVL).
function M.totalSlots(profile: PlayerData, config: Config): number
	return config.tuning.lodge.baseTrophySlots + profile.lodge.boughtSlots
end

export type SlotUsage = { used: number, total: number }
function M.slotUsage(profile: PlayerData, config: Config): SlotUsage
	return { used = M.countDisplayed(profile), total = M.totalSlots(profile, config) }
end

-- The provenance plaque (what / where / when / loop / tier / rarity), READ from the artifact's provenance +
-- the target index — never re-entered or stored on the wall (one source of truth). The rendered weight-kg
-- label is a Studio concern (derived from the source species' weight data); Provenance carries sourceId +
-- mintedAt, not a per-catch weight. Fields are nil when provenance.sourceId is absent (a non-source mint).
export type Plaque = {
	what: string?, -- the source creature/fish name
	where: string?, -- the source's home DestinationId
	when: number?, -- mintedAt (server time)
	loop: Enums.Loop?,
	tier: number?,
	rarity: Enums.Rarity?,
}
function M.plaque(config: Config, artifact: Artifact): Plaque
	local sid = artifact.provenance.sourceId
	local idx = if sid ~= nil then config.targetIndex[sid] else nil
	local what: string? = nil
	if sid ~= nil then
		local c = config.creatures[sid]
		local f = config.fish[sid]
		what = if c ~= nil then c.name elseif f ~= nil then f.name else nil
	end
	return {
		what = what,
		where = if idx ~= nil then idx.destinationId else nil,
		when = artifact.provenance.mintedAt,
		loop = if idx ~= nil then idx.loop else nil,
		tier = if idx ~= nil then idx.tier else nil,
		rarity = if idx ~= nil then idx.rarity else nil,
	}
end

return M
```

- [ ] **Step 4: Register the spec** — `tests/run.luau`, in the Step-8 block:

```luau
	require("@tests/TrophyHall.spec"),
```

- [ ] **Step 5: Run the suite**

Run: `./run-tests.sh 2>&1 | tail -20`
Expected: ALL GREEN ✓.

- [ ] **Step 6: Commit**

```bash
cd /home/toor/claude/RobloxRPG/RobloxRPG
git add -A && git commit -m "Step 8 (3/10): Trophy Hall view (filter DISPLAYED; plaque from provenance; no parallel store)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: The salvage flow (the data-integrity-critical headless piece)

**Files:**
- Create: `src/server/lodge/SalvageHandler.luau`
- Test: `tests/SalvageHandler.spec.luau`
- Modify: `tests/run.luau` (register `SalvageHandler.spec`)

**Interfaces:**
- Consumes: `Gauntlet.IntentHandler`/`Ctx` (factory shape from `ShopHandler`), `ArtifactStore.transition`, `Economy.salvageFloor`, `Ledger.applyEntry`, `config.targetIndex`, `Types.IdGenerator`/`Telemetry`.
- Produces: `SalvageHandler.new(deps: { idGen: Types.IdGenerator, telemetry: Types.Telemetry? }): Gauntlet.IntentHandler` — intent `"salvage"`, payload `{ artifactId: string }`, `critical = true`.

- [ ] **Step 1: Write the failing test** — create `tests/SalvageHandler.spec.luau`:

```luau
--!strict
-- Step 8 — salvage a trophy: ONE atomic operation (transition → SALVAGED + salvageFloor Cash credit, in one
-- Transaction). The CAS precondition makes it idempotent (no double-credit on a re-salvage / a concurrently
-- escrowed artifact); SALVAGED is terminal; DISPLAYED → SALVAGED is the §4 atomic un-display-then-salvage.
-- Reuses the Step-6 no-orphan proof shape (a forced save failure leaves the artifact un-salvaged + no Cash).

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local Ledger = require("@src/server/ledger/Ledger")
local Economy = require("@src/logic/Economy")
local ArtifactStore = require("@src/server/artifacts/ArtifactStore")
local Gauntlet = require("@src/server/authority/Gauntlet")
local SalvageHandler = require("@src/server/lodge/SalvageHandler")

return function(t: Harness.T)
	local function newReg(): Gauntlet.Registry
		local reg = Gauntlet.new()
		Gauntlet.register(reg, SalvageHandler.new({ idGen = Fakes.newIdGenerator(), telemetry = Fakes.newTelemetry() }))
		return reg
	end
	local function deps(saveOk: boolean): Gauntlet.Deps
		return { config = Catalog, now = 100, saveFn = function() return saveOk end, markDirty = function() end, telemetry = Fakes.newTelemetry() }
	end
	local function handle(p: any, payload: any, saveOk: boolean): Gauntlet.HandleResult
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		return Gauntlet.handle(newReg(), { intent = "salvage", playerId = 1, payload = payload }, session, deps(saveOk))
	end
	local function mintTrophy(p, sourceId)
		return ArtifactStore.mint(p, { kind = "trophy", tradeable = true, owner = "u1", sourceId = sourceId, validatingEventId = "ev" }, Fakes.newIdGenerator(), 1)
	end
	-- the expected credit for a Legendary hunting trophy (bayou_white_alligator), computed from the primitive
	local function expectedFloor(sourceId: string): number
		local idx = Catalog.targetIndex[sourceId]
		return Economy.salvageFloor(Catalog, idx.tier, idx.rarity, idx.loop)
	end

	t.section("Salvage — credits salvageFloor + transitions HELD→SALVAGED, atomically")
	do
		local p = Util.mkProfile(Catalog, { ledger = { 100 } })
		local a = mintTrophy(p, "bayou_white_alligator")
		local r = handle(p, { artifactId = a.artifactId }, true)
		t.ok("the salvage succeeds", r.ok)
		t.ok("artifact is SALVAGED + tombstoned (terminal)", p.artifacts[a.artifactId].disposition == "SALVAGED" and p.artifacts[a.artifactId].tombstoned == true)
		t.ok("it left the owned set", p.inventory.artifactIds[a.artifactId] == nil)
		t.eq("Cash credited the (low) salvage floor", Ledger.balanceOf(p.cash), 100 + expectedFloor("bayou_white_alligator"))
	end

	t.section("Salvage — atomic: a failed write-through leaves the artifact un-salvaged AND no Cash (no orphan)")
	do
		local p = Util.mkProfile(Catalog, { ledger = { 100 } })
		local a = mintTrophy(p, "bayou_white_alligator")
		local r = handle(p, { artifactId = a.artifactId }, false)
		t.ok("a failed persist returns persist_failed", r.ok == false and r.reason == "persist_failed")
		t.ok("artifact reverted to HELD, NOT tombstoned (no orphan transition)", p.artifacts[a.artifactId].disposition == "HELD" and p.artifacts[a.artifactId].tombstoned == false)
		t.ok("still in the owned set", p.inventory.artifactIds[a.artifactId] == true)
		t.eq("no Cash credited (no orphan credit)", Ledger.balanceOf(p.cash), 100)
	end

	t.section("Salvage — idempotent: re-salvaging a SALVAGED artifact fails the CAS precondition (no double-credit)")
	do
		local p = Util.mkProfile(Catalog, { ledger = { 100 } })
		local a = mintTrophy(p, "bayou_white_alligator")
		t.ok("first salvage succeeds", handle(p, { artifactId = a.artifactId }, true).ok)
		local balAfterFirst = Ledger.balanceOf(p.cash)
		local r2 = handle(p, { artifactId = a.artifactId }, true)
		t.ok("the re-salvage is rejected (already salvaged / tombstoned)", r2.ok == false)
		t.eq("NO double-credit", Ledger.balanceOf(p.cash), balAfterFirst)
	end

	t.section("Salvage — DISPLAYED → SALVAGED is ONE atomic transition (un-display-then-salvage)")
	do
		local p = Util.mkProfile(Catalog, { ledger = { 0 } })
		local a = mintTrophy(p, "bayou_leviathan") -- Mythic fishing
		assert(ArtifactStore.transition(p, a.artifactId, "HELD", "DISPLAYED").ok) -- on the wall
		local r = handle(p, { artifactId = a.artifactId }, true)
		t.ok("salvaging a DISPLAYED trophy succeeds in one transition", r.ok and p.artifacts[a.artifactId].disposition == "SALVAGED")
		t.eq("credited the Mythic salvage floor", Ledger.balanceOf(p.cash), expectedFloor("bayou_leviathan"))
	end

	t.section("Salvage — a non-trophy (escrowable) artifact cannot be salvaged (§4: SALVAGED is Trophy-only)")
	do
		local p = Util.mkProfile(Catalog, { ledger = { 0 } })
		local dog = ArtifactStore.mint(p, { kind = "trackingDog", tradeable = true, owner = "u1", sourceId = "bayou_white_alligator" }, Fakes.newIdGenerator(), 1)
		t.ok("a tracking dog is not salvageable here", handle(p, { artifactId = dog.artifactId }, true).ok == false)
	end
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `luau tests/run.luau 2>&1 | tail -5`
Expected: error — `SalvageHandler` module does not exist.

- [ ] **Step 3: Create the salvage handler** — `src/server/lodge/SalvageHandler.luau`:

```luau
--!strict
-- THE SALVAGE FLOW (Step 8) — the data-integrity-critical Lodge piece. Salvaging a trophy is ONE atomic
-- operation: ArtifactStore.transition(id, HELD|DISPLAYED → SALVAGED) AND a Ledger credit of
-- Economy.salvageFloor(...), wrapped in the gauntlet's `critical` Transaction so BOTH commit or BOTH revert
-- (a forced save failure leaves the artifact un-salvaged and no Cash — the Step-6 no-orphan shape). The CAS
-- precondition is the race/double-spend defense and makes salvage IDEMPOTENT: salvaging an already-SALVAGED
-- (tombstoned) or concurrently-ESCROWED artifact fails the precondition → no double-credit, no double-
-- transition. SALVAGED is terminal. Server-authoritative: the client only names the artifact; the server
-- derives the floor from the artifact's own provenance (never a client-asserted amount).
--
-- This handler CALLS the §4 CAS + the salvage-floor formula — it reimplements neither (SYS_lodge_trophy).

local Schema = require("@src/types/Schema")
local Economy = require("@src/logic/Economy")
local Ledger = require("@src/server/ledger/Ledger")
local ArtifactStore = require("@src/server/artifacts/ArtifactStore")
local Gauntlet = require("@src/server/authority/Gauntlet")
local Enums = require("@src/types/Enums")
local Types = require("@src/server/persistence/Types")

type Ctx = Gauntlet.Ctx
type Artifact = Schema.Artifact

local M = {}

local D = Enums.Disposition

export type SalvageDeps = { idGen: Types.IdGenerator, telemetry: Types.Telemetry? }

-- the two salvageable dispositions (a HELD or a DISPLAYED trophy; ESCROWED is locked in a live trade — §4).
local function salvageableFrom(a: Artifact): Enums.Disposition?
	if a.disposition == D.HELD or a.disposition == D.DISPLAYED then
		return a.disposition
	end
	return nil
end

function M.new(deps: SalvageDeps): Gauntlet.IntentHandler
	return {
		intent = "salvage",
		critical = true, -- the transition + the credit commit atomically (no orphan on a failed write)
		authority = function(ctx: Ctx): (boolean, string?)
			local id = ctx.payload.artifactId
			if type(id) ~= "string" then
				return false, "bad_payload"
			end
			local a = ctx.profile.artifacts[id]
			if a == nil then
				return false, "no_such_artifact"
			end
			if a.tombstoned then
				return false, "already_salvaged" -- idempotency: terminal SALVAGED has no exit
			end
			if a.kind ~= Enums.ArtifactKind.trophy then
				return false, "not_a_trophy" -- §4: SALVAGED is Trophy-only (dogs/mounts/boats live in their homes)
			end
			if salvageableFrom(a) == nil then
				return false, "not_salvageable" -- ESCROWED (a live trade) can't be salvaged
			end
			local sid = a.provenance.sourceId
			if sid == nil or ctx.config.targetIndex[sid] == nil then
				return false, "unresolvable_provenance" -- the floor is derived from the source; it must resolve
			end
			return true, nil
		end,
		commit = function(ctx: Ctx)
			local a = ctx.profile.artifacts[ctx.payload.artifactId]
			local from = assert(salvageableFrom(a), "salvage commit: authority verified salvageable + no yield")
			-- the §4 CAS — this is the un-display-then-salvage (DISPLAYED→SALVAGED) or HELD→SALVAGED, one edge.
			local tr = ArtifactStore.transition(ctx.profile, a.artifactId, from, D.SALVAGED)
			assert(tr.ok, "salvage commit: CAS must succeed (authority verified the precondition; nothing yields)")
			local idx = assert(ctx.config.targetIndex[a.provenance.sourceId :: string], "salvage commit: provenance verified in authority")
			local amount = Economy.salvageFloor(ctx.config, idx.tier, idx.rarity, idx.loop)
			Ledger.applyEntry(ctx.profile.cash, {
				type = "salvage", -- the §3 faucet/sink tag (a faucet: rare value realized at the low floor)
				amount = amount,
				tier = idx.tier,
				loop = idx.loop,
				validatingEventId = deps.idGen.next("salvage"),
			}, ctx.now)
			if deps.telemetry ~= nil then
				deps.telemetry.incr("lodge.salvage:" .. idx.rarity, 1)
			end
		end,
	}
end

return M
```

- [ ] **Step 4: Register the spec** — `tests/run.luau`, in the Step-8 block:

```luau
	require("@tests/SalvageHandler.spec"),
```

- [ ] **Step 5: Run the suite**

Run: `./run-tests.sh 2>&1 | tail -20`
Expected: ALL GREEN ✓ (salvage atomic + idempotent + terminal; no-orphan on failed write; DISPLAYED→SALVAGED one transition; non-trophy rejected).

- [ ] **Step 6: Commit**

```bash
cd /home/toor/claude/RobloxRPG/RobloxRPG
git add -A && git commit -m "Step 8 (4/10): salvage flow (atomic transition+credit, idempotent CAS, terminal)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Display / un-display flows (call the CAS; gate on slot capacity)

**Files:**
- Create: `src/server/lodge/DisplayHandler.luau`
- Test: `tests/DisplayHandler.spec.luau`
- Modify: `tests/run.luau` (register `DisplayHandler.spec`)

**Interfaces:**
- Consumes: `Gauntlet.IntentHandler`/`Ctx`, `ArtifactStore.transition`, `TrophyHall.countDisplayed`/`totalSlots` (Task 3), `Enums.ArtifactKind`/`Disposition`, `Types.Telemetry`.
- Produces:
  - `DisplayHandler.mountHandler(deps: { telemetry: Types.Telemetry? }): Gauntlet.IntentHandler` — intent `"mountTrophy"`, payload `{ artifactId }`, `critical = true`.
  - `DisplayHandler.takeDownHandler(deps): Gauntlet.IntentHandler` — intent `"takeDownTrophy"`, payload `{ artifactId }`, `critical = true`.

- [ ] **Step 1: Write the failing test** — create `tests/DisplayHandler.spec.luau`:

```luau
--!strict
-- Step 8 — mount = HELD→DISPLAYED CAS; take-down = DISPLAYED→HELD CAS. No Cash moves. Slot capacity is a
-- precondition on the mount (a player cannot display more trophies than owned slots — the sink pull). A
-- non-trophy → DISPLAYED is rejected (§4). A DISPLAYED trophy has no direct trade path: it must be taken
-- down first (the take-down-to-trade handoff; escrow/swap is Step 12). These CALL the §4 CAS, never rebuild it.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local ArtifactStore = require("@src/server/artifacts/ArtifactStore")
local TrophyHall = require("@src/logic/TrophyHall")
local Gauntlet = require("@src/server/authority/Gauntlet")
local DisplayHandler = require("@src/server/lodge/DisplayHandler")

return function(t: Harness.T)
	local function newReg(): Gauntlet.Registry
		local reg = Gauntlet.new()
		Gauntlet.register(reg, DisplayHandler.mountHandler({ telemetry = Fakes.newTelemetry() }))
		Gauntlet.register(reg, DisplayHandler.takeDownHandler({ telemetry = Fakes.newTelemetry() }))
		return reg
	end
	local function deps(saveOk: boolean): Gauntlet.Deps
		return { config = Catalog, now = 100, saveFn = function() return saveOk end, markDirty = function() end, telemetry = Fakes.newTelemetry() }
	end
	local function handle(p: any, intent: string, payload: any): Gauntlet.HandleResult
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		return Gauntlet.handle(newReg(), { intent = intent, playerId = 1, payload = payload }, session, deps(true))
	end
	local idGen = Fakes.newIdGenerator()
	local function mintTrophy(p, sourceId)
		return ArtifactStore.mint(p, { kind = "trophy", tradeable = true, owner = "u1", sourceId = sourceId, validatingEventId = "ev" }, idGen, 1)
	end

	t.section("Display — mount HELD→DISPLAYED, take-down DISPLAYED→HELD (no Cash moves; re-render the view)")
	do
		local p = Util.mkProfile(Catalog, {})
		local a = mintTrophy(p, "bayou_white_alligator")
		t.ok("mount succeeds", handle(p, "mountTrophy", { artifactId = a.artifactId }).ok)
		t.eq("the trophy is on the wall", TrophyHall.countDisplayed(p), 1)
		t.ok("take down succeeds → back to HELD", handle(p, "takeDownTrophy", { artifactId = a.artifactId }).ok)
		t.ok("after take-down the trophy is HELD (the take-down-to-trade handoff; escrow is Step 12)", p.artifacts[a.artifactId].disposition == "HELD")
		t.eq("the wall is empty again", TrophyHall.countDisplayed(p), 0)
	end

	t.section("Display — mounting past owned slot capacity is rejected (the sink pull)")
	do
		local p = Util.mkProfile(Catalog, {}) -- baseTrophySlots = 8, boughtSlots = 0 → 8 slots
		local mints = {}
		for i = 1, 9 do
			mints[i] = mintTrophy(p, "bayou_white_alligator")
		end
		for i = 1, 8 do
			t.ok("mount " .. i .. " (within capacity) succeeds", handle(p, "mountTrophy", { artifactId = mints[i].artifactId }).ok)
		end
		t.eq("8 displayed = full", TrophyHall.countDisplayed(p), 8)
		local r = handle(p, "mountTrophy", { artifactId = mints[9].artifactId })
		t.ok("the 9th mount is rejected: slots full (take one down or buy a slot)", r.ok == false and r.reason == "slots_full")
		t.eq("still 8 displayed (no over-capacity display)", TrophyHall.countDisplayed(p), 8)
		-- buying a slot raises capacity → the 9th now mounts
		p.lodge.boughtSlots = 1
		t.ok("with a bought slot (9 total), the 9th mounts", handle(p, "mountTrophy", { artifactId = mints[9].artifactId }).ok)
	end

	t.section("Display — only trophies display (§4): a non-trophy → DISPLAYED is rejected")
	do
		local p = Util.mkProfile(Catalog, {})
		local dog = ArtifactStore.mint(p, { kind = "trackingDog", tradeable = true, owner = "u1" }, idGen, 1)
		t.ok("a tracking dog cannot be mounted in the Trophy Hall", handle(p, "mountTrophy", { artifactId = dog.artifactId }).ok == false)
	end

	t.section("Display — take-down requires a currently-DISPLAYED trophy")
	do
		local p = Util.mkProfile(Catalog, {})
		local a = mintTrophy(p, "bayou_white_alligator") -- HELD
		t.ok("taking down a HELD (not displayed) trophy is rejected", handle(p, "takeDownTrophy", { artifactId = a.artifactId }).ok == false)
	end
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `luau tests/run.luau 2>&1 | tail -5`
Expected: error — `DisplayHandler` module does not exist.

- [ ] **Step 3: Create the display handler** — `src/server/lodge/DisplayHandler.luau`:

```luau
--!strict
-- THE DISPLAY / UN-DISPLAY FLOWS (Step 8). Mount = HELD→DISPLAYED CAS; take-down = DISPLAYED→HELD CAS. No
-- Cash moves; just the §4 transition, then the view re-renders (TrophyHall). `critical` because a disposition
-- change is a write-through trigger (Tuning.criticalSaveTriggers.dispositionTransition). Server-authoritative:
-- the client issues "display W" / "take down W"; the server validates against authoritative state.
--
-- SLOT CAPACITY is a precondition on the mount (TrophyHall: countDisplayed < totalSlots) — a player cannot
-- display more trophies than owned slots; a full wall rejects the mount (take one down or buy a slot → the
-- sink pull). Only trophies display (§4 kind-gating is enforced by the CAS; authority pre-checks for a clean
-- reason). A DISPLAYED trophy is NOT directly tradeable: to trade it the player takes it down (→ HELD) and
-- THEN trading escrows it (HELD→ESCROWED, Step 12) — this handler routes "take down to trade" into take-down;
-- it does NOT build escrow/the swap. These CALL the §4 CAS; they reimplement neither it nor the wall.

local ArtifactStore = require("@src/server/artifacts/ArtifactStore")
local TrophyHall = require("@src/logic/TrophyHall")
local Gauntlet = require("@src/server/authority/Gauntlet")
local Enums = require("@src/types/Enums")
local Types = require("@src/server/persistence/Types")

type Ctx = Gauntlet.Ctx

local M = {}

local D = Enums.Disposition

export type DisplayDeps = { telemetry: Types.Telemetry? }

-- ── mount: HELD → DISPLAYED, gated on slot capacity ───────────────────────────────────────────────────
function M.mountHandler(deps: DisplayDeps): Gauntlet.IntentHandler
	return {
		intent = "mountTrophy",
		critical = true,
		authority = function(ctx: Ctx): (boolean, string?)
			local id = ctx.payload.artifactId
			if type(id) ~= "string" then
				return false, "bad_payload"
			end
			local a = ctx.profile.artifacts[id]
			if a == nil then
				return false, "no_such_artifact"
			end
			if a.tombstoned then
				return false, "tombstoned"
			end
			if a.kind ~= Enums.ArtifactKind.trophy then
				return false, "not_a_trophy" -- §4: only Trophy artifacts display (dogs/mounts/boats have their own homes)
			end
			if a.disposition ~= D.HELD then
				return false, "not_held" -- already displayed, or escrowed in a live trade
			end
			if TrophyHall.countDisplayed(ctx.profile) >= TrophyHall.totalSlots(ctx.profile, ctx.config) then
				return false, "slots_full" -- the capacity constraint = the monetization lever (buy a slot / take one down)
			end
			return true, nil
		end,
		commit = function(ctx: Ctx)
			local tr = ArtifactStore.transition(ctx.profile, ctx.payload.artifactId, D.HELD, D.DISPLAYED)
			assert(tr.ok, "mount commit: authority verified HELD + trophy + capacity; CAS must succeed")
			if deps.telemetry ~= nil then
				deps.telemetry.incr("lodge.mount", 1)
			end
		end,
	}
end

-- ── take down: DISPLAYED → HELD (the take-down-to-trade handoff; trading owns escrow, Step 12) ───────────
function M.takeDownHandler(deps: DisplayDeps): Gauntlet.IntentHandler
	return {
		intent = "takeDownTrophy",
		critical = true,
		authority = function(ctx: Ctx): (boolean, string?)
			local id = ctx.payload.artifactId
			if type(id) ~= "string" then
				return false, "bad_payload"
			end
			local a = ctx.profile.artifacts[id]
			if a == nil then
				return false, "no_such_artifact"
			end
			if a.disposition ~= D.DISPLAYED then
				return false, "not_displayed"
			end
			return true, nil
		end,
		commit = function(ctx: Ctx)
			local tr = ArtifactStore.transition(ctx.profile, ctx.payload.artifactId, D.DISPLAYED, D.HELD)
			assert(tr.ok, "take-down commit: authority verified DISPLAYED; CAS must succeed")
			if deps.telemetry ~= nil then
				deps.telemetry.incr("lodge.takeDown", 1)
			end
		end,
	}
end

return M
```

- [ ] **Step 4: Register the spec** — `tests/run.luau`, in the Step-8 block:

```luau
	require("@tests/DisplayHandler.spec"),
```

- [ ] **Step 5: Run the suite + strict check**

Run: `./run-tests.sh 2>&1 | tail -25`
Expected: ALL GREEN ✓ (mount/take-down call the CAS; capacity gate rejects the 9th; non-trophy rejected; take-down requires DISPLAYED).

- [ ] **Step 6: Commit**

```bash
cd /home/toor/claude/RobloxRPG/RobloxRPG
git add -A && git commit -m "Step 8 (5/10): display/take-down flows (CAS mount/take-down + slot-capacity gate)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: The slot + decor Cash sink (the inflation ballast)

**Files:**
- Create: `src/server/lodge/LodgeShopHandler.luau`
- Test: `tests/LodgeShopHandler.spec.luau`
- Modify: `tests/run.luau` (register `LodgeShopHandler.spec`)

**Interfaces:**
- Consumes: `Gauntlet.IntentHandler`/`Ctx`, `Economy.slotExpansionPrice` (Task 1), `Ledger.balanceOf`/`attemptDebit`, `config.decor` (Task 2), `Types.IdGenerator`/`Telemetry`.
- Produces:
  - `LodgeShopHandler.buySlotHandler(deps: { idGen, telemetry? }): Gauntlet.IntentHandler` — intent `"buySlot"`, payload `{}`, `critical = true`.
  - `LodgeShopHandler.buyDecorHandler(deps): Gauntlet.IntentHandler` — intent `"buyDecor"`, payload `{ itemId }`, `critical = true`.
  - `LodgeShopHandler.placeDecorHandler(deps): Gauntlet.IntentHandler` — intent `"placeDecor"`, payload `{ itemId, slotKey }`, `critical = false` (cosmetic layout → dirty-flag autosave).

- [ ] **Step 1: Write the failing test** — create `tests/LodgeShopHandler.spec.luau`:

```luau
--!strict
-- Step 8 — the evergreen Cash sink (SYS_economy §9 inflation ballast). Buying a slot (escalating price) or a
-- decor SKU is a normal atomic ledger sink: debit Cash, grant the count-based owned slot/decor, server-
-- authoritative (the client never asserts ownership), tagged for the evergreen-sink telemetry. Insufficient
-- funds rejects with NO partial state; a failed write reverts both (no orphan). Placement is cosmetic layout.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local Ledger = require("@src/server/ledger/Ledger")
local Economy = require("@src/logic/Economy")
local Gauntlet = require("@src/server/authority/Gauntlet")
local LodgeShopHandler = require("@src/server/lodge/LodgeShopHandler")

return function(t: Harness.T)
	local function newReg(): Gauntlet.Registry
		local reg = Gauntlet.new()
		Gauntlet.register(reg, LodgeShopHandler.buySlotHandler({ idGen = Fakes.newIdGenerator(), telemetry = Fakes.newTelemetry() }))
		Gauntlet.register(reg, LodgeShopHandler.buyDecorHandler({ idGen = Fakes.newIdGenerator(), telemetry = Fakes.newTelemetry() }))
		Gauntlet.register(reg, LodgeShopHandler.placeDecorHandler({ idGen = Fakes.newIdGenerator(), telemetry = Fakes.newTelemetry() }))
		return reg
	end
	local function handle(p: any, intent: string, payload: any, saveOk: boolean): Gauntlet.HandleResult
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		local deps: Gauntlet.Deps = { config = Catalog, now = 100, saveFn = function() return saveOk end, markDirty = function() end, telemetry = Fakes.newTelemetry() }
		return Gauntlet.handle(newReg(), { intent = intent, playerId = 1, payload = payload }, session, deps)
	end

	t.section("Sink — buySlot debits the escalating price + grants a count-based slot (server-authoritative)")
	do
		local p = Util.mkProfile(Catalog, { ledger = { 20000 } })
		local r1 = handle(p, "buySlot", {}, true)
		t.ok("the 1st slot buy succeeds", r1.ok)
		t.eq("debited slotExpansionPrice(0) = 5000 (20000 → 15000)", Ledger.balanceOf(p.cash), 15000)
		t.eq("boughtSlots is now 1", p.lodge.boughtSlots, 1)
		local r2 = handle(p, "buySlot", {}, true)
		t.ok("the 2nd slot buy succeeds", r2.ok)
		t.eq("debited the ESCALATING price(1) = 7500 (15000 → 7500)", Ledger.balanceOf(p.cash), 7500)
		t.eq("boughtSlots is now 2", p.lodge.boughtSlots, 2)
	end

	t.section("Sink — buySlot insufficient funds rejects with NO partial state")
	do
		local p = Util.mkProfile(Catalog, { ledger = { 100 } })
		local r = handle(p, "buySlot", {}, true)
		t.ok("rejected: insufficient funds", r.ok == false and r.reason == "insufficient_funds")
		t.eq("no Cash debited", Ledger.balanceOf(p.cash), 100)
		t.eq("no slot granted", p.lodge.boughtSlots, 0)
	end

	t.section("Sink — buySlot is atomic: a failed write reverts the debit + the grant (no orphan)")
	do
		local p = Util.mkProfile(Catalog, { ledger = { 20000 } })
		local r = handle(p, "buySlot", {}, false)
		t.ok("persist_failed", r.ok == false and r.reason == "persist_failed")
		t.eq("Cash reverted", Ledger.balanceOf(p.cash), 20000)
		t.eq("no orphan slot", p.lodge.boughtSlots, 0)
	end

	t.section("Sink — buyDecor debits Cash + grants the count-based owned decor (evergreen-tagged ledger entry)")
	do
		local p = Util.mkProfile(Catalog, { ledger = { 1000 } })
		local r = handle(p, "buyDecor", { itemId = "decor_rustic_rug" }, true)
		t.ok("the decor buy succeeds", r.ok)
		t.eq("debited the rug's Cash price 500 (1000 → 500)", Ledger.balanceOf(p.cash), 500)
		t.eq("owned-decor count for the rug is 1", p.lodge.ownedDecor["decor_rustic_rug"], 1)
		-- the sink is tagged: the ledger tail carries a "decor" sink entry
		local tagged = false
		for _, e in p.cash.tail do
			if e.type == "decor" then
				tagged = true
			end
		end
		t.ok("the ledger entry is tagged 'decor' for the evergreen-sink telemetry", tagged)
	end

	t.section("Sink — buyDecor: unknown SKU + insufficient funds reject cleanly")
	do
		local p = Util.mkProfile(Catalog, { ledger = { 100 } })
		t.ok("an unknown decor id is rejected", handle(p, "buyDecor", { itemId = "decor_nope" }, true).ok == false)
		t.ok("insufficient funds rejected (rug 500 > balance 100)", handle(p, "buyDecor", { itemId = "decor_rustic_rug" }, true).ok == false)
		t.eq("no decor granted on rejection", next(p.lodge.ownedDecor), nil)
	end

	t.section("Sink — placeDecor requires ownership; records the cosmetic layout")
	do
		local p = Util.mkProfile(Catalog, { ledger = { 1000 } })
		t.ok("placing un-owned decor is rejected", handle(p, "placeDecor", { itemId = "decor_rustic_rug", slotKey = "wall_1" }, true).ok == false)
		assert(handle(p, "buyDecor", { itemId = "decor_rustic_rug" }, true).ok)
		t.ok("placing owned decor succeeds", handle(p, "placeDecor", { itemId = "decor_rustic_rug", slotKey = "wall_1" }, true).ok)
		t.eq("one placement recorded", #p.lodge.placements, 1)
		t.ok("the placement points at the owned decor + its layout slot", p.lodge.placements[1].itemId == "decor_rustic_rug" and p.lodge.placements[1].slotKey == "wall_1")
	end
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `luau tests/run.luau 2>&1 | tail -5`
Expected: error — `LodgeShopHandler` module does not exist.

- [ ] **Step 3: Create the lodge sink handler** — `src/server/lodge/LodgeShopHandler.luau`:

```luau
--!strict
-- THE LODGE CASH SINK (Step 8) — SYS_economy §9's PRIMARY evergreen inflation ballast. Buying a slot
-- (slotExpansionPrice, escalating/uncapped) or a decor SKU is a normal atomic ledger sink (the Step-6 buy
-- pattern): debit Cash via the Ledger, grant the COUNT-BASED owned slot/decor, server-authoritative (the
-- client never asserts ownership), tagged for the `evergreen-sink share` telemetry. `critical` → the debit +
-- the grant commit atomically (a failed write reverts both — no orphan). Decor is balance-free (asserted at
-- catalog load — assertDecorItem); here we only transact a Cash-priced SKU. placeDecor is cosmetic layout
-- (no economy/anti-dupe weight) → non-critical (dirty-flag autosave). Real-money decor is Step 14.

local Schema = require("@src/types/Schema")
local Economy = require("@src/logic/Economy")
local Ledger = require("@src/server/ledger/Ledger")
local Gauntlet = require("@src/server/authority/Gauntlet")
local Types = require("@src/server/persistence/Types")

type Ctx = Gauntlet.Ctx
type DecorItem = Schema.DecorItem

local M = {}

export type LodgeShopDeps = { idGen: Types.IdGenerator, telemetry: Types.Telemetry? }

-- ── buy an additional Trophy-Hall display slot (escalating, uncapped — the unbounded sink) ──────────────
function M.buySlotHandler(deps: LodgeShopDeps): Gauntlet.IntentHandler
	return {
		intent = "buySlot",
		critical = true,
		authority = function(ctx: Ctx): (boolean, string?)
			-- uncapped: no maxTrophySlots check (the sink must keep absorbing endgame Cash — §9)
			local price = Economy.slotExpansionPrice(ctx.config, ctx.profile.lodge.boughtSlots)
			if Ledger.balanceOf(ctx.profile.cash) < price then
				return false, "insufficient_funds"
			end
			return true, nil
		end,
		commit = function(ctx: Ctx)
			local price = Economy.slotExpansionPrice(ctx.config, ctx.profile.lodge.boughtSlots)
			local debit = Ledger.attemptDebit(ctx.profile.cash, price, {
				type = "slotExpansion", -- the evergreen-sink ledger tag (§9)
				loop = "none",
				validatingEventId = deps.idGen.next("slot"),
			}, ctx.now)
			assert(debit.ok, "buySlot commit: authority verified affordability and nothing yields, so the debit must succeed")
			ctx.profile.lodge.boughtSlots += 1 -- the count-based grant (no instanceId, no artifactId)
			if deps.telemetry ~= nil then
				deps.telemetry.incr("economy.evergreenSink:slot", 1)
			end
		end,
	}
end

-- ── buy a decor / theme / framing SKU (count-based owned decor) ─────────────────────────────────────────
function M.buyDecorHandler(deps: LodgeShopDeps): Gauntlet.IntentHandler
	local function resolve(ctx: Ctx): DecorItem?
		local itemId = ctx.payload.itemId
		if type(itemId) ~= "string" then
			return nil
		end
		return ctx.config.decor[itemId]
	end
	return {
		intent = "buyDecor",
		critical = true,
		authority = function(ctx: Ctx): (boolean, string?)
			local item = resolve(ctx)
			if item == nil then
				return false, "unknown_decor"
			end
			local cash = (item.cost :: any).cash
			if cash == nil then
				return false, "real_money_not_here" -- real-money decor is Step 14; this is the Cash sink
			end
			if Ledger.balanceOf(ctx.profile.cash) < cash then
				return false, "insufficient_funds"
			end
			return true, nil
		end,
		commit = function(ctx: Ctx)
			local item = assert(resolve(ctx), "buyDecor commit: authority should have caught this")
			local cash = (item.cost :: any).cash :: number
			local debit = Ledger.attemptDebit(ctx.profile.cash, cash, {
				type = "decor", -- the evergreen-sink ledger tag (§9)
				loop = "none",
				validatingEventId = deps.idGen.next("decor"),
			}, ctx.now)
			assert(debit.ok, "buyDecor commit: affordability verified, no yield, debit must succeed")
			ctx.profile.lodge.ownedDecor[item.id] = (ctx.profile.lodge.ownedDecor[item.id] or 0) + 1
			if deps.telemetry ~= nil then
				deps.telemetry.incr("economy.evergreenSink:decor", 1)
			end
		end,
	}
end

-- ── place owned decor in the Lodge layout (cosmetic-only; no economy/anti-dupe weight) ──────────────────
function M.placeDecorHandler(deps: LodgeShopDeps): Gauntlet.IntentHandler
	return {
		intent = "placeDecor",
		critical = false, -- cosmetic layout → the periodic dirty-flag autosave (part of the whole-profile write)
		authority = function(ctx: Ctx): (boolean, string?)
			local itemId = ctx.payload.itemId
			local slotKey = ctx.payload.slotKey
			if type(itemId) ~= "string" or type(slotKey) ~= "string" then
				return false, "bad_payload"
			end
			if (ctx.profile.lodge.ownedDecor[itemId] or 0) < 1 then
				return false, "not_owned" -- the server validates ownership (the client never asserts it)
			end
			return true, nil
		end,
		commit = function(ctx: Ctx)
			local itemId = ctx.payload.itemId :: string
			local slotKey = ctx.payload.slotKey :: string
			-- one placement per layout slotKey (placing replaces what sits there) → no placement dupe surface.
			for _, pl in ctx.profile.lodge.placements do
				if pl.slotKey == slotKey then
					pl.itemId = itemId
					return
				end
			end
			table.insert(ctx.profile.lodge.placements, { itemId = itemId, slotKey = slotKey })
			if deps.telemetry ~= nil then
				deps.telemetry.incr("lodge.placeDecor", 1)
			end
		end,
	}
end

return M
```

- [ ] **Step 4: Register the spec** — `tests/run.luau`, in the Step-8 block:

```luau
	require("@tests/LodgeShopHandler.spec"),
```

- [ ] **Step 5: Run the suite**

Run: `./run-tests.sh 2>&1 | tail -20`
Expected: ALL GREEN ✓ (escalating slot price; insufficient-funds no partial; atomic no-orphan; decor grant + evergreen tag; placement ownership).

- [ ] **Step 6: Commit**

```bash
cd /home/toor/claude/RobloxRPG/RobloxRPG
git add -A && git commit -m "Step 8 (6/10): lodge Cash sink (escalating slot + decor buy/place; evergreen-tagged)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Lodge arrival routing (headless)

**Files:**
- Modify: `src/config/Shells.luau` (add `Shells.lodge` — the hub arrival anchor)
- Modify: `src/server/ArrivalService.luau` (the `isOnboardingComplete` branch + the `kind` discriminator)
- Modify: `tests/Arrival.spec.luau` (assert the Lodge branch + `kind`)

**Interfaces:**
- Consumes: `Onboarding.isOnboardingComplete` (exists), `Schema.Vec3`.
- Produces:
  - `Shells.lodge: { zoneId: string, anchor: Schema.Vec3 }`.
  - `ArrivalService.Arrival = { kind: "lodge" | "destination", destinationId: Ids.DestinationId?, zoneId: string, anchor: Vec3 }` (the `kind` field is new; `destinationId` is now optional — set for `"destination"`, nil for `"lodge"`).
  - `ArrivalService.resolveArrival(profile, shells, config): Arrival` — returns a `"lodge"` arrival when `isOnboardingComplete(profile)`, else the `"destination"` Bayou root.
- Note: `ShellRegistry` (the `shells` param type) gains a `lodge` field. The consolidated bootstrap (Task 9) passes `Shells` (which now carries `.lodge`).

- [ ] **Step 1: Write the failing test** — replace the body of `tests/Arrival.spec.luau` with:

```luau
--!strict
local Harness = require("@tests/harness")
local Catalog = require("@src/config/Catalog")
local Shells = require("@src/config/Shells")
local ArrivalService = require("@src/server/ArrivalService")
local Profile = require("@src/logic/Profile")
local Onboarding = require("@src/logic/Onboarding")
local Enums = require("@src/types/Enums")
local Ids = require("@src/types/Ids")

return function(t: Harness.T)
	t.section("Arrival — a first-time player lands in the Bayou arrival anchor (the gate-less root)")
	local p = Profile.freshProfile(Catalog)
	local a = ArrivalService.resolveArrival(p, Shells, Catalog)
	t.ok("kind is 'destination'", a.kind == "destination")
	t.ok("destination is the Bayou (free-starter, requiredTier 0)", a.destinationId == Ids.Destination.Bayou)
	t.ok("zone is the arrival clearing", a.zoneId == "arrival_clearing")
	local clearing = Shells.byDestination[Ids.Destination.Bayou].zones.arrival_clearing
	t.ok("anchor is the arrival clearing center", a.anchor.x == clearing.center.x and a.anchor.z == clearing.center.z)

	t.section("Arrival — a funnel-COMPLETE player lands in the LODGE (the Step-8 returning-player branch)")
	local p2 = Profile.freshProfile(Catalog)
	-- drive the funnel to COMPLETE the only way it can: authoritative events (no client flag).
	Onboarding.advance(p2, "kill", 1)
	Onboarding.advance(p2, "catch", 2)
	Onboarding.advance(p2, "gearUpgrade", 3)
	Onboarding.advance(p2, "kill", 4)
	Onboarding.advance(p2, "kill", 5)
	Onboarding.advance(p2, "catch", 6)
	Onboarding.advance(p2, "dailyClaim", 7)
	t.ok("the funnel reached COMPLETE", Onboarding.isOnboardingComplete(p2))
	local a2 = ArrivalService.resolveArrival(p2, Shells, Catalog)
	t.ok("kind is 'lodge'", a2.kind == "lodge")
	t.ok("a COMPLETE player is NOT routed to a Destination (the Lodge is the hub, not a Destination)", a2.destinationId == nil)
	t.ok("the Lodge arrival zone + anchor come from Shells.lodge", a2.zoneId == Shells.lodge.zoneId and a2.anchor.z == Shells.lodge.anchor.z)
end
```

  **Verify the LOOP_CONFIRM count first:** `Onboarding.BEATS[LOOP_CONFIRM].requiredCount` is `3` and `completesOn = { kill, catch }`. The sequence above fires `kill, catch, gearUpgrade` (→ FIRST_HUNT→FIRST_CATCH→FIRST_PURCHASE→WORLD_MAP[pass-through]→LOOP_CONFIRM), then `kill, kill, catch` (3 LOOP_CONFIRM events → DAILY_INTRO), then `dailyClaim` (→ COMPLETE). If the spec's counts differ at implementation time, adjust the event list so `isOnboardingComplete(p2)` is true (the assertion guards this).

- [ ] **Step 2: Run to verify it fails**

Run: `luau tests/run.luau 2>&1 | tail -8`
Expected: failures — `a.kind` is nil (no `kind` field yet); `Shells.lodge` is nil; the COMPLETE player still resolves to the Bayou.

- [ ] **Step 3: Add the Lodge hub anchor to Shells** — `src/config/Shells.luau`. After `Shells.movement = movement` (before `byDestination`), add:

```luau
-- The Lodge hub arrival (Step 8). The Lodge is the player's home HUB, NOT a requiredTier-0 Destination, so
-- it does not live in `byDestination`/the gate DAG — it is its own arrival target the routing branch returns
-- for a funnel-COMPLETE (returning) player. The interior + service fixtures are Studio (WorldServer); this is
-- the headless arrival DATA the router needs. (Positions are plain {x,y,z}; the world converts to Vector3.)
Shells.lodge = { zoneId = "lodge_hub", anchor = v(0, 0, 600) }
```

- [ ] **Step 4: Add the routing branch + the `kind` discriminator** — replace `src/server/ArrivalService.luau` in full:

```luau
--!strict
-- ARRIVAL routing (Step 3 + Step 8). Resolves where a logging-in player spawns. Pure + server-authoritative:
-- the world bootstrap calls SessionService.login (lock + load) and then this to place the character.
--   • A FIRST-TIME player (funnel not COMPLETE) → the free, gate-less ROOT Destination (the Bayou, the
--     onboarding §0 spawn) — UNCONDITIONAL as in Step 3.
--   • A RETURNING player (funnel COMPLETE) → the LODGE (the hub; SYS_lodge_trophy §1 — spawning in and
--     returning from a Destination both land in the Lodge). The Lodge is NOT a Destination, so the result
--     carries kind="lodge" + destinationId=nil; a Destination arrival carries kind="destination".
-- This is the Step-8 routing branch the Step-3 TODO reserved.

local Schema = require("@src/types/Schema")
local Ids = require("@src/types/Ids")
local Shell = require("@src/logic/Shell")
local Onboarding = require("@src/logic/Onboarding")

type PlayerData = Schema.PlayerData
type Config = Schema.Config
type Vec3 = Schema.Vec3
type LodgeArrival = { zoneId: string, anchor: Vec3 }
type ShellRegistry = { byDestination: { [Ids.DestinationId]: Schema.Shell }, lodge: LodgeArrival }

local M = {}

-- A tagged arrival target: the Lodge hub (kind="lodge", no destinationId) or a Destination (kind="destination").
export type Arrival = { kind: "lodge" | "destination", destinationId: Ids.DestinationId?, zoneId: string, anchor: Vec3 }

function M.resolveArrival(profile: PlayerData, shells: ShellRegistry, config: Config): Arrival
	-- Step 8: a returning (funnel-COMPLETE) player lands in the Lodge hub, not the Bayou root.
	if Onboarding.isOnboardingComplete(profile) then
		return { kind = "lodge", destinationId = nil, zoneId = shells.lodge.zoneId, anchor = shells.lodge.anchor }
	end
	-- Otherwise: the free, gate-less root — the requiredTier-0 Destination (derived from data), i.e. the Bayou.
	local rootId: Ids.DestinationId? = nil
	for id, dst in config.destinations do
		if dst.gate.requiredTier == 0 then
			assert(rootId == nil, "ArrivalService: more than one free-starter (requiredTier 0) Destination")
			rootId = id
		end
	end
	local destinationId = assert(rootId, "ArrivalService: no free-starter (requiredTier 0) Destination")
	local shell = assert(shells.byDestination[destinationId], "ArrivalService: no shell for arrival Destination '" .. destinationId .. "'")
	return { kind = "destination", destinationId = destinationId, zoneId = shell.arrivalZoneId, anchor = Shell.arrivalAnchor(shell) }
end

return M
```

- [ ] **Step 5: Run the suite**

Run: `./run-tests.sh 2>&1 | tail -20`
Expected: ALL GREEN ✓ (first-time → Bayou `kind="destination"`; COMPLETE → Lodge `kind="lodge"`).

- [ ] **Step 6: Commit**

```bash
cd /home/toor/claude/RobloxRPG/RobloxRPG
git add -A && git commit -m "Step 8 (7/10): Lodge arrival routing (isOnboardingComplete branch + kind discriminator)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Replication projection — expose the Trophy Hall view server-side

**Files:**
- Modify: `src/server/authority/Replication.luau` (add the `trophyHall` view to the projection)
- Test: extend `tests/TrophyHall.spec.luau` (assert the projection carries the displayed set + slot usage)

**Interfaces:**
- Consumes: `TrophyHall.displayed`/`slotUsage` (Task 3), `Copy.deep`.
- Produces: `Replication.Projection.trophyHall: { displayed: { Schema.Artifact }, slotsUsed: number, slotsTotal: number }` (a read-only deep-copied shadow — the client renders the Hall from this, server-authoritative, never re-derives).
- Note: `Gauntlet.spec` reads only `projection.eht`/`projection.balance` and `projection ~= nil`, so adding a field is safe (verified by re-running the suite).

- [ ] **Step 1: Write the failing test** — append to `tests/TrophyHall.spec.luau` (and add the require at top: `local Replication = require("@src/server/authority/Replication")`):

```luau
	t.section("TrophyHall — the projection exposes the wall as a read-only server-computed shadow")
	do
		local p = Util.mkProfile(Catalog, {})
		local idGen = Fakes.newIdGenerator()
		local a = mintTrophy(p, idGen, "bayou_white_alligator", 1)
		assert(ArtifactStore.transition(p, a.artifactId, "HELD", "DISPLAYED").ok)
		local proj = Replication.buildProjection(p, Catalog)
		t.ok("the projection carries the trophyHall view", proj.trophyHall ~= nil)
		t.eq("one trophy on the projected wall", #proj.trophyHall.displayed, 1)
		t.ok("slot usage is projected (used 1 / total 8)", proj.trophyHall.slotsUsed == 1 and proj.trophyHall.slotsTotal == 8)
		-- it is a copy, not a handle: mutating the shadow changes nothing server-side
		proj.trophyHall.displayed[1].disposition = "HELD"
		t.ok("the projected wall is a deep copy (server state untouched)", p.artifacts[a.artifactId].disposition == "DISPLAYED")
	end
```

- [ ] **Step 2: Run to verify it fails**

Run: `luau tests/run.luau 2>&1 | tail -5`
Expected: failure — `proj.trophyHall` is nil.

- [ ] **Step 3: Extend the projection** — `src/server/authority/Replication.luau`:

  Add the require (with the other requires):

```luau
local TrophyHall = require("@src/logic/TrophyHall")
```

  Add to the `Projection` type (after `gates: { [string]: Gate.GateResult },`):

```luau
	trophyHall: { displayed: { Schema.Artifact }, slotsUsed: number, slotsTotal: number },
```

  In `buildProjection`, before the `return`, compute the view; and add it to the returned table:

```luau
	local usage = TrophyHall.slotUsage(profile, config)
```

  Add to the returned table (after `gates = gates,`):

```luau
		-- the Trophy Hall is a VIEW (filter artifacts, DISPLAYED) — the client renders it from this read-only
		-- shadow; deep-copied so a client edit changes nothing server-side. No parallel structure is persisted.
		trophyHall = { displayed = Copy.deep(TrophyHall.displayed(profile)), slotsUsed = usage.used, slotsTotal = usage.total },
```

- [ ] **Step 4: Run the suite (and confirm Gauntlet.spec stays green)**

Run: `./run-tests.sh 2>&1 | tail -20`
Expected: ALL GREEN ✓ — the new projection assertions pass; `Gauntlet.spec` (which reads only `.eht`/`.balance`) is unaffected.

- [ ] **Step 5: Commit**

```bash
cd /home/toor/claude/RobloxRPG/RobloxRPG
git add -A && git commit -m "Step 8 (8/10): replicate the Trophy Hall view in the read-only projection

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: The one-server bootstrap (Studio — the load-bearing consolidation)

> **Studio-only, NOT headless-analyzed/tested.** The bar is **exactly one login owner + every handler on one shared registry**, verified by the Studio checklist. The headless `SessionService` logic is UNCHANGED (Step 2 is verified) — this is `.server` wiring/ownership only. The "test" here is: `rojo build` succeeds and the headless suite stays green (the deleted files were excluded from it anyway).

**Files:**
- Create: `src/server/world/WorldServer.server.luau`
- Delete: `src/server/world/BayouBlockout.server.luau`, `src/server/world/HuntingService.server.luau`, `src/server/world/FishingService.server.luau`

**Interfaces:**
- Consumes (all already built): `SessionService`, `Gauntlet`, `FireHandler`, `EquipHandler`, `CatchHandler`, `ShopHandler`, `ClaimDailyHandler`, `SalvageHandler`, `DisplayHandler`, `LodgeShopHandler`, `ArrivalService` (now returns `kind`), `Shells` (now has `.lodge`), `Catalog`, `Spawning`, `Spawner`, `Combat`, `Fishing`, `Onboarding`, `RobloxAdapters`.

- [ ] **Step 1: Delete the three per-step bootstrap slices**

```bash
cd /home/toor/claude/RobloxRPG/RobloxRPG
git rm src/server/world/BayouBlockout.server.luau src/server/world/HuntingService.server.luau src/server/world/FishingService.server.luau
```

- [ ] **Step 2: Create the consolidated bootstrap** — `src/server/world/WorldServer.server.luau`. This file ASSEMBLES the proven glue from the three deleted files (the Bayou world build, the hunting spawner + fire flow, the fishing spawner + cast flow) under ONE `SessionService` + ONE `Gauntlet` registry, adds the Lodge interior placeholder + service fixtures, and places the player via `resolveArrival` (Lodge vs Bayou). Reuse the deleted files' bodies verbatim where noted; the ONLY substantive changes are: (a) one shared `sessionService` + one shared `registry` created ONCE at the top; (b) every handler registered on that one registry; (c) the Lodge build + the `kind`-aware arrival placement.

```luau
--!nonstrict
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- STUDIO-ONLY (NOT headless-analyzed). THE ONE RUNNABLE SERVER (Step 8 bootstrap consolidation). Before
-- Step 8 each per-step slice (BayouBlockout / HuntingService / FishingService) stood up its OWN
-- SessionService + gauntlet registry "self-contained for the slice" — they CANNOT coexist (multiple login
-- locks on one profile). This file is the single login owner: ONE SessionService, ONE shared gauntlet
-- registry into which hunting, fishing, the shop, the daily, and the salvage/display/decor handlers all
-- register; it builds the Bayou world + the Lodge interior + the service fixtures, runs both spawners +
-- both flows, and places the player via resolveArrival (Lodge for a returning player, Bayou for a first-
-- time player). The headless SessionService LOGIC is unchanged (Step 2 verified) — this is wiring only.
-- BAR: exactly ONE login lock per profile (Studio checklist) — verify no double-lock in a running session.
--
-- The Bayou world build, the hunting spawner/fire flow, and the fishing spawner/cast flow are the proven
-- glue from the deleted per-step slices, reassembled here on the shared substrate.
-- ════════════════════════════════════════════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local Lighting = game:GetService("Lighting")

-- headless modules (require-by-string via .luaurc; Rojo + Roblox resolve at runtime)
local Catalog = require("@src/config/Catalog")
local Shells = require("@src/config/Shells")
local Spawning = require("@src/config/Spawning")
local Spawner = require("@src/logic/Spawner")
local Combat = require("@src/logic/Combat")
local Fishing = require("@src/logic/Fishing")
local Onboarding = require("@src/logic/Onboarding")
local Gauntlet = require("@src/server/authority/Gauntlet")
local FireHandler = require("@src/server/combat/FireHandler")
local CatchHandler = require("@src/server/fishing/CatchHandler")
local EquipHandler = require("@src/server/authority/handlers/EquipHandler")
local ShopHandler = require("@src/server/shop/ShopHandler")
local ClaimDailyHandler = require("@src/server/daily/ClaimDailyHandler")
local SalvageHandler = require("@src/server/lodge/SalvageHandler")
local DisplayHandler = require("@src/server/lodge/DisplayHandler")
local LodgeShopHandler = require("@src/server/lodge/LodgeShopHandler")
local SessionService = require("@src/server/SessionService")
local ArrivalService = require("@src/server/ArrivalService")
local Adapters = require("@src/server/RobloxAdapters")

local BAYOU = "bayou"
local shell = Shells.byDestination[BAYOU]
local movement = Shells.movement
local huntingSpawn = Spawning.byDestination[BAYOU].hunting
local fishingSpawn = Spawning.byDestination[BAYOU].fishing

local function vec(p)
	return Vector3.new(p.x, p.y, p.z)
end

-- ── THE ONE SHARED SUBSTRATE: one telemetry sink, one idGen, one SessionService, one gauntlet registry ──
local idGen = Adapters.idGenerator(HttpService)
local telemetry = Adapters.telemetry(function(metric, value)
	-- TODO(ops): forward to AnalyticsService. Step-8 metrics to surface here + in the handlers: the §9 canary
	-- `evergreen-sink share of endgame Cash` (economy.evergreenSink:slot/decor vs total endgame Cash), first-
	-- trophy-display rate / time-to-first-mount (lodge.mount), slot-expansion purchase curve, take-down-to-
	-- trade rate (lodge.takeDown), Lodge-visit / in-Lodge session time (the co-op-hub signal — Studio).
end)
local sessionService = SessionService.new({
	store = Adapters.dataStore(DataStoreService:GetDataStore("WildWorld_Profiles_v1")),
	clock = Adapters.clock(),
	config = Catalog,
	serverId = (game.JobId ~= "" and game.JobId) or "studio",
	telemetry = telemetry,
})

-- ONE shared registry — every system's handler registers here (no second SessionService, no second registry).
local registry = Gauntlet.new()
Gauntlet.register(registry, FireHandler.new({ idGen = idGen, telemetry = telemetry }))
Gauntlet.register(registry, CatchHandler.new({ idGen = idGen, telemetry = telemetry }))
Gauntlet.register(registry, EquipHandler)
Gauntlet.register(registry, ShopHandler.buyHandler({ idGen = idGen, telemetry = telemetry }))
Gauntlet.register(registry, ShopHandler.upgradeHandler({ idGen = idGen, telemetry = telemetry }))
Gauntlet.register(registry, ClaimDailyHandler.new({ telemetry = telemetry }))
Gauntlet.register(registry, SalvageHandler.new({ idGen = idGen, telemetry = telemetry }))
Gauntlet.register(registry, DisplayHandler.mountHandler({ telemetry = telemetry }))
Gauntlet.register(registry, DisplayHandler.takeDownHandler({ telemetry = telemetry }))
Gauntlet.register(registry, LodgeShopHandler.buySlotHandler({ idGen = idGen, telemetry = telemetry }))
Gauntlet.register(registry, LodgeShopHandler.buyDecorHandler({ idGen = idGen, telemetry = telemetry }))
Gauntlet.register(registry, LodgeShopHandler.placeDecorHandler({ idGen = idGen, telemetry = telemetry }))

-- shared gauntlet deps for a given player (the write-through + dirty-flag wiring used by every handler)
local function gauntletDeps(plr)
	return {
		config = Catalog,
		now = os.time(),
		saveFn = function()
			return SessionService.saveNow(sessionService, plr.UserId)
		end,
		markDirty = function()
			SessionService.markDirty(sessionService, plr.UserId)
		end,
		telemetry = telemetry,
	}
end

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- THE BAYOU WORLD (the proven BayouBlockout glue — placeholder shell from the validated Shells config)
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
local world = Instance.new("Folder")
world.Name = "BayouShell_Placeholder"
world.Parent = workspace

local function part(name, size, position, color, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Anchored = true
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or world
	return p
end

part("Ground", Vector3.new(420, 2, 520), Vector3.new(0, -1, 100), Color3.fromRGB(74, 92, 56))

local zonesFolder = Instance.new("Folder")
zonesFolder.Name = "Zones"
zonesFolder.Parent = world
for id, z in shell.zones do
	local isWater = z.kind == "fishing" or z.kind == "rareSite"
	local pad = part(z.name, Vector3.new(z.size.x, 0.4, z.size.z), vec(z.center) + Vector3.new(0, 0.2, 0), isWater and Color3.fromRGB(55, 85, 105) or Color3.fromRGB(96, 116, 64), zonesFolder)
	pad.Material = isWater and Enum.Material.Glass or Enum.Material.Grass
	pad.Transparency = isWater and 0.3 or 0
	pad:SetAttribute("zoneId", id)
	pad:SetAttribute("zoneKind", z.kind)
end

part("OldCypress_Beacon", Vector3.new(8, 80, 8), vec(shell.landmarks.the_old_cypress.anchor) + Vector3.new(0, 40, 0), Color3.fromRGB(60, 50, 40))
part("TheLanding_Shack", Vector3.new(24, 12, 18), vec(shell.landmarks.the_landing.anchor) + Vector3.new(0, 6, 0), Color3.fromRGB(110, 90, 70))
part("Outfitter_Anchor", Vector3.new(4, 8, 4), vec(shell.vendorOutpostAnchor) + Vector3.new(-8, 4, 0), Color3.fromRGB(150, 120, 90))
part("TackleShop_Anchor", Vector3.new(4, 8, 4), vec(shell.vendorOutpostAnchor) + Vector3.new(8, 4, 0), Color3.fromRGB(90, 120, 150))
part("TravelSignpost_Anchor", Vector3.new(2, 10, 2), vec(shell.travelSignpostAnchor) + Vector3.new(0, 5, 6), Color3.fromRGB(120, 100, 60))

local ambFolder = Instance.new("Folder")
ambFolder.Name = "Ambiance"
ambFolder.Parent = world
for speciesId, zoneId in shell.ambiancePlacements do
	local z = shell.zones[zoneId]
	local species = Catalog.creatures[speciesId]
	for i = 1, 4 do
		local a = part(species.name, Vector3.new(1.5, 1.5, 1.5), vec(z.center) + Vector3.new(i * 7 - 14, 1, i * 5 - 12), Color3.fromRGB(220, 220, 200), ambFolder)
		a:SetAttribute("ambianceOnly", true)
		a:SetAttribute("speciesId", speciesId)
	end
end

local arrivalClearing = shell.zones[shell.arrivalZoneId]
local levee = shell.zones.sunny_levee.center
local bayouSpawn = Instance.new("SpawnLocation")
bayouSpawn.Name = "BayouArrival"
bayouSpawn.Anchored = true
bayouSpawn.Enabled = false -- placement is driven by resolveArrival below, not by auto-spawn
bayouSpawn.Size = Vector3.new(12, 1, 12)
bayouSpawn.Color = Color3.fromRGB(120, 130, 90)
bayouSpawn.CFrame = CFrame.lookAt(vec(arrivalClearing.center) + Vector3.new(0, 0.5, 0), Vector3.new(levee.x, 0.5, levee.z))
bayouSpawn.Parent = world

Lighting.FogStart = shell.render.fogStart
Lighting.FogEnd = shell.render.fogEnd
Lighting.FogColor = Color3.fromRGB(150, 160, 130)

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- THE LODGE (Step 8 — the hub interior placeholder + service fixtures). Low-poly placeholder; finished art
-- is the Phase-3 pass. PLACED service points (this doc owns the Trophy Hall; it only PLACES the others):
--   • Outfitter + Tackle Shop  → BUILT (Step 6 handlers) — look-navigable gun rack / tackle bench
--   • Trophy Hall              → BUILT (this step) — the display room (a VIEW over DISPLAYED artifacts)
--   • World Map (Travel Desk)  → Step 9 STUB · Trading Post → Step 12 STUB · Boat Dealer/Kennel → Step 11 STUB
-- The Trophy Hall renders the player's DISPLAYED artifacts (Replication.projection.trophyHall) — rendering
-- the rarity-distinct mounts + provenance plaques is the Studio checklist. Visit/social topology is FLAGGED
-- (own-Lodge only at MVL; Tuning.lodge.visitInstancingMode).
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
local lodge = Instance.new("Folder")
lodge.Name = "Lodge_Placeholder"
lodge.Parent = workspace
local lodgeAnchor = vec(Shells.lodge.anchor)
part("Lodge_Floor", Vector3.new(80, 1, 80), lodgeAnchor + Vector3.new(0, -0.5, 0), Color3.fromRGB(96, 78, 60), lodge)
local lodgeSpawn = Instance.new("SpawnLocation")
lodgeSpawn.Name = "LodgeArrival"
lodgeSpawn.Anchored = true
lodgeSpawn.Enabled = false
lodgeSpawn.Size = Vector3.new(10, 1, 10)
lodgeSpawn.Color = Color3.fromRGB(120, 100, 80)
lodgeSpawn.Position = lodgeAnchor + Vector3.new(0, 0.5, 0)
lodgeSpawn.Parent = lodge

-- the placed service fixtures (look-navigable per 00 §2 legibility; built vs stubbed labelled honestly)
local function fixture(name, offset, color, status)
	local f = part(name, Vector3.new(6, 8, 6), lodgeAnchor + offset, color, lodge)
	f:SetAttribute("service", name)
	f:SetAttribute("status", status) -- "built" | "stub" → the UI reads it as ready vs "coming soon"
	return f
end
fixture("Outfitter", Vector3.new(-30, 4, -20), Color3.fromRGB(150, 120, 90), "built")
fixture("TackleShop", Vector3.new(-30, 4, 0), Color3.fromRGB(90, 120, 150), "built")
fixture("TrophyHall", Vector3.new(0, 4, -30), Color3.fromRGB(180, 150, 70), "built")
fixture("TravelDesk_WorldMap", Vector3.new(30, 4, -20), Color3.fromRGB(120, 110, 80), "stub") -- Step 9
fixture("TradingPost", Vector3.new(30, 4, 0), Color3.fromRGB(110, 130, 110), "stub") -- Step 12
fixture("BoatDealer", Vector3.new(30, 4, 20), Color3.fromRGB(90, 110, 140), "stub") -- Step 11
fixture("KennelAndStable", Vector3.new(-30, 4, 20), Color3.fromRGB(130, 110, 90), "stub") -- Step 11

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- THE HUNTING SPAWNER + FIRE FLOW (the proven HuntingService glue, on the SHARED registry)
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
local targetsFolder = Instance.new("Folder")
targetsFolder.Name = "HuntingTargets"
targetsFolder.Parent = workspace
local liveTargets = {}

local function spawnTarget(creatureId, zoneId)
	local creature = Catalog.creatures[creatureId]
	local zone = shell.zones[zoneId]
	local model = Instance.new("Model")
	model.Name = creature.name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(3, 3, 4)
	root.Anchored = true
	root.Color = creature.behavior == "aggressive" and Color3.fromRGB(120, 70, 60) or Color3.fromRGB(150, 130, 90)
	root.Position = vec(zone.center) + Vector3.new((math.random() - 0.5) * zone.size.x, 1.5, (math.random() - 0.5) * zone.size.z)
	root.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("creatureId", creatureId)
	model:SetAttribute("targetId", creatureId)
	model.Parent = targetsFolder
	liveTargets[model] = { creatureId = creatureId, health = creature.health, accumulated = 0, zoneId = zoneId }
	return model
end

local function despawnTarget(model, respawnAfter)
	local state = liveTargets[model]
	liveTargets[model] = nil
	model:Destroy()
	if state ~= nil and respawnAfter ~= nil then
		task.delay(respawnAfter, function()
			local pool = Spawner.routineTargetsInZone(Catalog, BAYOU, state.zoneId)
			if #pool > 0 then
				spawnTarget(pool[math.random(1, #pool)], state.zoneId)
			end
		end)
	end
end

for zoneId, area in huntingSpawn.areas do
	local pool = Spawner.routineTargetsInZone(Catalog, BAYOU, zoneId)
	if #pool > 0 then
		for _ = 1, area.maxConcurrentTargets do
			spawnTarget(pool[math.random(1, #pool)], zoneId)
		end
	end
end

local function huntWorldState()
	return { time = "dawn or dusk", weather = "fog" } -- TODO(step-13): real time/weather/season/event
end
task.spawn(function()
	while true do
		task.wait(60)
		local w = huntWorldState()
		for id, c in Catalog.creatures do
			if c.destinationId == BAYOU and c.rare ~= nil and c.spawnZones ~= nil then
				if Spawner.rareSpawnEligible(c, w) and math.random(1, c.rare.spawnRate) == 1 then
					spawnTarget(id, c.spawnZones[1])
					telemetry.incr("combat.rare_spawned:" .. id, 1)
				end
			end
		end
	end
end)

local fireRequest = Instance.new("RemoteEvent")
fireRequest.Name = "FireRequest"
fireRequest.Parent = ReplicatedStorage
local lastShotAt = {}

local function zoneOfHit(part_)
	local z = part_:GetAttribute("hitZone")
	return (z == "vital" or z == "limb") and z or "body"
end

fireRequest.OnServerEvent:Connect(function(plr, aimOrigin, aimDirection)
	local session = sessionService.sessions[plr.UserId]
	local char = plr.Character
	if session == nil or char == nil or char.PrimaryPart == nil then
		return
	end
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { char }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local origin = char.PrimaryPart.Position
	local result = workspace:Raycast(origin, aimDirection.Unit * 500, params)
	local now = os.time()
	local rayHitTargetId, distance, zone, model = nil, math.huge, "body", nil
	if result ~= nil then
		model = result.Instance:FindFirstAncestorOfClass("Model")
		if model ~= nil and liveTargets[model] ~= nil then
			rayHitTargetId = model:GetAttribute("targetId")
			distance = (result.Position - origin).Magnitude
			zone = zoneOfHit(result.Instance)
		end
	end
	if rayHitTargetId == nil or model == nil then
		return
	end
	local state = liveTargets[model]
	local payload = {
		targetId = rayHitTargetId, zone = zone, distance = distance, claimedDamage = nil,
		lastShotAt = lastShotAt[plr.UserId] or 0, rayHitTargetId = rayHitTargetId, targetAlive = true,
		accumulatedDamageBefore = state.accumulated, owner = tostring(plr.UserId), partySize = 1,
	}
	local function equippedTierLevel()
		local refs = session.profile.equipped
		for _, c in session.profile.inventory.commodities do
			if c.instanceId == refs.weapon then
				local item = Catalog.equipment[c.catalogId]
				if item then
					return item.tier, Combat.gearLevelOf(c.intraLevel)
				end
			end
		end
		return 0, "entry"
	end
	local tlvl, lvl = equippedTierLevel()
	local shotDmg = Combat.shotDamage(Combat.weaponDamage(Catalog, tlvl, lvl), Combat.zoneMultiplier(Catalog, zone), Combat.rangeFalloff(Catalog, tlvl, distance))
	payload.claimedDamage = shotDmg
	if Combat.fireRateOk(Catalog, payload.lastShotAt, now, Combat.cycleTime(Catalog, tlvl)) then
		lastShotAt[plr.UserId] = now
	end
	if (state.accumulated + shotDmg) >= Catalog.creatures[state.creatureId].health then
		local deps = gauntletDeps(plr)
		deps.now = now
		local r = Gauntlet.handle(registry, { intent = "fire", playerId = plr.UserId, payload = payload }, session, deps)
		if r.ok then
			despawnTarget(model, huntingSpawn.areas[state.zoneId] and huntingSpawn.areas[state.zoneId].respawnIntervalSeconds or nil)
			fireRequest:FireClient(plr, "kill", rayHitTargetId, r.projection)
			-- TODO(Studio feel): hit-stop/impact/audio/haptics; the rare clean-kill flourish fires here when
			-- the kill minted an artifact → then the "Mount it in the Trophy Hall" auto-prompt (autoPromptOnMint
			-- on; a UI beat — the artifact stays HELD until the player taps; dismissing is a no-op).
		end
	else
		state.accumulated += shotDmg
		fireRequest:FireClient(plr, "hit", rayHitTargetId, shotDmg)
	end
end)

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- THE FISHING SPAWNER + CAST FLOW (the proven FishingService glue, on the SHARED registry)
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
local bitesFolder = Instance.new("Folder")
bitesFolder.Name = "FishingBites"
bitesFolder.Parent = workspace
local liveBites = {}

local function spawnBite(fishId, zoneId)
	local fishDef = Catalog.fish[fishId]
	local zone = shell.zones[zoneId]
	local marker = Instance.new("Part")
	marker.Name = "Bite_" .. fishDef.name
	marker.Shape = Enum.PartType.Ball
	marker.Size = Vector3.new(2, 2, 2)
	marker.Anchored = true
	marker.Transparency = 0.4
	marker.Color = Color3.fromRGB(120, 180, 220)
	marker.Position = vec(zone.center) + Vector3.new((math.random() - 0.5) * zone.size.x, 0.5, (math.random() - 0.5) * zone.size.z)
	marker:SetAttribute("fishId", fishId)
	marker:SetAttribute("targetId", fishId)
	marker.Parent = bitesFolder
	liveBites[marker] = { fishId = fishId, zoneId = zoneId }
	return marker
end

local function depleteBite(marker)
	local state = liveBites[marker]
	liveBites[marker] = nil
	marker:Destroy()
	if state ~= nil then
		local area = fishingSpawn.areas[state.zoneId]
		task.delay(area and area.respawnIntervalSeconds or 30, function()
			local pool = Spawner.routineTargetsInZone(Catalog, BAYOU, state.zoneId, "Fishing")
			if #pool > 0 then
				spawnBite(pool[math.random(1, #pool)], state.zoneId)
			end
		end)
	end
end

for zoneId, area in fishingSpawn.areas do
	local pool = Spawner.routineTargetsInZone(Catalog, BAYOU, zoneId, "Fishing")
	if #pool > 0 then
		for _ = 1, area.maxConcurrentTargets do
			spawnBite(pool[math.random(1, #pool)], zoneId)
		end
	end
end

local function fishWorldState()
	return { time = "night", weather = "storm" } -- TODO(step-13): real time/weather/season/event
end
task.spawn(function()
	while true do
		task.wait(60)
		local w = fishWorldState()
		for id, f in Catalog.fish do
			if f.destinationId == BAYOU and f.rare ~= nil and f.spawnZones ~= nil then
				if Spawner.rareSpawnEligible(f, w) and math.random(1, f.rare.spawnRate) == 1 then
					spawnBite(id, f.spawnZones[1])
					telemetry.incr("fishing.rare_spawned:" .. id, 1)
				end
			end
		end
	end
end)

local castRequest = Instance.new("RemoteEvent")
castRequest.Name = "FishingCast"
castRequest.Parent = ReplicatedStorage
local activeFight = {}

local function equippedReel(profile)
	for _, c in profile.inventory.commodities do
		if c.instanceId == profile.equipped.reel then
			local item = Catalog.equipment[c.catalogId]
			if item then
				return item.tier, Fishing.gearLevelOf(c.intraLevel)
			end
		end
	end
	return 0, "entry"
end

castRequest.OnServerEvent:Connect(function(plr, action, arg)
	local session = sessionService.sessions[plr.UserId]
	if session == nil then
		return
	end
	if action == "fight" then
		local fight = activeFight[plr.UserId]
		if fight == nil or liveBites[fight.marker] == nil then
			return
		end
		local fishId = liveBites[fight.marker].fishId
		local fish = Catalog.fish[fishId]
		local reelTier, reelLevel = equippedReel(session.profile)
		local E = math.clamp(tonumber(arg) or 0, 0, 1)
		local drain = Fishing.reelDrainMax(Catalog, reelTier, reelLevel) * E
		fight.accumulated += drain
		if fight.accumulated >= Fishing.staminaToLand(Catalog, fish) then
			local payload = {
				targetId = fishId, biteActive = true, E = E, claimedDrain = drain,
				accumulatedStaminaBefore = fight.accumulated - drain, owner = tostring(plr.UserId), partySize = 1,
			}
			local deps = gauntletDeps(plr)
			local r = Gauntlet.handle(registry, { intent = "catch", playerId = plr.UserId, payload = payload }, session, deps)
			if r.ok then
				depleteBite(fight.marker)
				castRequest:FireClient(plr, "landed", fishId, r.projection)
				-- TODO(Studio feel): land animation, weighty haptic resolve; on a rare mint, the clean-catch
				-- flourish → the "Mount it" auto-prompt (the artifact stays HELD until tapped).
			end
			activeFight[plr.UserId] = nil
		else
			castRequest:FireClient(plr, "fightProgress", fishId, fight.accumulated)
		end
		return
	end
	if action == "cast" then
		local nearest = nil
		for marker in liveBites do
			activeFight[plr.UserId] = { marker = marker, accumulated = 0 }
			nearest = marker
			break
		end
		if nearest ~= nil then
			castRequest:FireClient(plr, "bite", liveBites[nearest].fishId)
		end
	end
end)

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- LOGIN → ARRIVAL PLACEMENT (kind-aware) + the non-lethal clamp + the funnel first-spawn guarantees
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
local FIRST_HUNT_AREA = "sunny_levee"
local FIRST_FISH_AREA = "channel_banks"

local function guardHumanoid(hum)
	hum.HealthChanged:Connect(function(h)
		if Catalog.tuning.combat.nonLethalDestinations[BAYOU] and h < Catalog.tuning.combat.nonLethalMinHP then
			hum.Health = Catalog.tuning.combat.nonLethalMinHP
		end
	end)
end

local function placeCharacter(plr, char)
	local session = sessionService.sessions[plr.UserId]
	if session == nil then
		return
	end
	-- the Step-8 routing branch: a returning (funnel-COMPLETE) player lands in the Lodge, a first-time player
	-- in the Bayou root. ONE login owner resolves this — no second SessionService anywhere.
	local arrival = ArrivalService.resolveArrival(session.profile, Shells, Catalog)
	if char.PrimaryPart ~= nil then
		char:PivotTo(CFrame.new(vec(arrival.anchor) + Vector3.new(0, 3, 0)))
	end
end

local function guaranteeFirstSpawns(plr)
	local session = sessionService.sessions[plr.UserId]
	if session == nil then
		return
	end
	if Onboarding.firstSpawnEligible(Catalog, session.profile, BAYOU, FIRST_HUNT_AREA, "Hunting") then
		local pool = Spawner.routineTargetsInZone(Catalog, BAYOU, FIRST_HUNT_AREA, "Hunting")
		if #pool > 0 then
			spawnTarget(pool[1], FIRST_HUNT_AREA)
		end
	end
	if Onboarding.firstSpawnEligible(Catalog, session.profile, BAYOU, FIRST_FISH_AREA, "Fishing") then
		local pool = Spawner.routineTargetsInZone(Catalog, BAYOU, FIRST_FISH_AREA, "Fishing")
		if #pool > 0 then
			spawnBite(pool[1], FIRST_FISH_AREA)
		end
	end
end

Players.PlayerAdded:Connect(function(plr)
	pcall(function()
		SessionService.login(sessionService, plr.UserId) -- THE single login lock (lock + load via Step 2)
	end)
	plr.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid")
		hum.WalkSpeed = movement.walkSpeed
		hum.JumpPower = movement.jumpPower
		guardHumanoid(hum)
		placeCharacter(plr, char)
		guaranteeFirstSpawns(plr)
	end)
end)
Players.PlayerRemoving:Connect(function(plr)
	activeFight[plr.UserId] = nil
	pcall(function()
		SessionService.logout(sessionService, plr.UserId)
	end)
end)
game:BindToClose(function()
	for _, plr in Players:GetPlayers() do
		pcall(function()
			SessionService.logout(sessionService, plr.UserId)
		end)
	end
end)

print("[WildWorld] WorldServer online — ONE login owner; handlers:", (function()
	local n = 0
	for _ in registry.handlers do
		n += 1
	end
	return n
end)(), "· Bayou + Lodge built")
```

  **Implementation note (verify against the real modules while wiring):** confirm the helper names used above exist with these signatures — `Combat.gearLevelOf`, `Combat.weaponDamage`, `Combat.zoneMultiplier`, `Combat.rangeFalloff`, `Combat.fireRateOk`, `Combat.cycleTime`, `Combat.shotDamage`; `Fishing.gearLevelOf`, `Fishing.reelDrainMax`, `Fishing.staminaToLand`; `Spawner.routineTargetsInZone`, `Spawner.rareSpawnEligible`; `SessionService.saveNow`/`markDirty`/`login`/`logout`/`.sessions`. They are copied verbatim from the deleted slices (which used them), so they resolve — but this file is `--!nonstrict` and Studio-only, so the headless gate does not check it. If `RobloxAdapters.telemetry`/`idGenerator`/`clock`/`dataStore` signatures differ, match the deleted files' exact calls.

- [ ] **Step 3: Confirm the project still syncs + the headless suite is unaffected**

Run: `./run-tests.sh 2>&1 | tail -25`
Expected: ALL GREEN ✓ — gate 4 `rojo build` succeeds with the new `WorldServer.server.luau` and the three deleted files gone; gates 1–3 are unchanged (these `.server.luau` files were never in the headless set). Also confirm the Studio-only listing shows only `WorldServer.server.luau` + `CharacterController.client.luau`:

Run: `find src client \( -name '*.server.luau' -o -name '*.client.luau' \) | sort`
Expected: exactly `client/CharacterController.client.luau` and `src/server/world/WorldServer.server.luau`.

- [ ] **Step 4: Commit**

```bash
cd /home/toor/claude/RobloxRPG/RobloxRPG
git add -A && git commit -m "Step 8 (9/10): consolidate per-step slices into ONE WorldServer bootstrap (single login owner)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: README + docs (the honest split) and the final gate

**Files:**
- Modify: `README.md` (the Step-8 section; module map; deferred table; DoD status; the headline assertion count)

**Interfaces:** none (documentation).

- [ ] **Step 1: Add the Step-8 bullet to the intro list** — `README.md`, after the Step 7 bullet (before the source-of-truth blockquote):

```markdown
- **Step 8 — The Lodge & Trophy Hall.** A **thin-but-rigorous headless core** + a **large Studio bulk**. The
  Trophy Hall is a **VIEW, not a store** — `filter(profile.artifacts, DISPLAYED)`, no parallel list, no
  desync/dupe surface. Step 8 builds the **flows that CALL the existing primitives** (it reimplements none):
  **salvage** (the §4 CAS `→ SALVAGED` + the `salvageFloor` credit, in one `Transaction` — atomic,
  idempotent via the CAS precondition, terminal), **display / take-down** (the `HELD↔DISPLAYED` CAS, gated on
  owned **slot capacity**), the **slot + decor Cash sink** (the economy's §9 evergreen inflation ballast —
  escalating/uncapped slots + a balance-free decor catalog), and the **Lodge arrival routing** (a
  funnel-`COMPLETE` player returns to the Lodge; a first-time player to the Bayou root). The **one-server
  bootstrap** consolidates the per-step `.server` slices into a single login owner. **The flows are
  headless-proven; the bootstrap, the Lodge interior, trophy rendering, the "Mount it" prompt, decor
  placement, and the visit/social path are Studio** — split honestly below.
```

- [ ] **Step 2: Update the module map** — `README.md`, in the `## Module map` block, add under `logic/`:

```
           · TrophyHall (Step 8 — the VIEW: filter(artifacts, DISPLAYED); plaque from provenance; slot usage; NO parallel store)
           · Economy (+ Step-8 slotExpansionPrice: the escalating/uncapped evergreen-sink slot price)
```

  add under `config/`:

```
           · Decor (Step 8 — the starter MVL decor/theme/framing catalog; Cash-priced, balance-free, tradeable=false; self-validates)
```

  add a `lodge/` group under `server/` (after the `daily/` block):

```
    lodge/
      SalvageHandler.luau     (Step 8) the "salvage" intent — §4 CAS →SALVAGED + salvageFloor credit, one Transaction (critical, atomic, idempotent, terminal)
      DisplayHandler.luau     (Step 8) "mountTrophy"/"takeDownTrophy" — HELD↔DISPLAYED CAS + slot-capacity gate (critical; no Cash)
      LodgeShopHandler.luau   (Step 8) "buySlot"/"buyDecor" (the evergreen Cash sink, evergreen-tagged) + "placeDecor" (cosmetic layout)
```

  replace the three `world/` lines (`BayouBlockout`/`HuntingService`/`FishingService`) with:

```
    world/WorldServer.server.luau   ⌂ STUDIO-ONLY (Step 8) — THE ONE login owner: one SessionService + one shared gauntlet registry (every handler), Bayou + Lodge build, both spawners + flows, kind-aware arrival
```

  and update the `tests/` line to append the Step-8 specs:

```
         Step 8: Lodge/TrophyHall/SalvageHandler/DisplayHandler/LodgeShopHandler)
```

- [ ] **Step 3: Add the Step-8 section** — `README.md`, after the `## Step 7 …` section (before `## Deferred — who owns what`):

```markdown
## Step 8 — the Lodge & Trophy Hall (view-not-store; call-don't-reimplement; the bar is split, honestly)

The single most important property: **the Trophy Hall is a VIEW, not a store** — `filter(profile.artifacts,
disposition == DISPLAYED)`. There is **no parallel `trophyWall` list** to keep in sync, hence no
desync/dupe surface between inventory and wall (SYS_data_integrity §4). The plaque (what/where/when) reads
the artifact's **provenance** — one source of truth, never re-entered. The second property: Step 8 **CALLS
the existing primitives, it reimplements none** — `ArtifactStore.transition` (the §4 CAS), `Economy.salvageFloor`,
`profile.artifacts`, `Onboarding.isOnboardingComplete`, the `Ledger`, the `Gauntlet`, `Transaction`.

**Schema additions (Step 8 owns):** a count-based `PlayerData.lodge = { boughtSlots, ownedDecor, placements }`
— typed-owned slots/decor (no `instanceId`/`equipped`/`artifactId`), distinct from the instance-based gear
`commodities`; a `Config.decor` catalog (`Decor.luau`); `Tuning.lodge` (`baseTrophySlots = 8`, the
escalating/uncapped `slotExpansionPrice`, `visitInstancingMode`); and a Lodge **arrival representation**
(`Shells.lodge` + a `kind: "lodge" | "destination"` discriminator on `Arrival`) — the Lodge is the hub, NOT
a `requiredTier==0` Destination, so it does not fit the shell/gate model.

**Headless-proven (the flows + the sink — full discipline on the salvage path):**
- **Salvage** — `transition(HELD|DISPLAYED → SALVAGED)` + a `salvageFloor` credit commit in **one
  `Transaction`** (a forced save failure leaves the artifact **un-salvaged AND no Cash** — no orphan); a
  re-salvage of a SALVAGED/escrowed artifact **fails the CAS precondition → no double-credit**; `SALVAGED`
  is terminal; `DISPLAYED → SALVAGED` is **one** atomic transition. Server derives the floor from the
  artifact's own provenance (never a client amount).
- **Display / un-display** — `mountTrophy` (HELD→DISPLAYED) and `takeDownTrophy` (DISPLAYED→HELD) call the
  CAS and re-render; **mounting past owned slot capacity is rejected** (`slots_full` — the sink pull); a
  non-Trophy `→ DISPLAYED` is rejected (§4 kind-gating); a DISPLAYED trophy has **no direct trade path**
  (take it down first — escrow/swap is Step 12).
- **Trophy Hall view** — `TrophyHall.displayed(profile) = filter(artifacts, DISPLAYED)` with provenance read
  from the artifact record; **no parallel structure persisted** (a test asserts the wall is derived, not
  stored); also exposed read-only in `Replication.projection.trophyHall` (the client renders from the
  server-computed shadow; a client edit changes nothing).
- **Slot/decor sink** — `buySlot` (escalating, **uncapped** `slotExpansionPrice`) and `buyDecor` debit Cash +
  grant the count-based owned slot/decor, **server-validated + atomic + evergreen-tagged** (`slotExpansion`
  / `decor` ledger types; `economy.evergreenSink:*` telemetry — the §9 canary `evergreen-sink share of
  endgame Cash`); **insufficient funds rejects with no partial state**; a decor SKU that is not balance-free
  is **rejected at load** (`assertDecorItem`: identity-only monetization, Cash-priced, `tradeable=false`).
  `placeDecor` records the cosmetic layout (no economy/anti-dupe weight).
- **Arrival routing** — `resolveArrival` returns the **Lodge** for `isOnboardingComplete`, the **Bayou root**
  for a first-time player (a headless branch test).
- Steps 1–7 tests stay green (the artifact CAS + the ledger now carry the salvage/display/sink flows through
  their existing atomic paths).

**Studio / telemetry — NOT headless (the real bar; all unchecked):**
- [ ] **The one-server bootstrap** — a single login/`SessionService` owner with every handler (hunting,
      fishing, shop, daily, salvage/display/decor, world) on **one shared gauntlet registry**; the per-step
      `.server` slices (`BayouBlockout`/`HuntingService`/`FishingService`) consolidated into one runnable
      `WorldServer.server.luau`. **Verify exactly one login lock per profile** in a running session (the
      headless session logic is unchanged; this is the wiring). The deleted slices each stood up their own
      `SessionService` and could not coexist.
- [ ] The Lodge interior renders within mobile budget (low-poly, streamed); service fixtures are
      look-navigable (a gun rack reads as the Outfitter); built-vs-stub fixtures read as ready vs "coming"
      (Trophy Hall/Outfitter/Tackle Shop built; World Map → 9, Trading Post → 12, Boat Dealer/Kennel → 11).
- [ ] A mounted trophy renders with a **rarity-distinct model** (an albino reads white **without a UI
      label**), a provenance plaque (weight-kg/where/when — the **weight-kg label is the Studio render**,
      derived from the source species' weight data; provenance carries sourceId + mintedAt), and rarity
      framing — readable in a screenshot.
- [ ] The **"Mount it" auto-prompt** fires after the rare flourish (`autoPromptOnMint` on) as a UI beat that
      leaves the artifact **HELD until tapped** (dismissing is a no-op; no auto-display path).
- [ ] Decor placement *feels* like making the Lodge yours; the Hall fills as a visible return hook.
- [ ] The **instancing/visit path** (own-Lodge vs shared-lobby vs visit-on-invite) — **not built**; deferred
      to the server-model + moderation pass (see the flag below).
- [ ] `evergreen-sink share` + the display/expansion/visit metrics populate.

**Flagged (resolve-or-flag, not silently baked):**
- **Lodge-visit instancing model — UNRESOLVED.** MVL builds the player's **own-Lodge** Trophy Hall + all
  flows (instancing-agnostic — the content is a view either way; only *who can see it and how* is open).
  `Tuning.lodge.visitInstancingMode = "ownInstance"`. Recommend a **shared Lodge social-lobby**
  (partner-finding) **+ visitable individual Lodges on invite** (the flex) — but **confirm the mobile render
  budget first**. Decide with the server/session model + a moderation pass (13+ audience, visiting
  strangers). No visit/social path is built.
- **`baseTrophySlots` / `slotExpansionPrice` numbers are provisional** (`8` / base `5000` · growth `1.5`) —
  economy ratifies the absolute Cash post-soft-launch (same deferral as Step 7's daily amounts); the
  **model** (escalating, uncapped, no `maxTrophySlots`) is fixed.

**Deferrals (named with their owning step):** trading / `HELD→ESCROWED` / the swap → **Step 12** (Step 8
routes "take down to trade" into take-down and hands off); the World Map / Travel Desk reveal + gated
teleport → **Step 9** (the fixture is placed); Boats / Mounts / Dogs inventories → **Step 11** (fixtures
placed); real-money decor + the **auto-sell game pass** (assert auto-sell-never-salvages-a-trophy where
auto-sell is built) → **Step 14** (decor here is Cash-priced); the ongoing decor/theme/framing catalog
**cadence** → **Step 13** (Step 8 ships the starter MVL catalog + the purchase mechanism); a "show off rare
companions" surface (rare dogs/mounts beyond the Trophy Hall) → deferred (LiveOps / a future Kennel
deep-dive — do **not** overload the Trophy Hall). **Displayed trophies grant no non-cosmetic benefit, ever.**
```

- [ ] **Step 4: Update the Deferred table** — `README.md`, in `## Deferred — who owns what`, update the disposition-flows row and the cosmetics row to reflect Step 8 is now built:

```markdown
| ~~Disposition **flows** (held-then-choose, display, salvage — call the CAS primitive)~~ — **DONE (Step 8)**; remaining: trading's escrow/swap | Step 12 |
| ~~cosmetics & Lodge decor (the evergreen inflation ballast)~~ — **decor catalog + slot/decor Cash sink DONE (Step 8)**; **real-money** decor + the **auto-sell** pass | Step 14 |
```

- [ ] **Step 5: Add the Step-8 DoD status line** — `README.md`, in `## Definition of Done — status`, after the **Step 7** entry:

```markdown
**Step 8:** ✅ (headless) the count-based `lodge` schema + `Decor` catalog (balance-free, self-validating) +
`Tuning.lodge` + `Economy.slotExpansionPrice` (escalating/uncapped); the **Trophy Hall VIEW**
(`filter(artifacts, DISPLAYED)`, plaque from provenance, slot usage, **no parallel store**, exposed in the
projection); the **salvage** flow (CAS `→ SALVAGED` + `salvageFloor` credit in one `Transaction` — atomic,
idempotent via the precondition, terminal; no orphan on a failed write; `DISPLAYED→SALVAGED` one transition);
**display/take-down** (HELD↔DISPLAYED CAS + slot-capacity gate; non-trophy rejected; no direct trade path);
the **slot/decor Cash sink** (escalating slot + balance-free decor buy/place — atomic, evergreen-tagged,
insufficient-funds no partial); the **Lodge arrival branch** (`isOnboardingComplete` → Lodge, else Bayou).
⌂ (Studio, unchecked above) **the one-server bootstrap (verify exactly one login lock)**, the Lodge interior,
trophy rendering, the "Mount it" prompt, decor placement, and the **flagged** visit/social topology
(own-Lodge MVL only). Step 8 **calls** the §4 CAS / `salvageFloor` / `artifacts` — it rebuilds none of them.
```

- [ ] **Step 6: Update the headline assertion count** — `README.md`, the final summary line. First get the new count:

Run: `luau tests/run.luau 2>&1 | grep passed`
Then replace the `**546 assertions pass headless; …**` sentence with the new number (e.g. `**NNN assertions pass headless; both negative fixtures fail analysis as required; rojo build produces a place.**`). Also update the `# Wild World — Build (Steps 1–7)` title to `(Steps 1–8)` and the `Steps 1–7` references in the opening paragraph as appropriate.

  Also update `tests/run.luau`'s harness label from `"Wild World — Steps 1–7"` to `"Wild World — Steps 1–8"`.

- [ ] **Step 7: The final DoD gate**

Run: `./run-tests.sh 2>&1 | tail -30`
Expected: **ALL GREEN ✓** — all four gates pass (strict type-check every headless module incl. the new ones; all unit tests incl. the 5 new specs; both negative fixtures still fail analysis; `rojo build` succeeds). Confirm the Studio-only listing shows only `WorldServer.server.luau` + `CharacterController.client.luau`.

- [ ] **Step 8: Commit**

```bash
cd /home/toor/claude/RobloxRPG/RobloxRPG
git add -A && git commit -m "Step 8 (10/10): README + docs (view-not-store, one-server bootstrap, instancing flag, deferrals)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (run after implementation; this is the author's checklist)

**Spec coverage (every Scope item → a task):**
- A. Salvage flow (atomic/idempotent/terminal, no-orphan) → **Task 4** ✓
- B. Display / un-display (CAS + slot-capacity gate; no direct trade path) → **Task 5** ✓
- C. Trophy Hall view (query not structure; provenance plaque; no parallel store) → **Task 3** (+ projection **Task 8**) ✓
- D. Slot + decor Cash sink (escalating/uncapped slot; balance-free decor; evergreen-tagged; placement) → **Tasks 1, 2, 6** ✓
- E. Lodge arrival routing (headless branch) → **Task 7**; the one-server bootstrap (Studio) → **Task 9** ✓
- F. Telemetry (evergreen-sink tags + lodge.* metrics) → wired in **Tasks 4/5/6**; the rest enumerated Studio in **Task 10** ✓
- Prerequisites: count-based slot/decor structure + placement state (**Task 1**); decor catalog (**Task 2**); `baseTrophySlots` + escalating `slotExpansionPrice` (**Task 1**); Lodge arrival representation (**Task 7**) ✓
- Out-of-scope honored: no `HELD→ESCROWED`/escrow, no World-Map reveal, no Boat/Kennel inventories, no auto-sell, no real-money decor, no display-grants-benefit — fixtures are placed/stubbed only (**Task 9**) ✓
- Open question resolved-or-flagged: instancing model built own-Lodge + flagged (**Tasks 1 tuning, 10 README**) ✓

**Type-consistency checks:** `Arrival.kind` discriminator + optional `destinationId` used consistently (Task 7 module + Task 7/9 callers + Arrival.spec); `TrophyHall.totalSlots`/`countDisplayed`/`slotUsage` names match between Task 3 (definition), Task 5 (DisplayHandler), Task 8 (Replication); `LodgeState` field names (`boughtSlots`/`ownedDecor`/`placements`) match between Schema (Task 1), Profile/util (Task 1), TrophyHall (Task 3), LodgeShopHandler (Task 6); `Config.decor` populated Task 2 (Task 1 leaves a temporary `{}` to keep the suite green — documented). Handler factory shapes (`.new(deps)` / `.xHandler(deps)`) mirror `ShopHandler`.

**Between-task green:** Task 1 adds `decor = {}` so `Config` stays complete until Task 2 replaces it; every task ends on a green `./run-tests.sh`.
