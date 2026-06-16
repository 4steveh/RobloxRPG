# Competitive Landscape — The Gap We're Building Into

> **Purpose.** This is a *guardrail* doc, not a competitor playbook. Its job is to keep every design
> decision on the right side of one line: **informed by competitors' failures, never anchored to
> their solutions.** We do not copy their features (that risks duplicating a leaking treadmill). We
> identify the *problem they left unsolved* and solve it our own way. Every design chat should check
> a decision against §3: "does this attack a known competitor weakness, or are we drifting toward
> their treadmill?"
>
> **Epistemic honesty:** the diagnoses below are inferred from public store descriptions, wikis, and
> third-party stats (Rolimon's, RoMonitor), NOT hands-on teardowns. They are strong enough to set
> direction. They are not verified play-tested autopsies. Treat them as a working thesis to disprove,
> not gospel. If we ever bet heavily on a single differentiator, confirm that specific failure point
> first.

---

## 1. The demand is real (the theme attracts players)

The hunting/fishing theme is proven to pull traffic on Roblox. This is the encouraging half.

- **Fisch** (pure fishing) is a platform-scale juggernaut: 4.5B+ lifetime plays, crossed 1M
  concurrent players in Oct 2025, 73+ locations, ships major updates constantly (a co-op "Crews"
  system launched June 2026). Fishing-as-a-category is *saturated and hyper-competitive*.
- **Gone Hunting** (hunting + fishing RPG — our closest concept) pulled **11M+ visits and ~24k
  upvotes** on the strength of the theme alone. People clearly *try* it.
- Adjacent fishing titles (Fish It, Fishing Simulator, Hunt Giant Fish) crowd the pure-fishing lane.

**Takeaway:** the theme sells the click. Demand is not the question. *Retention* is.

**Hard constraint that falls out of this:** **do NOT build a fishing game.** That is Fisch's
category, at Fisch's scale, against Fisch's update cadence — an unwinnable fight. Our fishing loop
exists only as one half of a *dual loop*; the game is a hunting-and-fishing RPG with a world-travel
spine, which is a different category from "a fishing game."

---

## 2. The failure is retention (the obvious execution does not hold players)

The damning data point: **Gone Hunting's average session is ~8.6 minutes**, and its concurrent
players collapsed from an all-time peak of ~5,145 to roughly 160 in a 24-hour window. High visits,
high upvotes, near-zero retention. By our own Research Foundation (00, §0), that is the precise
profile the algorithm buries: people show up, do the loop twice, and never form a habit. It's a
**D1 failure wearing the costume of a hit.**

Diagnosed causes (inferred from the game's own description + structure):

- **Flat treadmill, no aspiration spine.** The loop is catch/shoot → sell → upgrade → repeat with
  reskinned content. Weather adds *variety*, but variety is not *depth*. There's no escalating wall
  that forces commitment and no far-off goal pulling the player forward. Progression is horizontal
  (more of the same) where retention comes from vertical pull (a reason the next thing matters).
- **Interchangeable, non-intuitive locations.** Invented fantasy zones ("Rainveil Forest,"
  "Ambergrove") carry no innate sense of scale. Unlocking one doesn't *feel* like a bigger deal than
  the last, so passport-style progress doesn't land emotionally.
- **No social or trade layer = no long tail.** It's a solo sell-to-NPC economy. Players are given
  nothing to do *with each other*. That caps the game at "fun for an afternoon," kills the
  player-to-player scarcity moat (the single biggest separator between a 3-month hit and a multi-year
  franchise — 00, §5), and generates zero creator content (no trade showcases, no rare-drop drama),
  starving the discovery flywheel (00, §6).
- **Shallow loop, short session.** 8.6 minutes is the symptom; a loop with no depth to optimize and
  no social reason to stay is the disease.

**The contrast that confirms the thesis:** Fisch is *thriving* precisely on the things Gone Hunting
lacks — relentless content cadence and (newly) a co-op social system. The fishing game that ships
constantly and adds social systems is at 1M+ CCU; the hunting-fishing game that's a static solo
treadmill leaks players to ~160. That contrast *is* the lesson.

---

## 3. Our wedge (each competitor weakness → the Wild World system that beats it)

This is the operational core of the doc. We are not entering an *empty* category — we're entering an
*occupied* one where the incumbent execution is leaking players. That's a stronger position than a
blank space: demand is proven and the bar is beatable. But it means our differentiators must be the
**core of the design, not features 6–8.** They are the entire reason to build this instead of
playing Gone Hunting.

| Competitor weakness (from §2) | Wild World system that attacks it | Where it's specified |
|-------------------------------|-----------------------------------|----------------------|
| Flat, horizontal progression; no aspiration | **Real-world-travel spine** — Bayou → Appalachia → Alaska → Africa. Real places carry innate scale; a child *knows* Alaska outranks a pond. The World Map dangles locked aspiration from minute one. | 01 (destination ladder), SYS_progression |
| Interchangeable fantasy zones | **Each Destination tells its own story** — distinct sensory signature, recognizable landmarks, real-world identity doing the motivational work an abstract zone can't. | 01, Template A §1–2, LOC_* docs |
| No escalating commitment wall | **Rising floors/ceilings + gear-or-die gates** (the first bear; the boat gate to Alaska) — legible, telegraphed walls that force the WoW-style level-up pressure, not a reskin treadmill. | 01 (floors/ceilings), SYS_progression, SYS_combat |
| Solo economy, no long tail | **Scarcity trade economy + Trophy Hall** — region-specific rares are tradeable status items, displayable in the Lodge. People log in to negotiate. This is a *core system*, not a bolt-on. | SYS_trading, SYS_lodge_trophy, Template E |
| No creator-content flywheel | **Designed content moments** — 1-in-N Mythic catches/kills built for the screenshot; trade showcases and rare-drop drama feed YouTube/TikTok. | 00 §6, Template E (content moment field) |
| Shallow single loop → 8-min sessions | **Dual cross-feeding loops + co-op** — hunting and fishing share one Cash/upgrade tree (a bored hunter fishes and still progresses); big game is soloable-but-tense, trivial-with-a-party. Depth + social reason to stay. | 01 (dual loop), SYS_combat, SYS_fishing |

---

## 4. Standing guardrail for every chat

Before finalizing any design decision, check:

1. **Does this deepen the loop or lengthen the session, or is it horizontal reskin?** If it's just
   "more content of the same shape," it's treadmill — flag it.
2. **Does this serve the aspiration spine or the trade moat?** Those are our two load-bearing
   differentiators. A feature that touches neither is a candidate for cutting (scope discipline).
3. **Are we solving the problem our own way, or importing a competitor's solution?** If a decision
   exists because "that's how Gone Hunting/Fisch does it," stop and re-derive it from the Research
   Foundation instead.
4. **Would this produce a content moment or a trade interaction?** If a system creates neither
   social interaction nor shareable content, ask whether it's earning its build cost.

---

## 5. Open flags

- The 8.6-min / CCU-collapse diagnosis is inferred, not play-verified. Highest-value single check, if
  we ever want one, is ~20 minutes in Gone Hunting *to confirm the failure points* — explicitly NOT
  to study its features. Confirm the disease; don't copy the patient.
- Fisch's scale means any *fishing-forward* marketing framing invites a direct, losing comparison.
  Position Wild World as a **hunting-and-fishing RPG with a world to conquer**, never as "a fishing
  game with hunting."
- Watch for new entrants: the theme's proven demand means others may attempt the same world-travel
  wedge. Our moat against that is execution depth (economy, trade integrity, progression) — the
  engineering-systems edge — not the idea itself.
