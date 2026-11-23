# Crownfall (The Humbled King) — Asset Manifest

* **Engine Target:** Godot **4.7.2-stable** (`4.7.2.stable.official.ed1daf0bf`, Compatibility Renderer)
* **Logical Viewport:** `480x270` (Window override `1280x720`, Stretch Mode `viewport`, Default Texture Filter `Nearest`)
* **Art Policy:** 100% human-made CC0 Kenney assets in `res://assets/` (zero generative AI art, zero plain colored placeholder boxes).
* **Packed Tilemap Grid Reference:** Both `res://assets/tiles/tiny_town_tilemap_packed.png` and `res://assets/tiles/tiny_dungeon_tilemap_packed.png` are **192×176 px** = **12 columns (`0..11`) × 11 rows (`0..10`)** of 16×16 tiles, indexed row-major (`tile_index = row * 12 + col`, `0000`–`0131`).

---

## Asset Flags & Folder Findings (Review Before Pass 1)

> [!WARNING]
> Please review these items discovered during visual inspection of `assets/` before starting Pass 1:
>
> 1. **MISSING Heart Sprite in `assets/ui/` (and everywhere in `assets/`):** Neither Kenney *Tiny Town* nor *Tiny Dungeon* includes a heart icon.
>    - **Pass 1 Recommendation:** Render Player HP in `HUD.tscn` using a crisp pixel-styled `ProgressBar` paired with `res://assets/ui/tiny_dungeon_tile_0115.png` (Red Potion Flask) or `res://assets/ui/tiny_dungeon_tile_0127.png` (Red Vial), **or** drop a CC0 16×16 heart PNG into `assets/ui/` before Pass 1.
> 2. **Gold Coin Sprite Location (`assets/crops/` instead of `assets/ui/`):** There is no coin icon in `assets/ui/`. However, `res://assets/crops/tiny_town_tile_0093.png` (Tiny Town row 7, col 9) is a golden coin/token and works cleanly as the Gold Coin HUD and Shop icon without adding new files.
> 3. **Monster Shard & Blight Shard Icons:** No standalone raw crystal/gem sprite exists in `assets/ui/`.
>    - **Pass 1 Recommendation:** Use `res://assets/ui/tiny_dungeon_tile_0130.png` (cyan crystal wand) for **Monster Shard** and `res://assets/ui/tiny_dungeon_tile_0129.png` (purple crystal staff) for **Blight Shard** (clean alternative: `res://assets/ui/tiny_dungeon_tile_0128.png` blue vial & `res://assets/ui/tiny_dungeon_tile_0126.png` green vial).
> 4. **`assets/crops/` Contains Town Props/Tools, Not Multi-Stage Wheat Sprites:** The 6 files currently in `assets/crops/` are `tiny_town_tile_0092.png` (well roof), `0093.png` (gold coin), `0094.png` (beehive / golden wheat-sheaf mound), `0095.png` (archery target), `0115.png` (pickaxe), and `0116.png` (pitchfork). Actual tilled dirt (`0025.png`, `0041.png`), green sprouts (`0017.png`), and golden bush/crop (`0027.png`) reside in `assets/tiles/`, so Section 5 composes 100% real Kenney crop stages from `assets/tiles/` + `assets/crops/tiny_town_tile_0094.png`.
> 5. **Tools in `assets/characters/` & Bat in `assets/ui/`:** `assets/characters/tiny_town_tile_0117.png`–`0119.png` (key, bow, arrow) and `0127.png`–`0131.png` (axe, shovel, scythe/hoe, empty bucket, water bucket) are farming/equipment props rather than character bodies, while `res://assets/ui/tiny_dungeon_tile_0120.png` is the orange Bat sprite.
> 6. **Harvest Flask Drink SFX:** `assets/audio/` contains no liquid gulp sound; mapped to `res://assets/audio/handleSmallLeather2.ogg` (flask uncork/rustle) as the cleanest fit.

---

## 1. TileSets & Terrain Atlas Coordinates (`TileMapLayer`)

### 1.1 `KingdomHub.tscn` — *Tiny Town*
* **Atlas Texture:** `res://assets/tiles/tiny_town_tilemap_packed.png` (16×16 tile size, 12×11 grid)

| Terrain / Prop Category | Atlas Coords `(col, row)` | Tile Index (`0000`–`0131`) | Usage in `KingdomHub.tscn` |
| :--- | :--- | :--- | :--- |
| **Grass Ground** | `(0,0)`, `(1,0)`, `(2,0)` | `0000`, `0001`, `0002` | Base meadow, tufted grass, flowered grass |
| **Farm Dirt 9-Slice** | `(0..2, 1..3)` | `0012`–`0014`, `0024`–`0026`, `0036`–`0038` | Farm zone ground & tilled patch border (`(1,2)` / `0025` is soil center) |
| **Dirt Paths** | `(3..6, 3)` | `0039`–`0042` | Connecting paths between Hall, Farm, Forge, Apothecary |
| **Cobblestone Main Plaza** | `(0..2, 8..10)` | `0096`–`0098`, `0108`–`0110`, `0120`–`0122` | Central hub plaza around player spawn |
| **Stepping Stones** | `(7,3)` | `0043` | Decorative path transitions on grass |
| **Tall Pines (Perimeter)** | `(4,0)`+`(4,1)` (Green), `(3,0)`+`(3,1)` (Autumn) | `0004`+`0016`, `0003`+`0015` | Village border trees with collision |
| **Dense Forest 3×3** | `(6..8, 0..2)` (Green), `(9..11, 0..2)` (Autumn) | `0006`–`0008`..`0032`, `0009`–`0011`..`0035` | Outer forest framing around Kingdom Hub |
| **Foliage Accents** | `(5,0)` bush, `(5,2)` mushrooms | `0005`, `0029` | Village edge & Apothecary accent props |
| **North Gate & Castle Wall** | `(3..6, 8)`, `(3..4, 9..10)`, `(5..6, 10)` | `0099`–`0102`, `0111`–`0112`, `0123`–`0126` | Northern Gate transition to `WildFrontier.tscn` |
| **Wooden Fences** | `(8..11, 3..5)`, `(8..10, 6)` | `0044`–`0047`, `0056`, `0058`–`0059`, `0068`–`0071`, `0080`–`0082` | Farm perimeter & ruined plot borders |
| **Village Props** | `(11,6)` sign, `(8,7..8)` well, `(9,4)` cart, `(10,8)` log, `(11,8)` pot | `0083`, `0092`+`0104`, `0057`, `0106`, `0107` | Landmarks and atmospheric props |

### 1.2 `WildFrontier.tscn` & `BossArena.tscn` — *Tiny Dungeon*
* **Atlas Texture:** `res://assets/tiles/tiny_dungeon_tilemap_packed.png` (16×16 tile size, 12×11 grid)

| Terrain / Prop Category | Atlas Coords `(col, row)` | Tile Index (`0000`–`0131`) | Usage in `WildFrontier.tscn` & `BossArena.tscn` |
| :--- | :--- | :--- | :--- |
| **Frontier Ground** | `(0..5, 4)` | `0048`–`0053` | Sandy/earth frontier clearings & paths |
| **Stone Pavers & Arena Floor** | `(6,3)`, `(0..3, 0)`, `(0,1)`, `(0,2)` | `0042`, `0000`–`0003`, `0012`, `0024` | Boss arena stone tiles, South/Boss gate thresholds, rubble |
| **Boundary Stone Walls** | `(1..3, 1..2)`, `(4,3)`, `(9..11, 4)` | `0013`–`0015`, `0025`–`0027`, `0040`, `0057`–`0059` | Perimeter walls & ricochet boundaries |
| **Ricochet Cover Pillars** | `(6,0)`, `(6,1)`, `(6,2)` | `0006`, `0018`, `0030` | Multi-tile vertical stone pillars in `WildFrontier` & `BossArena` |
| **Sealed / Open Boss Gate** | `(10..11, 3)` (sealed), `(10..11, 1)` (open) | `0046`–`0047`, `0022`–`0023` | Northern Boss Gate leading to `BossArena.tscn` |
| **Royal Banner & Arena Props** | `(5,2)` banner, `(4..6, 6)` iron bars, `(5,3)` spikes | `0029`, `0076`–`0078`, `0041` | Boss throne-room framing & hazard accents |

### 1.3 Standalone Interactive Prop Sprites (`res://assets/tiles/`)

| Interactive Object | Primary Sprite Path | Alternate / Open / Accent Path |
| :--- | :--- | :--- |
| **Sleep Bed (`SleepBed.tscn`)** | `res://assets/tiles/tiny_dungeon_tile_0066.png` | `res://assets/tiles/tiny_dungeon_tile_0072.png` (side table) |
| **Shipping Crate (`ShippingCrate.tscn`)** | `res://assets/tiles/tiny_dungeon_tile_0089.png` | `res://assets/tiles/tiny_dungeon_tile_0091.png` (open chest) |
| **Forge Anvil Prop** | `res://assets/tiles/tiny_dungeon_tile_0074.png` | `res://assets/tiles/tiny_town_tile_0106.png` (timber log) |
| **Apothecary Barrel & Pot** | `res://assets/tiles/tiny_dungeon_tile_0082.png` | `res://assets/tiles/tiny_town_tile_0107.png` (clay pot) |
| **Royal Banner Prop** | `res://assets/tiles/tiny_dungeon_tile_0029.png` | — |

---

## 2. Character Sprites (2D Rig Base Sprites)

Each character scene uses a `CharacterBody2D` → `VisualPivot` → `BodySprite` (`Sprite2D`) rig with procedural `AnimationPlayer`/Tween walk-bob, squash-and-stretch, `flip_h`, and white hit-flash.

| Role | Character Name | Sprite Path | Visual Rig Notes |
| :--- | :--- | :--- | :--- |
| **Player** | **Humbled King** | `res://assets/characters/tiny_dungeon_tile_0098.png` | Unhelmeted noble/king in steel armor; attaches `WeaponSprite` + `ShieldSprite` from `assets/ui/` |
| **Villager 1 (Farmstead)** | **Old Pip** | `res://assets/characters/tiny_dungeon_tile_0100.png` | Grey-haired elder villager; optional held pitchfork `res://assets/crops/tiny_town_tile_0116.png` |
| **Villager 2 (Forge)** | **Gideon** | `res://assets/characters/tiny_dungeon_tile_0086.png` | Bearded bald blacksmith in leather apron; optional held hammer `res://assets/ui/tiny_dungeon_tile_0117.png` |
| **Villager 3 (Apothecary)** | **Astrid** | `res://assets/characters/tiny_dungeon_tile_0099.png` | Villager in plum/purple dress; optional held flask `res://assets/ui/tiny_dungeon_tile_0114.png` |
| **Villager 4 (Gatehouse)** | **Captain Vance** | `res://assets/characters/tiny_dungeon_tile_0097.png` | Open-visor knight in steel armor (alt full-helm: `res://assets/characters/tiny_dungeon_tile_0096.png`) |
| **Day Enemy (Melee)** | **Forest Boar** | `res://assets/characters/tiny_dungeon_tile_0123.png` | Brown charging beast; charge telegraph dust + stun stars |
| **Day Enemy (Ranged)** | **Blight Imp** | `res://assets/characters/tiny_dungeon_tile_0110.png` | Red horned demon/imp; fires bounceable fireball orbs |
| **Night Enemy (Floater)** | **Night Wraith** | `res://assets/characters/tiny_dungeon_tile_0121.png` | Floating white ghost/wraith; translucent cyan/violet modulate |
| **Final Boss** | **The Usurper** | `res://assets/characters/tiny_dungeon_tile_0111.png` | Hooded dark warlock with red eyes, scaled ~`1.35x` holding `res://assets/ui/tiny_dungeon_tile_0129.png` (alt mage: `0084.png`) |

---

## 3. Equipment, Currency & UI Icons

| Item / UI Element | Sprite Path | Status / Notes |
| :--- | :--- | :--- |
| **Sword Lv. 1 (Rusty Sword)** | `res://assets/ui/tiny_dungeon_tile_0103.png` | Starter sword attached to `Player` weapon pivot |
| **Sword Lv. 2 (Iron Longsword)** | `res://assets/ui/tiny_dungeon_tile_0104.png` | Gideon Forge upgrade 1 (alt broadsword: `0106.png`) |
| **Sword Lv. 3 (Royal Greatsword)** | `res://assets/ui/tiny_dungeon_tile_0107.png` | Gideon Forge upgrade 2 (golden hilt greatsword) |
| **Cracked Royal Shield (Starter)** | `res://assets/ui/tiny_dungeon_tile_0101.png` | Starter Bounce Shield attached to `Player` shield pivot |
| **Explosive Bounce Shield / Royal Armor** | `res://assets/ui/tiny_dungeon_tile_0102.png` | Steel kite shield for Vance upgrade & Forge Armor icon |
| **Harvest Flask (+50 HP)** | `res://assets/ui/tiny_dungeon_tile_0115.png` | Red round potion flask (HUD + Apothecary icon) |
| **Gold Coin** | `res://assets/crops/tiny_town_tile_0093.png` | **Flagged:** stored in `assets/crops/` (genuine gold coin/token) |
| **Monster Shard** | `res://assets/ui/tiny_dungeon_tile_0130.png` | **Flagged:** cyan crystal wand stand-in (alt: `tiny_dungeon_tile_0128.png` blue vial) |
| **Blight Shard** | `res://assets/ui/tiny_dungeon_tile_0129.png` | **Flagged:** purple crystal staff stand-in (alt: `tiny_dungeon_tile_0126.png` green vial) |
| **Hearts / HP Indicator** | *None in `assets/`* (`res://assets/ui/tiny_dungeon_tile_0115.png` fallback) | **Flagged:** no heart sprite exists; pair HP `ProgressBar` with `0115.png` or `0127.png` (or add CC0 heart PNG) |
| **UI Focus & Combat VFX Helpers** | `res://assets/ui/tiny_dungeon_tile_0060.png`, `0061.png`, `0062.png` | Target reticle (`0060`), focus frame (`0061`), slash sparks (`0062`) |
| **Farming Tool Icons (Optional)** | `res://assets/characters/tiny_town_tile_0128.png`, `0129.png`, `0131.png` | Shovel (`0128`), Scythe (`0129`), Water Bucket (`0131`), Pitchfork (`assets/crops/tiny_town_tile_0116.png`) |

---

## 4. Multi-Tile Building Recipes (`assets/buildings/` + Props)

Each building is assembled in `BuildingPlot.tscn` (or `KingdomHub.tscn` for `Ruined Hall`) as a grid of 16×16 `Sprite2D` tiles with `StaticBody2D` collision. Every filename below exists in `res://assets/buildings/tiny_town_tile_0048.png`..`0091.png` unless explicitly prefixed with `assets/tiles/` or `assets/crops/`.

### 4.0 Ruined State Template (All 4 Ruined Plots)
* **Fence / Debris Perimeter:** `res://assets/buildings/tiny_town_tile_0068.png` (broken corner), `0080.png` (post L), `0082.png` (post R)
* **Rubble & Timber:** `res://assets/tiles/tiny_dungeon_tile_0024.png` (stone rubble), `res://assets/tiles/tiny_town_tile_0106.png` (fallen timber log)
* **Repair Signpost:** `res://assets/buildings/tiny_town_tile_0083.png` + world-space cost `Label`

### 4.1 Ruined Hall (King's Home — Houses `SleepBed.tscn`, 4×3 = 64×48 px)
| Row | Col 0 | Col 1 | Col 2 | Col 3 |
| :--- | :--- | :--- | :--- | :--- |
| **Row 0 (Slate Roof Top)** | `assets/buildings/tiny_town_tile_0048.png` | `assets/buildings/tiny_town_tile_0049.png` | `assets/buildings/tiny_town_tile_0049.png` | `assets/buildings/tiny_town_tile_0050.png` |
| **Row 1 (Slate Roof Eaves)** | `assets/buildings/tiny_town_tile_0060.png` | `assets/buildings/tiny_town_tile_0061.png` | `assets/buildings/tiny_town_tile_0061.png` | `assets/buildings/tiny_town_tile_0062.png` |
| **Row 2 (Stone Walls & Doors)** | `assets/buildings/tiny_town_tile_0088.png` | `assets/buildings/tiny_town_tile_0090.png` | `assets/buildings/tiny_town_tile_0091.png` | `assets/buildings/tiny_town_tile_0088.png` |

* **Hall Props:** `res://assets/tiles/tiny_dungeon_tile_0029.png` (royal banner) & `res://assets/tiles/tiny_dungeon_tile_0066.png` (`SleepBed.tscn` placed beside/inside doorway).

### 4.2 Ruin 1: Royal Farmstead (`farmstead` — Old Pip, 3×3 = 48×48 px)
| Row | Col 0 | Col 1 | Col 2 |
| :--- | :--- | :--- | :--- |
| **Row 0 (Terracotta Roof Top)** | `assets/buildings/tiny_town_tile_0052.png` | `assets/buildings/tiny_town_tile_0053.png` | `assets/buildings/tiny_town_tile_0054.png` |
| **Row 1 (Terracotta Roof Eaves)** | `assets/buildings/tiny_town_tile_0064.png` | `assets/buildings/tiny_town_tile_0065.png` | `assets/buildings/tiny_town_tile_0066.png` |
| **Row 2 (Tan Plaster Wall & Door)** | `assets/buildings/tiny_town_tile_0084.png` | `assets/buildings/tiny_town_tile_0085.png` | `assets/buildings/tiny_town_tile_0084.png` |

* **Farmstead Props:** Wooden cart `res://assets/buildings/tiny_town_tile_0057.png`, fence posts `0080.png`–`0082.png`, golden sheaf/beehive `res://assets/crops/tiny_town_tile_0094.png`.

### 4.3 Ruin 2: The Forge (`forge` — Gideon, 3×3 = 48×48 px)
| Row | Col 0 | Col 1 | Col 2 |
| :--- | :--- | :--- | :--- |
| **Row 0 (Slate Chimney Roof)** | `assets/buildings/tiny_town_tile_0048.png` | `assets/buildings/tiny_town_tile_0051.png` | `assets/buildings/tiny_town_tile_0050.png` |
| **Row 1 (Slate Roof Eaves)** | `assets/buildings/tiny_town_tile_0060.png` | `assets/buildings/tiny_town_tile_0061.png` | `assets/buildings/tiny_town_tile_0062.png` |
| **Row 2 (Stone Wall & Door)** | `assets/buildings/tiny_town_tile_0076.png` | `assets/buildings/tiny_town_tile_0089.png` | `assets/buildings/tiny_town_tile_0088.png` |

* **Forge Props:** Anvil `res://assets/tiles/tiny_dungeon_tile_0074.png`, timber log `res://assets/tiles/tiny_town_tile_0106.png`, plus `CPUParticles2D` chimney smoke & forge sparks.

### 4.4 Ruin 3: The Apothecary (`apothecary` — Astrid, 3×3 = 48×48 px)
| Row | Col 0 | Col 1 | Col 2 |
| :--- | :--- | :--- | :--- |
| **Row 0 (Terracotta Dormer Top)** | `assets/buildings/tiny_town_tile_0052.png` | `assets/buildings/tiny_town_tile_0055.png` | `assets/buildings/tiny_town_tile_0054.png` |
| **Row 1 (Peaked Gable Eaves)** | `assets/buildings/tiny_town_tile_0064.png` | `assets/buildings/tiny_town_tile_0067.png` | `assets/buildings/tiny_town_tile_0066.png` |
| **Row 2 (Stone Windows & Door)** | `assets/buildings/tiny_town_tile_0088.png` | `assets/buildings/tiny_town_tile_0089.png` | `assets/buildings/tiny_town_tile_0088.png` |

* **Apothecary Props:** Clay pot `res://assets/tiles/tiny_town_tile_0107.png`, mushrooms `res://assets/tiles/tiny_town_tile_0029.png`, barrel `res://assets/tiles/tiny_dungeon_tile_0082.png`.

### 4.5 Ruin 4: The Gatehouse (`gatehouse` — Captain Vance, 4×3 = 64×48 px)
| Row | Col 0 | Col 1 | Col 2 | Col 3 |
| :--- | :--- | :--- | :--- | :--- |
| **Row 0 (Castle Battlements)** | `assets/tiles/tiny_town_tile_0099.png` | `assets/tiles/tiny_town_tile_0100.png` | `assets/tiles/tiny_town_tile_0100.png` | `assets/tiles/tiny_town_tile_0101.png` |
| **Row 1 (Portcullis Arch)** | `assets/tiles/tiny_town_tile_0126.png` | `assets/tiles/tiny_town_tile_0111.png` | `assets/tiles/tiny_town_tile_0112.png` | `assets/tiles/tiny_town_tile_0126.png` |
| **Row 2 (Arch Base & Arrow Slits)** | `assets/tiles/tiny_town_tile_0125.png` | `assets/tiles/tiny_town_tile_0123.png` | `assets/tiles/tiny_town_tile_0124.png` | `assets/tiles/tiny_town_tile_0125.png` |

* **Gatehouse Props:** Archery target `res://assets/crops/tiny_town_tile_0095.png`.

---

## 5. Crop Growth Stage Tiles (`SoilPlot.tscn`)

Because `assets/crops/` holds town props/tools rather than multi-stage wheat sheets, `SoilPlot.tscn` layers a soil base `Sprite2D` and an overlay crop `Sprite2D` using verified Kenney tiles:

| Crop State / Stage | Base Soil Sprite | Crop Overlay Sprite | Visual / Tint Notes |
| :--- | :--- | :--- | :--- |
| **Empty (Dry)** | `res://assets/tiles/tiny_town_tile_0025.png` | *None* | `Color(1, 1, 1, 1)` |
| **Watered Soil (Any Stage)** | `res://assets/tiles/tiny_town_tile_0025.png` | *(Keep stage overlay)* | Darkened wet-soil tint `Color(0.62, 0.48, 0.38, 1.0)` |
| **Stage 0 (Planted Seeds)** | `res://assets/tiles/tiny_town_tile_0041.png` | *None* | Speckled seeded dirt (subtle gold tint for Golden Wheat) |
| **Stage 1 (Sprout — Sunwheat Night 1)** | `res://assets/tiles/tiny_town_tile_0025.png` | `res://assets/tiles/tiny_town_tile_0017.png` | Twin green sprouts |
| **Stage 2 (Mature Sunwheat — Night 2)** | `res://assets/tiles/tiny_town_tile_0025.png` | `res://assets/tiles/tiny_town_tile_0027.png` | Warm amber/golden plant + ready bob |
| **Mature Golden Wheat (1-Night Grow)** | `res://assets/tiles/tiny_town_tile_0025.png` | `res://assets/crops/tiny_town_tile_0094.png` | Rich golden wheat sheaf mound + gold sparkle `CPUParticles2D` |
| **HUD / Inventory Crop Icon** | — | `res://assets/crops/tiny_town_tile_0094.png` | Used beside `crops_count` / `gold_crops_count` |

---

## 6. Audio SFX Mappings (`AudioManager.gd` — `res://assets/audio/*.ogg`)

All 51 files in `assets/audio/` are Kenney *RPG Audio* `.ogg` clips:

| Game Event | Assigned `.ogg` File(s) | Playback Notes |
| :--- | :--- | :--- |
| **Footsteps (Random Pool)** | `res://assets/audio/footstep00.ogg` – `res://assets/audio/footstep09.ogg` | Randomize clip & pitch (`0.92`–`1.08`) while moving |
| **Sword Slash** | `res://assets/audio/knifeSlice.ogg`, `res://assets/audio/knifeSlice2.ogg` | Alternate on swing |
| **Spin Slash** | `res://assets/audio/drawKnife1.ogg`, `res://assets/audio/drawKnife2.ogg`, `res://assets/audio/knifeSlice2.ogg` | Layered or pitched metallic spin |
| **Bounce Shield Parry (Perfect)** | `res://assets/audio/metalPot1.ogg`, `res://assets/audio/metalPot2.ogg`, `res://assets/audio/metalPot3.ogg` | Crisp resonant ring on reflect (+ `metalClick.ogg`) |
| **Shield Raise / Normal Block** | `res://assets/audio/metalClick.ogg`, `res://assets/audio/metalLatch.ogg` | Guard raise / non-parry block |
| **Dodge Roll** | `res://assets/audio/cloth1.ogg`, `res://assets/audio/cloth2.ogg`, `res://assets/audio/cloth3.ogg`, `res://assets/audio/cloth4.ogg` | Random cloth rustle |
| **Enemy / Player Hit** | `res://assets/audio/chop.ogg`, `res://assets/audio/dropLeather.ogg` | Impact thud (`chop`) / player damage (`dropLeather`) |
| **Plant / Water / Harvest** | `res://assets/audio/clothBelt.ogg`, `res://assets/audio/clothBelt2.ogg`, `res://assets/audio/handleSmallLeather.ogg` | Plant (`clothBelt`), Water (`clothBelt2`), Harvest (`handleSmallLeather`) |
| **Buy / Sell / Shipping Crate** | `res://assets/audio/handleCoins.ogg`, `res://assets/audio/handleCoins2.ogg` | Coin jingle on trade |
| **Building Rebuild** | `res://assets/audio/chop.ogg`, `res://assets/audio/creak1.ogg`–`res://assets/audio/creak3.ogg`, `res://assets/audio/metalLatch.ogg` | Wood/stone repair burst |
| **Zone Gates / Doors** | `res://assets/audio/doorOpen_1.ogg`, `res://assets/audio/doorOpen_2.ogg`, `res://assets/audio/doorClose_1.ogg`–`res://assets/audio/doorClose_4.ogg` | Zone transition gates & sleep door |
| **UI Open / Close / Navigate** | `res://assets/audio/bookOpen.ogg`, `res://assets/audio/bookClose.ogg`, `res://assets/audio/bookFlip1.ogg`–`res://assets/audio/bookFlip3.ogg`, `res://assets/audio/bookPlace1.ogg`–`res://assets/audio/bookPlace3.ogg` | `bookOpen`/`bookClose` for menus, `bookFlip*` for focus move, `bookPlace*` for dialogue/confirm |
| **Harvest Flask Drink** | `res://assets/audio/handleSmallLeather2.ogg`, `res://assets/audio/beltHandle2.ogg` | **Flagged:** uncork/equip stand-in (no liquid SFX in pack) |
