# THJ 2026

Game jam project for THJ 2026. Godot **4.8-beta1**, [Lost framework](https://github.com/slost/lost-ecosystem) hot-swap assets, deployed with GitHub Pages.

Play: <https://slost.github.io/thj-2026/>

Asset status: <https://slost.github.io/thj-2026/assets/status.html>

Manifest: <https://slost.github.io/thj-2026/assets/manifest.json>

The first scene is `res://game/main.tscn`. It boots Lost and shows the project name plus how many remote assets have loaded and how many are still placeholders. Build the game on top of that scene.

## English

### What this repo is

A clean Godot 4.8-beta1 project. `addons/lost_framework/` is the Lost framework vendored from `slost/lost-ecosystem` commit `6c34a2adf7efafdb8f38eb098197ce87fd3e1022`, plus one local fix in `addons/lost_framework/modules/settings/settings.module.gd` so the missing `Game` autoload does not stop the script from parsing. Update the addon by replacing the `addons/lost_framework/` folder. Keep that settings fix unless the upstream file no longer calls `Game`.

Lost loads modules from `res://lost/assigned_modules.json`. This project activates `asset_manager` and `audio_manager`. Autoloads, in order, are Refs, Rng, SignalBus, Lost, Audio, SaveManager, and Settings. There is no `Asset` autoload. `Assets` is a `class_name`. Remote hot-swap is on: `lost_framework/asset_manager/remote_enabled` is true, `base_url` is `assets/`, and `max_concurrent` is 4. On the web build, `assets/` is resolved against the page URL. The Web export preset has thread support off, which GitHub Pages needs in order to boot.

Godot **4.8-beta1** comes from [godotengine/godot-builds](https://github.com/godotengine/godot-builds/releases/tag/4.8-beta1). `godot --version` reports `4.8.beta1.official` (a dot in the template folder name).

### Drop or replace an asset from the GitHub website

1. Open this repository on GitHub and go into the `assets/` folder.
2. Choose **Add file > Upload files**.
3. Select the file. The file name is the asset id (see the rules below). To replace a file, upload the same name again.
4. Commit directly to the `main` branch.
5. Wait until the **Deploy to GitHub Pages** workflow finishes. A commit that only changes files inside `assets/` reuses the cached web export and does not run Godot. Any other change exports the game again.
6. Refresh <https://slost.github.io/thj-2026/>. The game reads `assets/manifest.json` when the page loads.

Add `?assets=off` to keep every id on its placeholder:

<https://slost.github.io/thj-2026/?assets=off>

The status page lists the manifest: <https://slost.github.io/thj-2026/assets/status.html>

### Naming rules

The asset id is the file name without the extension.

- Lowercase. No spaces.
- Start with a letter. After that, use `a-z`, `0-9`, and `_`.
- `tex_` is a texture. `ui_` is a UI texture. Use `.png`, `.webp`, `.jpg`, or `.jpeg`.
- `sfx_` is a sound effect. Use `.ogg`, `.mp3`, or `.wav`.
- `bgm_` is music. Ids that start with `bgm_` loop.
- `assets/tex_hero.png` is id `tex_hero`. `assets/bgm_menu.ogg` is id `bgm_menu` and loops. `assets/sfx_jump.ogg` is id `sfx_jump`. `assets/ui_logo.png` is id `ui_logo`.

An id with no file stays on the built-in placeholder (a magenta checkerboard, or a short beep). Notes for the folder are in `assets/README.md`. Optional expected ids go in `assets/expected_ids.txt`, one id per line.

`assets/` has `.gdignore`, and the Web preset excludes `assets/` and `tools/`, so uploads are not packed into the game binary.

### How code fetches an asset

```gdscript
var texture := Assets.fetch_texture("tex_hero")
var music := Assets.fetch_audio("bgm_menu")

func _ready() -> void:
	if Assets.manager:
		Assets.manager.asset_updated.connect(_on_asset_updated)

func _on_asset_updated(id: String) -> void:
	if id == "tex_hero":
		$Sprite.texture = Assets.fetch_texture(id)
```

`Assets.fetch_texture` and `Assets.fetch_audio` never return null. Until a compatible remote file arrives they return the placeholder. `Assets.is_placeholder(id)` is true until that file is ready. `Assets.manager.asset_updated` is emitted with the id when a remote file replaces the placeholder or an older file. `?assets=off` leaves every id on its placeholder.

## ภาษาไทย

โปรเจกต์แจม THJ 2026 ใช้ Godot **4.8-beta1** และเฟรมเวิร์ก Lost เพื่อสลับไฟล์เพลง เสียง และรูปบน GitHub Pages โดยไม่ต้องแพ็กไฟล์เหล่านั้นเข้าไปในตัวเกม

เปิดเกม: <https://slost.github.io/thj-2026/>

หน้าสถานะไฟล์: <https://slost.github.io/thj-2026/assets/status.html>

manifest: <https://slost.github.io/thj-2026/assets/manifest.json>

ฉากแรกคือ `res://game/main.tscn` เปิดเฟรมเวิร์ก Lost แล้วแสดงชื่อโปรเจกต์พร้อมจำนวนแอสเซ็ตที่โหลดมาแล้ว และจำนวนที่ยังเป็น placeholder ตัวเกมจริงให้สร้างต่อจากฉากนี้

### โปรเจกต์นี้คืออะไร

โฟลเดอร์ `addons/lost_framework/` คือเฟรมเวิร์ก Lost ที่คัดลอกมาจาก `slost/lost-ecosystem` คอมมิต `6c34a2adf7efafdb8f38eb098197ce87fd3e1022` และมีจุดแก้เฉพาะที่ใน `addons/lost_framework/modules/settings/settings.module.gd` เพราะสคริปต์ต้นทางอ้างออโตโหลดชื่อ `Game` ที่โปรเจกต์นี้ไม่มี ถ้าจะอัปเดตแอดออน ให้ลบแล้ววางโฟลเดอร์ `addons/lost_framework/` ใหม่ทั้งก้อน และเก็บจุดแก้ไฟล์ settings ไว้ ถ้าไฟล์ต้นทางยังเรียก `Game` อยู่

Lost โหลดโมดูลจาก `res://lost/assigned_modules.json` โปรเจกต์นี้เปิด `asset_manager` กับ `audio_manager` ออโตโหลดเรียงเป็น Refs, Rng, SignalBus, Lost, Audio, SaveManager, Settings ไม่มีออโตโหลดชื่อ `Asset` คลาสที่ใช้คือ `Assets` โหมดรีโมตเปิดอยู่ `base_url` คือ `assets/` และดาวน์โหลดพร้อมกันได้สูงสุด 4 ไฟล์ บนเว็บ `assets/` จะต่อจากที่อยู่ของหน้าเกม พรีเซ็ต Web ปิด thread support เพื่อให้หน้า GitHub Pages เปิดได้

### วิธีวางหรือแทนที่ไฟล์ผ่านเว็บ GitHub

1. เปิดรีโปนี้บน GitHub แล้วเข้าโฟลเดอร์ `assets/`
2. เลือก **Add file > Upload files**
3. เลือกไฟล์ ชื่อไฟล์คือรหัสแอสเซ็ต (ดูกติกาด้านล่าง) ถ้าจะแทนที่ไฟล์เดิม ให้อัปโหลดด้วยชื่อเดิม
4. คอมมิตเข้าสาขา `main` โดยตรง
5. รอเวิร์กโฟลว์ **Deploy to GitHub Pages** ให้จบ ถ้าคอมมิตแก้เฉพาะไฟล์ใน `assets/` ระบบจะใช้เว็บที่เอ็กซ์พอร์ตไว้แล้ว และไม่รัน Godot ใหม่ ถ้ามีไฟล์อื่นเปลี่ยน จะเอ็กซ์พอร์ตเกมใหม่
6. รีเฟรช <https://slost.github.io/thj-2026/> เกมจะอ่าน `assets/manifest.json` ตอนเปิดหน้า

ถ้าต้องการให้ทุก id ค้างที่ placeholder ให้เปิด

<https://slost.github.io/thj-2026/?assets=off>

หน้าสถานะที่แสดงรายการใน manifest: <https://slost.github.io/thj-2026/assets/status.html>

### กติกาตั้งชื่อ

รหัสแอสเซ็ตคือชื่อไฟล์ไม่รวมนามสกุล

- ใช้ตัวพิมพ์เล็ก และห้ามมีช่องว่าง
- ขึ้นต้นด้วยตัวอักษร จากนั้นใช้ `a-z`, `0-9`, และ `_`
- `tex_` คือรูป `ui_` คือรูปส่วนติดต่อผู้ใช้ นามสกุล `.png`, `.webp`, `.jpg`, หรือ `.jpeg`
- `sfx_` คือเสียงเอฟเฟกต์ นามสกุล `.ogg`, `.mp3`, หรือ `.wav`
- `bgm_` คือเพลง รหัสที่ขึ้นต้นด้วย `bgm_` จะเล่นวน
- `assets/tex_hero.png` ได้รหัส `tex_hero` `assets/bgm_menu.ogg` ได้รหัส `bgm_menu` และเล่นวน `assets/sfx_jump.ogg` ได้รหัส `sfx_jump` `assets/ui_logo.png` ได้รหัส `ui_logo`

รหัสที่ยังไม่มีไฟล์จะใช้ placeholder ในตัว (ตารางหมากรุกสีม่วง หรือเสียงบี๊บสั้น ๆ) คำอธิบายสั้น ๆ อยู่ใน `assets/README.md` ถ้าระบุรหัสที่คาดไว้ ให้เขียนใน `assets/expected_ids.txt` หนึ่งรหัสต่อหนึ่งบรรทัด

โฟลเดอร์ `assets/` มี `.gdignore` และพรีเซ็ต Web ไม่แพ็ก `assets/` กับ `tools/` ไฟล์ที่อัปโหลดจึงไม่ถูกฝังในตัวเกม

### วิธีให้โค้ดดึงแอสเซ็ต

```gdscript
var texture := Assets.fetch_texture("tex_hero")
var music := Assets.fetch_audio("bgm_menu")

func _ready() -> void:
	if Assets.manager:
		Assets.manager.asset_updated.connect(_on_asset_updated)

func _on_asset_updated(id: String) -> void:
	if id == "tex_hero":
		$Sprite.texture = Assets.fetch_texture(id)
```

`Assets.fetch_texture` และ `Assets.fetch_audio` ไม่คืนค่า null ถ้าไฟล์รีโมตที่ชนิดตรงกันยังมาไม่ถึง จะได้ placeholder `Assets.is_placeholder(id)` เป็นจริงจนกว่าไฟล์นั้นจะพร้อม `Assets.manager.asset_updated` ส่งรหัสมาเมื่อไฟล์รีโมตมาแทน placeholder หรือแทนไฟล์เก่า `?assets=off` ทำให้ทุกรหัสค้างที่ placeholder
