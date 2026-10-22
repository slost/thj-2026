# Hot-swap drop folder (template)

Copy these files into the **game** repository (the project that exports to the web), not into `res://lost/assets`.

| Template | Copy to |
|---|---|
| `tools/` | `tools/` |
| `assets/` | `assets/` at the repo root |
| `github/workflows/deploy.yml` | `.github/workflows/deploy.yml` |
| `export_presets.cfg.example` | reference only; create the real preset in Godot |

Full guide, in English and Thai: `addons/lost_framework/modules/asset_manager/HOTSWAP.md`.

`assets/` here is the folder teammates upload music and textures into. Lost's `res://lost/assets` folder is a different thing: it stores `AssetEntry` `.tres` files. The template `assets/` folder contains a `.gdignore` so Godot does not pack those uploads into the game.

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

`assets/` ในเทมเพลตนี้คือที่ให้เพื่อนในทีมอัปเพลงและรูป โฟลเดอร์ `res://lost/assets` ของ Lost เป็นคนละอย่าง เพราะเก็บไฟล์ `.tres` ของ `AssetEntry` โฟลเดอร์ `assets/` ของเทมเพลตมี `.gdignore` เพื่อไม่ให้ Godot แพ็กไฟล์ที่อัปเข้าไปในตัวเกม
