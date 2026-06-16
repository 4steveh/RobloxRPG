# Wild World — Step 1: Project Skeleton & Data Model — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the data-driven content catalogs, the canonical player-state schema, and the pure derivation logic (EHT/EFT, gate, balance) for *Wild World* — **shape + pure logic only**, no persistence, gameplay, or UI.

**Architecture:** Strict-Luau, Rojo-syncable. Clean split: **config (data) modules** carry every content value; **logic modules** carry zero hardcoded content (they take a `config` argument). Everything lives server-side (`ServerScriptService.WildWorld`). Pure functions derive EHT/EFT, gate satisfaction, and Cash balance from a `PlayerData` profile — none of those are stored fields. Headless verification via the open-source `luau` runner + `luau-analyze` (`--!strict`) + `rojo build`.

**Tech Stack:** Luau (`--!strict`), Rojo 7 (`default.project.json`), `.luaurc` require-by-string aliases (`@src/...`), a hand-rolled assert-based test harness run under `luau`.

---

## Binding-spec reconciliations (decisions taken while reading the corpus — flagged, not silently resolved)

These are the points where the specs needed a judgment call. Each is encoded in code comments + the README.

1. **Gate model — three checks, per the build prompt's literal `evaluateGate` bullets.** `gate = { requiredTier, milestoneTargets, prerequisiteDestinations }`.
   - `prerequisiteDestinations ⊆ conqueredDestinations` (the DAG edges; **the field the Rockies test re-threads**).
   - `requiredTier`: `∃ loop ∈ offeredLoops : effectiveTier(loop) ≥ requiredTier` — **OR across *offered* loops, never a blind `max(EHT,EFT)`** (the fishing-only fixture proves this).
   - `milestoneTargets`: satisfied by **any** target whose loop ∈ `offeredLoops` and whose home Destination ∈ `conqueredDestinations`. Loop-aware; supplies the actionable creature/fish nouns for the legibility contract.
   - For the MVL linear DAG the prerequisite-conquered and milestone checks are correlated by construction (the milestone targets live in the single prerequisite Destination); both are coded + tested. `milestoneTargets` validates against `conqueredDestinations` because per-target recorded kill/catch events are **`TODO(step-4/5)`**.

2. **`monetizationRole` enum = `identity | convenience | access`** (build prompt's `EquipmentItem` schema; **no `power`**). EQUIPMENT_MASTER §4 calls gating gear "power-progression"; in the build prompt's no-power vocabulary that maps to **`convenience`** for gear (the real-money touch is grind-compression / currency packs — pay-proof), with the *gate* role carried by `tier` + `tierInput=true`, not by `monetizationRole`. Boats = `access`; mounts/dogs/premium consumables = `convenience`; cosmetics = `identity`; free starter items = `nil`. Flagged.

3. **`armorTierOrFloor`** (empty-armor floor): `if armor equipped → armor.tier; else → (weaponTier < armorGatingStartTier) and 1 or 0`. Gives EHT=1 for the T1 starter (armorless), and drops EHT to 0 for a T2+ weapon with no armor (armor is then a gating slot). Boundary tested both sides of `armorGatingStartTier` (=2).

4. **`destinationId` added to Creature/Fish rows** (their home Destination). Needed to (a) organize catalogs by Destination and (b) resolve a milestone target's home for the gate's milestone check. Within "catalogs keyed by Destination" scope; flagged as a structural addition beyond Template C/D's `spawn.location` string.

5. **Require style:** require-by-string via `.luaurc` alias `@src/...` — honored by `luau`/`luau-analyze`/luau-lsp; the Rojo tree makes it Studio-syncable. Runtime require wiring into services is **`TODO(step-2)`** (the RemoteEvent/service boundary is Step 2).

---

## File structure (module map)

```
RobloxRPG/                         (repo root — already holds the design corpus + .git)
  default.project.json             Rojo: src/ → ServerScriptService.WildWorld
  .luaurc                          strict mode + alias {src: ./src}
  README.md                        module map, config-vs-logic rule, deferred-stub ownership
  run-tests.sh                     analyze (--!strict) + run all specs + negative-analysis + rojo build
  src/
    types/
      Ids.luau                     DestinationId/TargetId registries + string-id type aliases
      Enums.luau                   Rarity, Category, Behavior, Disposition, ArtifactKind, MonetizationRole, RankPerkCategory, Loop, WaterType, Vendor + frozen value sets
      Schema.luau                  record TYPES: EquipmentItem, Creature, Fish, Reward(XOR), Destination, Gate, PlayerData, Artifact, LedgerEntry, Entitlement, RankPerk, Tuning
    config/
      Tuning.luau                  the ENTIRE EQUIPMENT_MASTER §1 constant set (+ TierCoefficient hook, armorGatingStartTier, idle*)
      Equipment.luau               MVL line T1–T4 (structural fields only — NO stat numbers)
      Creatures.luau               Bayou/Appalachia/Alaska hunting rosters (Template C)
      Fish.luau                    Bayou/Appalachia/Alaska fish rosters (Template D)
      Destinations.luau            Bayou T1, Appalachia T2, Alaska T4 + Rockies T3 stub + DeepSea T7 fishing-only fixture; gate DAG
      RankPerks.luau               rank-perk registry (category ∈ {identity,convenience}) — proves no `power`
      Catalog.luau                 aggregator + derived indexes (by id, by destination, target→home/loop)
    logic/
      EffectiveTier.luau           effectiveHuntingTier / effectiveFishingTier (pure; take config)
      Gate.luau                    evaluateGate → { unlocked, unmetReasons } (pure)
      Balance.luau                 balanceOf (fold ledger)
      Profile.luau                 freshProfile() + PlayerData constructors
      Validation.luau              build-time schema assertions (XOR, disposition-kind, no-power, tierInput, tradeable↔artifactId, cosmetic balance-free)
    server/
      DestinationService.luau      teleport interface scaffold (registry + travelTo stub) — names Step 9
      PersistenceStub.luau         load/save/session-lock surface — names Step 2 (interface only)
  tests/
    harness.luau                   tiny describe/it/expect; returns pass/fail counts; process exit code
    EffectiveTier.spec.luau
    Gate.spec.luau                 MVL chain + Rockies re-thread + OR-gate fishing-only fixture + empty-armor boundary
    Balance.spec.luau
    Profile.spec.luau              EHT=EFT=1, Bayou unlocked, balance 0
    Validation.spec.luau           power-perk rejected; disposition-kind rejected; XOR rarity↔reward
    init.spec.luau                 catalog integrity (every milestone target resolves; tierInput invariant; tradeable matrix)
    negative/                      files that MUST fail `luau-analyze` (proves TYPE-level unrepresentability)
      reward_both.luau             cash+artifact reward → type error
      power_perk.luau              rank perk category "power" → type error
      # (non-trophy DISPLAYED/SALVAGED is a kind×disposition cross-constraint between two independent
      #  fields — not expressible as a single type error while disposition stays "a single enum"
      #  per data-integrity §4. It is enforced at RUNTIME by Validation.assertDispositionLegal /
      #  Profile.newArtifact and proven in Validation.spec.luau, the appropriate layer.)
```

---

## Task list (TDD; commit after each green task)

- [ ] **T0 Skeleton & tooling** — `.luaurc`, `default.project.json`, `tests/harness.luau`, `run-tests.sh`; prove `luau` runs harness, `rojo build` succeeds on an empty src.
- [ ] **T1 Enums + Ids + Tuning** — string-literal unions + frozen value sets; the full §1 constant set as data. Spec: every §1 constant present and equals its default; `luau-analyze` clean.
- [ ] **T2 Schema types** — all record types incl. `Reward` XOR union and `PlayerData`. Spec: a value of each type constructs under `--!strict`; a both-fields Reward fails analysis (negative).
- [ ] **T3 Validation** — assertions; runtime rejection of power-perk / illegal disposition / XOR / tierInput / tradeable↔artifactId. Spec: each rejection fires; each valid case passes.
- [ ] **T4 Equipment catalog** — T1–T4 structural rows, tradeable matrix, accessGrant on Coastal Skiff, no stat numbers. Spec: validates clean; tierInput true only for weapon/armor/rod/reel; starter trio cost 0.
- [ ] **T5 Creature + Fish catalogs** — Bayou/Appalachia/Alaska rosters with rarity, reward XOR, reskinOf, destinationId, milestone flags. Spec: Common/Uncommon → cash reward; Rare+ → artifact reward; ambiance grants nothing.
- [ ] **T6 Destinations + gate DAG** — Bayou/Appalachia/Alaska + Rockies stub + DeepSea fixture; gates wired. Spec: every milestoneTarget + prerequisite resolves in the catalog; offeredLoops correct.
- [ ] **T7 EffectiveTier** — EHT/EFT pure fns. Spec: min rule, empty-slot Tier 0, empty-armor floor boundary around armorGatingStartTier.
- [ ] **T8 Gate** — evaluateGate. Spec: MVL chain across under-geared/mismatched/qualified; Rockies re-thread changes outcome with zero logic change; OR-gate fixture (maxed hunter fails fishing-only); unmetReasons are actionable nouns.
- [ ] **T9 Balance** — fold ledger. Spec: empty=0; faucet/sink mix sums signed.
- [ ] **T10 Profile** — freshProfile. Spec: EHT=EFT=1, Bayou ∈ unlocked, balance 0, armor empty, ranks 0, equipped trio present.
- [ ] **T11 Teleport + persistence stubs** — interface only, name owning steps.
- [ ] **T12 README + full green run** — `run-tests.sh` passes: analyze clean, all specs pass, negative files fail analysis, `rojo build` OK.

## Self-review checklist (run after build, before declaring done)

- Spec coverage: every DoD bullet → a passing test. Units/naming match the glossary. Logic modules contain zero content literals (grep for Cash numbers / creature names / destination strings in `logic/`).
- Placeholder scan: no TODO without a `(step-N)` owner; no stat numbers transcribed into Equipment.
- Type consistency: field/enum names identical across Schema, config, logic, tests.
- Adversarial verification: fan out reviewers (one per DoD guarantee) against code + the binding doc; a completeness critic for anything unverified.
