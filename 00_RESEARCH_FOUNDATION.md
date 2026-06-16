# Research Foundation — What Makes a Winning Roblox Game

> **Purpose of this document.** This is the anchor for the entire project. Every other
> document and every deep-dive chat reasons from the principles here. When a design
> decision is in question, the answer should trace back to one of these patterns.
> Read this first in any new chat before doing location, systems, or economy work.

---

## 0. The single most important fact

Roblox's discovery algorithm optimizes for **long-term player retention**, not popularity
you can buy. D1 (next-day return), D7, and D30 are the strongest predictors of whether the
algorithm promotes a game. Games with D1 above ~25% almost always outrank games with D1
below ~15%, regardless of marketing spend. Bot traffic does not help — bots do not return,
which *lowers* retention metrics, and can get a game terminated.

**Everything in this project is, ultimately, a mechanism for moving D1/D7/D30.** Loop design,
social systems, update cadence, fair monetization — all of it exists to make players come back.

---

## 1. The "highest grossing" vs "currently trending" distinction

Two different forces are at work on Roblox, and the games that last convert one into the other:

- **Evergreen earners** (Adopt Me, Blox Fruits, Brookhaven, Pet Sim 99) win on deep economies
  and operational discipline built over years.
- **Current explosions** (Steal a Brainrot peaked ~25M CCU; Grow a Garden hit 21.6M, a Guinness
  record) win on a near-frictionless loop plus a cultural moment.

A viral moment is luck you position yourself to catch. A *lasting franchise* is what you build
when you convert that moment into one of the durable patterns below. Our game is designed for
the durable patterns; the cultural moment is upside we cannot manufacture.

---

## 2. The core loop: simple to enter, deep to master

Every breakout shares one trait: a loop a seven-year-old grasps in 30 seconds, with tuned depth
underneath for the committed player.

- Grow a Garden: buy seeds → plant → sell harvest. Surface-simple. Depth comes from weather,
  growth mutations, and sprinklers — and **mutations are the key to getting rich**, which is what
  drives the spend.
- Brainrot genre: buy a unit → it generates passive income → reinvest into better units.
- Adopt Me: play → earn → acquire pets → trade → repeat; depth from how progression, rarity, and
  social interaction layer together.

**Design rule for us:** the shallow loop hooks the new player in the first minute; the deep
systems give the committed player something to optimize and spend on. Never sacrifice the
30-second legibility for depth, and never ship depth so shallow there's nothing to master.

### The idle / AFK component
Idle income (your stuff accumulates while offline) gives players a reason to return without
demanding continuous grind. It is a retention lever disguised as a convenience. Build it in.

---

## 3. The first five minutes are a designed funnel

The opening minutes do three jobs: **comprehension** (player understands the objective),
**fast visible progress** (a dopamine hit of reward), and a **soft monetization setup** (a clear
choice that can later become a purchase) — without hard-selling. This is the operational
translation of "get D1 above 25%." If the player doesn't grasp the objective and feel progress
in the first session, they don't come back, and the algorithm buries the game.

---

## 4. Monetization: sell WITH the player, never AGAINST them

This is where Roblox diverges hardest from mobile free-to-play. Copying predatory mobile tactics
actively kills Roblox games because the audience **downvotes** monetization it dislikes, and
downvotes feed back into the discovery algorithm. Predatory monetization is a discovery penalty,
not just an ethics question.

**Forbidden (Roblox players punish these):**
- Energy timers / "wait 4 hours to play again" mechanics. Players take issue with their fun
  coming to a premature end.
- Pay-to-win that breaks competitive balance.
- Anything that interrupts the core fun.

**The four native tools:**
- **Game passes** — permanent one-time purchases. Best for VIP status, persistent abilities,
  exclusive areas, cosmetic skins. Run *multiple price tiers* (cheap entry + premium flagship) to
  capture different spender segments. Right price maximizes price × conversion, not the highest
  price tolerable.
- **Developer products** — consumable, repurchasable. The recurring-revenue engine. Currency
  packs, and especially **time-limited boosts** (2x earnings for 30 min) that create urgency.
  Works exceptionally well in progression-based games.
- **Premium Payouts** — you earn from Premium subscribers' *engagement time*, so it rewards
  exactly the retention behaviors we want. Maximize via daily rewards, streaks, long-term
  progression, social features.
- **Rewarded video ads** — opt-in. Player watches a short ad for a defined reward (extra life,
  boost, revive). Monetizes non-spenders without degrading their experience.

**What to sell, in priority order:** identity (cosmetics, status items) > convenience/time-saving
(progression accelerators — players pay to save time *once they already like the loop*) > access.
Cosmetics are the safest, highest-margin money and have zero balance impact.

---

## 5. The player-to-player trade economy is the deepest moat

This is the single biggest separator between a 3-month hit and a multi-year franchise. The
longest-lived games monetize *interaction between players*, not gameplay difficulty.

Adopt Me's longevity: **the player-to-player economy IS the product.** Years on, "people do not
log in to play Adopt Me, they log in to negotiate." Built on **real scarcity** by resisting the
temptation to dilute rare item value with constant re-releases.

The mechanism is **scarcity + social signaling**: rare items become identity markers, not just
collectibles. A trade economy is also self-reinforcing — it drives social interaction AND
manufactures infinite content for creators (trade showcases, rare-drop reveals) that fuels
discovery on YouTube and TikTok.

**Discipline test for us:** when a rare item gets hyped, DO NOT re-release it to juice short-term
numbers. That destroys its trade value and the economy. Mint rares carefully and permanently.

---

## 6. Acquisition is viral and creator-driven, by design

Roblox grows primarily through word-of-mouth and shared links — roughly a third of gaming content
on YouTube is Roblox content. Two reinforcing loops: a **content viral loop** (better/more content
over time) and a **social-network viral loop** (more people joining and playing together).

**Implication:** design for shareability and content-generation as a *core feature*. Rare-drop
moments, trade showcases, chaotic co-op, leaderboard drama, live competitive events — these exist
partly to give creators something to film. A 1-in-10,000 legendary catch is a YouTube thumbnail;
design for that screenshot moment.

---

## 7. Update cadence: weekly is the standard, run as a release calendar

Roblox punishes content staleness because shipping is cheap. **Weekly updates are ideal; monthly
is the bare minimum.** It is much harder to regain a lapsed user than to maintain an active one.

Elite teams (e.g. Big Games / Pet Sim 99) treat the game as a product with a release *calendar*,
not a game with occasional patches — scheduled events, seasonal content, limited-time items
creating urgency, and they measure everything. LiveOps discipline is what converts a launch spike
into a sustained DAU base. This is operational, not creative, and it's where most indie devs lose.

**Implication for our architecture:** every system should be built so new content (a new location,
a new event, a new seasonal rare) is a *droppable unit* that doesn't require touching the rest of
the game. (This is a major reason our world is built as discrete destinations — see the design docs.)

---

## 8. Social and identity systems drive engagement — not graphics

Counterintuitive but well-supported: **graphics are not a differentiator on Roblox, and chasing
fidelity is usually a mistake.**

- Nearly every top social/RP game uses deliberately simple **low-poly** art. Low-poly is a
  *performance strategy*: assets load faster and run smoother, which matters enormously because
  Roblox is **mobile-first** — the game must run well on phones to reach its audience.
  **Frame rate beats fidelity. A smooth simple game beats a laggy beautiful one every time.**
- What actually drives engagement: group hubs (shared spaces to meet and show progress),
  collaborative goals (lengthen sessions), social rewards (badges/cosmetics tied to community
  actions), public activity cues (visible progress that pulls others in). Shared spaces also
  accelerate trends — players copy what they see, turning the player base into a marketing engine.

**Where graphics DO earn their keep:** the **thumbnail and game icon** — the actual conversion
surface for discovery. Optimized thumbnails can lift impressions ~40%. Single clear focal point,
clear depiction of the core action. **Spend the art budget on the storefront, not the polygon count.**

---

## 9. Co-op: incentivized, never forced

Interacting with friends is a core engagement signal Roblox weights heavily. But forced grouping
frustrates solo players. The pattern: make co-op **strongly incentivized but optional** — content
soloable with top gear as a tense challenge, trivial with a party. Early "pack" enemies naturally
teach grouping. The social hub is where players find partners.

---

## 10. The genre opportunity (why our game's genre is the right bet)

Roblox has **publicly stated** (Incubator/Jumpstart program, 2026) that **RPG, strategy, and
shooter games are heavily underrepresented despite strong demand from older age groups**, and that
they will actively scout and *amplify* games filling these gaps with tailored promotion and
curation. This is platform-level distribution help for choosing an underserved genre.

**Trade-off we accept:** RPG/strategy is harder to build and balance than a steal-clone, and the
audience skews older (13+), shifting monetization toward depth over impulse. Our engineering
capability is a real edge on the systems complexity where most RPG attempts fail.

---

## The formula, assembled (the causal chain)

A loop **simple enough to grasp in 30 seconds** with enough **tuned depth to optimize for hundreds
of hours** → delivered through a **first-five-minutes funnel** (comprehension + visible progress +
soft purchase setup) → which drives **D1/D7/D30 retention** → which the **algorithm rewards with
free distribution** → amplified by a **trading/social economy built on real scarcity** that
simultaneously creates **player-to-player engagement** and an **endless supply of creator content**
→ monetized **with the player** through identity and convenience (never timers or pay-to-win) →
sustained by a **weekly LiveOps cadence run as a release calendar** → all rendered in **performant
low-poly** that runs smooth on a phone, with the real art investment in a **high-CTR thumbnail.**

**Retention is the hub. Every spoke exists to move D1/D7/D30.**

---

## Honest caveats (do not over-trust the research)

- **Dollar figures by genre** from marketing/SEO sources ("$5K–$50K/month for RPGs") are
  directional vibes, not audited data. Do not model against them. The CCU records, algorithm
  mechanics, Roblox's own monetization docs, and named-game case studies are solid; the dollar
  ranges are soft.
- **The formula describes necessary, not sufficient, conditions.** Steal a Brainrot followed every
  structural rule AND caught a specific Gen Alpha meme wave (Skibidi Toilet, Grimace Shake, "Fanum
  tax") that cannot be manufactured. The mechanics are learnable; the cultural timing is luck. The
  formula maximizes the odds of converting a lucky moment into a lasting franchise — it does not
  generate the moment.
