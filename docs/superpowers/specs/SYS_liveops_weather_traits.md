# SYS_liveops_weather_traits.md — Weather Windows + Stackable Catch Traits

**Status:** DRAFT spec for owner review. Extends Step 13 LiveOps; introduces no parallel system.
**Author:** gameplay/economy engineering. **Date:** 2026-06-19.
**Competitor source:** Gone Hunting (GH) dynamic-weather → exclusive land animal + exclusive fish + stackable mutation trait, surfaced as a persistent "next global spawn" HUD countdown.

---

## 0. Thesis & framing

GH's loop is: an 8-type weather rotation (~5 min each) → each weather **enables one exclusive land animal + one exclusive fish + one exclusive stackable MUTATION TRAIT** → "trait farming" (timing sessions to stack traits for higher-value catches) is the retention meta. The persistent HUD countdown ("Next global dimensional spawn in HH:MM:SS") is the wrapper that makes it feel alive.

Wild World **already has the schedule + exclusive-spawn half of this** in Step 13: `imposes.event`/`imposes.weather` clauses (`Schema.ImposedWorld`, L339), the per-tick `LiveOps.worldStateAt` driver (`logic/LiveOps.luau` L66-73), the `Spawner.rareSpawnEligible` equality predicate (`logic/Spawner.luau` L138-147), and the require-time RD1 scarcity guard (`config/Validation.luau` L189-313). What is missing (confirmed by the codebase maps' gaps) is: (1) no live weather *driver* — `weather` is a string tag with no rotation; (2) **no trait/mutation concept anywhere**; (3) no payout multiplier for anything but `rarity` + the 2x/VIP boost; (4) no persistent countdown surface.

This spec reverse-engineers GH's loop into Wild World by **extending the existing event record** (a new `kind = "weatherWindow"` plus a `traitsGranted` field) and **reusing every existing seam**: the scheduler, the spawn predicate, the RewardPipeline Cash-branch boost pattern, the RD1 guard, and the entitlement/idempotency substrate. The only genuinely new mechanic is the **per-catch trait roll** (GH's mutation), which we slot into the *exact* place the 2x/VIP boost already lives so reconciliation stays intact.

Two invariants force the central design choice up front:
- **A traited routine catch must NOT be a rare** (rares mint artifacts, write no Cash; routine catches pay Cash). A trait is a **Cash-branch bonus on a routine catch**, mirroring the 2x/VIP boost exactly — never a path to an artifact.
- **A trait must NOT enter the normalized band** (`Economy.payoutExact` L112-115 divides by `avgRoutineMultiplier`; anything inside that band self-cancels). The trait bonus is applied **outside** the band as a separate `loop="none"`-tagged ledger entry, identical to `boostBonus` (`RewardPipeline.luau` L161-175).

---

## 1. Vocabulary mapping (GH → Wild World)

| GH concept | Wild World mapping | New or existing |
|---|---|---|
| Weather rotation (8 types, ~5 min) | A new `EventKind = "weatherWindow"` event record per weather type, scheduled by the existing recompute | **New kind**, existing scheduler |
| Exclusive land animal / fish per weather | A creature/fish with `spawn.conditions.weather = <weatherTag>`, gated by `rareSpawnEligible` | **Existing seam** (`Spawner.luau` L146) |
| Stackable mutation trait | A per-catch rolled `Trait`, multiplying the Cash branch; multiple traits stack multiplicatively | **New mechanic**, hooks existing boost seam |
| "Trait farming" meta | Timing play to weather windows whose `traitsGranted` set is richer/higher-value | Emergent from the above |
| "Next global spawn in HH:MM:SS" | `LiveOps.nextWindowChangeAt(config, now)` → projection field → client countdown | **New pure fn** + **new projection field**, client display only |
| GH carries catch as named item w/ weight | (Out of scope here; see clientCatch map — separate result-screen workstream) | Deferred |

**Naming decision (proposed):** call the trait axis **"Tracks"** in player-facing copy ("a Storm-Touched catch") to avoid the loaded word "mutation" and to read naturally for a grounded hunting/fishing game. Internally the type is `Trait`. Owner may override (see Open Decisions D1).

---

## 2. Data model additions

### 2.1 New enum: `Trait` and `TraitKind` (NEW — `src/types/Enums.luau`)

A closed union, per the "closed enums live once" rule. Add after `QuestLoop` (L245-250):

```lua
-- Weather-window catch traits (the GH "stackable mutation" analogue). A per-catch Cash-branch overlay
-- ROLLED at kill/catch time when its enabling weather window is live. Closed set — a trait is identity,
-- never power; it scales Cash only (RewardPipeline boost-branch), never tier/rarity/gate/artifact.
export type Trait = "stormTouched" | "frostbitten" | "goldenHour" | "fogShrouded" | "moonlit"
Enums.Trait = table.freeze({
    stormTouched = "stormTouched" :: Trait,
    frostbitten = "frostbitten" :: Trait,
    goldenHour = "goldenHour" :: Trait,
    fogShrouded = "fogShrouded" :: Trait,
    moonlit = "moonlit" :: Trait,
})
```

Add the new `EventKind` member to the existing closed `EventKind` union (L227-233):

```lua
export type EventKind = "conditionWindow" | "seasonal" | "limitedTime" | "destinationDrop" | "weatherWindow"
-- in the frozen table:
    weatherWindow = "weatherWindow" :: EventKind, -- the recurring short-cycle weather beat (exclusive spawns + trait grants)
```

> **Note on `weatherWindow` vs reusing `conditionWindow`:** `conditionWindow` is enum-legal but currently *unused* (liveops gap). We deliberately add a *distinct* `weatherWindow` kind because weather events carry the **new `traitsGranted` field** and have **short recurring cadence + countdown semantics** that `conditionWindow` (a one-off scheduled rare window) does not. Owner may instead fold this into `conditionWindow` (Open Decision D2).

### 2.2 Extend `EventConfig` with `traitsGranted` (HOOKS `src/types/Schema.luau` L340-356)

Add ONE optional field to the existing `EventConfig` type — this is the only schema change to the event record:

```lua
export type EventConfig = {
    -- ... all existing fields unchanged (id, name, kind, startTime, endTime, imposes, cashBudget,
    --     mintsFish, newScarcity, notes) ...
    -- NEW (weather windows only): the traits this window enables on routine catches/kills while live.
    -- nil/empty for every non-weather event (Salmon Run, Winter Freeze unaffected). A trait in this set
    -- becomes ELIGIBLE to roll on a routine target only while THIS event imposes its weather.
    traitsGranted: { Trait }?,
}
```

`Trait` must be imported into Schema (it already imports from Enums for `EventKind` etc.). All existing event records (`config/LiveOps.luau` L79-110) leave `traitsGranted` nil — **zero change to Salmon Run / Winter Freeze**.

### 2.3 No new field on `Creature`/`Fish`

Per the spawnEcon map: rarity is the only per-target axis, and adding a per-instance trait field to the catalog row would be wrong (a trait is per-*catch*, rolled, not authored per species). **Traits are never stored on the catalog row and never stored on the artifact** (artifacts are rares; routine catches mint nothing). The trait lives only:
- as **eligibility** in `EventConfig.traitsGranted` (which weather enables which trait), and
- as a **rolled value** carried on `KillEvent` from the Studio spawner into RewardPipeline (§5).

This keeps the Reward XOR and the catalog untouched.

---

## 3. Scheduler hooks (HOOKS `src/logic/LiveOps.luau` — pure, headless)

The weather rotation is **just more event records driven by the same recompute**. No new driver.

### 3.1 Weather imposition already works

A `weatherWindow` event sets `imposes.weather = <tag>` (and may set `imposes.event` if it also gates an exclusive species — see §4). `LiveOps.worldStateAt` (L66-73) **already returns `weather = e.imposes.weather`** from the active spawn-gating event. **No change needed** for weather to reach the spawn predicate *if* the weather window is also the spawn-gating event.

**Critical constraint interaction:** `worldStateAt` and `activeWorldEvent` only consider events with `imposes.event ~= nil` (L56, L68) and rely on the **build-time non-overlap guard** (`Validation.validateLiveOps` L306-312) that at most one *spawn-gating* event is live. Weather windows that impose **only weather** (`imposes.weather` set, `imposes.event = nil`) are **not** spawn-gating and are **invisible** to `worldStateAt` today, which scans for `imposes.event ~= nil`.

This forces a decision and a small, surgical scheduler change:

### 3.2 NEW pure fn: `M.activeWeather` (NEW — `src/logic/LiveOps.luau`)

Add a weather-specific resolver that does **not** require `imposes.event`, alongside `activeWorldEvent` (L54-61):

```lua
-- The single weather tag imposed now (the active weatherWindow's imposes.weather). Independent of the
-- spawn-gating `event` clause: a weatherWindow may impose ONLY weather. Build-time non-overlap of
-- weatherWindow events (see Validation §X) guarantees ≤1 at any instant, so first-match is unambiguous.
function M.activeWeather(config: Config, now: number): string?
    for _, e in config.liveOps.events do
        if e.kind == "weatherWindow" and e.imposes.weather ~= nil
            and now >= e.startTime and now <= e.endTime then
            return e.imposes.weather
        end
    end
    return nil
end
```

And **widen `worldStateAt`** (L66-73) so it overlays the active weather even when the spawn-gating event is a different beat. Replace the single-event return with a merge:

```lua
function M.worldStateAt(config: Config, now: number): WorldState
    local ws: WorldState = {}
    for _, e in config.liveOps.events do
        if e.imposes.event ~= nil and now >= e.startTime and now <= e.endTime then
            ws.event = e.imposes.event
            ws.season = e.imposes.season or ws.season
            ws.time = e.imposes.time or ws.time
            ws.weather = e.imposes.weather or ws.weather
        end
    end
    ws.weather = ws.weather or M.activeWeather(config, now) -- weather-only windows still drive `weather`
    return ws
end
```

> This stays faithful to the constraint that **only one spawn-gating `event` is live** (the inner loop still resolves `ws.event` from the single non-overlapping spawn-gating event). It adds an **independent, separately-guarded weather axis** so weather can rotate on its own ~5-min cadence while a slow seasonal/event beat (Salmon Run) runs underneath. This is the key structural insight: **weather is a second, faster, non-overlapping axis**, not a third `event` string.

### 3.3 NEW pure fn: `M.activeTraits` (NEW — `src/logic/LiveOps.luau`)

The set of traits eligible to roll right now:

```lua
-- The traits ELIGIBLE to roll at `now` — the union of traitsGranted across all live events (in practice
-- the single active weatherWindow, by the non-overlap guard). Empty set = no trait can roll (base catch).
function M.activeTraits(config: Config, now: number): { [string]: boolean }
    local set: { [string]: boolean } = {}
    for _, e in config.liveOps.events do
        if e.traitsGranted ~= nil and now >= e.startTime and now <= e.endTime then
            for _, tr in e.traitsGranted do
                set[tr] = true
            end
        end
    end
    return set
end
```

### 3.4 NEW pure fn: `M.nextWindowChangeAt` (NEW — feeds the HUD countdown, §6)

```lua
-- The next server-time instant at which the live weatherWindow set CHANGES (the next start OR the next
-- end+1 of any weatherWindow strictly after `now`). The countdown source of truth. nil = no upcoming
-- boundary (no scheduled weather changes ahead — client hides the countdown).
function M.nextWindowChangeAt(config: Config, now: number): number?
    local best: number? = nil
    for _, e in config.liveOps.events do
        if e.kind == "weatherWindow" then
            for _, boundary in { e.startTime, e.endTime + 1 } do
                if boundary > now and (best == nil or boundary < best) then
                    best = boundary
                end
            end
        end
    end
    return best
end
```

This mirrors the inclusive-window / `+1` discipline already used for entitlements (the `endTime + 1` boundary fix at `EventRewardHandler.luau` L76-81): a window contributes through `endTime`, so the change happens at `endTime + 1`.

> **Cadence authoring note:** GH's ~5-min weather is *runtime-random*. Wild World's scheduler is **server-time-deterministic** (pure, `now`-driven, revert-after-end). Reverse-engineering "feels random but is server-authoritative" means authoring a **repeating, pre-computed rotation** of `weatherWindow` records (a ring of N back-to-back ~5-min windows that the live-ops team re-bases periodically), OR adding a deterministic rotation generator. See Open Decision D3 — the spec recommends the deterministic-rotation generator (§8.3) so config stays small.

---

## 4. Spawner hook — exclusive / biased spawns (HOOKS `src/logic/Spawner.luau`)

### 4.1 Exclusive spawns: ZERO new code

GH's "exclusive land animal/fish per weather" is **already expressible**. Author the creature/fish with `spawn.conditions.weather = "<tag>"` (the same shape the Burbot uses for `event`, `config/LiveOps.luau` L63). `Spawner.rareSpawnEligible` (L138-147) already equality-matches `cond.weather` against `world.weather`, and §3.2's widened `worldStateAt` now feeds `world.weather` from the active weatherWindow. **An exclusive weather creature/fish needs only a config record + a `weather` condition — no Spawner edit**, exactly the "config-not-code" property of the existing event system.

**Decision — exclusive species rarity:** the GH "exclusive animal/fish" is a **rare** (condition-gated, artifact-minting) in Wild World terms — it should carry `rarity >= Rare`, ride the existing `rareSpawnEligible` + artifact-mint path, and (if introduced by a weather event rather than pre-existing) be declared `mintNew` under the RD1 guard (§7). This keeps "weather exclusive" = "scarce trophy," not a Cash faucet. A weather window may *also* simply window an **existing** rare via `referenceWindow` (RD1a).

### 4.2 Biased (not exclusive) routine spawns — the trait-farming texture

GH lets weather *bias* the routine pool, not only gate rares. Wild World's `Spawner.routineTargetsInZone` (L83-99) returns an **unweighted flat list** — there is no weighting hook in the headless layer (the spawnEcon map confirms `premiumBait.uncommonBias` exists in Tuning but is **unconsumed**). Two faithful options:

- **(Recommended) Keep routine membership unweighted in headless; do the trait roll, not a spawn-weight bias.** The "trait farming" meta comes from the **per-catch trait roll** (§5), not from biasing *which species* spawns. This avoids touching the band normalization entirely and keeps `routineTargetsInZone` pure. The weather changes *what bonus your routine catch can carry*, which is exactly GH's stackable-mutation meta.
- (Alternative, deferred) Add a weather-aware weighted selection helper next to `routineTargetsInZone` and consume `uncommonBias`. This is more invasive (the band's `avgRoutineMultiplier` assumes uniform-over-species), and is **out of scope** for this spec (Open Decision D4).

**This spec adopts the recommended option:** the spawn layer's only job for weather is the existing exclusive-rare gate (§4.1); the *economic* texture is the trait roll (§5).

---

## 5. The trait roll → payout (HOOKS `RewardPipeline.luau` Cash branch — the load-bearing seam)

This is the one genuinely-new mechanic, and it slots into the **exact** lines where 2x/VIP already lives (`RewardPipeline.luau` L161-175), so it inherits the proven reconciliation-safe pattern.

### 5.1 Where the trait is rolled — Studio spawner, carried on `KillEvent`

Per the spawnEcon constraints: a per-kill random roll touching Workspace **must** live in `*.server.luau`. The roll happens in `WorldServer.server.luau` at the moment a routine target is killed/caught:

1. Compute the live trait set: `LiveOps.activeTraits(Catalog, os.time())`.
2. If non-empty and the target is **routine** (not a rare/artifact — check `RarityRank[rarity] < RARE_AND_ABOVE_RANK`), roll each eligible trait **independently** at probability `traitRollChance` (Tuning, §8.2). Multiple traits can land → **stacking**.
3. Pass the rolled traits on the existing `KillEvent` into the gauntlet → RewardPipeline.

**NEW field on `KillEvent`** (`RewardPipeline.luau` L41-47):

```lua
export type KillEvent = {
    targetId: string,
    owner: string,
    validatingEventId: string,
    loop: Enums.Loop,
    partySize: number?,
    traits: { Enums.Trait }?, -- NEW: server-rolled weather traits (nil/empty = base catch). Routine only.
}
```

> **Why `KillEvent`, not the catalog/`PayoutFn`:** the spawnEcon map's three candidate seams resolve cleanly here. `PayoutFn`'s signature `(config, tier, rarity, destinationId, loop) -> number` has **no trait param** — widening it is the wrong move (it would pollute the band fn used by salvage/idle reconciliation). The catalog row is wrong (trait is per-catch, not per-species). `KillEvent` is the designed carrier for per-event data and is the seam the maps recommend for a "roll-at-kill" mechanic.

### 5.2 Trait → multiplier (NEW pure fn `Economy.traitMultiplier`)

Add a sibling to `Economy.rarityMultiplier` (`logic/Economy.luau` L73-75):

```lua
-- The Cash multiplier a single trait confers. Read from Tuning.economy.traitMultiplier. Unknown → 1.
function M.traitMultiplier(config: Config, trait: string): number
    return (config.tuning.economy.traitMultiplier :: { [string]: number })[trait] or 1
end

-- The COMBINED stacked multiplier for a set of traits (multiplicative, capped). Mirrors the 2x/VIP
-- stack-with-ceiling pattern (Monetization.activeCashMultiplier) so worst-case minting is bounded.
function M.traitStackMultiplier(config: Config, traits: { string }): number
    local m = 1.0
    for _, tr in traits do
        m *= M.traitMultiplier(config, tr)
    end
    return math.min(m, config.tuning.economy.traitStackCeiling)
end
```

### 5.3 The RewardPipeline injection — mirror the boost block exactly

Inside `M.resolve`, in the **`else` (Cash) branch only** (`RewardPipeline.luau` L142-176), **after** the base `Ledger.applyEntry` (L145-151) and **alongside** the existing boost block (L161-175), add a trait bonus written as its **own separate `loop="none"` tagged entry** — the boost block is the template:

```lua
-- WEATHER TRAIT bonus (the GH stackable-mutation analogue). Applies on the Cash branch ONLY, OUTSIDE the
-- normalized band (so avgRoutineMultiplier never self-cancels it), as its own loop="none" tagged entry —
-- the SAME separable pattern as the 2x/VIP boost, so the routine-hour reconciliation (which reads the base
-- formula) is left intact. Rares mint in the IF branch (no Cash) so a trait can never apply to an artifact.
local traits = event.traits or {}
if #traits > 0 then
    local traitMult = Economy.traitStackMultiplier(config, traits)
    local traitBonus = Monetization.boostBonus(amount, traitMult) -- reuse: round(amount*mult) - amount
    if traitBonus > 0 then
        Ledger.applyEntry(profile.cash, {
            type = "traitBonus", -- the weather-trait faucet subtype (separable; loop=none → reconciliation clean)
            amount = traitBonus,
            tier = d.tier,
            loop = "none",
            validatingEventId = event.validatingEventId .. ":trait",
            -- NOTE: NOT realMoneyTagged — this is an in-game faucet, not real-money (see §7.2 budget).
        }, deps.now)
        result.cash += traitBonus
        result.traitCash = traitBonus -- NEW Result field (parallels boostCash)
        incr(deps, "liveops.traitFaucet")
    end
end
```

**NEW `Result` field** (`RewardPipeline.luau` L48-56): add `traitCash: number` parallel to `boostCash`, and a `traitsApplied: { Enums.Trait }?` so the client result-screen (clientCatch workstream) can render which traits landed. `boostBonus` is reused verbatim (`logic/Monetization.luau`, `(base, multiplier) -> round(base*multiplier)-base`).

**Ordering:** trait bonus and 2x/VIP boost are **both** computed off the **same unmultiplied `amount`** base (they do not compound each other unless owner wants them to — Open Decision D5). Writing them as two independent entries keeps each separable in telemetry.

### 5.4 Why this is reconciliation-safe (the binding argument)

- The **base faucet** (`amount`, L147) stays the unmultiplied `Economy.payout` — the dual-loop reconciliation reads the base formula and is **untouched**.
- The trait bonus is `loop="none"` tagged → it is **excluded from the per-loop routine-hour sum** exactly as `boostBonus` is, so it cannot let one loop dominate the band (constraint: "the routine hour sums to exactly Income(T)").
- It is applied **outside** `payoutExact`, so it does **not** enter `avgRoutineMultiplier` and cannot self-cancel.
- It can **never** apply to a rare mint (it's in the `else`/Cash branch; rares mint in the `if` branch with `cash=0`).

---

## 6. The persistent HUD countdown (server-time truth, client display only)

GH's "Next global spawn in HH:MM:SS." This is **display only** — the client renders a ticking clock against a **server-authoritative target timestamp**; the client never computes liveness or value.

### 6.1 Server: NEW projection fields (HOOKS `src/server/authority/Replication.luau`)

Add to the `Replication.Projection` type and `buildProjection` (the projection already ships on every kill/landed reply and on login `StateSync`):

```lua
-- NEW projection fields (weather/countdown — read-only, server-computed):
activeWeather: string?,            -- = LiveOps.activeWeather(config, now)
activeTraits: { string },          -- = keys of LiveOps.activeTraits(config, now) (the "what can I farm now" list)
nextWindowChangeAt: number?,       -- = LiveOps.nextWindowChangeAt(config, now) — the countdown TARGET (server time)
```

The server stamps these from `os.time()` at projection-build time. **The client computes the countdown locally as `nextWindowChangeAt - <client's synced server time>`** and re-derives `activeWeather` only for label display — it never gates anything on its own clock.

### 6.2 Client: NEW countdown widget (HOOKS `client/Hud.luau`)

Per the clientCatch map, `Hud.luau` is the shared singleton with a `M.button` factory and label helpers. Add `M.setCountdown(nextWindowChangeAt, activeWeather, activeTraits)` that renders a persistent header chip ("⛈ Storm — next change 02:14") and a local `RunService.Heartbeat` tick that recomputes `MM:SS` from the server target each frame. `Hud.applyProjection` (L129-159) already runs on every projection push, so it calls `M.setCountdown(proj.nextWindowChangeAt, proj.activeWeather, proj.activeTraits)` there.

> **Clock-sync note:** the client should anchor to the server clock once (e.g. compute `offset = proj.nextWindowChangeAt - tick()` at receive time, then display `proj.nextWindowChangeAt - (tick() + offset)`), or use `workspace:GetServerTimeNow()`. The countdown is **cosmetic**; if it drifts a second, nothing economic depends on it — the server re-validates everything via `os.time()`.

### 6.3 No client→emit path

Per the invariant, the client **emits nothing** about weather/traits. The trait roll, weather liveness, and payout are all server-side; the client only *renders* projection fields. This satisfies "no client→emit analytics path" and "clients never mint value."

---

## 7. RD1 scarcity reuse + faucet/T_current balance

### 7.1 Reuse the require-time scarcity guard for exclusive species

A weather **exclusive species** introduced by a weather event is RD1 content and rides the **existing guard with no new validator**:
- If it's a genuinely-new minted fish → declared `mintNew`, listed in `mintsFish`, validated by `assertEventConfig` (`Validation.luau` L213-257) and merged via `Catalog.luau` L31-39 with `assertNewScarcityId` (the clone-evasion guard, L189-196). **Cannot be clone-evaded** (id collision fails the require) and **cannot be re-released** (a standing rare's id isn't in `mintsFish`).
- If it windows an existing rare → declared `referenceWindow` (rate untouched, RD1a).

**Traits themselves need a new, parallel require-time guard** because they are a new scarcity-adjacent axis. Add to `Validation.assertEventConfig` (after the `mintsFish` checks, L247-256):

```lua
-- NEW: weatherWindow trait discipline (RD1-class structural guard).
if event.traitsGranted ~= nil then
    assert(event.kind == "weatherWindow",
        event.id .. ": traitsGranted is only legal on a weatherWindow event")
    for _, tr in event.traitsGranted do
        assert((config.tuning.economy.traitMultiplier :: any)[tr] ~= nil,
            event.id .. ": trait '" .. tostring(tr) .. "' has no traitMultiplier (every granted trait must be priced)")
    end
end
```

And add to `validateLiveOps` (L272-313) a **weatherWindow non-overlap guard** mirroring the spawn-gating non-overlap (L306-312), so `activeWeather`/`activeTraits` first-match is unambiguous:

```lua
-- NEW: at most ONE weatherWindow live at any instant (activeWeather is a single string; activeTraits
-- first-match relies on it). Mirrors the spawn-gating non-overlap check.
local weather: { Schema.EventConfig } = {}
for _, e in lo.events do
    if e.kind == "weatherWindow" then table.insert(weather, e) end
end
for i = 1, #weather do
    for j = i + 1, #weather do
        local a, b = weather[i], weather[j]
        assert(not (a.startTime <= b.endTime and b.startTime <= a.endTime),
            "weatherWindow events '" .. a.id .. "' and '" .. b.id .. "' overlap — one weather at a time")
    end
end
```

> **Clone/re-release on traits:** because a trait is *priced* (must have a `traitMultiplier`) and is a **closed enum** (you cannot author a new trait string without editing `Enums.Trait`), trait dilution is structurally bounded the same way rarity is. A traited catch **mints no artifact** (it's a routine Cash catch), so there is **no traded artifact to clone or re-release** — the trade-moat concern that RD1 protects simply doesn't apply to traited routine catches. This is the clean reason traits are Cash-branch, not artifacts (see Open Decision D6 if owner wants *traited rares* as tradeable trophies).

### 7.2 Faucet budget — traits add to the Cash supply, so bound them

The 2x/VIP boost is real-money-tagged and budgeted by ARPU; the **trait bonus is an in-game faucet** and therefore **must be bounded against the economy budget**, not waved through.

**Required design rule:** the **expected** trait bonus per routine hour must be small relative to `Income(T)` and must be reconciliation-visible. Because it's `loop="none"` tagged it stays out of the per-loop band, but the analytics layer must meter it. Add a tuning bound and a peak-faucet check:

- `Tuning.economy.traitStackCeiling` (§8.2) caps any single catch's stacked multiplier (e.g. ≤ 3×), bounding worst-case per-catch mint.
- The **expected** hourly trait faucet = `routineCatches/hr × P(≥1 trait) × E[bonus]`. The owner sets `traitRollChance` and the `traitMultiplier` ladder so this stays within a declared fraction of `Income(T)` (recommend ≤ `dailyQuestFraction` = 0.25 of an hour's income as a soft cap — analogous to the event participation faucet thinking, `eventPayout` L116-119).
- **Telemetry separability:** the `liveops.traitFaucet` metric (incr in §5.3) lets the Analytics layer (Step 15 `categoryOf`/`healthReport` canaries) watch the trait faucet share exactly as it watches `boostFaucet` and `eventFaucet`.

### 7.3 T_current interaction — no new tier basis

Traits do **not** touch `Economy.currentTier`. The trait bonus is computed off the **target's displayed-tier base payout** (the same `amount` the routine catch already pays — `payout` uses the target's displayed tier, **not** `currentTier`, per the Economy constraint). So:
- A low-tier player farming traits in a low-tier zone gets a bonus proportional to a **low-tier** base — traits **do not** create a low-tier-farming vector (the multiplier scales the small base, not `Income(T_current)`).
- Idle/daily/salvage/milestone never call RewardPipeline, so they are **never** trait-multiplied — same as the 2x/VIP guarantee.

### 7.4 One loop can't dominate

Weather/traits are **loop-symmetric**: `activeTraits` applies to both hunting kills and fishing catches (the roll in WorldServer happens for both loops). To prevent a weather window that only grants a fishing-favorable trait from skewing the cross-loop balance, the **author rule** is: a weather window's `traitsGranted` are loop-agnostic (a trait multiplies any routine Cash catch). If the owner wants loop-specific traits, that's Open Decision D7 — but the default is symmetric, preserving the dual-loop reconciliation.

---

## 8. Exact Config additions

### 8.1 `src/types/Enums.luau`
- Add `Trait` union + `Enums.Trait` frozen table (§2.1).
- Add `weatherWindow` to the `EventKind` union + frozen table (§2.1).

### 8.2 `src/config/Tuning.luau` — add to `Tuning.economy` (L143-174)

```lua
-- Weather-trait Cash overlay (the GH stackable-mutation analogue). ILLUSTRATIVE DEFAULTS — calibrate
-- against the liveops.traitFaucet telemetry share (must stay a thin fraction of Income(T)). Every trait
-- is PRICED (the require-time guard asserts it). Keyed by Enums.Trait.
traitMultiplier = table.freeze({
    stormTouched = 1.5,
    frostbitten  = 1.4,
    goldenHour   = 1.6,
    fogShrouded  = 1.3,
    moonlit      = 1.8,
} :: { [string]: number }),
traitStackCeiling = 3.0,   -- max stacked per-catch trait multiplier (bounds worst-case mint; ~boost maxStackCeiling)
traitRollChance = 0.15,    -- per-eligible-trait independent roll probability while its weather is live (Studio spawner reads this)
```

> `traitRollChance` lives in `economy` (not `monetization`) because the trait faucet is an **in-game** Cash source the economy budget owns — parallel to `dailyQuestFraction`. The Studio spawner reads it via `config.tuning.economy.traitRollChance`.

### 8.3 `src/config/LiveOps.luau` — the weather rotation records

Add `weatherWindow` event records. **Recommended (Open Decision D3):** author a small deterministic **rotation generator** rather than hundreds of hand-written 5-min windows. Sketch:

```lua
-- A repeating weather ring: N back-to-back windows of `WEATHER_WINDOW_SECONDS`, re-based per real cadence.
-- Pure config: the scheduler's per-tick recompute makes each go live/revert from server time alone.
local WEATHER_WINDOW_SECONDS = 300 -- ~5 min, GH-style
local WEATHER_ROTATION = {
    { weather = "storm",    traits = { Tr.stormTouched },           gates = "alaska_storm_exclusive_fish" },
    { weather = "snow",     traits = { Tr.frostbitten },            gates = nil },
    { weather = "clear",    traits = { Tr.goldenHour },             gates = nil },
    { weather = "fog",      traits = { Tr.fogShrouded },            gates = "appalachia_fog_exclusive_creature" },
    { weather = "overcast", traits = { Tr.moonlit },                gates = nil },
}
-- Generate disjoint back-to-back windows over a base epoch; the live-ops team re-bases `WEATHER_BASE`.
```

Each generated record:
```lua
[id] = {
    id = id, name = "<Weather> Window", kind = "weatherWindow",
    startTime = base + k*WEATHER_WINDOW_SECONDS,
    endTime   = base + (k+1)*WEATHER_WINDOW_SECONDS - 1, -- inclusive, disjoint from the next start
    imposes = { weather = entry.weather, event = entry.gates ~= nil and ("Weather:"..entry.weather) or nil },
    cashBudget = 0, -- traits pay via RewardPipeline, NOT the eventReward faucet → weather events carry no event-faucet budget
    mintsFish = nil, newScarcity = {},
    traitsGranted = entry.traits,
    notes = "Recurring weather window (exclusive spawns + trait grants).",
}
```

**Cross-axis non-overlap caution:** if a weather window also sets `imposes.event` (to gate an exclusive species), it becomes a **spawn-gating** event and must not overlap *other* spawn-gating events (the existing L306-312 guard). Salmon Run/Winter Freeze are spawn-gating; a weather window that gates a species would collide with them. **Resolution:** weather-gated exclusive species should gate on `imposes.weather` (the new independent axis) via `spawn.conditions.weather`, **not** `imposes.event` — so weather windows set **`event = nil`** and only `weather`. This keeps the single-`event`-string invariant intact and lets weather rotate underneath a seasonal beat. (Revise the generator's `gates` to set `spawn.conditions.weather` on the species, not `imposes.event`.)

### 8.4 New `Ids.Event` entries (`src/types/Ids.luau` L27-29)
Add stable ids for each weather window (or a generated id scheme `weather_<tag>_<k>`).

### 8.5 New ids for any exclusive weather species
Author in `config/Creatures.luau` / `config/Fish.luau` with `spawn.conditions = { weather = "<tag>" }`, `rarity >= Rare`, and (if minted) declared `mintNew`.

### 8.6 `RewardPipeline.luau`, `Replication.luau`, `Economy.luau`, `Validation.luau`
The hooks in §3, §5, §6, §7 (all headless-strict; must pass `luau-analyze`).

---

## 9. Concrete test assertions (`./run-tests.sh` gates)

New/extended specs. Each is a `(t: Harness.T) -> ()` registered in `tests/run.luau`.

### 9.1 `tests/LiveOps.spec.luau` (extend)
- `activeWeather` returns the imposed weather tag inside a weatherWindow, `nil` outside (both inclusive ends — assert at `startTime`, `endTime`, `endTime+1`).
- `activeTraits` returns the union of `traitsGranted` while live; empty outside.
- `nextWindowChangeAt`: at a time strictly inside window k, returns `endTime_k + 1`; in a gap, returns the next `startTime`; returns `nil` when no weatherWindow is ahead.
- `worldStateAt` now overlays `weather` from a weather-only window **even while a spawn-gating seasonal event** (Salmon Run) is live, **without** changing `event` (assert `ws.event == "Salmon Run"` and `ws.weather == "storm"` simultaneously).
- Boundary: at exactly `endTime`, the weather is still active (inclusive); at `endTime+1` it is not.

### 9.2 `tests/Spawner.spec.luau` (extend)
- A creature/fish with `spawn.conditions.weather = "storm"` is `rareSpawnEligible` true iff `world.weather == "storm"`, false otherwise (reuses existing predicate — proves zero-code exclusivity).

### 9.3 `tests/RewardPipeline.spec.luau` (extend) — the core economic proof
- **Trait bonus is additive & separate:** a routine Cash catch with `event.traits = { stormTouched }` yields `result.cash == basePayout + boostBonus(basePayout, 1.5)` and writes a **second** ledger entry of `type="traitBonus"`, `loop="none"`. Assert the **base** entry's amount equals the unmultiplied `Economy.payout`.
- **Stacking:** `event.traits = { stormTouched, moonlit }` → multiplier `min(1.5*1.8, traitStackCeiling)`; assert the cap binds when the product exceeds `traitStackCeiling`.
- **Reconciliation neutrality:** sum of `loop != "none"` entries over a routine hour with traits active **equals** the no-trait routine-hour sum (the band is untouched). (Mirror the existing dual-loop reconciliation assertion.)
- **Rare immunity:** a rare/artifact catch with `event.traits` set **mints an artifact, `result.cash == 0`, and writes NO `traitBonus` entry** (the XOR holds; trait never touches the IF branch).
- **T_current independence:** trait bonus scales the target's displayed-tier base, not `Income(currentTier)` — assert a low-tier traited catch's bonus ≪ a high-tier traited catch's bonus for the same trait.
- **No-trait parity:** `event.traits = nil` reproduces the pre-change result exactly (regression guard).

### 9.4 `tests/Validation.spec.luau` (extend)
- An event with `traitsGranted` but `kind != "weatherWindow"` **fails** `assertEventConfig` (`t.errs`).
- A `traitsGranted` entry with no `traitMultiplier` in Tuning **fails** (every granted trait must be priced).
- Two overlapping `weatherWindow` events **fail** `validateLiveOps` (the new non-overlap guard).
- A weather window setting `imposes.event` overlapping Salmon Run **fails** the existing spawn-gating non-overlap guard (proves the §8.3 "weather sets only `weather`" rule is enforced).

### 9.5 `tests/Catalog.spec.luau` (extend)
- A weather-event-minted exclusive fish whose id collides with a base catalog id **fails** the require (`assertNewScarcityId` — clone-evasion, reused for traits' exclusive species).

### 9.6 `tests/Economy.spec.luau` (extend)
- `traitMultiplier` returns the Tuning value; unknown trait → `1`.
- `traitStackMultiplier` is multiplicative and capped at `traitStackCeiling`.

### 9.7 Negative fixture (`tests/negative/`) — prove pay/power-for-trait unrepresentable
- A fixture attempting a `ProductGrant` that grants a trait, OR a trait that raises tier/conquest, must **fail** `luau-analyze` (Gate 3). Since `Trait` only ever flows through `KillEvent` (server-rolled) and the Cash branch, and `ProductGrant` is the closed never-power union, **a monetized trait is already unrepresentable** — the fixture documents that the trait field is absent from `ProductGrant` and `KillEvent.traits` is server-only.

### 9.8 `tests/Replication.spec` (or wherever the projection is tested)
- `buildProjection` populates `activeWeather`/`activeTraits`/`nextWindowChangeAt` from the injected `now`, and they are `nil`/empty outside any weather window. (Headless: the projection builder is server-substrate, not the Studio file.)

---

## 10. End-to-end data flow (summary)

1. **Authoring:** live-ops adds `weatherWindow` records (rotation generator, §8.3) with `imposes.weather` + `traitsGranted`; optional exclusive species author `spawn.conditions.weather`. Config self-validates at require (`Catalog.luau` → `validateLiveOps`).
2. **Schedule (pure):** `WorldServer.server.luau`'s spawn loops call `LiveOps.worldStateAt(Catalog, os.time())` per tick (existing seam) → now also yields `weather`. `LiveOps.activeTraits`/`activeWeather`/`nextWindowChangeAt` computed from the same `os.time()`.
3. **Spawn gate (pure):** `Spawner.rareSpawnEligible` matches `world.weather` against a species' `conditions.weather` — exclusive spawns, zero new code.
4. **Trait roll (Studio):** on a routine kill/catch, WorldServer rolls each `activeTraits` member at `traitRollChance`, attaches `traits` to `KillEvent`.
5. **Payout (headless substrate):** `RewardPipeline.resolve` Cash branch writes the unmultiplied base, then a separate `loop="none"` `traitBonus` entry via `Economy.traitStackMultiplier` + `boostBonus` — reconciliation intact, rares immune.
6. **Replication (server):** projection ships `activeWeather`/`activeTraits`/`nextWindowChangeAt` on every kill/landed/login.
7. **HUD (client):** `Hud.setCountdown` ticks `nextWindowChangeAt - serverTime` locally; renders the weather chip + countdown. Client emits nothing.
8. **Telemetry:** `liveops.traitFaucet` metered separately for the faucet-share canary.

---

## OPEN DESIGN DECISIONS (owner)

- **D1 — Player-facing name for the trait axis.** Recommended "Tracks"/"Touched" (e.g. "Storm-Touched") over GH's "mutation," to fit a grounded hunting/fishing tone. Affects copy only; internal type stays `Trait`.
- **D2 — New `weatherWindow` kind vs reuse `conditionWindow`.** Spec recommends a distinct `weatherWindow` (short recurring cadence + `traitsGranted` + countdown). Owner may fold into the unused `conditionWindow` to avoid an enum addition — at the cost of overloading its semantics.
- **D3 — Deterministic rotation generator vs hand-authored windows vs a true runtime-random driver.** GH is runtime-random; Wild World's scheduler is server-time-deterministic. Recommended: a deterministic, re-basable rotation generator (small config, fully testable). Alternative: build an actual ambient weather *driver* in `WorldServer` (Studio-only) and have it set `world.weather` directly — but then weather liveness is **not** server-time-reproducible and the countdown/`nextWindowChangeAt` semantics weaken. **Pick one; the rest of the spec assumes the deterministic generator.**
- **D4 — Does weather *bias the routine spawn pool* (weighted membership) or only enable the trait roll?** Spec adopts trait-roll-only (keeps `routineTargetsInZone` unweighted and the band normalization untouched). Weighted weather spawns would require a new selection helper and care around `avgRoutineMultiplier`.
- **D5 — Do trait bonuses compound with the 2x/VIP boost, or both apply off the same base?** Spec applies both off the unmultiplied base (no compounding) for a clean bound. Compounding (trait × boost) is more generous but raises the worst-case mint ceiling and complicates the budget.
- **D6 — Traited *rares* as tradeable trophies?** Spec keeps traits strictly Cash-branch (routine only) so there is no traded artifact to clone/re-release. If the owner wants "a Storm-Touched Legendary" as a distinct tradeable artifact, that needs a per-artifact trait field on `Provenance` + the RD1 guard extended to traited artifacts (a meaningfully larger trade-moat surface — recommend deferring).
- **D7 — Loop-symmetric vs loop-specific traits.** Spec defaults to loop-agnostic traits (any routine Cash catch) to preserve dual-loop balance. Loop-specific traits (a fishing-only trait window) need a cross-loop-balance check so one loop's trait richness can't dominate.
- **D8 — Trait faucet budget magnitude.** `traitMultiplier` ladder + `traitRollChance` + `traitStackCeiling` are illustrative. Owner must set them so the **expected** `liveops.traitFaucet` share stays a thin fraction of `Income(T)` (recommend a soft cap ≈ `dailyQuestFraction`), and decide whether to add a hard per-window trait-faucet ceiling analogous to `eventPayoutBudgetCeiling`.
- **D9 — Countdown granularity & weather density.** GH ~5-min cycles. Owner sets `WEATHER_WINDOW_SECONDS` and how many weather types rotate — this is the "alive" pacing knob and trades server-time-config volume against feel.
- **D10 — Does an exclusive weather *species* need its own event-faucet (`cashBudget>0`) or is its value purely the artifact/trophy?** Spec sets weather events `cashBudget = 0` (value = the catch + the trait overlay), consistent with RD2. Owner may add a thin participation faucet via the existing `EventRewardHandler` if a weather beat should also pay a claim.

---

**Files this spec hooks (existing) vs creates (new):**
- HOOKS: `src/logic/LiveOps.luau` (widen `worldStateAt`; add `activeWeather`/`activeTraits`/`nextWindowChangeAt`), `src/logic/Spawner.luau` (zero code — reuses `rareSpawnEligible`), `src/server/combat/RewardPipeline.luau` (trait bonus in the Cash branch; `KillEvent.traits`, `Result.traitCash`), `src/logic/Economy.luau` (`traitMultiplier`/`traitStackMultiplier`), `src/config/Validation.luau` (trait + weather-overlap guards), `src/config/Tuning.luau` (`traitMultiplier`/`traitStackCeiling`/`traitRollChance`), `src/server/authority/Replication.luau` (projection fields), `src/server/world/WorldServer.server.luau` (Studio trait roll + countdown source), `client/Hud.luau` (countdown widget), `src/types/Schema.luau` (`EventConfig.traitsGranted`), `src/types/Enums.luau` (`Trait`, `weatherWindow`), `src/types/Ids.luau` (weather event ids).
- NEW config records: weatherWindow rotation in `src/config/LiveOps.luau`; optional exclusive species in `src/config/Creatures.luau` / `src/config/Fish.luau`.
- NEW/extended tests: `LiveOps.spec`, `Spawner.spec`, `RewardPipeline.spec`, `Validation.spec`, `Catalog.spec`, `Economy.spec`, a `tests/negative/` fixture, projection test (§9).

---

## Faithfulness review (automated adversarial pass · 2026-06-19)
**Verdict: faithful = True** — every referenced symbol/file was confirmed against the codebase maps; no invented APIs. The following are refinements to fold in during implementation (none are blockers):

- **[medium]** Replication.buildProjection's actual signature is buildProjection(profile: PlayerData, config: Config) -> Projection (Replication.luau L37) — it takes NO `now` parameter and references no Roblox globals (it is headless-strict, excluded from os.time()). It is invoked from inside the headless Gauntlet at Gauntlet.luau L99 (Replication.buildProjection(session.profile, deps.config)) for every kill/landed reply (r.projection at WorldServer L863/L986) and also directly at WorldServer L1196/L1121. The spec cannot 'stamp os.time() at projection-build time' without widening the headless contract, which the spec never calls out. This is the same class of omission the spec elsewhere flags carefully (e.g. PayoutFn signature widening).
  - _Re:_ §6.1: 'Add to the Replication.Projection type and buildProjection ... The server stamps these from os.time() at projection-build time.' Listed under HOOKS: src/server/authority/Replication.luau.
  - _Fix:_ State explicitly that buildProjection's signature must be widened to buildProjection(profile, config, now) and that Gauntlet.handle must pass deps.now at L99 (deps.now is already in scope in the Ctx/Deps — Gauntlet.luau L68/L32). All other call sites (WorldServer L1196/L1121) pass os.time(). Keep os.time() confined to the Studio file; the headless projection receives `now` by injection, consistent with the LiveOps purity invariant.
- **[medium]** The pattern is faithful, but the spec's example entry includes a trailing comment '-- NOTE: NOT realMoneyTagged' and omits realMoneyTag. That is correct (Ledger.EntryDraft.realMoneyTag is optional — Ledger.luau L23), but the spec should make explicit that the trait faucet is therefore NOT visible to the existing realMoney-tagged separability the boost uses (realMoneyTag = 'realmoney:boost' at RewardPipeline L170). The §7.2 telemetry-share canary depends on a distinct tag/metric (incr 'liveops.traitFaucet'); without a ledger-level tag the trait faucet is separable only by entry `type=traitBonus`, not by realMoneyTag. This is fine but under-specified for the reconciliation/audit story.
  - _Re:_ §5.3: the trait bonus Ledger.applyEntry uses validatingEventId = event.validatingEventId .. ':trait', mirroring boostBonus' event.validatingEventId .. ':boost'.
  - _Fix:_ Either add an optional non-realmoney audit tag distinct from 'realmoney:*' (e.g. add a faucetTag field, or rely solely on type='traitBonus' + the incr metric) and state that the trait faucet is identified at the ledger by type='traitBonus' and loop='none' (NOT by realMoneyTag, since it is an in-game faucet not a real-money one). Confirm the Analytics categoryOf taxonomy (Step 15) will bucket type='traitBonus' correctly — that mapping is net-new and should be named.
- **[low]** Faithful as additions. One precision note: Tuning.economy is table.freeze({...}) (Tuning.luau L143) and rarityMultiplier inside it is itself table.freeze (L148). The spec's §8.2 sketch correctly wraps traitMultiplier in table.freeze, but the cast ':: { [string]: number }' must match how rarityMultiplier is read (Economy.rarityMultiplier casts config.tuning.economy.rarityMultiplier :: { [string]: number } — Economy.luau L74). The spec's Economy.traitMultiplier uses the same cast, so it is consistent — but the new Tuning field is added inside a frozen table, so this is a source edit (config-not-code does NOT apply: adding a tuning field is a code change to Tuning.luau, like every prior tuning addition).
  - _Re:_ §5.3 / §5.2: references config.tuning.economy.traitMultiplier, traitStackCeiling (new), and Economy.traitStackMultiplier / traitMultiplier (new pure fns paralleling Economy.rarityMultiplier at Economy.luau L73-75).
  - _Fix:_ No correctness change needed; optionally note that adding traitMultiplier/traitStackCeiling/traitRollChance to the frozen Tuning.economy is a source edit (the same pattern as the Step-14 monetization knobs), not a runtime/config-only droppable, to avoid implying it is config-not-code.
- **[low]** The rewrite is faithful and preserves the single-spawn-gating-event invariant (inner loop still resolves ws.event from the one non-overlapping spawn-gating event). However the spec's rewrite drops the original early-return's exact-shape semantics: the current worldStateAt returns {time,weather,season,event} only from THE first spawn-gating event. The new merged loop sets ws.season/ws.time/ws.weather from ANY live spawn-gating event via 'or' — but since the non-overlap guard (Validation L306-312) guarantees at most ONE spawn-gating event live, the loop body runs at most once for event-bearing events, so behavior is equivalent. The weather-only overlay (ws.weather = ws.weather or M.activeWeather) is the genuinely new behavior and is sound given the new weatherWindow non-overlap guard (§7.1).
  - _Re:_ §3.2: proposes widening M.worldStateAt to merge weather across events and overlay activeWeather, replacing the existing single-event early-return (LiveOps.luau L66-73).
  - _Fix:_ No change to correctness. Optionally note in the spec that the merged loop is observationally identical to the early-return for event-bearing events (because non-overlap guarantees ≤1 spawn-gating event), so existing worldStateAt tests (tests/LiveOps.spec) remain green — the only new behavior is the weather overlay.
- **[low]** Faithful and correct. Minor: the existing spawn-gating guard collects events with imposes.event ~= nil (L300-305); the new weather guard collects e.kind == 'weatherWindow'. A weatherWindow that sets imposes.event (which §8.3 forbids but is structurally possible pre-validation) would be checked by BOTH guards. That is harmless (over-constraining), and §9.4 even tests the spawn-gating guard catches a weather window setting imposes.event overlapping Salmon Run. Consistent.
  - _Re:_ §7.1: the new weatherWindow non-overlap guard in validateLiveOps mirrors the existing spawn-gating non-overlap check (Validation.luau L306-312).
  - _Fix:_ No change needed. Optionally clarify that a weatherWindow is intended to set imposes.event = nil (weather is the independent axis); the dual coverage is intentional belt-and-suspenders.
