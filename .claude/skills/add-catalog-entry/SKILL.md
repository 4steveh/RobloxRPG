---
name: add-catalog-entry
description: Add a creature, fish, or equipment row to Wild World's data-driven catalogs (src/config/) using the correct builder template and schema, then validate via the test suite. Use when adding game content — a new huntable creature, a fishable fish, or a gear item.
disable-model-invocation: true
---

# Add a catalog entry

Content is **data-driven and self-validating**: each catalog builds a `rows` array through a `*Input`
builder, then `Catalog.luau` joins everything and runs `Validation.luau` at `require` time — a malformed
row **fails the require**. So adding content = append one well-formed row, then let the validator + tests
prove it. Author **structural fields only**: never transcribe stat numbers (damage/DR/pressure/drain are
generated from the §1 curves at consumption time) and treat any cash range as **illustrative** (economy
computes the authoritative payout in Step 6).

The rules the builders + `Validation.luau` enforce — get these right and the row will load:

- **Stable, unique, prefixed id.** Convention: `bayou_<thing>`, `weapon_<thing>`, etc. Duplicate ids error
  on load. Ids are join keys — never reuse or rename.
- **`destinationId`** (creatures/fish) must be a real `Ids.Destination` (e.g. `D.Bayou`). It is the home
  Destination (catalog keying + milestone-home lookup).
- **The Reward XOR (binding).** Common/Uncommon → a **cash** range. Rare-and-above → **rare fields**, which
  the builder turns into exactly one **artifact** reward and **no cash**. Ambiance creatures grant
  **nothing** (no cash, no rare). The builder asserts this — you supply `cash` *or* `rare`, never both.
- **`isMilestoneTarget`** marks the Destination's designated conquest target (one per loop).
- **Equipment `tierInput` is derived** from category (true only for weapon/armor/rod/reel) — never author
  it. **Cosmetics are balance-free** (no `accessGrant`, no tier slot). `monetizationRoles` defaults from
  category; only override per row where `EQUIPMENT_MASTER §4` differs.

## Templates (match the existing builder inputs exactly)

**Creature** → append to `rows` in `src/config/Creatures.luau` (`creature({ ... })`):
```lua
creature({
    id = "bayou_<name>",
    destinationId = D.Bayou,
    name = "Display Name",
    tier = 1,
    rarity = Ra.Common,                 -- Ra.Common .. Ra.Mythic
    behavior = B.passive,               -- B.passive|flees|aggressive|pack|ambush
    health = 40, damageToPlayer = 10, speed = 45,   -- 1–100 (0 for ambiance)
    minWeaponTierToKill = 1, minArmorTierToSurvive = 0,
    coop = Co.soloTopGear,              -- Co.soloTopGear|duo|party
    spawnLocation = "where it appears",
    conditions = { time = "daylight" }, -- optional SpawnConditions
    -- Common/Uncommon: a cash range. (OMIT for ambianceOnly; replace with `rare = rareFields(...)` for Rare+.)
    cash = { min = 20, max = 30 },
    -- isMilestoneTarget = true,        -- the destination's HUNTING conquest target
    -- ambianceOnly = true,             -- grants nothing; set health/damage 0, no cash, no rare
})
```

**Fish** → append to `rows` in `src/config/Fish.luau` (`fish({ ... })`):
```lua
fish({
    id = "bayou_<name>",
    destinationId = D.Bayou,
    name = "Display Name",
    tier = 1,
    rarity = Ra.Common,
    typicalWeightKg = { min = 0.2, max = 0.5 }, recordWeightKg = 0.8,
    fightDifficulty = 20,               -- 1–100
    minRodTier = 1, minReelTier = 1,
    waterType = W.pond,                 -- W.pond|river|lake|coastal|deepSea
    baitRequired = "worms",             -- optional
    cash = { min = 14, max = 20 },      -- Common/Uncommon; for Rare+ use `rare = rareFields(...)` instead
    -- isMilestoneTarget = true,
})
```

**Equipment** → append to `rows` in `src/config/Equipment.luau` (`item({ ... })`):
```lua
item({
    id = "weapon_<name>",
    name = "Display Name",
    category = C.weapon,                -- C.weapon|armor|rod|reel|bait|tackle|vehicle|mount|dog|tool|cosmetic
    tier = 2,
    availableAt = V.Outfitter,          -- V.Outfitter|TackleShop|BoatDealer|KennelAndStable|StarterLoadout
    cost = cash(3000),                  -- cash(n); a free starter is cash(0)
    tradeable = false,                  -- false → commodity path, true → artifact path (data-integrity RD1)
    -- monetizationRoles = {},          -- override only where EQUIPMENT_MASTER §4 differs from the default
    -- accessGrant = W.coastal,         -- vehicles that gate a water type; ACCESS, never a stat
    -- cosmeticOnly = true,             -- cosmetics only
    notes = "why it exists / what it gates.",
})
```

For a **Rare-and-above** creature/fish, drop `cash` and add `rare = rareFields(<1-in-N spawnRate>, "<the
intended content moment>")` (the local `rareFields` helper sets tradeable/displayable/NEVER-re-release).

## Verify

1. Type-check the edited file: `luau-analyze src/config/<File>.luau` (the PostToolUse hook also does this).
2. Run the suite: `luau tests/run.luau` — `Catalog.spec` loads the catalog, so a bad row fails here.
3. For the full Definition-of-Done gate: `./run-tests.sh`.

If a Rare-and-above row mints an artifact whose kind/disposition matters, also confirm `Validation.luau`'s
disposition + reward-XOR assertions still pass (they run on load). Don't touch `tests/negative/` to make
anything pass — those are meant to fail.
