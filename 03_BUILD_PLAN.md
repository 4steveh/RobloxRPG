# Build Plan — From Research Corpus to Shipped Game

> **Purpose.** The systematic plan of action: the order to run deep-dive chats, the order to build
> with Claude Code, and how the research hands off to implementation. Designed so each step's output
> is the next step's input, and so we ship the smallest thing that proves the loop *before* expanding.

---

## Guiding principle: prove the loop, then expand

The #1 risk is scope (see 01). The entire plan is structured around shipping a **Minimum Viable
Loop (MVL)** first — a complete, fun, monetizable game with just enough content to validate
retention — then using world-expansion as the ongoing LiveOps engine.

**MVL = 3 destinations (Bayou, Appalachia, Alaska) + both loops + lodge + trade + one event.**

Bayou proves first-five-minutes. Appalachia proves the difficulty step and first gear commitment.
Alaska proves the boat gate, the first real wall, and a high-tier rare. Skipping Rockies (Tier 3)
for MVL is deliberate — Appalachia→Alaska still demonstrates escalation; we slot Rockies in as the
first post-launch content drop, which also rehearses our update pipeline early.

---

---

## How each document is used (read this to understand the corpus)

Two consumers read these files: **design chats** (here, in the project) and **Claude Code** (at
build time). Each doc has a different job for each consumer. This table is the answer to "what is
each file actually for."

| Document | A design chat uses it to... | Claude Code uses it to... |
|----------|------------------------------|----------------------------|
| **00_RESEARCH_FOUNDATION** | Reason from the winning patterns; justify/check every decision. Read at the start of every chat. | Rarely directly — it's "why," not "what to build." May inform UX/monetization wiring. |
| **01_GAME_DESIGN_OVERVIEW** | Stay aligned to the game vision; know the destination ladder and feature set. Read every chat. | Understand overall structure when scaffolding the project and data model. |
| **02_DATA_SCHEMA_AND_TEMPLATES** | Produce output in the correct template + units. Read every chat that produces a doc. | Read the field definitions to design data structures (creature/fish/equipment schemas). |
| **03_BUILD_PLAN** (this file) | Know which chat to run next and in what order. | Know which build prompt comes next and which docs to load as context for it. |
| **04_GLOSSARY** | Use canonical terms; avoid synonyms. Read every chat. | Name variables/services consistently with the design vocabulary. |
| **05_COMPETITIVE_LANDSCAPE** | Check each decision against the differentiation guardrail; avoid drifting toward competitors' treadmill. Read every design chat. | Rarely directly — informs why certain systems (trade, world spine) are load-bearing, not cuttable. |
| **SYS_\*** (system specs) | Reference upstream systems a new doc depends on. | **Primary build instructions** — each becomes the spec for implementing that system. |
| **LOC_\*** (locations) | Reference when designing adjacent content or balancing. | Populate each Destination's content: spawns, rosters, vendors, map data. |
| **EQUIPMENT_MASTER** | Reference item stats when designing creatures/fish/gates. | The canonical item table — drives the equipment/shop data and balance values. |

**The mental model:** the `00–04` docs are the *rules of the project*. The `SYS_*` and `LOC_*` docs
are the *spec of the game*. Design chats write the spec by following the rules; Claude Code builds
the game by following the spec. The docs are the interface between the two — which is exactly why
they are Markdown (Claude Code parses them as prompts; they diff cleanly as they evolve).

**What a design chat reads vs. produces:**
- **Always reads first:** 00, 01, 02, 04 (the anchors + glossary), and 05 (the differentiation guardrail).
- **Also reads:** the specific upstream `SYS_*`/`LOC_*` docs its task depends on (per Phase 1 order).
- **Produces:** exactly one `LOC_*` or `SYS_*` doc (or an EQUIPMENT_MASTER merge), in the right template.

**What Claude Code is handed per build prompt:** only the docs relevant to that step (listed in
Phase 4), not the whole corpus — keeping its context focused on the system being built.

---

## Phase 0 — Project setup (DONE once these files are in the project)

The project knowledge base = docs 00–04. Every chat starts by reading the anchors (00, 01, 02) and
the glossary (04).

---

## Phase 1 — Core systems deep-dives (DO THESE BEFORE LOCATIONS)

These are cross-cutting: they constrain every location, so they come first. Each is one chat,
producing a `SYS_*.md` via Template F.

**Order matters — later ones depend on earlier ones:**

1. **`SYS_progression.md`** — the gear/passport ladder, how tiers gate, Hunter/Angler ranks.
   *Depends on:* 01. *Constrains:* everything.
2. **`SYS_economy.md`** — currency, faucets/sinks, per-tier income bands, gear pricing curve, the
   balance math that keeps hunting ≈ fishing income. *Depends on:* progression. *Constrains:* all
   locations + equipment. **This is the highest-leverage and most fragile doc — give it the most care.**
3. **`SYS_combat.md`** — hunting mechanics, weapon/armor interaction, damage model, co-op scaling,
   how "min weapon tier to kill / min armor tier to survive" actually computes.
4. **`SYS_fishing.md`** — fishing mechanics, rod/reel/bait interaction, the fight/reel model, how
   fish difficulty gates on gear.
5. **`EQUIPMENT_MASTER.md`** (via the equipment chat) — the full weapon/armor/rod/vehicle/mount/dog
   list with stats, weights, prices, using Template B. *Depends on:* progression, economy, combat,
   fishing. **Owns cross-tier balance.** Region-specific items get added here as locations are done.
6. **`SYS_data_integrity.md`** — data persistence model (what's saved, when, how), server-authority
   rules (the server owns all economy state; the client never asserts cash/inventory), anti-dupe and
   anti-exploit safeguards, session/rollback handling. *Depends on:* progression, economy.
   **EXISTENTIAL for a scarce-item trade economy** — if items can be duped or data rolls back, the
   scarcity moat collapses on day one. Specify this early; do not treat it as a detail inside trading.
7. **`SYS_lodge_trophy.md`** — the hub, trophy hall, cosmetic/decor monetization, social flex.
8. **`SYS_trading.md`** — player-to-player trade, scarcity rules, what's tradeable, anti-scam/
   anti-dupe trade-flow safeguards (escrow/confirm both sides, no item leaves one inventory until it
   enters the other). *Depends on:* economy, lodge, data_integrity.
9. **`SYS_onboarding_funnel.md`** — the first-five-minutes beat-by-beat in the Bayou. *Depends on:*
   progression, economy, combat, fishing. **Retention-critical.**
10. **`SYS_liveops_calendar.md`** — the event/seasonal/spawn cadence framework. *Depends on:* most
   of the above.

> Note: 5 (equipment) is partly iterative — it gets a first full pass here, then absorbs
> region-specific gear as each location chat completes.

---

## Phase 2 — Location deep-dives (one chat each, Template A)

Do the **3 MVL locations first**, in tier order, then the rest as content pipeline:

**MVL locations (build these now):**
1. `LOC_01_bayou.md` — also the onboarding proving ground; coordinate with `SYS_onboarding_funnel.md`.
2. `LOC_02_appalachia.md`
3. `LOC_04_alaska.md`

**Post-launch content pipeline (later chats, in rough priority):**
4. `LOC_03_rockies.md` (first content drop — rehearses the update pipeline)
5. `LOC_05_africa.md` (carry the appropriateness framing from 01)
6. `LOC_06_amazon.md`
7. `LOC_07_deep_sea.md`
8. `LOC_08+_*` mythic/seasonal destinations as ongoing LiveOps.

Each location chat: fills Template A completely, produces region-specific equipment in Template B
(to merge into EQUIPMENT_MASTER), and hands economy hooks to `SYS_economy.md` for balancing.

---

## Phase 3 — Map recognizability & art direction pass

One chat (or part of each location chat) to lock the **recognizable, compelling** landmarks and
art-direction notes per location — the sensory signatures that make each map instantly readable and
distinct. Remember: low-poly + performant (mobile-first), and **the thumbnail/icon is where art
budget actually matters** (see 00, §8). Produce a thumbnail concept per "season"/destination launch.

---

## Phase 4 — Claude Code build (implementation)

Now the corpus becomes ordered prompts. **Build in this dependency order**, handing Claude Code the
relevant `.md` files as context for each prompt. Roughly:

1. **Project skeleton & data model** — the schemas for creatures, fish, equipment, player state,
   the destination/teleport framework. Hand it: 01, 02, 04, SYS_progression, SYS_economy, EQUIPMENT_MASTER.
2. **Data persistence + server-authority foundation** — wire the save/load model and the rule that
   the server owns all economy/inventory state, BEFORE any Cash or items exist to exploit. Hand it
   SYS_data_integrity. *Everything economic is built on top of this; retrofitting it later is painful.*
3. **Core movement + one destination shell (Bayou)** — get a player walking/arriving in one Destination.
4. **Hunting system** — hand it SYS_combat + EQUIPMENT_MASTER + LOC_01.
5. **Fishing system** — hand it SYS_fishing + EQUIPMENT_MASTER + LOC_01.
6. **Economy + shops (Outfitter, Tackle Shop)** — hand it SYS_economy + EQUIPMENT_MASTER. *Server-
   authoritative per step 2.*
7. **The onboarding funnel** — hand it SYS_onboarding_funnel + LOC_01. *Instrument D1 from here.*
8. **Lodge + Trophy Hall** — hand it SYS_lodge_trophy.
9. **World Map + fast-travel + Destination gating** — hand it SYS_progression + the LOC docs.
10. **Add Appalachia, then Alaska** — hand it the respective LOC docs.
11. **Boats / mounts / tracking dogs** — hand it EQUIPMENT_MASTER + relevant SYS docs.
12. **Trading system** — hand it SYS_trading + SYS_data_integrity. *Escrow/both-sides-confirm; no
    item leaves one inventory until it enters the other. Anti-dupe is non-negotiable here.*
13. **First LiveOps event + timed spawns** — hand it SYS_liveops_calendar + LOC rares.
14. **Monetization wiring** — game passes, dev products, rewarded ads, per the monetization map.
15. **Analytics instrumentation** — D1/D7/D30, per-loop income, funnel drop-off, conversion. *This
    is not optional and not last-in-practice — wire telemetry alongside each system.*

> **Engineering-background leverage:** steps 1–2, 6, 12, and 15 (data model, persistence/server-
> authority, economy, trading integrity, telemetry) are where systems rigor wins and where most
> Roblox RPGs fail. Front-load care there.

---

## Phase 5 — Soft launch, measure, iterate

- Launch MVL quietly. **Target D1 > 25%** (see 00, §0). If D1 is below ~15%, the loop or onboarding
  is broken — fix before any marketing or expansion.
- Watch per-loop income balance live; retune the economy.
- Hit the **weekly update cadence** from day one — Rockies is the first scheduled drop.
- Coordinate a growth-velocity push to break the "Up and Coming" sort once retention is solid.

---

## How to run a deep-dive chat (paste-ready procedure)

For each chat in Phases 1–3:
1. Confirm the project has docs 00–03 loaded.
2. Open a new chat in the project. Tell it which document to produce (e.g. "Produce `LOC_04_alaska.md`").
3. It reads 00, 01, 02, fills the correct template completely, flags open questions.
4. Review, refine in-chat, then save the output as a new project file with the canonical name.
5. If it produced Template B equipment blocks, note them for the next EQUIPMENT_MASTER merge.

**Keep chats single-purpose.** One location or one system per chat keeps context clean and outputs
composable. Don't let a location chat drift into rebalancing the economy — flag it for the economy
doc instead.

---

## Definition of done for the research phase

The research phase is complete and ready for full Claude Code build when:
- Docs 00–04 are stable.
- All 10 `SYS_*.md` exist and are internally consistent.
- `SYS_data_integrity.md` specifies persistence + server-authority + anti-dupe **before** any
  trading or economy code is written.
- The 3 MVL `LOC_*.md` exist and their equipment is merged into `EQUIPMENT_MASTER.md`.
- The economy doc has reconciled per-loop income across all 3 MVL locations.
- The onboarding funnel is specified beat-by-beat.

Everything past that (Rockies onward) is content pipeline, produced on the live update cadence.
