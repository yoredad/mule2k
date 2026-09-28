# M.U.L.E. 2K — Implementation Plan (v1.4 — Land Give/Lose Events)

Godot 4.6 (`C:\tools\Godot\Godot_v4.6-stable_win64.exe`) — Windows + Android (landscape, touch),
1 human vs 3 CPU, 12 rounds, 9x5 grid filling the view. This plan is the authoritative spec:
implement every table and formula exactly as written here.

---

## 0. User-Specified Rules (must implement exactly)

- 9x5 grid fills the view; center `(4,2)` = store; `(4,1)` + `(4,3)` = river plots (food production increased).
- Random mountain squares with 1/2/3 mountains; smithore production scales with mountain count (3 > 1).
- Production scales over time (per-round growth x1.08).
- Adjacent same-player squares producing the same unit buff production (+1, economies of scale).
- Empty (plains) squares give the best energy production.
- Store is NOT player-ownable. Include: per-good player auctions, Wampus hunt, mule shortage
  (2 smithore -> 1 new mule), food/energy spoilage, $60,000 colony win condition.
- Crystite: 3 hidden HIGH deposits with star expansion (medium orthogonally, low at orthogonal-2 and
  diagonally), discovered via the Assay Office; crystite is a full commodity traded in the auction
  phase at the end of each turn (5.3, 5.5, 7) and priced by supply/demand at HIGH levels so it is
  always the most expensive good; the recurring Meteorite Strike round event (8.1) destroys a mule
  and creates an EXTRA HIGH (4) deposit.
- All interaction via click/tap (mouse + touch). Menu overlays as needed.

## 1. Project Setup

- Engine: `C:\tools\Godot\Godot_v4.6-stable_win64.exe` (console variant for headless tests).
- `project.godot`: name "M.U.L.E. 2K"; main scene `res://scenes/main.tscn`; viewport 1280x720;
  stretch `canvas_items` + `expand`; `window/handheld/orientation=4` (sensor_landscape);
  `emulate_mouse_from_touch=true`; `emulate_touch_from_mouse=true`.
- Autoloads: `GameState`, `AudioManager`, `GameFlow`.
- `export_presets.cfg`: Windows Desktop + Android (gradle build, arm64-v8a/armeabi-v7a/x86_64, minSdk 24).
- Android setup (README): Editor -> Manage Export Templates -> install; Editor Settings -> Export ->
  Android -> Android SDK + JDK 17 paths; first export auto-generates `debug.keystore`.
- Headless tests: `godot --headless --path . -s res://tools/unit_test.gd` (pattern from cardwars2k).

## 2. Board & Terrain (`scripts/data/board.gd`)

- 45 cells, 0-indexed `(col,row)`; 9 cols x 5 rows.
- `(4,2)` = Store (not claimable). River = the vertical strip through the store column:
  `(4,0)`, `(4,1)`, `(4,3)`, `(4,4)` (fixed; all render identically in blue).
- 10 random mountain plots among the remaining 40 (not store/river). Each rolls a mountain count:
  1 (50%), 2 (35%), 3 (15%). Force at least one 1-mountain and one 3-mountain plot.
- All other plots = Plains. 44 claimable plots / 4 players = 11 plots each (claimed rounds 1-11).

### 2.1 Crystite deposits (hidden)

- 3 random plots (never the store, never river) get HIGH crystite (quality 3).
- Star expansion from each HIGH deposit (overlaps keep the highest quality; clamped to map bounds):

        . . L . .
        . L M L .
        L M *H* M L
        . L M L .
        . . L . .

  H = High (3); M = Medium (2, orthogonal distance 1); L = Low (1, orthogonal distance 2 AND all
  4 diagonals). Only in-bounds cells are set; a cell keeps the max of all contributions.
- All deposits are HIDDEN until assayed (`plot.crystite_assayed = false`). The Assay Office
  (5.6) reveals a plot's true quality permanently.
- Mounting a Crystite mule on an unassayed plot is allowed and is a gamble: production follows the
  hidden quality (0 if there is no deposit).
- The Meteorite Strike round event (8.1) upgrades a random plot to EXTRA HIGH (4) and can recur
  (max 3x per game, per statistics).

## 3. Production System (`scripts/data/economy.gd` — pure functions)

### 3.1 Base production per mule (EBPC)

| Plot type | Food | Energy | Smithore |
|---|---|---|---|
| Plains (empty) | 2 | 3 | 1 |
| River | 4 | 2 | 0 (mining not allowed) |
| 1 Mountain | 1 | 1 | 2 |
| 2 Mountains | 1 | 1 | 3 |
| 3 Mountains | 1 | 1 | 4 |

### 3.1b Crystite base production (by plot quality)

| Crystite quality | Crystite base |
|---|---|
| None (0) | 0 |
| Low (1) | 1 |
| Medium (2) | 2 |
| High (3) | 3 |
| Extra High (4, meteorite only) | 4 |

Crystite mining is NOT allowed on River (base 0). Crystite mules are non-energy mules
(they need 1 energy each, see 3.4).

Tenure: a crystite mule deployed 2+ rounds on a quality-0 (non-river) plot coaxes
the base to 1 (`tenure_base_bonus`). Changing the mule (refit/new) resets tenure
to 0 and the base drops back to 0. Terrain bans always hold.

### 3.2 Per-plot output this round

```
per_plot = clamp(base + eco_bonus + variance + seniority, 0, 8)
base      = EBPC[terrain][unit] (0 if type not allowed on terrain)
            OR crystite quality (3.1b) for Crystite mules
eco_bonus = number of orthogonally adjacent plots owned by SAME player
            producing the SAME unit type, capped at +2
variance  = -1 (16%), 0 (68%), +1 (16%)            (original "Standard" variance)
seniority = floor(mule turns deployed / 3)          (+1 per 3 turns on the plot)
```
Every deployed mule ages +1 turn each production round. Refitting a mule resets
its deployed counter (and bonus) to 0.

### 3.3 Player totals with time scaling

```
growth = 1 + 0.08 * (round - 1)        ; round 1: 1.0 ... round 12: 1.88
total[unit] = floor( sum(per_plot) * growth )
```

### 3.4 Energy check (before output is banked)

- `energy_requirement = number of non-Energy mules owned` (Energy mules need none).
  Food, Smithore AND Crystite mules all count.
- For each missing energy unit, one random mule of that player produces 0 this round.

### 3.5 Crystite output & storage

- Crystite output is computed exactly like other units (base from 3.1b + eco bonus + variance,
  then growth) and STORED in the player's inventory, capped at 50 units (like smithore, 4).
- Crystite is never consumed; it is traded in the auction phase (7) and scores at its current
  price (9).

## 4. Consumption, Spoilage, Shortage

| Item | Rule |
|---|---|
| Food requirement | Rounds 1-4: 3; 5-8: 4; 9-12: 5 (per player, per round; 0 after round 12) |
| Energy requirement | # non-Energy mules (per player) |
| Consumption | End of production: `food -= min(food, req)`; `energy -= min(energy, req)` |
| Food spoilage | After consumption: `food = floor(food / 2)` |
| Energy spoilage | After consumption: `energy = floor(energy * 3 / 4)` |
| Smithore spoilage | Storage capped at 50 units (excess lost) |
| Crystite | Stored, capped at 50 (like smithore); no spoilage; traded in the auction phase (7) |
| Food shortage | Owned food < requirement -> development actions reduced (section 6) |
| Energy shortage | Missing units -> random mules produce 0 (3.4) |

## 5. Store, Prices & Mule Economy

### 5.1 Initial state (Standard)

- Store stock: food 8, energy 8, smithore 8, mules 14.
- Initial prices: food $30, energy $25, smithore $50, mule $100.
- Each player: $1000 cash, 4 food, 2 energy, 0 smithore.

### 5.2 Price update (each round, after production & consumption)

```
ratio      = clamp(demand / supply, 0.25, 3.0)
             (zero demand -> 0.25; zero supply -> 3.0, so scarcity drives prices up)
new_price  = price * (0.25 + 0.75 * ratio)
```

| Good | Supply | Demand | Min $ | Max $ | Extra |
|---|---|---|---|---|---|
| Food | store_food + sum(players' food) | 4 * next-round food req | 30 | 265 | - |
| Energy | store_energy + sum(players' energy) | sum(players' energy req) + 4 | 25 | 265 | - |
| Smithore | store_smithore + sum(players' smithore) | mule_req (below) | 50 | 265 | add binomial noise -14..+14 in steps of 7 |
| Crystite | store_crystite + sum(players' crystite) | 8 (fixed home-world demand) | 150 | 500 | - |

`mule_req = min(8, min(4, unclaimed plots left) + plots without mule)`

Mule shortage: while the store has 0 mules, the smithore price doubles after the
normal update (clamped to the $265 max).

### 5.3 Store margins (buy = store pays players; sell = store charges players)

| Good | Store buys at | Store sells at |
|---|---|---|
| Food | price - $15 | buy + $35 (= price + $20) |
| Energy | price - $15 | buy + $35 (= price + $20) |
| Smithore | price | buy + $35 (= price + $35) |
| Crystite | price | buy + $35 (= price + $35) |

### 5.4 Mule economy

- Mule price (updated after auctions): `mule_price = floor_to_10(2 * smithore_price)`
  (e.g., smithore $49 -> mule $90; $50 -> $100).
- Outfit cost on purchase: Food $25, Energy $50, Smithore $75, Crystite $100.
  Total = mule_price + outfit.
- Mule shortage: store builds `floor(store_smithore / 2)` new mules at round end (consuming that
  smithore), stock capped at 14. Hoarded smithore -> mules run out -> prices skyrocket.
- Store never runs out of money.

### 5.5 Crystite price

- Supply/demand driven like every other good (5.2): `supply = store_crystite + sum(players' crystite)`,
  `demand = 8` (fixed home-world demand), base price $200, min $150, max $500, NO noise.
  Initial price $150 (store starts with 20 of every good, crystite included).
- Crystite is by design the MOST EXPENSIVE good: practical price maxima are food ~$75,
  energy ~$63, smithore ~$139 (incl. noise), vs. crystite $150-$500.

### 5.6 Assay Office

- Part of the development phase (section 6, step 3). Costs 1 development action.
- Flow: tap "Assay Office" -> tap ONE of YOUR OWNED plots -> tap "Return to Office" ->
  the plot's true crystite quality is revealed (High / Medium / Low / None) and stays
  revealed for the rest of the game (`plot.crystite_assayed = true`).
- Assaying a plot with no deposit reveals "None". Plots other players own cannot be assayed.

## 6. Round Flow (state machine in `scripts/game/game_flow.gd`)

12 rounds. Rounds 1-11: all phases; round 12: no land grant.

1. Round start: `round += 1`, banner.
2. Land Grant (R1-R11): each player picks 1 unclaimed plot. Order: worst net worth first
   (ties -> random). Human taps a highlighted free plot; CPU auto-picks after ~0.8s.
3. Development (per player): order best net worth first; REVERSED if store mules <= 7.
   AT THE START of each player's turn (before any actions), check for land give/lose events (8.5).
   Budget: `actions = max(2, 1 + int(5 * clamp(food / food_requirement, 0, 1)))` (2-6).
   Each action = one of: buy + mount 1 mule on one of your empty plots, OR use the
   Assay Office (5.6), OR gamble (costs 1 action, ends your turn immediately,
   grants `ceil(75 * (round / 2 + 1))`), OR pass. "End Turn" button to finish early.
4. Production: compute section 3 outputs. Roll & apply round event (8.1) BEFORE computing
   (rounds 1-11 only; round 12 has no event).
5. Consumption + spoilage (section 4). Crystite was already banked as inventory (3.5).
6. Price update (5.2) — includes crystite.
7. Auctions: order Smithore -> Food -> Energy -> Crystite (section 7).
8. Mule replenishment + mule price (5.4).
9. Status summary: net worth table, ranks update (section 9). Next round.
10. After round 12: End screen — colony rating, verdict, winner.

## 7. Auctions (touch-friendly listing)

Per good (order S -> F -> E -> C), overlay shows: your stock, requirement, surplus/deficit,
current store price, store stock. Crystite is traded exactly like smithore: store buy at price,
store sell at price + $35, player listings, and it is scored at its current price (9).
Players act in reverse rank order each good (lowest-ranked player first).

1. Sell to store: tap to sell surplus at the store buy price (store stock grows).
2. Buy from store: tap to buy at the store sell price while store stock lasts.
3. Player-player: each player may list up to N units at a chosen price within
   [store buy price, $999] (price stepper buttons; re-listing refunds the active
   listing so the price can be adjusted). CPU buyers accept your offer
   if listed <= their max bid (section 10.4), and each sale reports the buyer's
   color. If your price is too high, CPUs running a deficit answer with a lower
   counter-offer (a buy bid at their max, sized to fit their budget) that is
   remembered for the rest of the auction: listing again at a price equal to or
   below a remembered bid completes the sale at your listed price, and you can
   also accept a counter directly to sell at the bid price. CPU sell offers appear
   as buttons; accept if <= your max (your max = store sell - $5). Resolve offers
   round-robin; trades transfer cash+units instantly.

## 8. Events (`scripts/game/events.gd`)

### 8.1 Round event — EVERY round 1-11, applied to THIS round's production

An event occurs every round 1-11 (no event in round 12). Type is rolled from the weights below,
which are the EMPIRICAL frequencies recorded by SMITHORE.COM across 1,093 real M.U.L.E.
tournaments (11,778 events; source: http://www.smithore.com/eventstats.php). Each event has an
animated icon (`assets/events/`, AnimatedSprite2D via SpriteFrames .tres, built by
`tools/build_event_sprites.gd`):

| # | Event (icon) | Effect | Observed | Weight |
|---|---|---|---|---|
| 1 | Sunspot Activity | Energy production x2 this round | 1754 | 14.9% |
| 2 | Acid Rain Storm | Food x2, Energy x0.5 (floor) this round | 1828 | 15.5% |
| 3 | Pest Attack | One random FOOD plot produces 0 this round | 1672 | 14.2% |
| 4 | Planetquake | Mining x0.5 (floor) this round (smithore AND crystite) | 1745 | 14.8% |
| 5 | Meteorite Strike | Random plot (never the store) gains EXTRA HIGH (4) crystite; any mule there is destroyed | 1208 | 10.3% |
| 6 | Fire in Store | Store food/energy/smithore/crystite stock = 0 | 1243 | 10.6% |
| 7 | Pirate Attack | Every player loses ALL crystite | 1149 | 9.8% |
| 8 | Radiation | One random mule (any player) goes crazy and runs away | 1179 | 10.0% |

Observed maxima per game: Pirate 2x, Sunspot 3x, Acid Rain 4x, Pest 4x, Meteorite 3x, Fire 3x,
Planetquake 4x, Radiation 3x — events CAN repeat.

### 8.2 Player event — 25% at start of a player's development turn

Good events never for rank 1; bad events never for last 2 ranks.
- Gift: +3 food +2 energy; Gift: +2 smithore.
- Win/lose `x * m` where `m = 25 * (round/4 + 1)` (R1-3: $25, R4-7: $50, R8-11: $75, R12: $100), x = 2..8.

### 8.3 Wampus hunt

- Wampus sits on a random mountain plot. In development, "Hunt Wampus" button if actions remain:
  tap = 60% catch (cash reward, hunt ends) else it moves to another mountain; max 2 attempts.
- Reward: R1-3: $100, R4-7: $200, R8-11: $300, R12: $400. CPUs attempt with 40% chance.
- If caught, a new Wampus spawns on a random mountain at the start of the next player's
  development turn (each player always gets a hunt opportunity).

### 8.4 Meteorite Strike (round event, can recur)

- Rolled as a normal round event (8.1) in rounds 1-11; not a separate end-of-round check.
- Effect: a random plot (NEVER the store) is struck. Any mule on it is destroyed (owner loses it;
  the plot is emptied). The plot's crystite quality becomes EXTRA HIGH (4) — still hidden until
  assayed (2.1). If the struck plot already had a deposit, its quality is overwritten to 4.
- Statistics: 1,208 occurrences (10.3% of events); max 3 strikes in one game.

### 8.5 Land give/lose events — checked at the START of each player's turn

Separate from round events (8.1): rolled at the START of EACH PLAYER'S TURN (before that player's
development actions), NOT at the end of the round. Source (same smithore.com page): "When does a
Player receive or lose a Plot of Land" (Atari & C64) — 438 receives + 732 loses over 1,093
tournaments.

Per-month distribution of occurrences (% of that event's total; months #1-#12 — land events CAN
occur in round 12, unlike round events):

| Month | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Receive | 7.5 | 10.5 | 8.4 | 9.6 | 10.5 | 13.0 | 13.2 | 15.1 | 8.2 | 1.4 | 1.4 | 1.1 |
| Lose | 0.1 | 9.0 | 9.7 | 11.1 | 8.3 | 9.6 | 7.5 | 9.0 | 10.1 | 8.9 | 10.4 | 6.3 |

Per-turn chance = distribution[month] / 100 / 4 players * (event total / 1,093), so a full game
expects 0.40 receives and 0.67 loses (matching the observed rates). Receive and lose are
independent of each other and of the round event; both can trigger on the same turn.

- Lose a Plot of Land: targets ONLY the current leader (rank 1). If the leader owns no plots the
  event fizzles (nothing happens). A random plot of the leader is lost: any mule on it is
  destroyed (owner loses the mule), the plot reverts to unowned and is available for future land
  grants and development.
- Receive an Extra Plot: targets ONLY the current last-place player (rank 4). A random unowned
  plot (never the store) is granted; if no unclaimed plots remain the event fizzles.

Presentation: text banner only (smithore.com has no icon for these events). No score change.

## 9. Scoring (`economy.gd`)

```
score = cash * 1
      + sum over plots of (500 + outfit)   ; empty 500, food 525, energy 550, smithore 575, crystite 600
      + mules * 35
      + food * p_food + energy * p_energy + smithore * p_smithore + crystite * p_crystite
      (current store prices)
```
- Ranks: descending score, ties broken randomly (drives turn orders, section 6).
- Colony verdict: `colony_total = sum(4 player scores)`. Success iff colony_total >= $60,000.
  - Success -> player with highest score wins ("First Founder").
  - Failure -> EVERYONE loses ("sent home to work in a M.U.L.E. factory").
- Colony rating (end screen): `rating = clamp(round((colony_total - 10000) / 20000), 0, 6)`.

## 10. CPU AI — Exact Formulas (`scripts/game/ai_controller.gd`)

### 10.0 Constants

```
r      = current round (1..12)
n_rem  = 13 - r                      ; rounds the new plot will produce
G(n)   = n + 0.04 * n * (n - 1)      ; sum_{i=0..n-1} (1 + 0.08*i)
         G(12)=17.28  G(9)=11.88  G(6)=7.20  G(3)=3.24
p_u    = current store price of unit u (AI assumes prices stay flat)
p_c    = current crystite market price (5.2/5.5)
mule_price = floor_to_10(2 * smithore_price);  outfit: F=25, E=50, S=75, C=100
dist(x) = Manhattan distance from store (4,2)
noise   = U(-0.15, +0.15) * valuation        ; per decision, per CPU
```

### 10.1 Land Grant (rounds 1-11, worst rank picks first, ties random)

Crystite is hidden, so land valuation does NOT include crystite (CPUs never cheat).

```
shortage_bonus(F) = p_f * 2 * max(0, -proj_food_next)
shortage_bonus(E) = p_e * 2 * max(0, -proj_energy_next)
shortage_bonus(S) = 0
eco(x,u) = number of orthogonally adjacent plots owned by this CPU currently
           producing u, capped at 2

value(x,u) = p_u * (EBPC(x,u) + eco(x,u)) * G(13 - r) - (mule_price + outfit(u))
             + shortage_bonus(u)                  ; EBPC = 0 if unit not allowed
V(x) = max_u value(x,u) - (dist(x) - 1) + noise   ; dist penalty -1..-5
pick x* = argmax V(x) over unclaimed plots
```

Conflict: pick order = worst net worth first; a CPU whose chosen plot was already taken
re-picks argmax over remaining.

### 10.2 Projections (recomputed after every purchase; used in 10.1/10.3)

```
prod_units(u)   = floor( sum over owned plots of (EBPC + eco_actual) * growth(r) )
req_f_now       = food_req(r);  req_f_next = food_req(r+1)   ; 0 if r = 12
proj_food_next   = food - min(food, req_f_now) + prod(F)
                   - floor(proj_food_next/2) - req_f_next    ; 50% spoilage
proj_energy_next = energy - min(energy, E_req) + prod(E)
                   - floor(proj_energy_next/4) - E_req_after_purchase   ; 25% spoilage
E_req = # non-Energy mules (including the mule being bought; crystite mules count)
```

### 10.3 Development (each action; best rank first; reversed if store mules <= 7)

```
if proj_energy_next < E_req:   target = ENERGY     ; energy shortage always wins
elif owns an empty plot with assayed crystite quality >= 2: target = CRYSTITE
else:                          target = SMITHORE   ; default: prioritize smithore
target plot = argmax over own empty plots of (EBPC(x,target) + eco_future(x,target))
              + noise (small); ties -> lower dist(x), then random
              (eco_future = matching same-unit neighbors, capped at +2)
buy iff cash >= mule_price + outfit(target) (no reserve rule, no profit check)
if target == ENERGY but no energy mule can be bought (store out of mules, no
empty plot, or short on cash): refit the least productive owned non-energy mule
to energy instead (costs 2 actions + $50 outfit). If refit is impossible, pass.
repeat until: no actions left, or no affordable plot / refit
```

   Crystite is never a shortage target. Only assayed plots count for the crystite
   branch (CPUs never use hidden deposit info). Food shortage no longer drives
   CPU buys (the 2-action minimum keeps CPUs active through food shortages).

### 10.4 Auctions (per good, order S -> F -> E -> C; deficit/surplus computed AFTER consumption)

```
deficit(u) = max(0, req_u - owned_u)      ; req: F = req_f_next, E = E_req, S = 0
keep_level: F = req_f_next + 2,  E = E_req + 1,  S = 8
surplus(u) = max(0, owned_u - keep_level(u))
store_buy  = price the store pays;  store_sell = store_buy + 35
max_bid(u) = store_sell - 5                 ; never outbid the store
```

- If deficit(u) > 0: buy `min(deficit, store_stock, floor(cash/price))` from store;
  if store stock = 0, accept any player offer <= max_bid (cheapest first) up to deficit.
- Elif surplus(u) > 0:
  - sell to store if `store_buy >= min_sell` (F=35, E=30, S=55) — always sell all surplus.
  - else if store_stock == 0 and store_buy < min_sell: list `min(surplus, 2)` units at
    `list = store_buy + 10` (F/E) or `store_buy + 20` (S); accept counter-bids >= store_buy + 5.
- Neutral: no trades. Crystite uses the smithore rules with fixed values: deficit(C) = 0
  (never buy), keep_level(C) = 8, min_sell(C) = 150 (store_buy = p_c >= 150, so surplus is
  always sold), list at store_buy + 20; max_bid(C) = store_sell - 5.
- Mule shortage: while the store has 0 mules, every CPU sells its entire smithore
  stock to the store (no keep level, no min price), so the store can build mules.

### 10.5 Wampus

40% chance to attempt per development turn (active hunt + >=1 action remains); 50% success,
same reward as human.

### 10.6 Personality (the only CPU difference)

```
CPU "Homesteader": food urgency threshold 1.5; +10% weight on eco(F)
CPU "Miner":       shortage_bonus(S) = p_s * 1.5; +10% weight on smithore AND crystite value
CPU "Trader":      list prices at store_buy + 14 (F/E) / +24 (S); sells to store when
                   store_buy >= min_sell - 5
```

### 10.7 Crystite AI

```
assayed(x) = plot.crystite_assayed;   q(x) = plot.crystite_quality (only if assayed)
```

- Assay (during development, after the food/energy purchase decision): if any owned plot is
  unassayed, 35% chance per action to spend 1 action assaying. Target: an owned unassayed plot
  orthogonally adjacent to a revealed quality >= 2 deposit if any exists, else a random owned
  unassayed plot.
- Development (free-buy branch): additionally consider crystite mules:

```
value_c(x) = p_c * (q(x) + eco_future(x, CRYSTITE)) * G(13 - r) - (mule_price + 100)
for owned empty plots x with assayed q(x) >= 2
buy a crystite mule if max value_c(x) beats the best F/E/S profit AND value_c > 0
```

- Crystite mules raise E_req like other non-energy mules (10.2).
- Auction phase: crystite follows 10.4 (hoard 8, sell the rest; never buy). Land grant valuation
  never includes crystite (hidden).

## 11. UI / UX (`scripts/ui/`)

- Layout (1280x720): board (9x5 cells, ~120px, fits 1080x600) centered; top bar = round, phase
  banner, current prices + store stock (F/E/S/C); bottom strip = 4 player HUD
  columns (color, cash, food, energy, smithore, mules, score). Touch targets >= 48px.
- Colors: players green/blue/orange/purple. Terrain: plains tan, river blue, mountains gray with
  1-3 triangle peaks, store red with "$". Mule = colored box with unit letter (F/E/S/C).
- Assayed plots show a small quality gem: gray (None), green (Low), yellow (Medium), orange
  (High), red (Extra High). Unassayed plots show nothing.
- Overlays (modal Panels): MainMenu (Start / How to Play / Quit), Land Grant picker,
  Development panel, Auction panels, Event banner (auto-dismiss ~2.5s; shows the event's name and
  its animated icon via AnimatedSprite2D + SpriteFrames from `assets/events/`), Status Summary,
  End Screen. How-to-Play overlay summarizes sections 3-9.
- Development panel: plot list with Buy/Mount buttons for all 4 mule types (Crystite $100),
  an "Assay Office" button (then tap owned plot, then "Return to Office", then reveal popup),
  and an "End Turn" button.
- All interaction via Button signals (mouse + touch via emulation); no drag minigames.
- Simple beeps (purchase/produce/auction) via AudioStreamGenerator — optional polish (M7).

## 12. File Structure

```
mule2k/
  project.godot  export_presets.cfg  icon.svg  PLAN.md  README.md  .gitignore
  scenes/        main.tscn
  assets/events/  pirates/  sunspots/  acidrain/  pest/  meteorite/  fireinstore/
                  quake/  radiation/   (frame_XX.png + sprite_frames.tres per event;
                  source/ = original animated GIFs from smithore.com/_gfx/)
  scripts/
    autoload/    game_state.gd   audio_manager.gd
    data/        plot.gd  player.gd  mule.gd  board.gd  economy.gd
    game/        game_flow.gd  ai_controller.gd  events.gd
    ui/          board_view.gd  hud.gd   panels/(dev, auction, status, end, menu)
  tools/         unit_test.gd   game_sim_test.gd   build_event_sprites.gd
```

## 13. Milestones & Definition of Done

| # | Task | Verify |
|---|---|---|
| M1 | Scaffold + settings + main scene + board rendering (terrain gen incl. river/mountains) | F5 shows correct map |
| M2 | Data layer + economy.gd pure functions (incl. crystite deposits, crystite price, event statistics from smithore.com) + unit tests | tests green |
| M3 | Round/phase state machine (land grant -> development -> production -> events -> consumption) | manual playthrough |
| M4 | Store, price updates, mule shortage, auctions (human + store, incl. crystite), Assay Office + crystite mules | manual |
| M5 | CPU AI for every phase (incl. crystite assay/mule logic, 10.7) | watch 3 CPUs play sensibly |
| M6 | Status summary, final scoring, colony verdict, end screen, menu overlays, round events (8.1, incl. Meteorite Strike) with animated icons | full 12-round game |
| M7 | Polish: banners, beeps, Wampus, player events, How-to-Play | full game |
| M8 | Android export + landscape/touch QA; Windows export | both platforms |

**Definition of done:** unit_test.gd passes; game_sim_test.gd runs 12 rounds error-free with
prices in bounds; one manual 12-round game vs 3 CPUs completes; APK runs landscape with touch.
