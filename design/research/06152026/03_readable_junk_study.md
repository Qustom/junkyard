# Readable-Junk Study

*Research companion to the Technical Design Doc §9. How to make a salvage item's value, rarity, era, and origin-band legible at a glance while it lies on the ground in a top-down 2D extraction/life-sim.*

---

## 1. Why this matters for THE FAR YARD

In a top-down looter where you "pick up salvage/junk off the ground to extract and sell," the floor is the primary interface. A player scanning a cluttered junkyard tile must answer, in under a second and from a distance: *Is this worth grabbing? How rare is it? What band/era is it from?* Every convention below exists to compress those questions into a glance. The recurring lesson across the genre is that **no single channel carries the load** — color, beam, outline, shadow, size, icon shape, and sound stack redundantly so the message survives clutter, distance, low vision, and colorblindness.

---

## 2. The rarity color spectrum (the de facto standard)

Color-coded loot was popularized by **Diablo** (1996) and **Diablo II** (2000), whose designer borrowed the idea from the roguelike *Angband*. Diablo II used grey (inferior), white (common), blue (magic), yellow (rare), orange (unique), green (set). But the spectrum most games copy today is **World of Warcraft's** (2004):

| Tier | WoW color | Notes |
|---|---|---|
| Poor / junk | **Grey** | "Vendor trash" — literally achromatic, a blank slate |
| Common | **White** | Baseline, no hue |
| Uncommon | **Green** | Primary nature color, easy to read |
| Rare | **Blue** | Colorblind-safe, reads at distance |
| Epic | **Purple** | Rare in nature, signals specialness |
| Legendary | **Orange** | Hot, attention-grabbing, top of scale |

The progression is roughly **muted → saturated → "hot"**: low tiers are desaturated/cool, top tiers are warm and bright. **Borderlands** uses essentially the same scale — white → green → blue → purple → orange (legendary) — and reserves **magenta** for off-spectrum "E-Tech" gear that sits *outside* the normal ladder. **Apex Legends** compresses it to white → blue → purple → gold. **Path of Exile** keeps a deliberately small base set: white (Normal), blue (Magic), yellow (Rare), orange/brown (Unique).

**Takeaways for the Yard:**
- Adopt the grey→white→green→blue→purple→orange ladder. It is so internalized that players will read value correctly with *zero* tutorial.
- Keep the ladder short. PoE's four base rarities and Apex's four tiers prove that fewer, more distinct steps read better than a 7-step gradient where blue and purple blur.
- Use the "off-spectrum color" trick (Borderlands magenta) to mark a special axis. For the Yard, an off-ladder hue (e.g. cyan or magenta) is a natural way to flag **alien-band** salvage as categorically *other*, separate from the value ladder.

Sources: [TV Tropes – Color-Coded Item Tiers](https://tvtropes.org/pmwiki/pmwiki.php/Main/ColorCodedItemTiers); [Loot (video games) – Wikipedia](https://en.wikipedia.org/wiki/Loot_(video_games)); [Origins of Color Coded Loot – Aggronaut](https://aggronaut.com/2020/09/03/origins-of-color-coded-loot/); [How Color Theory Codifies Item Quality – Claire Fishman](https://medium.com/@ClaireFish/how-color-theory-codifies-item-quality-in-video-games-104d8118044); [Borderlands Rarity – Borderlands Wiki](https://borderlands.fandom.com/wiki/Rarity); [Apex Legends Loot Guide – Tom's Guide](https://www.tomsguide.com/us/apex-legends-loot-colors-guide,news-29450.html).

---

## 3. Glints, outlines, beams, and labels

Color alone fails when the item is small or buried in clutter. Genres solve this with **vertical light beams, outlines, sparkle/glint, and floating labels.**

- **Loot beams.** *Old School RuneScape* (via RuneLite) draws a colored vertical beam over highlighted items and items above a chosen price tier — a beam visible across the screen tells you "valuable thing here" before you can read it. **Path of Exile** does the same: its `PlayEffect` action draws "a coloured beam of light above an item," either temporarily as it drops (`Temp`) or permanently. PoE also writes a **minimap icon** (`MinimapIcon`) with selectable size/color/shape, so value reads even off-screen.
- **Outlines / highlight-on-keypress.** **Diablo IV** highlights all ground items, chests, and lootable corpses while you hold **Alt** — explicitly framed by Blizzard as a feature for "players with less than perfect vision." This is now an ARPG standard: a hold-to-reveal pass cuts through clutter without permanently cluttering the screen. Outlining a sprite is also a baseline pixel-art readability move regardless of loot.
- **Glint / sparkle.** Many games add a small animated sparkle to draw the eye to interactables. Minecraft's enchanted-item glint is the canonical "this is special" shimmer.
- **Floating labels.** Diablo and PoE drop a **text label** with a colored background/border at the item's feet. PoE's filter exposes `SetTextColor`, `SetBackgroundColor`, `SetBorderColor`, and `SetFontSize` (1–45) — letting more valuable items literally get **bigger, brighter labels** so the eye triages by size and contrast.

**Takeaways for the Yard:**
- Use a **graduated beam**: no beam for junk/common, a subtle beam from uncommon up, a tall bright beam for top tiers. Reserve the strongest beams for "you truly cannot miss this."
- Add a **hold-to-highlight** key (à la D4 Alt) as both a clutter-buster and an accessibility feature.
- For named/valuable salvage, scale **label size and contrast with value**, not just color.

Sources: [Loot beam – OSRS Wiki](https://oldschool.runescape.wiki/w/Loot_beam); [RuneLite update – ground item loot beams](https://x.com/runeliteclient/status/1417826582455111683); [PoE Item Filters – About (PlayEffect, MinimapIcon, Set*)](https://www.pathofexile.com/item-filter/about); [Diablo IV highlight interactables – TheGamer](https://www.thegamer.com/diablo-4-highlight-interactables-gear-items-settings/); [Hotkey to highlight loot – Diablo IV Forums](https://eu.forums.blizzard.com/en/d4/t/hotkey-to-highlight-loot/3624).

---

## 4. Drop shadows, silhouette, and grounding

A top-down sprite must read as *sitting on the ground*, not floating, and must separate cleanly from a busy junkyard floor.

- **Drop shadows ground the object.** A soft contact shadow under each item anchors it to the floor plane and gives depth cues. It also doubles as a separation device: the shadow + a subtle ambient occlusion ring tells the eye "discrete object here" even when the sprite's colors are close to the background. (PoE's own filter docs warn that "a loot filter cannot fix an unreadable image" — if "shadows and particles cover the ground, visual load should be reduced first." Grounding shadows must aid, not add to, the noise.)
- **Silhouette is the first thing read.** Shape-language theory: a well-designed silhouette triggers recognition before any internal detail — Mickey, Batman, and Sonic are identifiable by outline alone. For ground junk, this means each item type should have a **distinct, recognizable outline** so the player categorizes it (gear vs. bottle vs. circuit board) from the silhouette before color even registers.
- **Outlines for figure/ground.** Adding a 1–2px outline (dark or light, depending on background) is the standard pixel-art trick to lift a sprite off any background. Negative space inside the silhouette matters as much as the outline — over-detailing small sprites destroys readability.

**Takeaways for the Yard:**
- Give every ground item a **contact drop shadow** for grounding and figure/ground separation.
- Design item art **silhouette-first** — test each item as a black shape on grey; if you can't tell what it is, redesign before adding detail.
- Use a consistent **outline rule** (e.g. dark outline on light floors, rim-light on dark band areas) so junk never melts into the tile.

Sources: [Importance of Silhouette in Character Design – Big Red](https://bigredillustration.com/articles/importance-of-silhouette-in-character-design/); [Pixel Art Design for Game Dev – Alain Galvan](https://medium.com/@AlainGalvan/pixel-art-design-for-game-dev-32d22c83a296); [PoE2 loot filter visibility guide – JEU.VIDEO](https://jeu.video/en/guide/path-exile-2-loot-filter-settings).

---

## 5. Scale and size cues

Physical size on the ground is itself an information channel:

- **PoE filters scale label font size with value** (`SetFontSize` 1–45), and "strict" community filters such as **NeverSink's** use this plus markup and sound to make expensive gear visibly larger/louder while hiding low-value drops entirely. The principle: **importance maps to apparent size.**
- **Tarkov's grid inventory** ties size to a different meaning — physical footprint (a 1×1 bolt vs. a 4×2 rifle) — which communicates *carry cost* and value-density at a glance. A small item that's worth a lot (a graphics card, a key) is a deliberate readability/decision-making hook.

**Takeaways for the Yard:**
- Let **rarer or higher-value salvage occupy a slightly larger ground footprint and/or a larger label**, so value triages partly by size.
- Consider a **value-density** dimension (small-but-precious) for late-band alien tech to create "do I grab this over that bulky low-value scrap?" decisions, the way Tarkov's small high-value items do.

Sources: [PoE Item Filters – About (SetFontSize)](https://www.pathofexile.com/item-filter/about); [NeverSink-Filter – GitHub](https://github.com/NeverSinkDev/NeverSink-Filter); [Escape from Tarkov Menu UX Redesign – Markus](https://www.heiolenmarkus.com/blog/escape-from-tarkov-menu-ux-redesign).

---

## 6. Icon design for clutter

A junkyard is, by premise, cluttered. Icon design has to survive density and small size:

- **Fit a tight bounding box.** A common rule of thumb is 16×16 or 32×32 for 2D items; within that, **eliminate detail that doesn't aid recognition** — at small sizes you fight anti-aliasing vs. readability.
- **Shape over detail.** Read by silhouette; use distinct gross shapes per category so a screen full of icons still parses.
- **Tarkov as a cautionary scale.** Tarkov uses **photo-realistic, highly specific icons** in a tight grid; players rely on shape + grid-footprint + color tags to triage hundreds of items. The lesson: when icon detail is high, the **grid and consistent footprint** carry readability, not the art alone.
- **Reduce ambient load.** PoE's docs are explicit: avoid similar colors for adjacent meanings, and reduce on-ground visual noise before relying on highlighting.

**Takeaways for the Yard:**
- Build a **shape/category language**: each junk class (machine parts, glassware, electronics, organic/alien) gets a recognizable gross silhouette and a consistent palette family.
- Keep ground icons **readable at the smallest zoom** the camera ever uses; design at target resolution, not zoomed in.
- Don't over-decorate the floor tile art — clutter in the *background* is the enemy of clutter-on-the-ground readability.

Sources: [Pixel Art Design for Game Dev – Alain Galvan](https://medium.com/@AlainGalvan/pixel-art-design-for-game-dev-32d22c83a296); [Game 2D/3D Icon Design – RetroStyle Games](https://retrostylegames.com/outsourcing/game-2d-3d-icons-design/); [EfT item icons – Tarkov Wiki](https://escapefromtarkov.fandom.com/wiki/Category:Item_icons); [PoE2 loot filter guide – JEU.VIDEO](https://jeu.video/en/guide/path-exile-2-loot-filter-settings).

---

## 7. Ground vs. inventory representation

The same item must read in two contexts with different constraints:

- **Ground = low-information, high-speed.** It needs the *triage* layer: silhouette, drop shadow, rarity color (beam/outline/label), maybe a beam and minimap/HUD icon. The player decides grab/skip in a glance.
- **Inventory/shop = high-information, slow.** Here you can afford the full card: name, era, origin band, sale value, condition, and detailed art. **Borderlands** shows the full color-coded item card on selection; **Moonlighter** surfaces a sale-pricing layer (Cheap / Perfect / Expensive / Overpriced) where rarity gives a price multiplier — the readability target shifts from "should I grab it" to "what's it worth to sell."
- **Consistency is the bridge.** The rarity color and icon must be **identical** on the ground and in the inventory so the player links them instantly. PoE and Tarkov keep the icon constant across ground, inventory, and trade.

**Takeaways for the Yard:**
- On the **ground**, show only: silhouette + shadow + rarity color/beam (and band tint for alien). No text unless hovered or near.
- In the **inventory/shop**, show the full card: name, **band**, **era**, value, condition. Moonlighter's pricing-feedback model (a clear good/bad sale signal) is a strong fit for the "profit to pay debt" loop.
- Use the **same icon and rarity color in both views** so recognition transfers.

Sources: [Confused on item cards/color/rarity – Borderlands 2 (Steam)](https://steamcommunity.com/app/49520/discussions/0/2245553353031987993/); [Moonlighter Perfect Price Guide – GameRant](https://gamerant.com/moonlighter-all-item-prices/); [Moonlighter Perfect Prices – Steam Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=1757126124).

---

## 8. Encoding era and origin-band (the Yard-specific axes)

Rarity color is spoken for by the value ladder, so **era** and **origin band** (mundane → temporal → lateral → alien) need their *own* channels. Borrow the multi-channel principle:

- **Band = a secondary, off-ladder visual signature.** Borderlands' magenta "E-Tech" proves a reserved off-spectrum color can mark a whole category without disturbing the rarity ladder. Give each band a **distinct palette/material treatment and particle/glow signature**: mundane = neutral/desaturated, temporal = warm sepia/clockwork shimmer, lateral = chromatic-aberration/glitch tint, alien = an off-ladder hue (cyan/magenta) with an uncanny glow. The band should read from the **glow color and material**, leaving rarity to the beam/label color.
- **Era = silhouette + material + a small glyph.** Era can ride on art style (rusted vs. retro-futurist vs. organic) and an optional small **corner glyph/stamp** on the inventory card — keeping the ground read uncluttered.
- **Redundancy rule.** Because rarity, band, and era are three separate axes, lean hard on the colorblind-safe principle (next section): pair each with a **non-color cue** (shape, glow pattern, glyph, particle) so they don't collide as three competing colors.

**Takeaways for the Yard:**
- **Rarity → label/beam color** (the standard ladder).
- **Band → glow color + particle/material signature** (reserve an off-ladder hue for alien).
- **Era → art material + optional corner glyph** (mostly an inventory-card read).
- Never make all three purely color — that's three color systems fighting on one sprite.

Sources: [Borderlands Rarity (E-Tech magenta) – Borderlands Wiki](https://borderlands.fandom.com/wiki/Rarity); [TV Tropes – Color-Coded Item Tiers](https://tvtropes.org/pmwiki/pmwiki.php/Main/ColorCodedItemTiers).

---

## 9. Accessibility / colorblind-safe palettes

Roughly 1 in 12 men has some color-vision deficiency, and the standard rarity ladder has known weak spots (green/grey and the blue/purple boundary).

- **Blue and orange are the safest anchors** — they remain distinguishable across red-green deficiency, tritanopia, and achromatopsia. The standard ladder's blue (rare) and orange (legendary) are already strong; the **green (uncommon) vs. grey (junk)** pair and the **blue (rare) vs. purple (epic)** pair are the risky ones.
- **Never rely on color alone.** Guidance is consistent: encode rarity with **edge shape, number of stars/pips, pattern, or icons** in addition to color. PoE's filter supports exactly this — `MinimapIcon` offers 12 **shapes** (circle, diamond, hexagon, star, triangle, cross, moon, etc.) so rarity reads by *shape* independent of hue.
- **Test with simulators.** Use **Color Oracle**, **Sim Daltonism**, or Adobe's accessibility tools; Godot, Unity, and Unreal all support colorblind simulation passes. Offer in-game **colorblind modes/filters** as a settings option (now an expected feature).

**Takeaways for the Yard:**
- Pair every rarity color with a **redundant non-color cue** — a pip count, a border pattern, or a beam-shape — so the ladder survives without hue.
- Differentiate the **green/grey** and **blue/purple** steps with extra brightness/value contrast and a shape cue.
- Ship a **colorblind mode** and validate the full ladder + band glows in Color Oracle / Sim Daltonism before lock.

Sources: [Unlocking Colorblind Friendly Game Design – Chris Fairfield](https://chrisfairfield.com/unlocking-colorblind-friendly-game-design/); [How to make video games more accessible – Faris Durrani](https://medium.com/@farisdurrani/how-to-make-video-games-more-accessible-c33416dfb33d); [Colorblind-Friendly Palettes – Venngage](https://venngage.com/blog/color-blind-friendly-palette/); [Coloring for Colorblindness – David Nichols](https://davidmathlogic.com/colorblind/); [PoE Item Filters – About (MinimapIcon shapes)](https://www.pathofexile.com/item-filter/about).

---

## 10. How the reference games handle ground-loot readability (summary)

| Game | Ground read | Key technique |
|---|---|---|
| **Diablo II / IV** | Color-coded labels + hold-Alt highlight | Floating text labels; D4 Alt-hold reveals all loot (accessibility framing) |
| **Borderlands** | Rarity color + beam/glow on weapons | Standard ladder + off-ladder magenta E-Tech; full card on pickup |
| **Path of Exile** | Fully player-tunable filter | Beams (`PlayEffect`), minimap icons (12 shapes), font size, bg/border color, **per-item sounds**; hides junk entirely |
| **Escape from Tarkov** | Realistic icons in a grid | Shape + grid footprint + value-density; container-based discovery |
| **Moonlighter** | Simpler ground read; emphasis on **sell** | Rarity → price multiplier; Cheap/Perfect/Expensive/Overpriced sale feedback |

The throughline: **Diablo/Borderlands** push readability onto *the game's* art and labels; **PoE/Tarkov** push it onto *systems* (filters, grids, sound); **Moonlighter** shifts the readability burden from acquisition to *valuation*. The Yard, being extraction + shop sim, needs both halves: fast triage on the ground (Diablo/PoE) and a clear valuation read in the shop (Moonlighter).

---

## 11. Concrete recommendations for THE FAR YARD

1. **Adopt the standard rarity ladder** grey → white → green → blue → purple → orange. Keep it to ~5–6 distinct steps; don't add tiers that blur blue/purple. Use it for the **label/beam color** only.
2. **Multi-channel every read.** On the ground, stack: distinct **silhouette** + **contact drop shadow** + **rarity color** + (uncommon-and-up) **beam** that scales in height/brightness with value. Reserve the loudest beam for must-not-miss salvage.
3. **Give bands their own off-ladder signature.** Rarity owns the label/beam color; **band owns a glow color + particle/material treatment**, with an off-spectrum hue (cyan or magenta, à la Borderlands E-Tech) reserved for **alien**. This keeps value and origin from fighting.
4. **Encode era via material + an inventory-card glyph**, not a third ground color. Keep the ground read to two color systems max (rarity beam + band glow).
5. **Design icons silhouette-first** in a tight box (test as black-on-grey), with a per-category shape language so a cluttered floor still parses. Keep floor tile art quiet so it doesn't compete.
6. **Two-layer representation.** Ground = triage only (silhouette + shadow + color/beam). Inventory/shop = full card (name, band, era, value, condition). Use the **identical icon + rarity color** in both.
7. **Add a hold-to-highlight key** (D4 Alt-style) that outlines all ground salvage — a clutter-buster *and* an accessibility win.
8. **Lean into the sell-side read** (Moonlighter): clear price feedback (under/perfect/over) so the "profit to pay debt" loop is legible at the counter, not just on the floor.
9. **Make it colorblind-safe by construction.** Pair every rarity step with a **non-color cue** (pip count, border pattern, or beam/minimap shape — PoE-style). Boost value contrast on the risky green/grey and blue/purple steps. Ship a **colorblind mode** and validate in Color Oracle / Sim Daltonism before art lock.
10. **Optional audio tier.** PoE-style **distinct pickup/drop sounds for high-rarity or alien salvage** add a redundant, eyes-off channel — useful when scanning a cluttered yard.

---

## Sources

- [TV Tropes – Color-Coded Item Tiers](https://tvtropes.org/pmwiki/pmwiki.php/Main/ColorCodedItemTiers)
- [Loot (video games) – Wikipedia](https://en.wikipedia.org/wiki/Loot_(video_games))
- [Origins of Color Coded Loot – Tales of the Aggronaut](https://aggronaut.com/2020/09/03/origins-of-color-coded-loot/)
- [How Color Theory Helps Codify Item Quality in Video Games – Claire Fishman (Medium)](https://medium.com/@ClaireFish/how-color-theory-codifies-item-quality-in-video-games-104d8118044)
- [Rarity – Borderlands Wiki](https://borderlands.fandom.com/wiki/Rarity)
- [Apex Legends Loot Guide – Tom's Guide](https://www.tomsguide.com/us/apex-legends-loot-colors-guide,news-29450.html)
- [Loot beam – OSRS Wiki](https://oldschool.runescape.wiki/w/Loot_beam)
- [RuneLite ground item loot beams update – X/Twitter](https://x.com/runeliteclient/status/1417826582455111683)
- [Path of Exile – About Item Filters (PlayEffect, MinimapIcon, SetFontSize, sounds)](https://www.pathofexile.com/item-filter/about)
- [NeverSink-Filter – GitHub](https://github.com/NeverSinkDev/NeverSink-Filter)
- [PoE2 loot filter visibility guide – JEU.VIDEO](https://jeu.video/en/guide/path-exile-2-loot-filter-settings)
- [How To Highlight Items And Interactables In Diablo IV – TheGamer](https://www.thegamer.com/diablo-4-highlight-interactables-gear-items-settings/)
- [Hotkey to highlight loot? – Diablo IV Forums](https://eu.forums.blizzard.com/en/d4/t/hotkey-to-highlight-loot/3624)
- [Importance of Silhouette in Character Design – Big Red Illustration](https://bigredillustration.com/articles/importance-of-silhouette-in-character-design/)
- [Pixel Art Design for Game Development – Alain Galvan (Medium)](https://medium.com/@AlainGalvan/pixel-art-design-for-game-dev-32d22c83a296)
- [Game 2D/3D Icon Design Services – RetroStyle Games](https://retrostylegames.com/outsourcing/game-2d-3d-icons-design/)
- [Escape from Tarkov Menu UX Redesign – Hey I'm Markus](https://www.heiolenmarkus.com/blog/escape-from-tarkov-menu-ux-redesign)
- [Category: Item icons – Escape from Tarkov Wiki](https://escapefromtarkov.fandom.com/wiki/Category:Item_icons)
- [Moonlighter Perfect Price Guide – GameRant](https://gamerant.com/moonlighter-all-item-prices/)
- [Moonlighter Perfect Prices – Steam Community Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=1757126124)
- [Unlocking Colorblind Friendly Game Design – Chris Fairfield](https://chrisfairfield.com/unlocking-colorblind-friendly-game-design/)
- [How to make video games more accessible – Faris Durrani (Medium)](https://medium.com/@farisdurrani/how-to-make-video-games-more-accessible-c33416dfb33d)
- [Colorblind-Friendly Palettes: Why & How – Venngage](https://venngage.com/blog/color-blind-friendly-palette/)
- [Coloring for Colorblindness – David Nichols](https://davidmathlogic.com/colorblind/)
- [Gaming and color blindness – ForAllWe](https://www.forallwe.com/en/post/color-blindness-video-games-accessibility-filters)
