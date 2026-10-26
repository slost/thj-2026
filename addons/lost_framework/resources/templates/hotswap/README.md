# Hot-swap drop folder (template)

Copy these files into the **game** repository (the project that exports to the web), not into `res://lost/assets`.

| Template | Copy to |
|---|---|
| `tools/` | `tools/` |
| `assets/` | `assets/` at the repo root |
| `github/workflows/deploy.yml` | `.github/workflows/deploy.yml` |
| `export_presets.cfg.example` | reference only; create the real preset in Godot |

Full guide, in English and Thai: `addons/lost_framework/modules/asset_manager/HOTSWAP.md`.

`assets/` here is the folder teammates upload music, textures, and animation resources into. Lost's `res://lost/assets` folder is a different thing: it stores `AssetEntry` `.tres` files. The template `assets/` folder contains a `.gdignore` so Godot does not pack those uploads into the game.

`assets/anim_player_run.tres` is an example Animation. On a `HotSwapAnimationPlayer`, `bind_by_name` replaces the clip `player/run` with that file. `run` would be `anim_run.tres`. Set `animation_ids` when the names differ, for example `{ "dash": "anim_player_run" }`. The scene clip stays until the remote file exists.

---

# โฟลเดอร์วางไฟล์ hot-swap (เทมเพลต)

คัดลอกไฟล์เหล่านี้ไปไว้ที่ **รีโปของเกม** (โปรเจกต์ที่จะ export ขึ้นเว็บ) ไม่ใช่ไปไว้ใน `res://lost/assets`

| ในเทมเพลต | ไปไว้ที่ |
|---|---|
| `tools/` | `tools/` |
| `assets/` | `assets/` ที่รากของรีโป |
| `github/workflows/deploy.yml` | `.github/workflows/deploy.yml` |
| `export_presets.cfg.example` | ใช้อ่านอย่างเดียว สร้าง preset จริงใน Godot |

คู่มือฉบับเต็มทั้งอังกฤษและไทยอยู่ที่ `addons/lost_framework/modules/asset_manager/HOTSWAP.md`

`assets/` ในเทมเพลตนี้คือที่ให้เพื่อนในทีมอัปเพลง รูป และไฟล์แอนิเมชัน โฟลเดอร์ `res://lost/assets` ของ Lost เป็นคนละอย่าง เพราะเก็บไฟล์ `.tres` ของ `AssetEntry` โฟลเดอร์ `assets/` ของเทมเพลตมี `.gdignore` เพื่อไม่ให้ Godot แพ็กไฟล์ที่อัปเข้าไปในตัวเกม

`assets/anim_player_run.tres` เป็นตัวอย่าง Animation บน `HotSwapAnimationPlayer` ค่า `bind_by_name` จะใช้ไฟล์นี้แทนคลิป `player/run` คลิปชื่อ `run` ใช้ไฟล์ `anim_run.tres` ถ้าชื่อไม่ตรงกัน ให้ตั้ง `animation_ids` เช่น `{ "dash": "anim_player_run" }` คลิปที่เซฟไว้ในซีนจะอยู่จนกว่าจะมีไฟล์รีโมต
