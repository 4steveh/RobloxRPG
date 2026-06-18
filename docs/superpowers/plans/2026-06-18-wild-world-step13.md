# Wild World Step 13 — LiveOps Calendar & Event Framework: Implementation Plan

> **For agentic workers:** Execute task-by-task with TDD. Steps use checkbox (`- [ ]`) syntax. Run
> `./run-tests.sh` after each task — it is THE Definition-of-Done gate. Steps 1–12 MUST stay green and the
> economy reconciliation MUST stay untouched (event Cash is a separate tagged faucet, never routine income).

**Goal:** Build the config-driven LiveOps event framework (the schema, the moat-structural scarcity guard,
the server-time scheduler/activation, the per-event + aggregate payout budgets, the daily-quest rotation,
the evergreen-sink alarm) and ship its one concrete event — **Winter Freeze**, opening a doubly-gated
seasonal Frozen Lake.

**Architecture:** This step **composes, it does not rebuild.** The `event` spawn-predicate clause
(`Spawner.WorldState`/`rareSpawnEligible`), the commodity-ownership gate pattern
(`Fishing.ownsBoatForWater` → mirror for the Ice-Fishing Kit), the `Daily` cross-loop skeleton, the
`Decor`/`Catalog`/`Validation` self-validate-at-require pattern, the `Ledger`/`Economy` faucet, and the
`Entitlement`/`activeEntitlements` server-time substrate ALL exist. Step 13 adds: a pure **scheduler**
(`src/logic/LiveOps.luau`) that recomputes `world.event` from server time every tick; an **event-config
data module** (`src/config/LiveOps.luau`) joined into `Config.liveOps`; the **scarcity-discipline guard**
in `Validation.luau` (a require-time build error); an **event-reward handler**
(`src/server/liveops/EventRewardHandler.luau`) writing budget-capped, event-faucet-tagged atomic ledger
entries; the **Frozen Lake content** (new fish in `Fish.luau` + a `frozen_lake` zone); and the Studio-only
**scheduler tick** in `WorldServer.server.luau`.

**Tech Stack:** Luau `--!strict`; headless `luau`/`luau-analyze`/`rojo`; require-by-string `@src/…`/`@tests/…`.

## Global Constraints (copied verbatim from the build prompt + corpus — every task inherits these)

- **Config-not-code (RD4):** a new event/season is a config record; no code per event. Flag any kind that needs code per instance.
- **Scarcity-discipline guard is STRUCTURAL (RD1):** a config editing an existing artifact's `rarity`/`1-in-N`/mint accounting → **build-time error**; a new-scarcity id colliding with an existing catalog id → **rejected** (clone evasion). Events may reference an existing rare's predicate (window at unchanged rate) and/or introduce a genuinely-new id — never dilute existing scarcity.
- **Server-authoritative, server-time activation:** server owns whether an event is live; client displays, never asserts; timed entitlements count offline time (`Entitlement.expiryTimestamp` is wall-clock absolute).
- **Events deliver scarce/identity value, not Cash (RD2):** a rare mint writes **no Cash**; Cash payouts are thin, budget-capped, atomic, event-faucet-tagged; concurrent event faucets sum ≤ ceiling.
- **The decor SLA counts Cash-priced SKUs only** (game-pass cosmetics are revenue, not ballast).
- **Reuse the integrity layer wholesale** — event spawns/mints/entitlements add no new anti-dupe surface.
- **The aggregate-overlap check is the PEAK instantaneous concurrent sum** (sweep-line), not a naive pairwise-window sum.
- **`world.event` is a single `string?` matched by equality** (`ok(c,w)=c==nil or c==w`) — one spawn-gating event at a time; the scheduler recomputes it from server time every tick so it goes active at `start` and **reverts after `end`**.
- **`eventPayoutBudgetCeiling` / `aggregateEventFaucetCeiling` are Tuning knobs co-owned with economy** — no hardcoded magnitude in logic; live in `Tuning.economy`.
- **`T_current` basis under the OR-gate stays `max(EHT,EFT)`** (the existing `ClaimDailyHandler` choice) and is **flagged** as economy's open call — do NOT paper it over or re-resolve it here.
- **Headless/Studio split:** no Roblox globals in headless modules; the scheduler tick + Frozen-Lake geometry are Studio-only (`*.server.luau`), excluded from `run-tests.sh`, verified by the README playtest checklist.

---

## File Structure

**New (headless):**
- `src/logic/LiveOps.luau` — the pure scheduler/budget/rotation/alarm engine (no Roblox, no persistence).
- `src/config/LiveOps.luau` — the event-config DATA (Winter Freeze, Salmon Run) + the daily-quest pool; joined into `Config.liveOps`.
- `src/server/liveops/EventRewardHandler.luau` — the Gauntlet handler for claiming an event participation reward (budget-capped, event-faucet-tagged, server-time-entitlement idempotent).
- `tests/LiveOps.spec.luau` — scheduler/budget/rotation/alarm + scarcity-guard tests.
- `tests/EventRewardHandler.spec.luau` — handler tests (budget cap, atomic tagged entry, entitlement server-time, idempotency, no-Cash rare mint).

**New (Studio-only — NOT headless):**
- scheduler tick block appended to `src/server/world/WorldServer.server.luau`.

**Modified (headless):**
- `src/types/Enums.luau` — `EventKind`, `NewScarcityKind`, `QuestLoop` enums.
- `src/types/Ids.luau` — `EventId` type + `Ids.Event` registry.
- `src/types/Schema.luau` — `EventConfig`, `NewScarcityDecl`, `Quest`, `LiveOpsConfig` types; `liveOps: LiveOpsConfig` on `Config`; `requiresItem: ItemId?` on `Fish`.
- `src/config/Tuning.luau` — `Tuning.economy.eventPayoutBudgetCeiling`/`aggregateEventFaucetCeiling`; new `Tuning.liveops` table.
- `src/config/Fish.luau` — the Frozen Lake fish (the genuinely-new winter catch + a Common); `requiresItem` plumbed through the builder.
- `src/config/Spawning.luau` — `frozen_lake` fishing area (low bite cap).
- `src/server/world/...` shell — `frozen_lake` zone added to the Alaska shell (wherever the Alaska shell is authored, headless data).
- `src/config/Validation.luau` — `assertEventConfig`, `assertNewScarcityId`, `assertQuest`, `validateLiveOps`; called from `validateConfig`.
- `src/config/Catalog.luau` — require `LiveOps`, add `liveOps = LiveOps`.
- `src/logic/Fishing.luau` — `ownsRequiredItem(profile, config, itemId)` (mirror of `ownsBoatForWater`).
- `src/server/fishing/CatchHandler.luau` — the Frozen-Lake double-gate (event-active backstop + Ice-Fishing-Kit ownership) in `authority`.
- `tests/run.luau` — register the two new specs; relabel "Steps 1–13".
- `README.md` — Step 13 status section, module map, deferred table, reconciliation, playtest checklist.

---

## Key type designs (locked — later tasks rely on these exact shapes)

```lua
-- Enums.luau
export type EventKind = "conditionWindow" | "seasonal" | "limitedTime" | "destinationDrop"
export type NewScarcityKind = "referenceWindow" | "mintNew"
export type QuestLoop = "Hunting" | "Fishing" | "either"

-- Ids.luau
export type EventId = string
Ids.Event = table.freeze({
  WinterFreeze = "winter_freeze" :: EventId,
  SalmonRun = "salmon_run" :: EventId,
})

-- Schema.luau
export type NewScarcityDecl = { kind: NewScarcityKind, targetId: TargetId } -- referenceWindow|mintNew → an existing catalog target
export type ImposedWorld = { event: string?, season: string?, weather: string?, time: string? } -- what the event SETS on WorldState when live
export type EventConfig = {
  id: EventId,
  name: string,
  kind: EventKind,
  startTime: number, -- server-time absolute (inclusive)
  endTime: number,   -- server-time absolute (inclusive)
  imposes: ImposedWorld, -- imposes.event is the single spawn-gating clause (nil = a non-spawn beat, e.g. a decor drop)
  cashBudget: number, -- per-window thin participation Cash cap (≤ tuning.economy.eventPayoutBudgetCeiling)
  newScarcity: { NewScarcityDecl },
  notes: string,
}
export type EventCatalog = { [EventId]: EventConfig }
export type Quest = { id: string, loop: QuestLoop, objective: string, themedFor: EventId? } -- mechanical, not narrative
export type LiveOpsConfig = { events: EventCatalog, dailyQuestPool: { Quest } }
-- Config gains:  liveOps: LiveOpsConfig
-- Fish gains:    requiresItem: ItemId?   -- a commodity (e.g. tackle_ice_fishing_kit) the angler must OWN to catch
```

```lua
-- LiveOps.luau (pure) — the signatures later tasks consume:
M.isEventActive(config, eventId, now) -> boolean                 -- start ≤ now ≤ end
M.activeEventIds(config, now) -> { [EventId]: boolean }
M.activeWorldEvent(config, now) -> string?                       -- the single spawn-gating imposes.event live now (nil if none)
M.worldStateAt(config, now) -> Spawner.WorldState                -- {time,weather,season,event} from the active spawn-gating event's `imposes`
M.entitlementActive(entitlement, now) -> boolean                 -- now < expiryTimestamp (offline counts)
M.peakConcurrentCashBudget(config) -> number                    -- sweep-line PEAK of summed cashBudgets of simultaneously-live events
M.eventPayout(config, event, tier) -> number                    -- min(round(dailyQuestFraction·Income(tier)), event.cashBudget) ; loop="none"
M.dailyQuestSet(config, now, activeEvent: EventId?) -> { Quest }-- deterministic by day; ≥1 Hunting + ≥1 Fishing; themed to activeEvent
M.cashPricedDecorCount(config) -> number                        -- count decor with (cost::any).cash ~= nil  (SLA = Cash-priced only)
M.meetsDecorReplenishQuota(newCashPricedSkus, config) -> boolean-- newCashPricedSkus ≥ tuning.liveops.decorReplenishCadence
M.evergreenSinkAlarm(shareOfEndgameCash, config) -> boolean     -- share < tuning.liveops.evergreenSinkShareAlarmThreshold → fire
```

---

## Task 1 — Enums, Ids, Schema, Tuning (the data shapes)

**Files:** Modify `src/types/Enums.luau`, `src/types/Ids.luau`, `src/types/Schema.luau`, `src/config/Tuning.luau`.

**Interfaces produced:** all types in the "Key type designs" block above; `Tuning.economy.eventPayoutBudgetCeiling`, `Tuning.economy.aggregateEventFaucetCeiling`, `Tuning.liveops.{evergreenSinkShareAlarmThreshold, decorReplenishCadence, dailyQuestSetSize, weeklyHeartbeatSeconds, monthlyMarqueeSeconds, eventEntitlementSeconds}`.

- [ ] Add `EventKind`/`NewScarcityKind`/`QuestLoop` to `Enums.luau` (union + frozen table + `::` casts, matching the file idiom).
- [ ] Add `EventId` + `Ids.Event` registry to `Ids.luau`.
- [ ] Add `NewScarcityDecl`/`ImposedWorld`/`EventConfig`/`EventCatalog`/`Quest`/`LiveOpsConfig` to `Schema.luau`; add `requiresItem: ItemId?` to `Fish`; add `liveOps: LiveOpsConfig` to `Config`.
- [ ] Add the tuning knobs. `Tuning.economy` is frozen — extend the literal (illustrative defaults: `eventPayoutBudgetCeiling = 0.5 * B` i.e. **500** (≈½hr T1 income); `aggregateEventFaucetCeiling = B` i.e. **1000**). New `Tuning.liveops = table.freeze({ evergreenSinkShareAlarmThreshold = 0.25, decorReplenishCadence = 2, dailyQuestSetSize = 3, weeklyHeartbeatSeconds = 604800, monthlyMarqueeSeconds = 2592000, eventEntitlementSeconds = 0 })`. Mark every magnitude `-- illustrative default`.
- [ ] **Verify:** `luau-analyze` clean on the four files; `luau tests/run.luau` still green (no behavior change yet — `requiresItem`/`liveOps` are additive optional/new and the catalog doesn't populate them yet, so `Config` construction in `Catalog.luau` must add `liveOps` — do that in Task 5; until then keep `Config.liveOps` change deferred OR stub it). **Sequencing note:** to keep the build green, land the `Config.liveOps` field + `Catalog` wiring together in Task 5; in Task 1 add only the standalone types + `requiresItem` + tuning. The `LiveOpsConfig`/`EventConfig`/`Quest` types are pure type additions (erased) and compile without a consumer.

---

## Task 2 — `LiveOps.luau` scheduler core (TDD): activeness, world.event, entitlements

**Files:** Create `src/logic/LiveOps.luau`; create `tests/LiveOps.spec.luau`; register in `tests/run.luau`.

**Interfaces consumed:** `Schema.Config`, `Spawner.WorldState`. **Produced:** `isEventActive`, `activeEventIds`, `activeWorldEvent`, `worldStateAt`, `entitlementActive` (signatures above).

- [ ] **RED:** write `tests/LiveOps.spec.luau` with a synthetic mini-config (two events: a spawn-gating `winter_freeze` window `[1000,2000]` imposing `event="Winter Freeze"`, and a non-overlapping `salmon_run` `[3000,4000]` imposing `event="Salmon Run"`). Assert: `isEventActive` true at `now=1000` and `now=2000` (inclusive), false at `999`/`2001`; `activeWorldEvent` == `"Winter Freeze"` at `1500`, `nil` at `2500`, `"Salmon Run"` at `3500` (**reverts after end** is the `nil` at `2500`); `worldStateAt(_,1500).event == "Winter Freeze"`; `entitlementActive({kind="x",expiryTimestamp=2000}, 1999)==true` and `==false` at `2000` and `2001` (offline counts — only `now` matters).
- [ ] Run: `luau tests/run.luau` → FAIL (module missing).
- [ ] **GREEN:** implement the five functions. `activeWorldEvent` iterates events, returns the single active one with `imposes.event ~= nil` (the build-time non-overlap guard in Task 4 guarantees ≤1).
- [ ] Run → PASS. `luau-analyze src/logic/LiveOps.luau` clean.
- [ ] Commit.

---

## Task 3 — `LiveOps.luau` budgets + alarm + daily rotation (TDD)

**Files:** Extend `src/logic/LiveOps.luau` + `tests/LiveOps.spec.luau`.

**Interfaces produced:** `peakConcurrentCashBudget`, `eventPayout`, `dailyQuestSet`, `cashPricedDecorCount`, `meetsDecorReplenishQuota`, `evergreenSinkAlarm`.

- [ ] **RED (peak overlap — the v2 correctness case):** three events with `cashBudget` 300 each: A=[0,100], B=[50,150], C=[80,200]. A overlaps B and A overlaps C, but B∩C only on [80,150]. Naive "sum every window touching A" = 900; the **peak** = max over the timeline = at t=80..100 all three live → 900? Choose budgets so the distinction bites: A=[0,100] b=400, B=[50,60] b=400, C=[200,300] b=400 (A overlaps B; A does NOT overlap C; B does NOT overlap C). Naive-sum-touching = A+B = 800 (peak), and the test that bites: A=[0,100] b=400, B=[120,130] b=400, C=[50,60] b=400 where B is disjoint from A&C but a naive "all events" sum=1200; peak = A+C=800. Assert `peakConcurrentCashBudget == 800`, not 1200.
- [ ] **RED (budget cap):** `eventPayout` for an event with `cashBudget=500` and a tier whose `dailyQuestFraction·Income(tier)` would be 900 → returns 500 (capped). For `cashBudget=500` and computed 250 → returns 250.
- [ ] **RED (daily rotation):** with a pool of ≥2 hunting + ≥2 fishing + ≥1 either + ≥1 themed-for-`winter_freeze`, `dailyQuestSet(config, now, nil)` returns exactly `dailyQuestSetSize` quests with ≥1 `Hunting` and ≥1 `Fishing`; same `now`-day → identical set (deterministic); a `now` one day later → a set still satisfying ≥1 hunt+fish; `dailyQuestSet(config, now, "winter_freeze")` includes at least one quest whose `themedFor == "winter_freeze"`.
- [ ] **RED (alarm + decor SLA):** `evergreenSinkAlarm(0.10, config)==true`, `evergreenSinkAlarm(0.25, config)==false`, `evergreenSinkAlarm(0.40, config)==false`; `cashPricedDecorCount` counts only entries with `(cost::any).cash ~= nil` (synthetic decor table with one cash + one realMoney → returns 1); `meetsDecorReplenishQuota(2, config)==true`, `meetsDecorReplenishQuota(1, config)==false` (cadence default 2).
- [ ] Run → FAIL. **GREEN:** implement. `peakConcurrentCashBudget` = sweep-line: collect `{t=start,+b}`/`{t=end+ε,-b}` events (use `end` as exclusive via `endTime + 0.5` since times are integer server-seconds, so a window ending exactly when another starts is NOT counted concurrent), sort, running-sum, track max. `eventPayout` = `math.min(math.round(config.tuning.economy.dailyQuestFraction * Economy.income(config, tier)), event.cashBudget)`. `dailyQuestSet` = deterministic pick keyed on `math.floor(now / DAY_SECONDS)` (rotate the pool by day offset; force-include the first Hunting + first Fishing; when `activeEvent` set, prefer `themedFor==activeEvent` quests).
- [ ] Run → PASS; analyze clean; commit.

---

## Task 4 — The scarcity-discipline guard + LiveOps validation (TDD, the moat-structural piece)

**Files:** Modify `src/config/Validation.luau` (+ `tests/LiveOps.spec.luau` or `tests/Validation.spec.luau` for the guard).

**Interfaces produced:** `V.assertEventConfig(event, config)`, `V.assertNewScarcityId(proposedId, config)`, `V.assertQuest(q, config)`, `V.validateLiveOps(config)`; `validateConfig` calls `validateLiveOps(config)` at the end.

- [ ] **RED — accept directions:** `assertEventConfig(salmonRunEvent, Catalog)` (a `referenceWindow` decl naming an existing rare, e.g. `alaska_king_salmon`) does NOT error; `assertEventConfig(winterFreezeEvent, Catalog)` (a `mintNew` decl naming the new event-exclusive burbot, gated by `imposes.event=="Winter Freeze"`) does NOT error; `assertNewScarcityId("alaska_glacier_burbot_v2", Catalog)` (genuinely-new id) does NOT error.
- [ ] **RED — reject directions (the guard has teeth):**
  - `assertNewScarcityId("alaska_king_salmon", Catalog)` → ERRORS (clone evasion: a "new" id colliding with an existing catalog id).
  - `assertEventConfig` with a `mintNew` decl naming an EXISTING standing rare whose `spawn.conditions.event ~= event.imposes.event` (e.g. Winter Freeze claiming to mint `alaska_king_salmon`, a Salmon-Run rare) → ERRORS ("mintNew must name a genuinely-new event-exclusive rare gated by this event — re-releasing an existing rare dilutes its holders, RD1").
  - `assertEventConfig` with a `referenceWindow` decl naming a NON-existent id → ERRORS; naming a Common (not rare-and-above) target → ERRORS ("you can only window an actual rare").
  - `assertEventConfig` with `cashBudget > tuning.economy.eventPayoutBudgetCeiling` → ERRORS.
  - `validateLiveOps` with two **spawn-gating** events whose windows OVERLAP → ERRORS ("one spawn-gating event at a time"); with overlapping events whose summed `cashBudget` peak > `aggregateEventFaucetCeiling` → ERRORS (peak-concurrent ceiling).
- [ ] Run → FAIL. **GREEN:** implement following the `assertDecorItem`/`assert(cond, id..": msg")` idiom. `assertEventConfig`: budget bound, `startTime < endTime`, per-decl resolution+rarity+event-exclusivity. `assertNewScarcityId`: error if id ∈ keys of `equipment ∪ creatures ∪ fish ∪ decor ∪ destinations`. `validateLiveOps`: per-event `assertEventConfig`; dup-id; `peakConcurrentCashBudget(config) <= aggregateEventFaucetCeiling`; non-overlap of spawn-gating windows. `assertQuest`: `loop ∈ QuestLoop`, objective non-empty, `themedFor` (if set) resolves to an event id. Append `V.validateLiveOps(config)` to `validateConfig`.
- [ ] Run → PASS; analyze clean; commit.

---

## Task 5 — `config/LiveOps.luau` data + Catalog wiring + Frozen Lake content (TDD)

**Files:** Create `src/config/LiveOps.luau`; modify `src/config/Catalog.luau`, `src/config/Fish.luau`, `src/config/Spawning.luau`, the Alaska shell module, and `src/types/Schema.luau` (the `liveOps` field activation deferred from Task 1).

**Interfaces produced:** `Catalog.liveOps` populated; the Winter Freeze + Salmon Run event records; the Frozen Lake fish; the `frozen_lake` zone.

- [ ] Author the two genuinely-new Frozen Lake fish in `Fish.luau` (RD1b new permanent scarcity): a **Legendary** event-exclusive `alaska_burbot` (the new mint — artifact, `rare = rareFields(1800, "the ghost-pale eelpout hauled up through the ice")`, `requiresItem = "tackle_ice_fishing_kit"`, `waterType = lake`, `spawnZones = {"frozen_lake"}`, `spawn.conditions = { event = "Winter Freeze" }`, T4, `isMilestoneTarget` unset) and a **Common** `alaska_lake_whitefish` (cash, low `fightDifficulty` calmer-seated, `minRodTier`/`minReelTier` chosen so `Fishing.landableAt` passes the role band, same zone/condition/requiresItem). Thread `requiresItem` through the `fish()` builder (default nil; copy to output).
- [ ] Add `frozen_lake` to the Alaska shell `zones` (kind `"fishing"`, headless Vec3 data) and to `Spawning.luau` `alaskaFishing.areas` with a LOW bite cap (LOC_04 §8.4: "Frozen Lake (event) capped low" — e.g. `maxConcurrentBites = 2`, `biteRespawnInterval` ≈ 55).
- [ ] Create `src/config/LiveOps.luau`: `events = { winter_freeze = {...}, salmon_run = {...} }`, `dailyQuestPool = { … }` (≥2 hunting, ≥2 fishing, ≥1 either, ≥1 `themedFor="winter_freeze"`, ≥1 `themedFor="salmon_run"`; all mechanical: "Catch 5 trout", "Bag 3 caribou"…). Winter Freeze: `kind="limitedTime"`, `imposes={event="Winter Freeze"}`, `cashBudget=500` (= ceiling, the thin participation reward), `newScarcity={ {kind="mintNew", targetId="alaska_burbot"} }`. Salmon Run: `kind="seasonal"`, `imposes={event="Salmon Run", season="Salmon Run"}`, `cashBudget=0` (pure scarcity content), `newScarcity={ {kind="referenceWindow", targetId="alaska_king_salmon"}, ... existing Salmon-Run rares }`, windows chosen NON-overlapping with Winter Freeze.
- [ ] Wire `Catalog.luau`: `local LiveOps = require("@src/config/LiveOps")`; add `liveOps = LiveOps` to the `Catalog` literal; activate `liveOps: LiveOpsConfig` on the `Config` type. `validateConfig(Catalog)` now runs `validateLiveOps` (Task 4) on the real data — the live config self-validates under the guard.
- [ ] **Verify:** `luau tests/run.luau` green (the new fish pass `assertFish` + cross-tier role band; the events pass the guard; `Catalog` requires clean). Add a focused test in `tests/LiveOps.spec.luau`: the real `Catalog.liveOps` validates; `activeWorldEvent` for Winter Freeze's window == "Winter Freeze"; the new fish resolve in `Catalog.fish` with `requiresItem == "tackle_ice_fishing_kit"`.
- [ ] **Verify placement:** if any test requires the Alaska shell, confirm `Spawner.validatePlacement` accepts `frozen_lake` (the new zone resolves). Run `./run-tests.sh` — gate 1 (analyze) + gate 4 (rojo) included.
- [ ] Commit.

---

## Task 6 — The Frozen-Lake double-gate in CatchHandler (TDD, §E)

**Files:** Modify `src/logic/Fishing.luau` (add `ownsRequiredItem`), `src/server/fishing/CatchHandler.luau` (add the two gates to `authority`); test in `tests/CatchHandler.spec.luau`.

**Interfaces produced:** `Fishing.ownsRequiredItem(profile, config, itemId) -> boolean`; CatchHandler authority denial reasons `"event_inactive"` and `"missing_ice_fishing_kit"`.

- [ ] **RED (ownership helper):** `ownsRequiredItem(profile, config, "tackle_ice_fishing_kit")` is false for a bare angler, true after the kit commodity is in `inventory.commodities` (resolve `config.equipment[c.catalogId].id == itemId`). Mirror `ownsBoatForWater`.
- [ ] **RED (the double-gate, in CatchHandler):** build an angler with rod/reel adequate for `alaska_burbot`. Four cases, `deps.now` driving the window:
  1. `now` OUTSIDE Winter Freeze, kit owned → denied `"event_inactive"` (closed out-of-window **regardless of Kit**).
  2. `now` INSIDE Winter Freeze, kit NOT owned → denied `"missing_ice_fishing_kit"` (no Kit → denied **even in-window**).
  3. `now` INSIDE, kit owned → the two gates PASS (catch proceeds to the existing fight checks; assert it is NOT denied for these two reasons).
  4. a non-event, non-`requiresItem` fish (existing behavior) → neither gate fires (Steps 5/11 stay green).
- [ ] Run → FAIL. **GREEN:** in `authority`, after the existing tier/exists/boat checks, add — **event-active backstop first** (so out-of-window returns `event_inactive` regardless of kit): `if fish.spawn.conditions ~= nil and fish.spawn.conditions.event ~= nil and LiveOps.activeWorldEvent(ctx.config, ctx.now) ~= fish.spawn.conditions.event then return false, "event_inactive" end`; then **kit ownership**: `if fish.requiresItem ~= nil and not Fishing.ownsRequiredItem(ctx.profile, ctx.config, fish.requiresItem) then return false, "missing_ice_fishing_kit" end`. (This is the two-layer pattern — spawn predicate is PRIMARY at the bite level; these are the authority BACKSTOP, mirroring Step 11's boat backstop. The item-ownership gate is NOT `canAccessZone`.)
- [ ] **Salmon-Run interaction check:** the event-active backstop now also gates `alaska_king_salmon`/`alaska_sockeye_salmon` (they carry `conditions.event="Salmon Run"`). Confirm no existing CatchHandler/CrossTier test catches a salmon-run fish; if one does, set its `deps.now` inside the Salmon Run window. (Salmon Run is registered in Task 5 precisely so this content is coherent, not dead.)
- [ ] Run `./run-tests.sh` → all green. Commit.

---

## Task 7 — EventRewardHandler: budget-capped, event-faucet-tagged, server-time-entitlement idempotent (TDD, §D)

**Files:** Create `src/server/liveops/EventRewardHandler.luau`; create `tests/EventRewardHandler.spec.luau`; register in `tests/run.luau`.

**Interfaces consumed:** `Gauntlet` handler contract, `Ledger.applyEntry`, `Economy`/`EffectiveTier`, `LiveOps.{isEventActive,eventPayout,entitlementActive}`. **Produced:** intent `"claimEventReward"`.

- [ ] **RED:** register the handler with Fakes; `deps.now` inside Winter Freeze. Assert:
  - claim while active → one ledger entry, `type=="eventReward"`, `loop=="none"`, `tier==max(EHT,EFT)`, `amount==LiveOps.eventPayout(...)≤cashBudget`, `validatingEventId` keyed `"eventReward:winter_freeze@<windowStart>"`; an entitlement pushed with `expiryTimestamp==event.endTime`.
  - a SECOND claim same window → denied `"already_claimed"` (idempotency via the active claim entitlement), no second ledger entry.
  - claim while INACTIVE (`now` outside window) → denied `"event_inactive"`, no entry.
  - the entitlement still blocks a re-claim when `now` is advanced but `< endTime` (server-time; offline counts) and is moot after `endTime`.
  - **no-Cash rare mint:** catching `alaska_burbot` (rare) via the existing CatchHandler mints an artifact and grows the cash tail by **0** (event value flows to trade/Trophy Hall, not the faucet). (Assert against the existing RewardPipeline path.)
- [ ] Run → FAIL. **GREEN:** implement `authority` (active + no active claim entitlement → else reason) and `commit` (`critical=true`; compute tier; `amount=eventPayout`; `Ledger.applyEntry`; push claim entitlement; `deps.telemetry` `incr("liveops.eventFaucet:"..eventId, amount)` + `incr("liveops.eventParticipation", 1)`).
- [ ] Run `./run-tests.sh` → green. Commit.

---

## Task 8 — Studio scheduler tick (NOT headless) + README + memory

**Files:** Modify `src/server/world/WorldServer.server.luau` (Studio-only); `README.md`; memory.

- [ ] Append a Studio-only tick to `WorldServer.server.luau` (mirrors the existing rare-spawn `task.spawn(while true task.wait(N))` loops): each tick `local now = os.time(); local world = LiveOps.worldStateAt(Catalog, now)` and feed `world` (merged with ambient time/weather) into the spawner's `WorldState`; register `EventRewardHandler`. Mark the block `-- Studio-only (server-time recompute every tick → world.event goes active at start, reverts after end)`. This file is excluded from `run-tests.sh`.
- [ ] README: add the Step 13 section (inherited vs new table; config-not-code; the scarcity guard; server-time activation; the decor-SLA Cash-priced-only rule; the `T_current` seam flagged); extend the module map (`logic/LiveOps`, `config/LiveOps`, `server/liveops/EventRewardHandler`); update the Deferred table (Rockies drop, decor SKU art, monetization → their steps); add a reconciliation entry (event budget ceiling echoed from economy Tuning); add the Studio playtest items (event UI/banner/countdown/leaderboard, Frozen-Lake geometry, daily-board UI, seasonal-theming visuals) + the telemetry-population checklist (evergreen-sink share + alarm, rare-price trend, event participation + faucet share, daily claim rate esp. session 2, reactivation, cadence-adherence) as honestly **unchecked**.
- [ ] Update `tests/run.luau` label to "Steps 1–13" and confirm both new specs are registered.
- [ ] Run `./run-tests.sh` → ALL GREEN. Update memory (`wildworld-step13-decisions.md` + MEMORY.md pointer).
- [ ] Commit.

---

## Verification gates (every task) & final adversarial review

- `./run-tests.sh`: (1) `luau-analyze --!strict` clean on all headless modules, (2) all specs pass, (3) negative fixtures still FAIL analysis, (4) `rojo build` succeeds. Steps 1–12 stay green; the economy reconciliation (`Economy.spec` routine-hour parity) is untouched (event faucet is `loop="none"`).
- **Final:** dispatch the `wildworld-invariant-reviewer` (architecture: headless/Studio split, config-vs-logic purity, derive-don't-store, closed enums, self-validation) and `economy-integrity-reviewer` (ledger no-yield/atomic, no event-specific dupe surface, faucet tagging, reconciliation untouched) + a scarcity-guard skeptic (try to dilute scarcity past the guard) + a server-time skeptic (try to extend an event with a client clock). Fix confirmed findings.

## Self-review against the build prompt (spec coverage)

§A schema → Task 1+5. §B guard (both directions) → Task 4. §C scheduler/server-time/revert → Task 2 + Task 8. §D budgets (per-event + aggregate peak + no-Cash mint) → Task 3 + Task 7. §E Winter Freeze + Frozen Lake double-gate (item-ownership not canAccessZone) → Task 5 + Task 6. §F daily rotation (≥1 hunt+fish, rotates, reward scale = economy, `T_current` flagged) → Task 3 (+ existing ClaimDailyHandler unchanged). §G alarm + Cash-priced-only quota → Task 3. §H telemetry → Task 7 (wired) + Task 8 (enumerated). Deferred (Rockies exec, decor SKU art, monetization, marketplace, event-specific integrity) → built NONE; named in README (Task 8).
