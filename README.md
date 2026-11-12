# HEADCOUNT

> *"Stay with your group. Wait for headcount. Never, ever answer the whistle."*
> — Camp Hollow Pines rulebook, 1987

A story-mode horror game for Roblox. 1–6 players, about 20–30 minutes per night.

In the summer of 1987, Camp Hollow Pines closed overnight. Eleven campers and their counselor, Marcy Hale, vanished. Tonight your car breaks down at the camp gate. Your phones are dead. Then a whistle blows three times in the woods. Something in the camp is still taking headcount, and it wants the numbers to be right.

## What's in the game

- **Full story:** prologue, 6 chapters, a secret chapter and 3 endings (Escape, Counted, Secret).
- **The Twelfth:** a 12-stud faceless figure with red eyes. It stalks, kills the lights when it's near, hunts with pathfinding, gets faster with every page you find, and always comes back.
- **Flare-gun combat:** each hit stuns it for 2 seconds, 4 hits knock it down, and the finale is a boss fight where you burn the roster.
- **Every signature scare from the script:** the shack light, the tape that counts to twelve, the sighting that vanishes when you look away, the rise from the lake, the PA in Marcy's stolen voice, "Headcount."
- **The whole map is built from code:** road, gate, cabins, lake, dock, boathouse, mess hall, office on the hill, flagpole and a 750-tree forest. You don't have to build anything by hand.
- **Ready to earn:** 2 game passes, 2 developer products, 6 badges and saved stats are already wired up. You only paste in IDs.
- Works on PC, mobile and controller, with sprint and flashlight buttons on touch screens.

---

## 1. Play it in 2 minutes

1. Install **Roblox Studio** from <https://create.roblox.com>.
2. Double-click **`HEADCOUNT.rbxlx`** in this folder. It opens in Studio.
3. Press **F5** (Play). The camp builds itself in a second or two.
4. To test multiplayer, go to **Test → Clients and Servers**, choose 2 players and click **Start**.

Controls: **Shift** to run, **F** for the flashlight, **click** to fire a flare. On mobile, use the RUN and LIGHT buttons and tap to fire.

## 2. Publish it on Roblox

1. In Studio: **File → Publish to Roblox → Create new experience**.
   - Name: `HEADCOUNT [STORY]`
   - Genre: Horror
   - Devices: all
2. **File → Game Settings → Security**, then turn on **Enable Studio Access to API Services**. This is what saves the *Escapes* stat.
3. On <https://create.roblox.com/dashboard/creations>, open your experience:
   - **Places → Configure place → Server size:** 6 players.
   - **Audience → Maturity & Compliance:** fill in the questionnaire honestly (fear and jumpscares, no blood). Roblox requires it before the game can be public.
   - **Icon and Thumbnails:** see [section 5](#5-make-people-click).
4. In Studio: **File → Game Settings → Permissions → Public**, then publish again.

Every time you change the game, use **File → Publish to Roblox** again. Live servers pick up the update on their next restart.

## 3. Swap in real sounds (the biggest quality jump)

The game ships with built-in placeholder sounds so that nothing breaks. Real horror audio makes it about ten times scarier.

1. In Studio, open **Toolbox → Audio**.
2. Search for each sound below and pick one uploaded by **Roblox**. Those are free for every game.
3. Right-click the sound → **Copy Asset ID**.
4. Paste it into `src/ReplicatedStorage/Shared/Config.luau` as `"rbxassetid://123456"`.

| Config key | Search for | Why it matters |
|---|---|---|
| `Whistle` | whistle | The game's signature. Players learn to panic at it. |
| `Ambience` | night forest, crickets | Constant dread (loops) |
| `Heartbeat` | heartbeat | Gets louder as it gets closer (loops) |
| `Screech` | monster scream | Flare hits, knockdowns, catches |
| `Jumpscare` | jumpscare | When you get counted |
| `Radio` | radio static | Plays under every line Marcy says |
| `Sting` | horror sting | The tape and the first sighting |
| `Generator` | generator start | Mess hall power-up |

After you edit a file, rebuild the place (see [section 6](#6-change-the-game)), or edit the script straight inside Studio.

## 4. Make money

### Step 1: create the store items (about 10 minutes)

Open Creator Hub → your experience → **Monetization**:

| Item | Type | Config key | Suggested price |
|---|---|---|---|
| Survivor Kit: +2 starting flares, stronger flashlight | Pass | `GamePasses.SurvivorKit` | 149 R$ |
| VIP: gold flashlight beam, [VIP] chat tag | Pass | `GamePasses.VIP` | 249 R$ |
| Second Chance: instant revive after being counted | Developer Product | `Products.SecondChance` | 25 R$ |
| Flare Pack: +5 flares now | Developer Product | `Products.FlarePack` | 15 R$ |

Copy each ID into `Config.luau`, rebuild and republish. The in-game **SHOP** button, the **SECOND CHANCE** button on the "You were counted" screen and the receipt handling all work right away.

Also create 6 **badges** (Welcome, First Page, Knocked Down, Escaped, Counted, Secret Ending) and paste their IDs into `Config.Badges`. Badges make players come back to collect them all.

### Step 2: turn on the free income

- **Premium Payouts:** automatic. Roblox pays you for the time Premium members spend in your game.
- **Private servers:** Creator Hub → **Access → Private servers**. Friend groups love these for horror games; 50–100 R$ a month is typical.
- **Rewarded video ads:** if your experience is eligible, players can watch an ad instead of paying. Second Chance is the perfect spot for one. Check Creator Hub → **Monetization**.

### Step 3: cash out

You keep **70%** of every pass and product sale; Roblox keeps 30%. When you have enough earned Robux (the minimum has been 30,000), you can convert them to real money through **DevEx** at <https://create.roblox.com/dashboard/devex>. You must be 13 or older, have a verified email and complete ID verification. Check that page for the current rate and requirements.

### The honest part

Roblox pays you when people *play*, and its recommendation system promotes games that keep players: long sessions, players returning the next day, friends inviting friends. So:

1. Fix whatever makes players quit (check **Analytics → Retention** after launch).
2. Make an eye-catching icon and thumbnails.
3. Release updates often.

Don't sell power players need to win. Keep the store fair, because players rate fair games higher.

## 5. Make people click

**Title:** `HEADCOUNT [STORY]`

**Description** (ready to paste):

```
Summer, 1987. Eleven campers and their counselor vanished from Camp Hollow Pines overnight.

Tonight your car breaks down at the gate. Your phones are dead. And somewhere in the woods, a whistle blows three times.

- Find Marcy's 8 lost journal pages
- Fight back with flares. It hates fire.
- Don't let The Twelfth count you
- One secret ending. Can you find it?

Play solo or with up to 5 friends.

"Stay with your group. Wait for headcount. Never, ever answer the whistle."
```

**Icon prompt** (for any image generator, or as a brief for an artist):

> Roblox game icon, square. A tall, faceless black figure with two glowing red eyes stands behind a rusted summer-camp gate in a foggy pine forest at night. A silver whistle hangs on its chest. Bold red title "HEADCOUNT". High contrast, red and black palette, centered, readable at small size.

**Thumbnail ideas** (16:9, make 3 or more; Roblox rotates them):

1. A player shining a flashlight down the dock while red eyes rise out of the lake behind them.
2. Close-up of the roster on the flagpole: eleven names crossed out in red, "MARCY HAL..." half-written.
3. The group around the campfire while the figure stands at the far end of the path, watching.

To grab real screenshots in Studio, hide the HUD (**View → UI** toggle) and use **View → Screenshot**.

**Getting players in the first week**

- Record 15–30 second clips (the lake rise, the jumpscare, "Headcount.") and post them as TikTok / YouTube Shorts.
- Run a small ad campaign in Creator Hub → **Ads Manager** to get your first players. Start small and check what works.
- Make a Roblox group, and post update logs and "secret ending" hints there.
- Update every week for the first month: a new chapter, a new monster behavior, seasonal events.

## 6. Change the game

| File | What it controls |
|---|---|
| `src/ReplicatedStorage/Shared/Config.luau` | All the numbers: speeds, flares, timers, store IDs, sounds |
| `src/ReplicatedStorage/Shared/Story.luau` | Every line of dialogue, the page texts, the endings |
| `src/ServerScriptService/Server/MapBuilder.luau` | The map layout |
| `src/ServerScriptService/Server/Director.luau` | Story flow: chapters, scares, hunts, endings |
| `src/ServerScriptService/Server/Monster.luau` | The Twelfth's body and AI |
| `src/StarterPlayer/StarterPlayerScripts/Client/` | HUD, controls, sounds, camera effects |

After editing, rebuild the place file:

```bash
python tools/build_place.py
```

Or use [Rojo](https://rojo.space) for live sync between this folder and Studio. Install it, run `rojo serve`, and connect from the Rojo Studio plugin.

You can also decorate the camp with Toolbox models. MapBuilder rebuilds the `Camp` folder every round, so put your extra models in a different folder in Workspace.

## Project layout

```
default.project.json       Rojo project (also read by tools/build_place.py)
HEADCOUNT.rbxlx            Ready-to-open Studio place, built from src/
src/
  ReplicatedStorage/Shared/        Config + Story (shared by server and client)
  ServerScriptService/Server/      Director, MapBuilder, Monster, Flares, Monetization
  StarterPlayer/.../Client/        HUD and controls
tools/build_place.py       Builds HEADCOUNT.rbxlx without Rojo
```

## Ideas for updates

- A lobby with "party bus" elevators that teleport groups into private story servers.
- Chapter 7: the lake bottom.
- Cosmetic flashlight colors and flare trails (pure-cosmetic shop items sell well).
- A Halloween night with a second Twelfth.

## License

All rights reserved. The story, characters and code of HEADCOUNT © 2026 Muhammad Ali Khan. You may read the code to learn from it, but you may not publish copies of this game.
