# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Wild World** — a Roblox/Luau hunting-and-fishing RPG. The repo holds both the **design corpus** (the
`*.md` specs at the root) and the **implementation** (`src/`, `tests/`, `client/`), built step-by-step per
`03_BUILD_PLAN.md`. `README.md` is the authoritative status/architecture doc — read it first for any
non-trivial task; this file is the operating manual.

**Git root is the `RobloxRPG/` subdirectory**, not the outer wrapper dir. Run all commands from there.

## Commands

```bash
./run-tests.sh                 # THE Definition-of-Done gate — run this before claiming any work done
luau tests/run.luau            # unit tests only (aggregates every spec; non-zero exit on failure)
luau-analyze path/to/File.luau # strict type-check a single module (config in .luaurc)
rojo build default.project.json --output /tmp/wildworld.rbxlx   # confirm the project still syncs
```

`./run-tests.sh` runs four gates and is the success bar: (1) `luau-analyze --!strict` on every headless
module, (2) all unit tests, (3) the negative fixtures must **fail** analysis, (4) `rojo build` succeeds.

Toolchain (`luau`, `luau-analyze`, `rojo`) is on `PATH` at `~/.local/bin`. Requires resolve via
require-by-string using `.luaurc` aliases: `@src/...` and `@tests/...`. Language mode is `strict`, all
lints on.

**Running a single test:** there is no name filter. `tests/run.luau` hard-codes the spec list and each
spec is a `(t: Harness.T) -> ()` function. To run one in isolation, temporarily trim the `specs` table in
`tests/run.luau` (revert before committing), or write a throwaway runner that requires the one spec plus
`@tests/harness`. Specs assert via `t.test/ok/eq/errs`; `t.finish()` returns the exit code.

## The headless / Studio split (critical — don't break the build)

The codebase is deliberately divided by what a headless harness can verify:

- **Headless-verifiable** = data (`src/config/`), pure logic (`src/logic/`), and the server substrate
  (`src/server/**`, excluding the `*.server.luau` world script). These are `--!strict`, reference **no**
  Roblox globals, and are unit-tested against in-memory fakes. This is what `./run-tests.sh` proves.
- **Studio-only** = `*.server.luau`, `*.client.luau`, and everything in `client/`. These touch
  `Workspace`/`Humanoid`/`DataStoreService` etc. They are **excluded** from type-check and tests (see the
  `find` filter in `run-tests.sh`) and are verified by the manual **playtest checklist in README.md** —
  not headless.

Consequences when editing:
- Keep Roblox-API code in `*.server.luau`/`*.client.luau`/`client/`. Never pull `game:GetService` or
  Workspace references into a headless module — it will break `--!strict` and the no-Roblox-globals rule.
- Roblox services enter headless code only through **injection-based thin adapters**
  (`src/server/RobloxAdapters.luau`) that satisfy the interfaces in `src/server/persistence/Types.luau`.
  In-memory **fakes** (`src/server/persistence/Fakes.luau`) make the logic testable; the real
  `game:GetService(...)` bootstrap is the one Studio-only edge (illustrative bootstrap in README).
- "ALL GREEN headless" is **not** the bar for Step 3+ world/feel work — the Studio checklist is.

## Architectural rules (the invariants the design enforces)

- **config (data) vs logic (pure).** `src/config/` holds every content value; `src/logic/` holds pure
  functions with **zero** content literals — they read `profile` (state) + `config` (data) args only.
- **interface vs adapter.** Persistence logic depends on the `Types.luau` interfaces, never on
  `DataStoreService` directly (fakes for tests, adapters for Studio).
- **derive, don't store.** Cash balance, EHT/EFT, and gate satisfaction are **functions over the
  profile**, never stored fields. Any stored derivable is a stale-state dupe surface. (Cash itself is
  `{ checkpoint, tail }`; `balanceOf = checkpoint.balance + Σ tail`.)
- **substrate vs operations.** This build owns primitives (session lock, ledger, CAS artifact store,
  validation gauntlet, transaction); later steps own the *operations* that call them. Don't implement a
  later step's operation inside the substrate.
- **closed enums live once.** Every closed string-set is in `src/types/Enums.luau` as both a Luau literal
  union (compile-time) and a frozen value table (runtime). Use those; don't introduce string synonyms.
- **configs self-validate on load.** `Catalog.luau` joins the catalogs and runs `Validation.luau` at
  require time — a malformed catalog fails the `require`.

## The step / branch model

Work proceeds in numbered steps from `03_BUILD_PLAN.md`, one branch per step (`main`,
`step-2-persistence`, `step-3-bayou-shell`). Implementation plans live in
`docs/superpowers/plans/`. Steps 1–3 are done; later steps are stubbed.

Before building something that seems missing, check README's **"Deferred — who owns what"** table — much
unbuilt behavior (combat/fishing resolution, faucet/sink economy operations, teleport enforcement,
trading, real-money wiring) is intentionally deferred to a specific later step and often marked
`TODO(step-N)` in code. Don't implement another step's work prematurely.

## Specs are the source of truth

The root `*.md` files are the binding design corpus; code cites them by section (e.g. `§4`, `RD5`). When a
behavior is ambiguous, the spec wins. Priority order (per README): `02_DATA_SCHEMA_AND_TEMPLATES.md`
(units/templates) → `04_GLOSSARY.md` (names) → `SYS_progression.md` / `SYS_economy.md` /
`EQUIPMENT_MASTER.md` → `SYS_data_integrity.md` (**binding** for the Step 2 substrate). README's
"Binding-spec reconciliations" section records the judgment calls already made — honor them.

## Negative fixtures

`tests/negative/*.luau` are intended to **fail** `luau-analyze` — they prove an invalid state is
unrepresentable by construction (e.g. a `power` rank-perk, a reward that is both Cash and artifact). Gate 3
of `run-tests.sh` fails if any of them analyzes clean. Do **not** "fix" them to pass analysis.

## Module map

See README.md's "Module map" for the per-file responsibilities (`types/`, `config/`, `logic/`,
`server/{persistence,ledger,artifacts,authority,idle}`, the Step-2 substrate table, and the keystone
`ProfileStore.luau` session-lock semantics). It is kept current with the implementation.
