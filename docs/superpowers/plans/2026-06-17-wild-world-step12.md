# Wild World Step 12 — Trading (the moat's runtime enforcement) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make design-time scarcity into runtime scarcity — an all-or-nothing two-sided artifact swap (dupe-proof), a server-owned negotiation state machine with version-bound double-confirm and escrow, the trade tax, and the 8 MVL pre-launch checks — without ever letting an artifact be LIVE in two profiles.

**Architecture:** Two layers kept strictly separate. (1) **The atomic swap primitive** — a new `ArtifactStore.transferOwnership` (live copy to the new owner + tombstone-not-erase on the old) riding a new two-profile `PairTransaction` (parallel to the single-profile `Transaction.run`), composed in `TradeSwap` which pre-validates every CAS precondition before any mutation and runs as one no-yield section. (2) **The trade flow** — `TradeService`, a server-owned `PendingTrade` state machine (REQUESTED→BUILDING→A/B_CONFIRMED→COMMITTING→COMPLETE|CANCELLED) with one-active-trade, the terms-snapshot-version re-arm, the escrow lifecycle (HELD↔ESCROWED on the existing CAS), offer validation, the tax, and the server-sourced read-only projection/final-terms. The swap is a special two-session path (both profiles via injected `getProfile`), never a single-session gauntlet handler.

**Tech Stack:** Luau (`--!strict`), the headless harness (`tests/harness.luau` + `tests/util.luau`), Rojo. Toolchain on PATH at `~/.local/bin`. Require-by-string via `.luaurc` aliases `@src/...` / `@tests/...`.

## Global Constraints

- **Run all commands from the git root** `RobloxRPG/RobloxRPG/`.
- **`./run-tests.sh` is the DoD gate** — (1) `luau-analyze --!strict` clean on every headless module, (2) all unit tests pass, (3) negative fixtures FAIL analysis, (4) `rojo build` succeeds. Baseline before Step 12: **ALL GREEN, 938 passed, 0 failed**. Every task ends ALL GREEN.
- **Headless vs Studio split:** headless = `src/config/`, `src/logic/`, `src/server/**` except `*.server.luau`. Never put a Roblox global into a headless module. `WorldServer.server.luau` is Studio-only (excluded from gates 1–2) but must `rojo build`.
- **THE anti-dupe invariant (rigor-critical):** no artifact is ever **LIVE in two profiles** at any observable instant. The new owner gets the live record; the old owner's is **tombstoned (marked traded-away), never erased** (audit/rollback — exactly as `SalvageHandler` tombstones). A tombstone is audit-only: not tradeable, not usable.
- **All-or-nothing over both profiles:** every transfer commits or none does. A CAS mismatch or save failure reverts **both** profiles in memory and transfers nothing. No item leaves one inventory until it enters the other.
- **The whole swap is ONE no-yield section** (the existing `Transaction` discipline) — so no transient mid-move state is ever observable. Do not chase an impossible single-statement cross-table move.
- **Server-authority absolute:** the server owns `PendingTrade`; clients send intents and see a read-only projection; no client asserts the trade's contents, an item's identity, or the outcome.
- **The confirm is bound to a terms-snapshot version:** any offer change increments the version and clears **both** confirms (re-arm) and reverts that side's escrow; a stale-version confirm is **rejected** (structural, not a flag-and-hope).
- **Escrow reverts on every exit path** — re-arm, cancel, timeout, disconnect. Never dangling.
- **Cash moves only as the priced payment leg, net of tax, inside the atomic commit;** `|A.items| + |B.items| ≥ 1` at commit; tax taken **exactly once** on commit. Zero-Cash trades pay zero tax. **No raw Cash send.**
- **Offerable iff `tradeable == true` AND `disposition == HELD` AND owned by the offerer.** A commodity (no artifactId) is structurally un-offerable; a DISPLAYED trophy must be un-displayed first; ESCROWED/SALVAGED can't be added.
- **Reuse, never reimplement:** `ArtifactStore.transition` (the CAS edge table), `Copy.deep`/`restoreInto`, `Ledger`, `SessionService`, `SalvageHandler`'s tombstone idea. The swap *rides* the ESCROWED→HELD edge with an owner change and *composes* Copy over a pair.
- **Two-key persist window:** `saveNow` persists ONE ProfileStore key, so two profiles = two saves (not ProfileStore-atomic). The two-profile snapshot/restore covers a save *failure* (revert both in memory). The residual **crash window** (key A persisted, crash before key B) is closed by the **two-sided trade record** (built here, per-profile `tradeLog`) + **reconcile-on-reload** — build the record (headless); the reconcile consumer is the **named, flagged recovery path** in the README (it needs the audit-log / point-in-time substrate already deferred to ops). Do NOT leave it silently unhandled.
- **Deferrals (do NOT build):** cross-server trading / MemoryStore broker → post-launch; auction house / order book / matching → post-launch; raw Cash transfer/gifting → never; the Trading Post UI / negotiation panels / final-terms rendering / countdown visuals → Studio.

## Constants & names (added this step; copy verbatim)

- `Tuning.economy.tradeTaxRate = 0.05` — §5 LOW anti-wash friction (not inflation ballast).
- `Tuning.persistence.commitSettleSeconds = 3` — the settle-delay freeze before the swap (the fat-finger guard). (`escrowTimeoutSeconds = 120` already exists.)
- `Economy.tradeTax(config, grossCash): number` = `round(grossCash * config.tuning.economy.tradeTaxRate)`.
- Ledger entry types (free strings): `"tradepay-out"` (payer, −gross), `"tradepay-in"` (payee, +gross), `"tradetax"` (payee, −tax). `loop = "none"` on all three. `validatingEventId = tradeId`.
- `Enums.TradeState` = `"REQUESTED" | "BUILDING" | "A_CONFIRMED" | "B_CONFIRMED" | "COMMITTING" | "COMPLETE" | "CANCELLED"`.
- Disposition (exists): `HELD | DISPLAYED | ESCROWED | SALVAGED`. The swap rides `ESCROWED → (new owner, HELD)`.

---

## File Structure

**Create (headless):**
- `src/server/authority/PairTransaction.luau` — the two-profile atomic transaction.
- `src/server/trading/TradeSwap.luau` — the atomic two-sided swap primitive (§A).
- `src/server/trading/TradeService.luau` — the `PendingTrade` state machine + intents + escrow + tax + projection (§B–F).
- `tests/PairTransaction.spec.luau`, `tests/TradeSwap.spec.luau`, `tests/TradeService.spec.luau`.

**Modify (headless):**
- `src/config/Tuning.luau` — add `tradeTaxRate` + `commitSettleSeconds`.
- `src/logic/Economy.luau` — add `tradeTax`.
- `src/server/artifacts/ArtifactStore.luau` — add `transferOwnership`.
- `src/types/Schema.luau` — add `TradeRecord` type + `PlayerData.tradeLog: { TradeRecord }`.
- `src/types/Enums.luau` — add `TradeState`.
- `src/logic/Profile.luau` — init `tradeLog = {}` in the fresh-profile constructor.
- `tests/util.luau` — init `tradeLog = {}` in `mkProfile`.
- `tests/Economy.spec.luau`, `tests/ArtifactStore.spec.luau`, `tests/Profile.spec.luau` — new sections.
- `tests/run.luau` — register the three new specs.

**Modify (Studio-only — must `rojo build`):**
- `src/server/world/WorldServer.server.luau` — wire `TradeService`, flip the `TradingPost` fixture to `built`.

**Modify (docs):**
- `README.md` — Step 12 section + the deferred table + the two-key reconcile flag.

---

## Setup

- [ ] **Step S1: Branch** (commits user-gated)
```bash
git checkout -b step-12-trading
```
- [ ] **Step S2: Confirm baseline**
Run: `./run-tests.sh 2>&1 | tail -3` → `ALL GREEN ✓`, `938 passed, 0 failed`.

---

## Task 1: Trade tax — the rate + the formula

**Files:**
- Modify: `src/config/Tuning.luau` (Tuning.economy + Tuning.persistence)
- Modify: `src/logic/Economy.luau` (add `tradeTax`)
- Test: `tests/Economy.spec.luau` (new section)

**Interfaces:**
- Produces: `config.tuning.economy.tradeTaxRate: number` (0.05); `config.tuning.persistence.commitSettleSeconds: number` (3); `Economy.tradeTax(config: Config, grossCash: number): number` = `round(grossCash * rate)`. Consumed by Task 5 (TradeSwap) + Task 7 (settle).

- [ ] **Step 1: Write the failing test** — append inside the `return function(t: Harness.T)` body of `tests/Economy.spec.luau`:
```lua
	t.section("Economy — trade tax: round(rate * gross); LOW anti-wash friction (Step 12)")
	do
		t.eq("5% of 1000 = 50", Economy.tradeTax(Catalog, 1000), 50)
		t.eq("zero gross = zero tax (item-for-item)", Economy.tradeTax(Catalog, 0), 0)
		t.eq("rounds to integer Cash", Economy.tradeTax(Catalog, 999), 50) -- 999*0.05=49.95 → 50
		t.ok("the rate is LOW (≤ 10%)", Catalog.tuning.economy.tradeTaxRate <= 0.10)
		t.ok("commitSettleSeconds is a small positive freeze", Catalog.tuning.persistence.commitSettleSeconds > 0 and Catalog.tuning.persistence.commitSettleSeconds <= 10)
	end
```
(If `Catalog` isn't imported in Economy.spec, it is — verify the require block has `local Catalog = require("@src/config/Catalog")`; add it if missing.)

- [ ] **Step 2: Run to verify it fails** — Run: `luau tests/run.luau 2>&1 | grep -iE "trade tax|tradeTax|nil value" | head` → FAIL (`attempt to call a nil value (field 'tradeTax')`).

- [ ] **Step 3: Add the Tuning constants.** In `src/config/Tuning.luau`, find the end of `Tuning.economy` (the `crossLoopBonusHours = 0.5,` line followed by `})`) and add the rate before the `})`:
```lua
	crossLoopBonusHours = 0.5,
	tradeTaxRate = 0.05, -- §5 LOW anti-wash-trading friction on the Cash leg (NOT inflation ballast)
})
```
Then find the end of `Tuning.persistence` (the `escrowTimeoutSeconds = 120,` line followed by `})`) and add:
```lua
	escrowTimeoutSeconds = 120, -- pending-trade auto-cancel window (Step 12 consumes)
	commitSettleSeconds = 3, -- the settle freeze between the 2nd confirm and the swap (Step 12; fat-finger guard)
})
```

- [ ] **Step 4: Add `Economy.tradeTax`.** In `src/logic/Economy.luau`, add (after `M.salvageFloor`, before `return M`):
```lua
-- Step 12: the trade tax on a Cash leg — round(rate · gross). The rate is LOW (§5 anti-wash friction); this
-- code APPLIES it (economy owns the rate). Zero gross → zero tax (an item-for-item trade has no Cash leg).
function M.tradeTax(config: Config, grossCash: number): number
	return round(grossCash * config.tuning.economy.tradeTaxRate)
end
```
(`round` is the existing `local function round(x) return math.floor(x + 0.5) end`; `Config` is the existing `type Config = Schema.Config`.)

- [ ] **Step 5: Run to verify it passes** — Run: `luau tests/run.luau 2>&1 | tail -3` → `0 failed`.
- [ ] **Step 6: Full gate** — Run: `./run-tests.sh 2>&1 | tail -3` → `ALL GREEN ✓`.
- [ ] **Step 7: Commit** (when authorized)
```bash
git add src/config/Tuning.luau src/logic/Economy.luau tests/Economy.spec.luau
git commit -m "feat(step12): trade tax rate + Economy.tradeTax + commitSettleSeconds

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Schema — TradeRecord + PlayerData.tradeLog + Enums.TradeState

**Files:**
- Modify: `src/types/Schema.luau` (add `TradeRecord`; add `tradeLog` to `PlayerData`)
- Modify: `src/types/Enums.luau` (add `TradeState`)
- Modify: `src/logic/Profile.luau` (init `tradeLog = {}` in the fresh-profile constructor)
- Modify: `tests/util.luau` (init `tradeLog = {}` in `mkProfile`)
- Test: `tests/Profile.spec.luau` (assert a fresh profile has an empty `tradeLog`)

**Interfaces:**
- Produces: `Schema.TradeRecord = { tradeId: string, partyA: string, partyB: string, aArtifactIds: { ArtifactId }, bArtifactIds: { ArtifactId }, payer: string, cashGross: number, tax: number, timestamp: number }`; `PlayerData.tradeLog: { TradeRecord }`; `Enums.TradeState`. Consumed by Tasks 5–7.

- [ ] **Step 1: Find every PlayerData constructor** so analysis won't break on the new required field.
Run: `grep -rn "tradeLog\|freshProfile\|inventory = {" src/ tests/ | grep -v "\.spec"` and `grep -rln "artifacts = {}" src tests`. Expect constructors in `src/logic/Profile.luau` (fresh profile) and `tests/util.luau` (`mkProfile`). If `ProfileStore.luau` or another file constructs a `PlayerData` literal, it must also init `tradeLog = {}` — note all sites before editing.

- [ ] **Step 2: Write the failing test** — append inside the `return function(t: Harness.T)` body of `tests/Profile.spec.luau`:
```lua
	t.section("Profile — a fresh profile starts with an empty tradeLog (Step 12 audit substrate)")
	do
		local p = Util.mkProfile(Catalog, { weapon = 1 })
		t.eq("mkProfile tradeLog is empty", #p.tradeLog, 0)
	end
```
(Ensure `Util` + `Catalog` are imported in Profile.spec; add the requires if missing.)

- [ ] **Step 3: Run to verify it fails** — Run: `luau tests/run.luau 2>&1 | grep -iE "tradeLog|nil|fields missing" | head` → FAIL (`tradeLog` is nil / `attempt to get length of a nil value`).

- [ ] **Step 4: Add the `TradeRecord` type + `tradeLog` field** in `src/types/Schema.luau`. Find the `Provenance`/`Artifact` block and add `TradeRecord` after `Artifact` (it references `ArtifactId`):
```lua
-- Step 12: the two-sided trade record (audit/rollback substrate, data-integrity §5/§7). Written to BOTH
-- parties' tradeLog inside the atomic swap so a reconcile-on-reload can reconstruct/reverse a trade.
export type TradeRecord = {
	tradeId: string,
	partyA: string, -- the two owner keys
	partyB: string,
	aArtifactIds: { ArtifactId }, -- A's artifacts that moved to B
	bArtifactIds: { ArtifactId }, -- B's artifacts that moved to A
	payer: string, -- the owner key that paid the net Cash leg ("" if no Cash leg)
	cashGross: number, -- the gross Cash moved (net of the two sides' offers); tax skimmed from it
	tax: number,
	timestamp: number,
}
```
Then find the `PlayerData` type and add the field (next to `artifacts`):
```lua
	artifacts: { [ArtifactId]: Artifact },
	tradeLog: { TradeRecord }, -- Step 12: append-only two-sided trade records (audit/rollback)
```

- [ ] **Step 5: Add `Enums.TradeState`** in `src/types/Enums.luau` (after the `Disposition` block):
```lua
-- Step 12: the PendingTrade negotiation states (server-owned; the read-only projection carries this).
export type TradeState = "REQUESTED" | "BUILDING" | "A_CONFIRMED" | "B_CONFIRMED" | "COMMITTING" | "COMPLETE" | "CANCELLED"
Enums.TradeState = table.freeze({
	REQUESTED = "REQUESTED" :: TradeState,
	BUILDING = "BUILDING" :: TradeState,
	A_CONFIRMED = "A_CONFIRMED" :: TradeState,
	B_CONFIRMED = "B_CONFIRMED" :: TradeState,
	COMMITTING = "COMMITTING" :: TradeState, -- both confirmed; in the settle window, then the swap
	COMPLETE = "COMPLETE" :: TradeState,
	CANCELLED = "CANCELLED" :: TradeState,
})
```

- [ ] **Step 6: Init `tradeLog`** in `src/logic/Profile.luau`'s fresh-profile constructor (the table literal that has `artifacts = {}`):
```lua
		artifacts = {},
		tradeLog = {},
```
and in `tests/util.luau`'s `mkProfile` return table (after `artifacts = {},`):
```lua
		artifacts = {},
		tradeLog = {},
```
Plus any other constructor found in Step 1.

- [ ] **Step 7: Run to verify it passes** — Run: `luau tests/run.luau 2>&1 | tail -3` → `0 failed`.
- [ ] **Step 8: Full gate** — `./run-tests.sh 2>&1 | tail -3` → `ALL GREEN ✓` (confirms every PlayerData constructor inits `tradeLog`).
- [ ] **Step 9: Commit** (when authorized)
```bash
git add src/types/Schema.luau src/types/Enums.luau src/logic/Profile.luau tests/util.luau tests/Profile.spec.luau
git commit -m "feat(step12): TradeRecord + PlayerData.tradeLog + Enums.TradeState

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: ArtifactStore.transferOwnership (the cross-profile transfer — anti-dupe core)

**Files:**
- Modify: `src/server/artifacts/ArtifactStore.luau` (add `transferOwnership`)
- Test: `tests/ArtifactStore.spec.luau` (new section)

**Interfaces:**
- Consumes: the existing `Artifact` shape, `D` (Disposition), `TransitionResult` (the `{ ok, reason? }` return type already used by `transition`).
- Produces: `ArtifactStore.transferOwnership(fromProfile: PlayerData, toProfile: PlayerData, artifactId: string, expected: Disposition, newOwner: string): TransitionResult` — CAS on `from`'s `expected` disposition; on success, `to` gets a LIVE copy (owner=newOwner, HELD, in `to.artifacts` + `to.inventory.artifactIds`) and `from`'s record is tombstoned + removed from `from.inventory.artifactIds`. Consumed by Task 5.

- [ ] **Step 1: Write the failing test** — append inside the `return function(t: Harness.T)` body of `tests/ArtifactStore.spec.luau`:
```lua
	t.section("ArtifactStore — transferOwnership: live to new owner, TOMBSTONE (not erased) on the old (Step 12)")
	do
		local Util = require("@tests/util")
		local from = Util.mkProfile(Catalog, {})
		local to = Util.mkProfile(Catalog, {})
		local a = ArtifactStore.mint(from, { kind = "trophy", tradeable = true, owner = "u1", sourceId = "bayou_white_alligator", validatingEventId = "ev" }, Fakes.newIdGenerator(), 1)
		assert(ArtifactStore.transition(from, a.artifactId, "HELD", "ESCROWED").ok) -- escrow before the swap
		local r = ArtifactStore.transferOwnership(from, to, a.artifactId, "ESCROWED", "u2")
		t.ok("the transfer succeeds", r.ok)
		t.ok("LIVE in the new owner: owner flipped, HELD, in the owned set", to.artifacts[a.artifactId] ~= nil and to.artifacts[a.artifactId].owner == "u2" and to.artifacts[a.artifactId].disposition == "HELD" and to.inventory.artifactIds[a.artifactId] == true and to.artifacts[a.artifactId].tombstoned == false)
		t.ok("TOMBSTONE in the old owner: marked, NOT erased, and NOT in the owned set", from.artifacts[a.artifactId] ~= nil and from.artifacts[a.artifactId].tombstoned == true and from.inventory.artifactIds[a.artifactId] == nil)
		t.ok("provenance preserved on the live record (immutable history)", to.artifacts[a.artifactId].provenance.sourceId == "bayou_white_alligator")
		-- the anti-dupe invariant: NOT live in two profiles (old is tombstoned, new is live)
		t.ok("not LIVE in two profiles", (from.inventory.artifactIds[a.artifactId] == nil) and (to.inventory.artifactIds[a.artifactId] == true))
	end
	t.section("ArtifactStore — transferOwnership CAS: a non-ESCROWED source is rejected (no transfer)")
	do
		local Util = require("@tests/util")
		local from = Util.mkProfile(Catalog, {})
		local to = Util.mkProfile(Catalog, {})
		local a = ArtifactStore.mint(from, { kind = "trophy", tradeable = true, owner = "u1", sourceId = "bayou_white_alligator", validatingEventId = "ev" }, Fakes.newIdGenerator(), 1)
		-- still HELD (not escrowed) → expected=ESCROWED CAS fails
		local r = ArtifactStore.transferOwnership(from, to, a.artifactId, "ESCROWED", "u2")
		t.ok("rejected: precondition_mismatch (CAS)", r.ok == false and r.reason == "precondition_mismatch")
		t.ok("nothing transferred: old keeps it live, new has nothing", from.inventory.artifactIds[a.artifactId] == true and to.artifacts[a.artifactId] == nil)
	end
```
(Ensure `Fakes` is imported in ArtifactStore.spec; the existing spec uses `Fakes.newIdGenerator()`, so it is.)

- [ ] **Step 2: Run to verify it fails** — Run: `luau tests/run.luau 2>&1 | grep -iE "transferOwnership|nil value" | head` → FAIL.

- [ ] **Step 3: Implement `transferOwnership`** in `src/server/artifacts/ArtifactStore.luau`. Find the end of `M.transition` (the `return { ok = true }` / `end` that closes it) and add after it (before `return M`):
```lua

-- ── Step 12: the cross-profile OWNERSHIP TRANSFER (the swap's per-artifact move; SYS_data_integrity §5).
-- Rides the ESCROWED → (new owner, HELD) edge: the new owner gets a LIVE copy (owner flipped, HELD, owned);
-- the old owner's record is TOMBSTONED (marked traded-away, never erased — audit/rollback, exactly as SALVAGE
-- tombstones) and leaves the owned set. CAS on the expected ESCROWED state defeats the double-spend race.
-- THE anti-dupe invariant: no artifact is ever LIVE in two profiles (the old side is a tombstone, not live).
-- The two-profile atomicity (all-or-nothing, no-yield, restore-both-on-failure) is the CALLER's job (TradeSwap
-- over PairTransaction); this is the single-artifact primitive it composes.
function M.transferOwnership(fromProfile: PlayerData, toProfile: PlayerData, artifactId: string, expected: Disposition, newOwner: string): TransitionResult
	local a = fromProfile.artifacts[artifactId]
	if a == nil then
		return { ok = false, reason = "no_such_artifact" }
	end
	if a.tombstoned then
		return { ok = false, reason = "tombstoned" }
	end
	if a.disposition ~= expected then
		return { ok = false, reason = "precondition_mismatch" } -- CAS failure (the artifact isn't ESCROWED as expected)
	end
	if not a.tradeable then
		return { ok = false, reason = "not_tradeable" }
	end
	-- the new owner's LIVE record: owner flipped, HELD; provenance preserved (immutable mint history).
	local live: Artifact = {
		artifactId = a.artifactId,
		owner = newOwner,
		kind = a.kind,
		disposition = D.HELD,
		tradeable = a.tradeable,
		tombstoned = false,
		provenance = { sourceId = a.provenance.sourceId, mintedAt = a.provenance.mintedAt, validatingEventId = a.provenance.validatingEventId },
	}
	toProfile.artifacts[artifactId] = live -- overwrites any prior tombstone of this id (a re-acquisition)
	toProfile.inventory.artifactIds[artifactId] = true
	-- the old owner's side: a TOMBSTONE (audit, never erased), out of the owned set (not live, not tradeable).
	a.tombstoned = true
	fromProfile.inventory.artifactIds[artifactId] = nil
	return { ok = true }
end
```
(`TransitionResult` is the existing exported return type of `transition`; if `transition` declares it inline rather than as an exported type, add `export type TransitionResult = { ok: boolean, reason: string? }` near the top of the module and reuse it for both. Verify the existing name during execution.)

- [ ] **Step 4: Run to verify it passes** — `luau tests/run.luau 2>&1 | tail -3` → `0 failed`.
- [ ] **Step 5: Full gate** — `./run-tests.sh 2>&1 | tail -3` → `ALL GREEN ✓`.
- [ ] **Step 6: Commit** (when authorized)
```bash
git add src/server/artifacts/ArtifactStore.luau tests/ArtifactStore.spec.luau
git commit -m "feat(step12): ArtifactStore.transferOwnership — live-to-new + tombstone-not-erase (anti-dupe core)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: PairTransaction (the two-profile atomic transaction)

**Files:**
- Create: `src/server/authority/PairTransaction.luau`
- Test: `tests/PairTransaction.spec.luau`
- Modify: `tests/run.luau` (register the spec)

**Interfaces:**
- Consumes: `Copy.deep`, `Copy.restoreInto`, `Schema.PlayerData`.
- Produces: `PairTransaction.run(profileA: PlayerData, profileB: PlayerData, mutate: (PlayerData, PlayerData) -> (), saveA: () -> boolean, saveB: () -> boolean): RunResult` where `RunResult = { ok: boolean, reason: string? }`. Snapshots both, applies `mutate` in one no-yield section, runs both saves; if **either** save fails, restores **both** in place and returns `{ ok=false, reason="save_failed" }`. Consumed by Task 5.

- [ ] **Step 1: Write the failing spec** — create `tests/PairTransaction.spec.luau`:
```lua
--!strict
-- Step 12 — the two-profile atomic transaction: snapshot both, mutate both in one no-yield section, save both,
-- and restore BOTH on any save failure (the two-profile no-orphan / no-dupe substrate the swap rides).

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local PairTransaction = require("@src/server/authority/PairTransaction")

return function(t: Harness.T)
	t.section("PairTransaction — both saves ok: both mutations stick")
	do
		local a = Util.mkProfile(Catalog, { weapon = 1 })
		local b = Util.mkProfile(Catalog, { weapon = 1 })
		local r = PairTransaction.run(a, b, function(pa, pb)
			pa.hunterRankXP = 10
			pb.hunterRankXP = 20
		end, function() return true end, function() return true end)
		t.ok("ok", r.ok)
		t.eq("A mutated", a.hunterRankXP, 10)
		t.eq("B mutated", b.hunterRankXP, 20)
	end
	t.section("PairTransaction — B save fails: BOTH revert (all-or-nothing, no half-commit)")
	do
		local a = Util.mkProfile(Catalog, { weapon = 1 })
		local b = Util.mkProfile(Catalog, { weapon = 1 })
		local r = PairTransaction.run(a, b, function(pa, pb)
			pa.hunterRankXP = 10
			pb.hunterRankXP = 20
		end, function() return true end, function() return false end)
		t.ok("save_failed", r.ok == false and r.reason == "save_failed")
		t.eq("A reverted (even though A's save 'succeeded')", a.hunterRankXP, 0)
		t.eq("B reverted", b.hunterRankXP, 0)
	end
	t.section("PairTransaction — A save fails: BOTH revert; held references stay valid (identity preserved)")
	do
		local a = Util.mkProfile(Catalog, { weapon = 1 })
		local b = Util.mkProfile(Catalog, { weapon = 1 })
		local aRef = a -- a held reference (the session) must survive the revert
		local r = PairTransaction.run(a, b, function(pa, pb)
			pa.anglerRankXP = 5
			pb.anglerRankXP = 7
		end, function() return false end, function() return true end)
		t.ok("save_failed", r.ok == false)
		t.eq("A reverted via the SAME table (identity preserved)", aRef.anglerRankXP, 0)
		t.eq("B reverted", b.anglerRankXP, 0)
	end
end
```

- [ ] **Step 2: Register the spec** in `tests/run.luau` — replace the `-- Step 12 specs go here` placeholder region (after the Step 11 `VendorHandler.spec` line, before the closing `}`):
```lua
	-- Step 11 (Boats, Mounts & Tracking Dogs — the vendor sinks)
	require("@tests/VendorHandler.spec"),
	-- Step 12 (Trading — the moat's runtime enforcement)
	require("@tests/PairTransaction.spec"),
}
```
(Later tasks insert `TradeSwap.spec` and `TradeService.spec` on the lines after `PairTransaction.spec`.)

- [ ] **Step 3: Run to verify it fails** — `luau tests/run.luau 2>&1 | grep -iE "PairTransaction|could not resolve" | head` → FAIL (module missing).

- [ ] **Step 4: Implement the module** — create `src/server/authority/PairTransaction.luau`:
```lua
--!strict
-- Step 12 — the TWO-PROFILE atomic transaction (parallel to the single-profile Transaction.run). Trading's
-- atomic swap touches BOTH traders' profiles; this snapshots both, runs the mutation as ONE no-yield section
-- over the pair, persists both, and — if EITHER save fails — restores BOTH in place (table identity kept, so
-- the held session references stay valid). All-or-nothing over both profiles: never a half-committed state.
-- The residual two-key CRASH window (key A persisted, server dies before key B) is NOT covered here — it is
-- closed by the two-sided trade record (TradeSwap writes it to both tradeLogs) + reconcile-on-reload (README).

local Copy = require("@src/server/persistence/Copy")
local Schema = require("@src/types/Schema")

type PlayerData = Schema.PlayerData

local M = {}

export type RunResult = { ok: boolean, reason: string? }

-- run(A, B, mutate, saveA, saveB): snapshot both → mutate(A, B) (no yield) → saveA() and saveB() →
-- if either failed, restore BOTH from snapshots and return save_failed; else ok.
function M.run(profileA: PlayerData, profileB: PlayerData, mutate: (PlayerData, PlayerData) -> (), saveA: () -> boolean, saveB: () -> boolean): RunResult
	local snapA = Copy.deep(profileA)
	local snapB = Copy.deep(profileB)
	mutate(profileA, profileB) -- atomic in-memory; the whole pair-pipeline is one synchronous section
	local okA = saveA()
	local okB = saveB()
	if not (okA and okB) then
		Copy.restoreInto(profileA :: any, snapA)
		Copy.restoreInto(profileB :: any, snapB)
		return { ok = false, reason = "save_failed" }
	end
	return { ok = true }
end

return M
```

- [ ] **Step 5: Run to verify it passes** — `luau tests/run.luau 2>&1 | tail -3` → `0 failed`.
- [ ] **Step 6: Full gate** — `./run-tests.sh 2>&1 | tail -3` → `ALL GREEN ✓` (confirm `src/server/authority/PairTransaction.luau` shows `✓` in gate 1).
- [ ] **Step 7: Commit** (when authorized)
```bash
git add src/server/authority/PairTransaction.luau tests/PairTransaction.spec.luau tests/run.luau
git commit -m "feat(step12): PairTransaction — two-profile all-or-nothing atomic transaction

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: TradeSwap (the atomic two-sided swap primitive — §A headline, rigor-critical)

**Files:**
- Create: `src/server/trading/TradeSwap.luau`
- Test: `tests/TradeSwap.spec.luau`
- Modify: `tests/run.luau` (register the spec)

**Interfaces:**
- Consumes: `ArtifactStore.transferOwnership` (Task 3), `PairTransaction.run` (Task 4), `Ledger.attemptDebit`/`applyEntry`/`balanceOf`, `Economy.tradeTax` (Task 1), `Schema.TradeRecord` (Task 2), `Types.IdGenerator`/`Telemetry`.
- Produces: `TradeSwap.commit(args: SwapArgs): SwapResult` where
```
SwapArgs = { aProfile, bProfile, aOwner: string, bOwner: string, aArtifactIds: { string }, bArtifactIds: { string },
             payer: "a" | "b" | "none", cashGross: number, config: Config, idGen: IdGenerator, now: number,
             saveA: () -> boolean, saveB: () -> boolean, telemetry: Telemetry? }
SwapResult = { ok: boolean, reason: string?, tax: number? }
```
Pre-validates ALL CAS preconditions (every offered artifact is ESCROWED+owned+tradeable; `|a|+|b| ≥ 1`; payer balance ≥ cashGross) BEFORE any mutation; computes `tax = Economy.tradeTax`; then `PairTransaction.run` applies the transfers + the ledger triple + the trade record. On any precondition failure → `{ok=false, reason}` with nothing mutated; on save failure → both reverted. Consumed by Task 7.

- [ ] **Step 1: Write the failing spec** — create `tests/TradeSwap.spec.luau`:
```lua
--!strict
-- Step 12 — the rigor-critical core: a successful two-sided swap moves each artifact LIVE to its new owner and
-- TOMBSTONES the old, applies the tradepay-out/tradepay-in/tradetax triple, writes the trade record to both;
-- a forced CAS mismatch transfers NOTHING (both unchanged); a forced save failure reverts BOTH profiles.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local Ledger = require("@src/server/ledger/Ledger")
local Economy = require("@src/logic/Economy")
local ArtifactStore = require("@src/server/artifacts/ArtifactStore")
local TradeSwap = require("@src/server/trading/TradeSwap")

return function(t: Harness.T)
	-- helpers: a profile owning a tradeable trophy escrowed and ready to swap
	local function owner(key: string, ledger: number): any
		return Util.mkProfile(Catalog, { ledger = { ledger } })
	end
	local function mintEscrowed(p: any, key: string, sourceId: string): string
		local a = ArtifactStore.mint(p, { kind = "trophy", tradeable = true, owner = key, sourceId = sourceId, validatingEventId = "ev" }, Fakes.newIdGenerator(), 1)
		assert(ArtifactStore.transition(p, a.artifactId, "HELD", "ESCROWED").ok)
		return a.artifactId
	end
	local function args(pa, pb, aIds, bIds, payer, gross, saveA, saveB): any
		return { aProfile = pa, bProfile = pb, aOwner = "u1", bOwner = "u2", aArtifactIds = aIds, bArtifactIds = bIds,
			payer = payer, cashGross = gross, config = Catalog, idGen = Fakes.newIdGenerator(), now = 100,
			saveA = saveA, saveB = saveB, telemetry = Fakes.newTelemetry() }
	end

	t.section("TradeSwap — a successful item-for-item-plus-Cash swap: live to new, tombstone old, tax triple")
	do
		local pa = owner("u1", 5000) -- A pays 1000 Cash + gives item a1
		local pb = owner("u2", 0)
		local a1 = mintEscrowed(pa, "u1", "bayou_white_alligator")
		local b1 = mintEscrowed(pb, "u2", "bayou_leviathan")
		local r = TradeSwap.commit(args(pa, pb, { a1 }, { b1 }, "a", 1000, function() return true end, function() return true end))
		t.ok("the swap succeeds", r.ok)
		-- a1: live in B, tombstone in A
		t.ok("a1 LIVE in B (owner u2, HELD, owned)", pb.artifacts[a1].owner == "u2" and pb.artifacts[a1].disposition == "HELD" and pb.inventory.artifactIds[a1] == true)
		t.ok("a1 TOMBSTONED in A, not in A's owned set", pa.artifacts[a1].tombstoned == true and pa.inventory.artifactIds[a1] == nil)
		-- b1: live in A, tombstone in B
		t.ok("b1 LIVE in A (owner u1)", pa.artifacts[b1].owner == "u1" and pa.inventory.artifactIds[b1] == true)
		t.ok("b1 TOMBSTONED in B", pb.artifacts[b1].tombstoned == true and pb.inventory.artifactIds[b1] == nil)
		-- never LIVE in two profiles
		t.ok("no artifact LIVE in two profiles", (pa.inventory.artifactIds[a1] == nil) and (pb.inventory.artifactIds[b1] == nil))
		-- the Cash triple: A −1000 (5000→4000); B +1000 −tax (tax = 5% of 1000 = 50) → 950
		t.eq("tax = 50", r.tax, 50)
		t.eq("payer A debited gross (5000→4000)", Ledger.balanceOf(pa.cash), 4000)
		t.eq("payee B credited gross−tax (0→950)", Ledger.balanceOf(pb.cash), 950)
		-- the trade record written to both tradeLogs
		t.eq("A tradeLog has the record", #pa.tradeLog, 1)
		t.eq("B tradeLog has the record", #pb.tradeLog, 1)
		t.ok("the record carries both sides + tax", pa.tradeLog[1].tax == 50 and pa.tradeLog[1].cashGross == 1000 and #pa.tradeLog[1].aArtifactIds == 1 and #pa.tradeLog[1].bArtifactIds == 1)
	end

	t.section("TradeSwap — zero-Cash item-for-item: zero tax, no Cash legs")
	do
		local pa = owner("u1", 0)
		local pb = owner("u2", 0)
		local a1 = mintEscrowed(pa, "u1", "bayou_white_alligator")
		local b1 = mintEscrowed(pb, "u2", "bayou_leviathan")
		local r = TradeSwap.commit(args(pa, pb, { a1 }, { b1 }, "none", 0, function() return true end, function() return true end))
		t.ok("succeeds", r.ok)
		t.eq("zero tax", r.tax, 0)
		t.eq("no Cash moved A", Ledger.balanceOf(pa.cash), 0)
		t.eq("no Cash moved B", Ledger.balanceOf(pb.cash), 0)
	end

	t.section("TradeSwap — forced CAS mismatch: one artifact NOT escrowed → nothing transfers, both unchanged")
	do
		local pa = owner("u1", 0)
		local pb = owner("u2", 0)
		local a1 = mintEscrowed(pa, "u1", "bayou_white_alligator")
		-- b1 left HELD (NOT escrowed) → the swap's ESCROWED precondition fails
		local b = ArtifactStore.mint(pb, { kind = "trophy", tradeable = true, owner = "u2", sourceId = "bayou_leviathan", validatingEventId = "ev" }, Fakes.newIdGenerator(), 1)
		local b1 = b.artifactId
		local r = TradeSwap.commit(args(pa, pb, { a1 }, { b1 }, "none", 0, function() return true end, function() return true end))
		t.ok("the commit fails (CAS mismatch)", r.ok == false)
		t.ok("a1 untouched: still ESCROWED in A, not in B", pa.artifacts[a1].disposition == "ESCROWED" and pa.inventory.artifactIds[a1] == true and pb.artifacts[a1] == nil)
		t.ok("b1 untouched: still HELD in B, not tombstoned", pb.artifacts[b1].disposition == "HELD" and pb.artifacts[b1].tombstoned == false)
		t.ok("nothing written to either tradeLog", #pa.tradeLog == 0 and #pb.tradeLog == 0)
	end

	t.section("TradeSwap — forced save failure: BOTH profiles revert (no dupe, no orphan)")
	do
		local pa = owner("u1", 5000)
		local pb = owner("u2", 0)
		local a1 = mintEscrowed(pa, "u1", "bayou_white_alligator")
		local b1 = mintEscrowed(pb, "u2", "bayou_leviathan")
		local r = TradeSwap.commit(args(pa, pb, { a1 }, { b1 }, "a", 1000, function() return true end, function() return false end))
		t.ok("the commit fails (save_failed)", r.ok == false and r.reason == "save_failed")
		t.ok("a1 reverted: still ESCROWED+owned in A, NOT in B", pa.artifacts[a1].disposition == "ESCROWED" and pa.inventory.artifactIds[a1] == true and pb.inventory.artifactIds[a1] == nil)
		t.ok("b1 reverted: still ESCROWED+owned in B, NOT in A", pb.artifacts[b1].disposition == "ESCROWED" and pb.inventory.artifactIds[b1] == true and pa.inventory.artifactIds[b1] == nil)
		t.eq("A Cash reverted", Ledger.balanceOf(pa.cash), 5000)
		t.eq("B Cash reverted", Ledger.balanceOf(pb.cash), 0)
		t.ok("no orphan trade record", #pa.tradeLog == 0 and #pb.tradeLog == 0)
	end

	t.section("TradeSwap — a pure-Cash trade (no artifacts) is rejected at the primitive (|items| ≥ 1)")
	do
		local pa = owner("u1", 5000)
		local pb = owner("u2", 0)
		local r = TradeSwap.commit(args(pa, pb, {}, {}, "a", 1000, function() return true end, function() return true end))
		t.ok("rejected: no_items", r.ok == false and r.reason == "no_items")
		t.eq("no Cash moved", Ledger.balanceOf(pa.cash), 5000)
	end

	t.section("TradeSwap — insufficient payer balance is rejected before any mutation")
	do
		local pa = owner("u1", 100) -- can't afford 1000
		local pb = owner("u2", 0)
		local a1 = mintEscrowed(pa, "u1", "bayou_white_alligator")
		local r = TradeSwap.commit(args(pa, pb, { a1 }, {}, "a", 1000, function() return true end, function() return true end))
		t.ok("rejected: insufficient_funds", r.ok == false and r.reason == "insufficient_funds")
		t.ok("a1 untouched (still escrowed in A)", pa.artifacts[a1].disposition == "ESCROWED" and pa.inventory.artifactIds[a1] == true)
	end
end
```

- [ ] **Step 2: Register the spec** in `tests/run.luau` (after `PairTransaction.spec`):
```lua
	require("@tests/PairTransaction.spec"),
	require("@tests/TradeSwap.spec"),
}
```

- [ ] **Step 3: Run to verify it fails** — `luau tests/run.luau 2>&1 | grep -iE "TradeSwap|could not resolve" | head` → FAIL (module missing).

- [ ] **Step 4: Implement the module** — create `src/server/trading/TradeSwap.luau`:
```lua
--!strict
-- Step 12 — THE atomic two-sided swap primitive (data-integrity §5; the rigor-critical core). All-or-nothing
-- over BOTH profiles: pre-validate EVERY CAS precondition before any mutation, then in ONE no-yield section
-- (PairTransaction) move each artifact (ArtifactStore.transferOwnership: live to new, tombstone old), apply
-- the Cash triple (tradepay-out / tradepay-in / tradetax), and write the two-sided trade record to both
-- tradeLogs. If ANY precondition fails → nothing mutates. If a save fails → both profiles revert. No artifact
-- is ever LIVE in two profiles; no item leaves one inventory until it enters the other. Trading INVOKES this;
-- it never inlines the atomic logic.

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")
local Economy = require("@src/logic/Economy")
local Ledger = require("@src/server/ledger/Ledger")
local ArtifactStore = require("@src/server/artifacts/ArtifactStore")
local PairTransaction = require("@src/server/authority/PairTransaction")
local Types = require("@src/server/persistence/Types")

type PlayerData = Schema.PlayerData
type Config = Schema.Config
local D = Enums.Disposition

local M = {}

export type SwapArgs = {
	aProfile: PlayerData,
	bProfile: PlayerData,
	aOwner: string,
	bOwner: string,
	aArtifactIds: { string },
	bArtifactIds: { string },
	payer: string, -- "a" | "b" | "none"
	cashGross: number,
	config: Config,
	idGen: Types.IdGenerator,
	now: number,
	saveA: () -> boolean,
	saveB: () -> boolean,
	telemetry: Types.Telemetry?,
}
export type SwapResult = { ok: boolean, reason: string?, tax: number? }

-- A pre-check: every id is ESCROWED + owned + tradeable on `profile` (the CAS preconditions, read-only).
local function allEscrowed(profile: PlayerData, ids: { string }): boolean
	for _, id in ids do
		local a = profile.artifacts[id]
		if a == nil or a.tombstoned or a.disposition ~= D.ESCROWED or not a.tradeable or profile.inventory.artifactIds[id] ~= true then
			return false
		end
	end
	return true
end

function M.commit(args: SwapArgs): SwapResult
	-- ── PRE-VALIDATE everything BEFORE any mutation (so a failure transfers nothing). ──
	if (#args.aArtifactIds + #args.bArtifactIds) < 1 then
		return { ok = false, reason = "no_items" } -- |A.items| + |B.items| ≥ 1 (no raw-Cash channel)
	end
	if not allEscrowed(args.aProfile, args.aArtifactIds) then
		return { ok = false, reason = "precondition_failed" } -- A's side not all ESCROWED as expected (CAS)
	end
	if not allEscrowed(args.bProfile, args.bArtifactIds) then
		return { ok = false, reason = "precondition_failed" } -- B's side not all ESCROWED as expected (CAS)
	end
	local tax = Economy.tradeTax(args.config, args.cashGross)
	if args.cashGross > 0 then
		local payerProfile = if args.payer == "a" then args.aProfile elseif args.payer == "b" then args.bProfile else nil
		if payerProfile == nil then
			return { ok = false, reason = "bad_payer" }
		end
		if Ledger.balanceOf(payerProfile.cash) < args.cashGross then
			return { ok = false, reason = "insufficient_funds" }
		end
	end

	-- ── APPLY in ONE no-yield section over BOTH profiles; restore both on any save failure. ──
	local tradeId = args.idGen.next("trade")
	local run = PairTransaction.run(args.aProfile, args.bProfile, function(pa, pb)
		-- artifact legs: A's → B, B's → A (live to new, tombstone old). Pre-validated, no yield → assert ok.
		for _, id in args.aArtifactIds do
			assert(ArtifactStore.transferOwnership(pa, pb, id, D.ESCROWED, args.bOwner).ok, "swap: A→B transfer must succeed (pre-validated)")
		end
		for _, id in args.bArtifactIds do
			assert(ArtifactStore.transferOwnership(pb, pa, id, D.ESCROWED, args.aOwner).ok, "swap: B→A transfer must succeed (pre-validated)")
		end
		-- Cash leg: payer −gross (tradepay-out); payee +gross (tradepay-in) then −tax (tradetax sink). Once.
		if args.cashGross > 0 then
			local payerProfile = if args.payer == "a" then pa else pb
			local payeeProfile = if args.payer == "a" then pb else pa
			local debit = Ledger.attemptDebit(payerProfile.cash, args.cashGross, { type = "tradepay-out", loop = "none", validatingEventId = tradeId }, args.now)
			assert(debit.ok, "swap: payer affordability pre-validated, no yield → debit must succeed")
			Ledger.applyEntry(payeeProfile.cash, { type = "tradepay-in", amount = args.cashGross, loop = "none", validatingEventId = tradeId }, args.now)
			if tax > 0 then
				Ledger.applyEntry(payeeProfile.cash, { type = "tradetax", amount = -tax, loop = "none", validatingEventId = tradeId }, args.now)
			end
		end
		-- the two-sided trade record → both tradeLogs (audit/rollback; the reconcile-on-reload substrate).
		local payerKey = if args.payer == "a" then args.aOwner elseif args.payer == "b" then args.bOwner else ""
		local record: Schema.TradeRecord = {
			tradeId = tradeId,
			partyA = args.aOwner,
			partyB = args.bOwner,
			aArtifactIds = table.clone(args.aArtifactIds),
			bArtifactIds = table.clone(args.bArtifactIds),
			payer = payerKey,
			cashGross = args.cashGross,
			tax = tax,
			timestamp = args.now,
		}
		table.insert(pa.tradeLog, record)
		table.insert(pb.tradeLog, table.clone(record) :: any)
	end, args.saveA, args.saveB)

	if not run.ok then
		return { ok = false, reason = run.reason }
	end
	if args.telemetry ~= nil then
		args.telemetry.incr("trade.completed", 1)
		args.telemetry.incr("trade.tax", tax)
	end
	return { ok = true, tax = tax }
end

return M
```

- [ ] **Step 5: Run to verify it passes** — `luau tests/run.luau 2>&1 | tail -3` → `0 failed`.
- [ ] **Step 6: Full gate** — `./run-tests.sh 2>&1 | tail -3` → `ALL GREEN ✓` (confirm `TradeSwap.luau` shows `✓`).
- [ ] **Step 7: Commit** (when authorized)
```bash
git add src/server/trading/TradeSwap.luau tests/TradeSwap.spec.luau tests/run.luau
git commit -m "feat(step12): TradeSwap — atomic two-sided swap (CAS pre-validate, tax triple, trade record, revert-both)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: TradeService — negotiation (request/accept/build/validate/version/re-arm/one-active)

**Files:**
- Create: `src/server/trading/TradeService.luau` (the negotiation half; confirm/commit added in Task 7)
- Test: `tests/TradeService.spec.luau` (negotiation sections)
- Modify: `tests/run.luau` (register the spec)

**Interfaces:**
- Consumes: `Enums.TradeState`, `Schema.PlayerData`, `Config`, `Types.IdGenerator`/`Telemetry`, the injected `getProfile`/`saveProfile`.
- Produces:
```
TradeService.new(deps: TradeDeps): TradeService
TradeDeps = { config: Config, idGen: IdGenerator, telemetry: Telemetry?, getProfile: (key: string) -> PlayerData?, saveProfile: (key: string) -> boolean }
TradeService.request(self, from: string, to: string, now: number): Result   -- Result = { ok: boolean, reason: string?, tradeId: string? }
TradeService.accept(self, by: string, tradeId: string, now: number): Result
TradeService.setOffer(self, by: string, tradeId: string, items: { string }, cash: number, now: number): Result
TradeService.get(self, tradeId: string): PendingTrade?   -- server state (the projection builds on this; Task 8 in spec section)
```
`PendingTrade = { tradeId, a, b, state: TradeState, version: number, offers: { [string]: Offer }, settleStartedAt: number?, createdAt: number }`; `Offer = { items: { string }, cash: number, confirmed: boolean }`. Consumed by Task 7.

- [ ] **Step 1: Write the failing spec** — create `tests/TradeService.spec.luau`:
```lua
--!strict
-- Step 12 — the trade flow state machine. This task covers negotiation: request/accept (one-active-trade),
-- setOffer validation (owned + tradeable + HELD; no raw Cash), and the terms-version re-arm. Confirm/commit
-- and the 8 checks' commit half are added in the next section.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local ArtifactStore = require("@src/server/artifacts/ArtifactStore")
local TradeService = require("@src/server/trading/TradeService")

return function(t: Harness.T)
	-- a world of two players keyed "u1"/"u2", each a profile; getProfile/saveProfile injected.
	local function world(saveOk: boolean)
		local profiles: { [string]: any } = { u1 = Util.mkProfile(Catalog, { ledger = { 5000 } }), u2 = Util.mkProfile(Catalog, { ledger = { 5000 } }) }
		local svc = TradeService.new({
			config = Catalog, idGen = Fakes.newIdGenerator(), telemetry = Fakes.newTelemetry(),
			getProfile = function(k) return profiles[k] end,
			saveProfile = function(_) return saveOk end,
		})
		return svc, profiles
	end
	local function mintHeld(p: any, key: string, sourceId: string): string
		return ArtifactStore.mint(p, { kind = "trophy", tradeable = true, owner = key, sourceId = sourceId, validatingEventId = "ev" }, Fakes.newIdGenerator(), 1).artifactId
	end

	t.section("TradeService — request + accept + one-active-trade")
	do
		local svc, profiles = world(true)
		local r = TradeService.request(svc, "u1", "u2", 100)
		t.ok("request opens a REQUESTED trade", r.ok and r.tradeId ~= nil)
		t.eq("state REQUESTED", TradeService.get(svc, r.tradeId :: string).state, "REQUESTED")
		-- one-active: neither party can open a second
		t.ok("u1 can't open a second trade", TradeService.request(svc, "u1", "u2", 100).ok == false)
		t.ok("u2 (the requestee) can't open a second either", TradeService.request(svc, "u2", "u1", 100).ok == false)
		local acc = TradeService.accept(svc, "u2", r.tradeId :: string, 100)
		t.ok("accept → BUILDING", acc.ok and TradeService.get(svc, r.tradeId :: string).state == "BUILDING")
	end

	t.section("TradeService — setOffer validates ownership + tradeable + HELD; commodity/DISPLAYED rejected")
	do
		local svc, profiles = world(true)
		local a1 = mintHeld(profiles.u1, "u1", "bayou_white_alligator")
		local r = TradeService.request(svc, "u1", "u2", 100)
		TradeService.accept(svc, "u2", r.tradeId :: string, 100)
		local tid = r.tradeId :: string
		t.ok("u1 can offer its own HELD tradeable artifact", TradeService.setOffer(svc, "u1", tid, { a1 }, 0, 100).ok)
		-- not owned by u2
		t.ok("u2 can't offer u1's artifact (not owned)", TradeService.setOffer(svc, "u2", tid, { a1 }, 0, 100).ok == false)
		-- a DISPLAYED trophy can't be offered (check 4)
		local a2 = mintHeld(profiles.u1, "u1", "bayou_leviathan")
		assert(ArtifactStore.transition(profiles.u1, a2, "HELD", "DISPLAYED").ok)
		t.ok("a DISPLAYED trophy can't be offered until un-displayed", TradeService.setOffer(svc, "u1", tid, { a1, a2 }, 0, 100).ok == false)
		-- an unknown / non-existent artifact id rejected
		t.ok("an unknown artifact id is rejected", TradeService.setOffer(svc, "u1", tid, { "nope" }, 0, 100).ok == false)
	end

	t.section("TradeService — the terms-version increments on every offer change (re-arm substrate)")
	do
		local svc, profiles = world(true)
		local a1 = mintHeld(profiles.u1, "u1", "bayou_white_alligator")
		local r = TradeService.request(svc, "u1", "u2", 100)
		TradeService.accept(svc, "u2", r.tradeId :: string, 100)
		local tid = r.tradeId :: string
		local v0 = TradeService.get(svc, tid).version
		TradeService.setOffer(svc, "u1", tid, { a1 }, 0, 100)
		t.ok("version increments on an offer change", TradeService.get(svc, tid).version > v0)
		local v1 = TradeService.get(svc, tid).version
		TradeService.setOffer(svc, "u1", tid, { a1 }, 250, 100) -- set Cash → another change
		t.ok("version increments again on a Cash change", TradeService.get(svc, tid).version > v1)
	end
end
```

- [ ] **Step 2: Register the spec** in `tests/run.luau` (after `TradeSwap.spec`):
```lua
	require("@tests/TradeSwap.spec"),
	require("@tests/TradeService.spec"),
}
```

- [ ] **Step 3: Run to verify it fails** — `luau tests/run.luau 2>&1 | grep -iE "TradeService|could not resolve" | head` → FAIL.

- [ ] **Step 4: Implement the negotiation half** — create `src/server/trading/TradeService.luau`:
```lua
--!strict
-- Step 12 — the trade FLOW: the server-owned PendingTrade state machine (REQUESTED → BUILDING →
-- A/B_CONFIRMED → COMMITTING → COMPLETE | CANCELLED). The server owns the state; clients send INTENTS
-- (validated against authoritative state) and see a read-only projection. This module owns negotiation,
-- the version-bound double-confirm + re-arm, the escrow lifecycle (HELD↔ESCROWED via the existing CAS), the
-- offer validation, the tax assembly, and the commit which INVOKES TradeSwap (it never moves items itself).
-- Two profiles are reached via injected getProfile/saveProfile (in Studio: SessionService; in tests: a table).

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")
local Economy = require("@src/logic/Economy")
local Ledger = require("@src/server/ledger/Ledger")
local ArtifactStore = require("@src/server/artifacts/ArtifactStore")
local Transaction = require("@src/server/authority/Transaction")
local TradeSwap = require("@src/server/trading/TradeSwap")
local Types = require("@src/server/persistence/Types")

type PlayerData = Schema.PlayerData
type Config = Schema.Config
type TradeState = Enums.TradeState
local TS = Enums.TradeState
local D = Enums.Disposition

local M = {}

export type Offer = { items: { string }, cash: number, confirmed: boolean }
export type PendingTrade = {
	tradeId: string,
	a: string,
	b: string,
	state: TradeState,
	version: number,
	offers: { [string]: Offer },
	settleStartedAt: number?,
	createdAt: number,
}
export type TradeDeps = {
	config: Config,
	idGen: Types.IdGenerator,
	telemetry: Types.Telemetry?,
	getProfile: (key: string) -> PlayerData?,
	saveProfile: (key: string) -> boolean,
}
export type TradeService = {
	deps: TradeDeps,
	trades: { [string]: PendingTrade },
	activeByPlayer: { [string]: string }, -- player key → tradeId (the one-active-trade index)
}
export type Result = { ok: boolean, reason: string?, tradeId: string? }

function M.new(deps: TradeDeps): TradeService
	return { deps = deps, trades = {}, activeByPlayer = {} }
end

local function incr(self: TradeService, metric: string)
	if self.deps.telemetry ~= nil then
		self.deps.telemetry.incr(metric, 1)
	end
end

-- the other party's key
local function other(trade: PendingTrade, who: string): string
	return if who == trade.a then trade.b else trade.a
end

-- ── request: A asks B; both become party to a live trade (one-active-trade reserves BOTH). ──
function M.request(self: TradeService, from: string, to: string, now: number): Result
	if from == to then
		return { ok = false, reason = "self_trade" }
	end
	if self.activeByPlayer[from] ~= nil or self.activeByPlayer[to] ~= nil then
		return { ok = false, reason = "already_trading" } -- one active trade per player (check 8)
	end
	local tradeId = self.deps.idGen.next("trade")
	self.trades[tradeId] = {
		tradeId = tradeId, a = from, b = to, state = TS.REQUESTED, version = 1,
		offers = { [from] = { items = {}, cash = 0, confirmed = false }, [to] = { items = {}, cash = 0, confirmed = false } },
		settleStartedAt = nil, createdAt = now,
	}
	self.activeByPlayer[from] = tradeId
	self.activeByPlayer[to] = tradeId
	incr(self, "trade.requested")
	return { ok = true, tradeId = tradeId }
end

-- ── accept: the requestee moves the trade to BUILDING. ──
function M.accept(self: TradeService, by: string, tradeId: string, now: number): Result
	local trade = self.trades[tradeId]
	if trade == nil then
		return { ok = false, reason = "no_such_trade" }
	end
	if trade.state ~= TS.REQUESTED or by ~= trade.b then
		return { ok = false, reason = "not_acceptable" }
	end
	trade.state = TS.BUILDING
	return { ok = true, tradeId = tradeId }
end

-- validate one offered artifact: exists, owned by `by`, tradeable, HELD. Returns nil on ok or a reason.
local function badOfferItem(self: TradeService, by: string, id: string): string?
	local p = self.deps.getProfile(by)
	if p == nil then
		return "no_profile"
	end
	local art = p.artifacts[id]
	if art == nil or art.tombstoned or p.inventory.artifactIds[id] ~= true or art.owner ~= by then
		return "not_owned"
	end
	if not art.tradeable then
		return "not_tradeable" -- a commodity is structurally un-offerable (check 5)
	end
	if art.disposition ~= D.HELD then
		return "not_held" -- DISPLAYED (un-display first, check 4) / ESCROWED / SALVAGED
	end
	return nil
end

-- forward declaration (defined in Task 7): revert a side's escrow on re-arm/cancel/etc.
local revertEscrow

-- re-arm: any offer change clears BOTH confirms, reverts any escrow, bumps the version, returns to BUILDING.
local function reArm(self: TradeService, trade: PendingTrade)
	for key, offer in trade.offers do
		if offer.confirmed then
			offer.confirmed = false
			if revertEscrow ~= nil then
				revertEscrow(self, trade, key)
			end
		end
	end
	trade.version += 1
	trade.settleStartedAt = nil
	trade.state = TS.BUILDING
end

-- ── setOffer: replace a side's offer (covers add/remove item + set Cash). Validates every item; any change
-- re-arms (clears both confirms, reverts escrow, bumps version). ──
function M.setOffer(self: TradeService, by: string, tradeId: string, items: { string }, cash: number, now: number): Result
	local trade = self.trades[tradeId]
	if trade == nil then
		return { ok = false, reason = "no_such_trade" }
	end
	if by ~= trade.a and by ~= trade.b then
		return { ok = false, reason = "not_a_party" }
	end
	if trade.state == TS.COMPLETE or trade.state == TS.CANCELLED or trade.state == TS.COMMITTING then
		return { ok = false, reason = "not_editable" }
	end
	if cash < 0 then
		return { ok = false, reason = "bad_cash" }
	end
	local seen: { [string]: boolean } = {}
	for _, id in items do
		if seen[id] then
			return { ok = false, reason = "duplicate_item" }
		end
		seen[id] = true
		local bad = badOfferItem(self, by, id)
		if bad ~= nil then
			return { ok = false, reason = bad }
		end
	end
	trade.offers[by] = { items = table.clone(items), cash = cash, confirmed = false }
	reArm(self, trade)
	return { ok = true, tradeId = tradeId }
end

function M.get(self: TradeService, tradeId: string): PendingTrade?
	return self.trades[tradeId]
end

return M
```
> Note: `revertEscrow` is a forward-declared local filled in Task 7 (so re-arm in this task already clears confirms; escrow revert wires up once confirm exists). The `reArm` here works for negotiation (no escrow yet exists pre-confirm).

- [ ] **Step 5: Run to verify it passes** — `luau tests/run.luau 2>&1 | tail -3` → `0 failed`.
- [ ] **Step 6: Full gate** — `./run-tests.sh 2>&1 | tail -3` → `ALL GREEN ✓`.
- [ ] **Step 7: Commit** (when authorized)
```bash
git add src/server/trading/TradeService.luau tests/TradeService.spec.luau tests/run.luau
git commit -m "feat(step12): TradeService negotiation — request/accept/setOffer, validation, version re-arm, one-active

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: TradeService — confirm, escrow, settle, commit, cancel/timeout/disconnect + final-terms

**Files:**
- Modify: `src/server/trading/TradeService.luau` (add `revertEscrow` body, `confirm`, `tryCommit`, `cancel`, `timeoutTick`, `onDisconnect`, `projection`)
- Test: `tests/TradeService.spec.luau` (the confirm→commit sections + the remaining checks)

**Interfaces:**
- Produces:
```
TradeService.confirm(self, by, tradeId, version: number, now): Result  -- version-bound; escrows by's items
TradeService.tryCommit(self, tradeId, now): Result  -- after settle elapsed: invoke TradeSwap → COMPLETE|CANCELLED
TradeService.cancel(self, by, tradeId, now): Result  -- reverts escrow, releases active, CANCELLED
TradeService.timeoutTick(self, tradeId, now): Result -- auto-cancel if escrowTimeout elapsed
TradeService.onDisconnect(self, player, now): Result -- cancels the player's active trade
TradeService.projection(self, tradeId): Projection?  -- read-only; final-terms (gross/tax/net + server-sourced item identities)
```
- Consumes: `Transaction.run` (single-profile escrow), `TradeSwap.commit`, `Economy.tradeTax`, `config.tuning.persistence.commitSettleSeconds`/`escrowTimeoutSeconds`, `config.targetIndex` (for server-sourced names/rarity).

- [ ] **Step 1: Write the failing test** — append these sections inside `tests/TradeService.spec.luau`'s `return function(t)` body. (Reuse the `world`/`mintHeld` helpers from Task 6; they're in scope.)
```lua
	-- helper: drive a full trade to BOTH_CONFIRMED + settle-elapsed, return svc/profiles/tid
	local function builtTrade(saveOk: boolean)
		local svc, profiles = world(saveOk)
		local a1 = mintHeld(profiles.u1, "u1", "bayou_white_alligator")
		local b1 = mintHeld(profiles.u2, "u2", "bayou_leviathan")
		local r = TradeService.request(svc, "u1", "u2", 100)
		local tid = r.tradeId :: string
		TradeService.accept(svc, "u2", tid, 100)
		TradeService.setOffer(svc, "u1", tid, { a1 }, 1000, 100) -- u1: item + 1000 Cash
		TradeService.setOffer(svc, "u2", tid, { b1 }, 0, 100) -- u2: item
		return svc, profiles, tid, a1, b1
	end

	t.section("TradeService — confirm escrows the confirming side; both-confirm → settle; commit runs the swap")
	do
		local svc, profiles, tid, a1, b1 = builtTrade(true)
		local v = TradeService.get(svc, tid).version
		t.ok("u1 confirm escrows a1 (HELD→ESCROWED)", TradeService.confirm(svc, "u1", tid, v, 100).ok and profiles.u1.artifacts[a1].disposition == "ESCROWED")
		t.eq("state A_CONFIRMED", TradeService.get(svc, tid).state, "A_CONFIRMED")
		t.ok("u2 confirm escrows b1 + opens the settle window", TradeService.confirm(svc, "u2", tid, v, 100).ok and profiles.u2.artifacts[b1].disposition == "ESCROWED")
		t.eq("state COMMITTING (both confirmed, settling)", TradeService.get(svc, tid).state, "COMMITTING")
		-- before settle elapses: commit is held
		t.ok("commit blocked during the settle freeze", TradeService.tryCommit(svc, tid, 101).ok == false)
		-- after settle elapses: the swap runs
		local r = TradeService.tryCommit(svc, tid, 100 + Catalog.tuning.persistence.commitSettleSeconds)
		t.ok("commit succeeds → COMPLETE", r.ok and TradeService.get(svc, tid).state == "COMPLETE")
		t.ok("a1 LIVE in u2, tombstone in u1", profiles.u2.artifacts[a1].owner == "u2" and profiles.u2.inventory.artifactIds[a1] == true and profiles.u1.artifacts[a1].tombstoned == true)
		t.ok("b1 LIVE in u1, tombstone in u2", profiles.u1.artifacts[b1].owner == "u1" and profiles.u1.inventory.artifactIds[b1] == true and profiles.u2.artifacts[b1].tombstoned == true)
		t.eq("u1 paid 1000 (5000→4000)", require("@src/server/ledger/Ledger").balanceOf(profiles.u1.cash), 4000)
		t.eq("u2 got 950 (1000 − 50 tax) (5000→5950)", require("@src/server/ledger/Ledger").balanceOf(profiles.u2.cash), 5950)
		-- one-active released after completion
		t.ok("both players freed after completion", TradeService.request(svc, "u1", "u2", 200).ok)
	end

	t.section("TradeService — check 1: a re-arm while one side confirmed clears BOTH confirms + reverts escrow; stale-version confirm rejected")
	do
		local svc, profiles, tid, a1, b1 = builtTrade(true)
		local v = TradeService.get(svc, tid).version
		TradeService.confirm(svc, "u1", tid, v, 100) -- u1 confirmed → a1 ESCROWED
		t.ok("a1 escrowed by the confirm", profiles.u1.artifacts[a1].disposition == "ESCROWED")
		-- u2 changes its offer → re-arm
		TradeService.setOffer(svc, "u2", tid, { b1 }, 50, 100)
		t.eq("back to BUILDING", TradeService.get(svc, tid).state, "BUILDING")
		t.ok("u1's confirm cleared", TradeService.get(svc, tid).offers.u1.confirmed == false)
		t.ok("a1's escrow reverted ESCROWED→HELD", profiles.u1.artifacts[a1].disposition == "HELD")
		t.ok("the version bumped", TradeService.get(svc, tid).version > v)
		-- a stale-version confirm (naming the old version) is rejected
		t.ok("stale-version confirm rejected", TradeService.confirm(svc, "u1", tid, v, 100).ok == false)
	end

	t.section("TradeService — check 2: disconnect auto-cancels with full escrow revert")
	do
		local svc, profiles, tid, a1, b1 = builtTrade(true)
		local v = TradeService.get(svc, tid).version
		TradeService.confirm(svc, "u1", tid, v, 100) -- a1 escrowed
		TradeService.onDisconnect(svc, "u2", 100)
		t.eq("trade CANCELLED", TradeService.get(svc, tid).state, "CANCELLED")
		t.ok("a1 escrow reverted", profiles.u1.artifacts[a1].disposition == "HELD")
		t.ok("both freed", self_freed(svc))
	end

	t.section("TradeService — check 6: a pure-Cash trade cannot be committed")
	do
		local svc, profiles = world(true)
		local r = TradeService.request(svc, "u1", "u2", 100)
		local tid = r.tradeId :: string
		TradeService.accept(svc, "u2", tid, 100)
		TradeService.setOffer(svc, "u1", tid, {}, 1000, 100) -- Cash only, no items
		TradeService.setOffer(svc, "u2", tid, {}, 0, 100)
		local v = TradeService.get(svc, tid).version
		TradeService.confirm(svc, "u1", tid, v, 100)
		TradeService.confirm(svc, "u2", tid, v, 100)
		local cr = TradeService.tryCommit(svc, tid, 100 + Catalog.tuning.persistence.commitSettleSeconds)
		t.ok("pure-Cash commit rejected (|items| ≥ 1)", cr.ok == false)
		t.eq("no Cash moved", require("@src/server/ledger/Ledger").balanceOf(profiles.u1.cash), 5000)
	end

	t.section("TradeService — check 7: tax taken exactly once on commit, never on cancel/re-arm")
	do
		local svc, profiles, tid, a1, b1 = builtTrade(true)
		local v = TradeService.get(svc, tid).version
		TradeService.confirm(svc, "u1", tid, v, 100)
		TradeService.cancel(svc, "u1", tid, 100) -- cancel before commit
		t.eq("no tax on a cancelled trade — u2 balance unchanged", require("@src/server/ledger/Ledger").balanceOf(profiles.u2.cash), 5000)
		t.eq("no tradetax entry anywhere on u2", (function()
			local n = 0
			for _, e in profiles.u2.cash.tail do if e.type == "tradetax" then n += 1 end end
			return n
		end)(), 0)
	end

	t.section("TradeService — check 3: a forced CAS mismatch at commit transfers nothing, reverts to CANCELLED")
	do
		local svc, profiles, tid, a1, b1 = builtTrade(true)
		local v = TradeService.get(svc, tid).version
		TradeService.confirm(svc, "u1", tid, v, 100)
		TradeService.confirm(svc, "u2", tid, v, 100)
		-- force a CAS mismatch: yank a1 out of ESCROWED behind the swap's back
		assert(ArtifactStore.transition(profiles.u1, a1, "ESCROWED", "HELD").ok)
		local cr = TradeService.tryCommit(svc, tid, 100 + Catalog.tuning.persistence.commitSettleSeconds)
		t.ok("commit fails on the CAS mismatch", cr.ok == false)
		t.eq("trade → CANCELLED", TradeService.get(svc, tid).state, "CANCELLED")
		t.ok("nothing transferred: b1 still u2's, a1 not in u2", profiles.u2.artifacts[b1] ~= nil and profiles.u2.inventory.artifactIds[b1] == true and profiles.u2.artifacts[a1] == nil)
	end

	t.section("TradeService — final-terms projection is server-sourced (canonical name/rarity, gross/tax/net)")
	do
		local svc, profiles, tid, a1, b1 = builtTrade(true)
		local proj = TradeService.projection(svc, tid)
		t.ok("projection exists with both offers + state + version", proj ~= nil and proj.state == "BUILDING" and proj.version ~= nil)
		t.eq("gross Cash from u1's side", proj.gross, 1000)
		t.eq("tax = 50 (server-computed, not client)", proj.tax, 50)
		t.eq("net = 950", proj.net, 950)
		-- the offered item identity comes from the artifact's authoritative record (provenance → catalog), not client text
		t.ok("a1's offered identity is the canonical Catalog name (server-sourced)", (function()
			for _, it in proj.offers.u1.items do
				if it.artifactId == a1 then
					return it.name == Catalog.creatures.bayou_white_alligator.name and it.rarity == Catalog.creatures.bayou_white_alligator.rarity
				end
			end
			return false
		end)())
	end
```
Also add this tiny helper near the top of the `return function(t)` body (used by the disconnect section):
```lua
	local function self_freed(svc: any): boolean
		return TradeService.request(svc, "u1", "u2", 999).ok -- both must be free to open a new one
	end
```

- [ ] **Step 2: Run to verify it fails** — `luau tests/run.luau 2>&1 | grep -iE "confirm|tryCommit|projection|nil value" | head` → FAIL.

- [ ] **Step 3: Implement the confirm→commit half** in `src/server/trading/TradeService.luau`. First, replace the forward declaration line `local revertEscrow` with the full body (place it ABOVE `reArm`, since `reArm` calls it — so move `reArm`/`setOffer` below, or define `revertEscrow` as a real function before `reArm`). Concretely, change:
```lua
-- forward declaration (defined in Task 7): revert a side's escrow on re-arm/cancel/etc.
local revertEscrow
```
to:
```lua
-- revert a side's escrow: every ESCROWED artifact in `who`'s offer goes ESCROWED → HELD (the no-dangling-
-- escrow guarantee). Persisted via the single-profile Transaction (a failed save leaves it escrowed for the
-- timeout/reconcile to sweep — the fail-safe direction). Used by re-arm, cancel, timeout, disconnect.
local function revertEscrow(self: TradeService, trade: PendingTrade, who: string)
	local p = self.deps.getProfile(who)
	if p == nil then
		return
	end
	local offer = trade.offers[who]
	Transaction.run(p, function()
		for _, id in offer.items do
			local art = p.artifacts[id]
			if art ~= nil and art.disposition == D.ESCROWED then
				ArtifactStore.transition(p, id, D.ESCROWED, D.HELD)
			end
		end
	end, function()
		return self.deps.saveProfile(who)
	end)
end
```
(Because `reArm`/`setOffer` reference `revertEscrow`, ensure this function is defined ABOVE them. If they are above it, move this `revertEscrow` definition up to just below `other(...)`.)

Then add the confirm/commit/cancel/timeout/disconnect/projection functions before `return M`:
```lua
-- the freed-up release of the one-active-trade reservation for both parties.
local function release(self: TradeService, trade: PendingTrade)
	self.activeByPlayer[trade.a] = nil
	self.activeByPlayer[trade.b] = nil
end

-- ── confirm: version-bound. Escrows the confirming side's items (HELD→ESCROWED, atomic). On a failed escrow
-- CAS (an item raced out of HELD), the confirm fails and the trade re-arms. Second confirm opens the settle. ──
function M.confirm(self: TradeService, by: string, tradeId: string, version: number, now: number): Result
	local trade = self.trades[tradeId]
	if trade == nil then
		return { ok = false, reason = "no_such_trade" }
	end
	if by ~= trade.a and by ~= trade.b then
		return { ok = false, reason = "not_a_party" }
	end
	if trade.state ~= TS.BUILDING and trade.state ~= TS.A_CONFIRMED and trade.state ~= TS.B_CONFIRMED then
		return { ok = false, reason = "not_confirmable" }
	end
	if version ~= trade.version then
		return { ok = false, reason = "stale_version" } -- the confirm names terms that have since changed (re-arm)
	end
	local offer = trade.offers[by]
	if offer.confirmed then
		return { ok = false, reason = "already_confirmed" }
	end
	local p = self.deps.getProfile(by)
	if p == nil then
		return { ok = false, reason = "no_profile" }
	end
	-- pre-check every item is HELD (so the escrow CAS will succeed in the no-yield Transaction).
	for _, id in offer.items do
		local art = p.artifacts[id]
		if art == nil or art.tombstoned or art.disposition ~= D.HELD or p.inventory.artifactIds[id] ~= true then
			reArm(self, trade) -- it raced — re-arm ("that item is no longer available")
			return { ok = false, reason = "item_unavailable" }
		end
	end
	-- escrow the confirming side's items, atomically (HELD→ESCROWED), and lock the Cash leg.
	local txn = Transaction.run(p, function()
		for _, id in offer.items do
			assert(ArtifactStore.transition(p, id, D.HELD, D.ESCROWED).ok, "confirm: escrow CAS pre-validated, no yield")
		end
	end, function()
		return self.deps.saveProfile(by)
	end)
	if not txn.ok then
		return { ok = false, reason = "persist_failed" }
	end
	offer.confirmed = true
	local otherOffer = trade.offers[other(trade, by)]
	if otherOffer.confirmed then
		trade.state = TS.COMMITTING -- both confirmed; the settle window opens (cancel still allowed)
		trade.settleStartedAt = now
	else
		trade.state = if by == trade.a then TS.A_CONFIRMED else TS.B_CONFIRMED
	end
	incr(self, "trade.confirmed")
	return { ok = true, tradeId = tradeId }
end

-- compute the net Cash leg: payer is the side that offered more Cash; gross = the net moved.
local function cashLeg(trade: PendingTrade): (string, number) -- returns (payer "a"|"b"|"none", gross)
	local aCash = trade.offers[trade.a].cash
	local bCash = trade.offers[trade.b].cash
	if aCash > bCash then
		return "a", aCash - bCash
	elseif bCash > aCash then
		return "b", bCash - aCash
	end
	return "none", 0
end

-- ── tryCommit: after the settle freeze elapses, invoke the atomic swap. Success → COMPLETE; precondition/
-- save failure → escrow released, CANCELLED, nothing transferred. ──
function M.tryCommit(self: TradeService, tradeId: string, now: number): Result
	local trade = self.trades[tradeId]
	if trade == nil then
		return { ok = false, reason = "no_such_trade" }
	end
	if trade.state ~= TS.COMMITTING or trade.settleStartedAt == nil then
		return { ok = false, reason = "not_committing" }
	end
	if (now - (trade.settleStartedAt :: number)) < self.deps.config.tuning.persistence.commitSettleSeconds then
		return { ok = false, reason = "settle_pending" } -- the fat-finger window is still open
	end
	local pa = self.deps.getProfile(trade.a)
	local pb = self.deps.getProfile(trade.b)
	if pa == nil or pb == nil then
		return { ok = false, reason = "no_profile" }
	end
	local payer, gross = cashLeg(trade)
	local swap = TradeSwap.commit({
		aProfile = pa, bProfile = pb, aOwner = trade.a, bOwner = trade.b,
		aArtifactIds = trade.offers[trade.a].items, bArtifactIds = trade.offers[trade.b].items,
		payer = payer, cashGross = gross, config = self.deps.config, idGen = self.deps.idGen, now = now,
		saveA = function() return self.deps.saveProfile(trade.a) end,
		saveB = function() return self.deps.saveProfile(trade.b) end,
		telemetry = self.deps.telemetry,
	})
	if not swap.ok then
		-- the swap moved nothing (pre-validate) or reverted both (save); release escrow + cancel cleanly.
		M.cancel(self, trade.a, tradeId, now)
		incr(self, "trade.cancelled:precondition")
		return { ok = false, reason = swap.reason }
	end
	trade.state = TS.COMPLETE
	release(self, trade)
	incr(self, "trade.completed:flow")
	return { ok = true, tradeId = tradeId }
end

-- ── cancel / timeout / disconnect: every exit reverts BOTH sides' escrow and frees both players. ──
function M.cancel(self: TradeService, by: string, tradeId: string, now: number): Result
	local trade = self.trades[tradeId]
	if trade == nil then
		return { ok = false, reason = "no_such_trade" }
	end
	if trade.state == TS.COMPLETE or trade.state == TS.CANCELLED then
		return { ok = false, reason = "not_cancellable" }
	end
	revertEscrow(self, trade, trade.a)
	revertEscrow(self, trade, trade.b)
	trade.state = TS.CANCELLED
	trade.settleStartedAt = nil
	release(self, trade)
	incr(self, "trade.cancelled")
	return { ok = true, tradeId = tradeId }
end

function M.timeoutTick(self: TradeService, tradeId: string, now: number): Result
	local trade = self.trades[tradeId]
	if trade == nil then
		return { ok = false, reason = "no_such_trade" }
	end
	if trade.state == TS.COMPLETE or trade.state == TS.CANCELLED then
		return { ok = false, reason = "not_active" }
	end
	if (now - trade.createdAt) < self.deps.config.tuning.persistence.escrowTimeoutSeconds then
		return { ok = false, reason = "not_expired" }
	end
	return M.cancel(self, trade.a, tradeId, now)
end

function M.onDisconnect(self: TradeService, player: string, now: number): Result
	local tradeId = self.activeByPlayer[player]
	if tradeId == nil then
		return { ok = false, reason = "no_active_trade" }
	end
	return M.cancel(self, player, tradeId, now)
end

-- ── projection: the read-only, server-sourced view (the panel is Studio; the data is headless). Each offered
-- item's identity is rendered from the artifact's authoritative record (provenance → Catalog name/rarity),
-- NEVER from client text (the anti-impersonation guarantee). gross/tax/net are server-computed. ──
export type ProjItem = { artifactId: string, name: string, rarity: string }
export type ProjOffer = { items: { ProjItem }, cash: number, confirmed: boolean }
export type Projection = {
	tradeId: string,
	state: TradeState,
	version: number,
	offers: { [string]: ProjOffer },
	gross: number,
	tax: number,
	net: number,
}
local function identify(self: TradeService, holder: string, id: string): ProjItem
	local p = self.deps.getProfile(holder)
	local art = if p ~= nil then p.artifacts[id] else nil
	local name, rarity = id, "Unknown"
	if art ~= nil and art.provenance.sourceId ~= nil then
		local entry = self.deps.config.targetIndex[art.provenance.sourceId :: string]
		if entry ~= nil then
			name = entry.name
			rarity = entry.rarity
		end
	end
	return { artifactId = id, name = name, rarity = rarity }
end
function M.projection(self: TradeService, tradeId: string): Projection?
	local trade = self.trades[tradeId]
	if trade == nil then
		return nil
	end
	local payer, gross = cashLeg(trade)
	local tax = Economy.tradeTax(self.deps.config, gross)
	local offers: { [string]: ProjOffer } = {}
	for key, offer in trade.offers do
		local items: { ProjItem } = {}
		for _, id in offer.items do
			table.insert(items, identify(self, key, id))
		end
		offers[key] = { items = items, cash = offer.cash, confirmed = offer.confirmed }
	end
	return { tradeId = tradeId, state = trade.state, version = trade.version, offers = offers, gross = gross, tax = tax, net = gross - tax }
end
```
> **Build note (verify during execution):** `config.targetIndex[sourceId]` carries `.name` and `.rarity` (it indexes creatures/fish). If a field name differs (e.g. the index entry lacks `name`), resolve the name via `config.creatures[sourceId]`/`config.fish[sourceId]`. Confirm `targetIndex` entry shape before finalizing `identify`.

- [ ] **Step 4: Run to verify it passes** — `luau tests/run.luau 2>&1 | tail -3` → `0 failed`.
- [ ] **Step 5: Full gate** — `./run-tests.sh 2>&1 | tail -3` → `ALL GREEN ✓`.
- [ ] **Step 6: Commit** (when authorized)
```bash
git add src/server/trading/TradeService.luau tests/TradeService.spec.luau
git commit -m "feat(step12): TradeService confirm/escrow/settle/commit/cancel/timeout/disconnect + final-terms (8 checks)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: World wiring (Studio-only) + README

**Files:**
- Modify: `src/server/world/WorldServer.server.luau` (Studio-only — not analyzed/tested; must `rojo build`)
- Modify: `README.md`

- [ ] **Step 1: Wire TradeService in `WorldServer.server.luau`.** Add the require near the other server requires (after `WorldMapHandler`):
```lua
local TradeService = require("@src/server/trading/TradeService")
```
After the registry block (where Step 11's VendorHandler registered), construct the service (it is NOT a gauntlet handler — it reaches both sessions):
```lua
-- Step 12: the Trading Post — a SPECIAL two-session path (NOT a gauntlet handler; the gauntlet is single-
-- profile). It reaches both traders' profiles via SessionService and runs the atomic swap (TradeSwap) over
-- PairTransaction. Client trade intents (request/accept/setOffer/confirm/cancel) route here; a tick drives
-- timeoutTick and the post-settle tryCommit; player-removing fires onDisconnect.
local tradeService = TradeService.new({
	config = Catalog,
	idGen = idGen,
	telemetry = telemetry,
	getProfile = function(key: string)
		local s = sessionService.sessions[tonumber(key)]
		return if s ~= nil then s.profile else nil
	end,
	saveProfile = function(key: string)
		return SessionService.saveNow(sessionService, tonumber(key))
	end,
})
```
(Match the actual SessionService accessor names confirmed at execution time — `sessionService.sessions[playerId]` and `SessionService.saveNow(sessionService, playerId)`. If owner keys are `tostring(UserId)`, `tonumber(key)` recovers the playerId.)

- [ ] **Step 2: Flip the TradingPost fixture to `built`.** Find:
```lua
fixture("TradingPost", Vector3.new(30, 4, 0), Color3.fromRGB(110, 130, 110), "stub") -- Step 12
```
Replace with:
```lua
fixture("TradingPost", Vector3.new(30, 4, 0), Color3.fromRGB(110, 130, 110), "built") -- Step 12: same-server P2P escrow swap
```

- [ ] **Step 3: Verify rojo builds (gate 4).** Run: `./run-tests.sh 2>&1 | tail -8` → gate 4 `✓ rojo build`, overall `ALL GREEN ✓`, and `WorldServer.server.luau` appears under the `⌂ Studio-only` list.

- [ ] **Step 4: Update the README.** Add a Step 12 section (mirroring the Step 11 section format) before `## Deferred — who owns what`:
````markdown
### Step 12 — Trading (the moat's runtime enforcement)

Design-time scarcity becomes runtime scarcity: rares trade, and **cannot be duped**.

- **The atomic two-sided swap (rigor-critical core).** `ArtifactStore.transferOwnership` rides the `ESCROWED → (new owner, HELD)` edge: the new owner gets the **live** record (owner flipped, HELD, owned); the old owner's is **tombstoned — marked traded-away, never erased** (audit/rollback, exactly as salvage tombstones). `TradeSwap.commit` pre-validates **every** CAS precondition before any mutation, then in **one no-yield section** (`PairTransaction`, the new two-profile transaction) moves both sides' artifacts, applies the `tradepay-out`/`tradepay-in`/`tradetax` Cash triple, and writes the two-sided trade record to both `tradeLog`s. **THE invariant: no artifact is ever LIVE in two profiles.** A forced CAS mismatch transfers nothing (both unchanged); a forced save failure reverts **both** profiles in memory.
- **The new primitives (built here; the CAS edge table was inherited).** `PairTransaction.run` (two-profile snapshot/mutate/save/restore-both — parallel to the single-profile `Transaction.run`); `ArtifactStore.transferOwnership` (the cross-profile ownership transfer); the swap is a **special two-session path**, never a single-profile gauntlet handler.
- **The trade flow (`TradeService`).** A server-owned `PendingTrade` state machine: `REQUESTED → BUILDING → A/B_CONFIRMED → COMMITTING → COMPLETE | CANCELLED`. One active trade per player. The **double-confirm is bound to a terms-snapshot version**: any offer change increments the version, clears **both** confirms, and reverts that side's escrow; a stale-version confirm is **rejected** (structural). Escrow at confirm (HELD→ESCROWED via the existing CAS); a `commitSettleSeconds` freeze (fat-finger window) before the swap. Escrow reverts on **every** exit — re-arm, cancel, timeout, disconnect.
- **No raw Cash.** Cash moves only as the net payment leg, inside the atomic commit, net of the **trade tax** (`Economy.tradeTax`, a LOW anti-wash rate); `|A.items| + |B.items| ≥ 1` at commit; tax taken **exactly once**, never on cancel/re-arm; zero-Cash trades pay zero tax.
- **Anti-scam.** The final-terms projection is **server-sourced** — each offered item's name/rarity comes from the artifact's authoritative record (provenance → Catalog), never client text. gross/tax/net are server-computed.
- **The 8 MVL pre-launch checks** are headless-proven: (1) re-arm clears both confirms + reverts escrow, stale-version confirm rejected; (2) disconnect auto-cancels with full escrow revert; (3) a forced CAS mismatch transfers nothing + reverts to CANCELLED; (4) a DISPLAYED trophy can't be offered until un-displayed; (5) a `tradeable=false` commodity can't be added; (6) a pure-Cash trade can't commit; (7) tax taken exactly once on commit; (8) one-active-trade blocks a second.
- **The two-key persist window (named recovery path).** `saveNow` is one ProfileStore key per profile, so two profiles are two saves (not ProfileStore-atomic). The two-profile snapshot/restore covers a save **failure** (revert both in memory — tested). The residual **crash window** (key A persisted, server dies before key B) is closed by the **two-sided trade record** (written here to both `tradeLog`s) consumed by a **reconcile-on-reload** — flagged as the named recovery path leveraging the audit/point-in-time substrate already deferred to ops. It is **not silently unhandled**.

**Studio / telemetry (NOT headless — playtest-pending):** the Trading Post in-instance player list + "open to trade" toggle + browse-before-request; the negotiation panels (live offers, visible re-arm); the final-terms panel (server-sourced names/rarity, gross/tax/net, settle countdown + live Cancel, escrow-timeout countdown, disconnect message); telemetry dashboards (initiated/completed/cancelled+reason, traded-by-rarity, Cash volume + tradetax, swap-precondition-failure rate ≈ 0); the actual reconcile-on-reload consumer of the trade record.

**Deferrals (named):** cross-server trading / MemoryStore broker → post-launch; auction house / order book / matching → post-launch; raw Cash transfer → never (the `≥ 1 artifact` rule is the structural block).
````
Also update the **Deferred — who owns what** table: change the **Trading** row(s) (escrow/swap/ownership-transfer, `HELD↔ESCROWED`) from `Step 12` to **done (Step 12)** (strikethrough + `✅ Step 12`), and add a new row: **`reconcile-on-reload` for the two-key trade-persist crash window** → ops/later (the trade record substrate is built).

- [ ] **Step 5: Final full gate** — `./run-tests.sh 2>&1 | tail -5` → `ALL GREEN ✓`, `0 failed`.
- [ ] **Step 6: Commit** (when authorized)
```bash
git add src/server/world/WorldServer.server.luau README.md
git commit -m "feat(step12): wire TradeService into WorldServer + README (Trading, two-key reconcile flag)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Definition of Done (verify before claiming complete)

- [ ] `./run-tests.sh` → **ALL GREEN ✓**, `0 failed`, negative fixtures still FAIL analysis, rojo builds.
- [ ] **Atomic swap:** a success makes each artifact live-in-new-owner + tombstone-in-old (never live in both) and applies the `tradepay-out`/`tradepay-in`/`tradetax` triple; a forced CAS mismatch transfers nothing (both unchanged → CANCELLED); a forced save failure reverts both in memory; pre-validation runs before any mutation, in one no-yield section.
- [ ] **Two-key persist window** reconciled or explicitly flagged (the trade record is built + tested; the reconcile consumer is the README's named recovery path).
- [ ] **The 8 checks** all headless-proven (re-arm + stale-version; disconnect; CAS-mismatch; DISPLAYED-can't-offer; commodity-can't-add; pure-Cash-can't-commit; tax-once; one-active).
- [ ] **Anti-dupe:** ESCROWED locks an artifact out of a second trade / salvage / display (existing handlers + one-active enforce it); the `dog_redbone_rare` (Step 11's trade-routed rare) trades through this path (it's a `tradeable` artifact — but note: dogs mint as commodities in Step 11; a `tradeable` rare breed must be on the artifact path to trade — verify and note in README if the rare-dog artifact-minting is itself deferred).
- [ ] **Steps 1–11 stay green**; the economy reconciliation is untouched (trades move existing artifacts + taxed Cash, not routine income).
- [ ] **Studio/telemetry** enumerated honestly as unchecked.

---

## Self-Review

**Spec coverage:** §A swap primitive → Tasks 3,4,5. §B state machine → Tasks 6,7. §C escrow lifecycle → Task 7 (revertEscrow on every exit). §D offer validation + no-raw-Cash → Task 6 (setOffer) + Task 5 (|items|≥1). §E tax → Tasks 1,5,7. §F discovery + final-terms → Task 7 (projection; discovery list is Studio). §G telemetry → Tasks 5,7 (incr) + Studio dashboards. The 8 checks → Tasks 6,7. Two-key window → Task 5 (record) + Task 8 (README flag). ✓

**Placeholder scan:** every code step has complete source; commands have expected output; the one explicitly-flagged uncertainty (`targetIndex` entry shape, SessionService accessor names) is called out as a verify-during-execution build note, with the fallback specified. ✓

**Type/name consistency:** `transferOwnership(from, to, id, expected, newOwner)` defined in Task 3, consumed verbatim in Task 5. `PairTransaction.run(A, B, mutate, saveA, saveB)` defined in Task 4, consumed in Task 5. `TradeSwap.commit(SwapArgs)` defined in Task 5, consumed in Task 7. `TradeService` deps (`getProfile`/`saveProfile`) consistent across Tasks 6,7,8. `Enums.TradeState` values match the state-machine usage. Ledger types `tradepay-out`/`tradepay-in`/`tradetax`, loop `"none"`, consistent. `tradeTaxRate`/`commitSettleSeconds` defined Task 1, consumed Tasks 5,7. ✓

**Open item flagged for execution:** the rare-dog (`dog_redbone_rare`) trade path — Step 11 mints dogs as **commodities** (typed-owned), but a `tradeable=true` rare breed must be a unique **artifact** to trade. Verify whether Step 11/earlier mints the rare dog as an artifact; if not, the "rare breed trades through this path" DoD line is satisfied structurally for **trophy/record artifacts** and the rare-dog-as-artifact minting is a noted gap to flag in the README (its data is `tradeable=true` but the artifact-minting hook may be a later wire). Resolve honestly during execution; do not claim the rare dog trades if its artifact isn't minted.
