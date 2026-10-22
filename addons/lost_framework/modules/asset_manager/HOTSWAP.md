# Hot-swap assets

Lost's asset manager can keep using local `AssetEntry` resources and, when a game opts in, replace textures and audio at runtime from a manifest hosted next to the web build. A teammate uploads `sfx_jump.ogg` or `tex.hand.point.png` through the GitHub web UI. GitHub Actions republishes the site. The running game picks up the new files on refresh. No Godot export is required for an asset-only change.

The download queue, hash cache-busting, decoders, and Pages workflow follow a standalone starter kit that was already run on Godot 4.2/4.3 desktop and Web. This document is the Lost integration. On a web export the bytes are read with `fetch()`, because Godot's web `HTTPRequest` does not finish a GitHub Pages response.

## Design

Remote loading is an overlay inside `AssetManager`, not a second autoload.

- `AssetEntry` files under `res://lost/assets` stay the editor database and the built-in placeholders.
- A child node (`RemoteAssetLoader`) fetches `manifest.json` only after remote mode is turned on.
- `Assets.fetch(key)` is unchanged while remote mode is off. When a compatible download exists, that call returns the remote texture or audio instead, and the cache is updated.
- Scenes, item definitions, and other non-media entries are not replaced when the remote file is a different kind. The local resource stays, and a warning is printed once.
- `reload()` downloads only files whose manifest hash changed.
- Web exports download with the browser's `fetch()` (`JavaScriptBridge`, `arrayBuffer`, base64, `Marshalls.base64_to_raw`). Desktop and other platforms keep `HTTPRequest`. The web call sends no custom headers. Cache-busting stays on the query string (`?t=` for the manifest, `?v=<hash>` for each file). The concurrency cap, hash skip, timeouts, and placeholder fallback apply on both paths.
- `bgm_` and `bgm.` ids loop. Other audio does not, unless the manifest entry sets `"loop"` explicitly.
- Nodes that already copied a texture in `_ready` do not change by themselves. Use `HotSwapSprite`, `HotSwapTextureRect`, or `HotSwapAudio`, or connect to `asset_updated`. `AudioManager` restarts the current music when the key it is playing updates.

## Turn it on

Project Settings (added by the Lost plugin):

| Setting | Default | Role |
|---|---|---|
| `lost_framework/asset_manager/remote_enabled` | `false` | Opt in. Leave this off for normal builds. |
| `lost_framework/asset_manager/base_url` | `assets/` | Folder or absolute URL. `off` or `none` disables remote mode. |
| `lost_framework/asset_manager/max_concurrent` | `4` | Parallel downloads, clamped to 1–16. |

URL priority, highest first:

1. Web export: `?assets=` on the page URL. `?assets=off` disables remote mode for that visit.
2. Desktop: user argument `--assets=<url>` (`godot -- --assets=http://127.0.0.1:8000/assets/`).
3. `lost_framework/asset_manager/base_url`.
4. `assets/` when remote mode is enabled and the setting is empty.

An explicit `?assets=` or `--assets=` opts in for that run even if `remote_enabled` is false. Relative URLs are resolved against `window.location` on the web, so `assets/` means "the `assets` folder beside this page". On desktop a relative URL cannot be fetched; the game keeps placeholders and prints a warning.

Same-origin GitHub Pages does not need CORS. A CDN or bucket must send `Access-Control-Allow-Origin` for the game origin, or the browser blocks the files and the placeholders stay.

GitHub Pages answers with HTTP/2 and `Content-Encoding: gzip`. The browser shows HTTP 200, then `HTTPRequest` still fails. On Godot 4.8-beta1 the web client is `HTTPClientWeb`, and the engine prints `Condition "err != 0 && err != 1" is true. Returning: FAILED` from `stream_peer_gzip.cpp`. `request_completed` comes back as result 8 (body decompress failed) with an empty body: the engine tries to decompress bytes the browser has already decoded. A local server that sends the raw body does not do this. The loader therefore skips `HTTPRequest` when `OS.has_feature("web")` is true. Do not add request headers to that `fetch()`: a custom header turns the GET into a CORS preflight, and Pages does not answer it. A failed or timed-out file stays on its placeholder.

## IDs and file names

The id is the file name without its extension, lowercased.

| File | Id | Notes |
|---|---|---|
| `sfx_jump.ogg` | `sfx_jump` | Jam-style name. |
| `sfx.scissors.use.ogg` | `sfx.scissors.use` | Same string as an existing AssetEntry key. |
| `bgm_menu.ogg` / `bgm.level1.ogg` | `bgm_menu` / `bgm.level1` | Loops. |
| `sfx/sfx_hit.wav` | `sfx_hit` | Subfolders are kept in the URL; the id is still the file name. |

Allowed characters: a letter, then `a-z`, `0-9`, `_`, and extra `.segments` that also start with a letter. No spaces, no Thai characters, no uppercase in the file name (uppercase is accepted but rewritten to a lowercase id, and the manifest tool warns).

Extensions: `.png`, `.webp`, `.jpg`, `.jpeg`, `.ogg`, `.mp3`, `.wav`. If two files share an id, `.ogg` wins over `.mp3` and `.wav`, then textures. WAV is PCM 8/16/24/32-bit or 32-bit float, mono or stereo. ADPCM is not decoded. `.ogg` is the format to ask for.

Known prefixes (`tex_`, `spr_`, `ui_`, `bg_`, `sfx_`, `bgm_`, `vo_`, `amb_`, and the same words with a dot) are hints for the status page. Other ids still ship; the tool only warns.

## What the game calls

```gdscript
var tex := Assets.fetch("tex_player") as Texture2D
var sfx := Assets.fetch("sfx.scissors.use") as AudioStream
Assets.manager.asset_updated.connect(func(id: String) -> void:
    if id == "tex_player":
        sprite.texture = Assets.fetch("tex_player"))
Assets.manager.reload()
```

`Assets.fetch_texture` and `Assets.fetch_audio` never return null. They try the remote file, then the local entry, then `res://placeholders/<id>.<ext>`, then a magenta checkerboard or a short beep. `Assets.fetch` still returns null for an unknown key, which is the old contract.

`HotSwapSprite`, `HotSwapTextureRect`, and `HotSwapAudio` read `asset_id` and update when `asset_updated` fires. An editor-assigned texture or stream is kept until the remote file arrives (`prefer_editor_texture` / `prefer_editor_stream`). For `AudioStreamPlayer2D` or `AudioStreamPlayer3D`, duplicate `hot_swap_audio.gd` and change `extends`.

Signals on `AssetManager`:

- `asset_updated(id)` — a remote file replaced the placeholder or an older hash.
- `manifest_loaded(ok)` — the manifest request finished. `ok` is false when the request failed. An explicit `reload()` while remote mode is off also emits false.
- `all_loaded` — the queue for that `reload()` is done, including the failure path, so a loading screen can continue.

Startup does not emit those signals when remote mode is off. Games that do not opt in see the previous `Assets.fetch` behavior and no extra log line.

`Audio.play_music()` on an `AssetEntry` or on a stream that belongs to an asset key restarts the current track when that id updates. One-shot `play_sfx` / `play_ui` calls are not replayed.

## Game-repo template

Copy from `addons/lost_framework/resources/templates/hotswap/` into the game repository:

| Template | Destination |
|---|---|
| `tools/` | `tools/` |
| `assets/` | `assets/` at the repo root |
| `github/workflows/deploy.yml` | `.github/workflows/deploy.yml` |
| `export_presets.cfg.example` | Read it, then create the preset in the editor. |

`res://lost/assets` remains the folder of `.tres` entries. The new root `assets/` folder is only the drop zone. It contains `.gdignore`, so Godot does not import those uploads into the `.pck`. If the game already uses `res://assets` for imported art, pick another drop folder, point `base_url` at it, and change the copy step in the workflow. The Pages site still serves the files at `assets/` next to `index.html` when the workflow copies them there.

`assets/expected_ids.txt` lists ids the game wants, one per line. `python3 tools/make_manifest.py assets/ --status assets/status.html` writes `manifest.json` (sha1 prefix per file, used as `?v=`) and a bilingual status page. `--strict` exits 1 when the tool warned.

Pages setup, once:

1. Settings → Pages → Source = GitHub Actions.
2. In Godot, add a Web preset named `Web` and turn **Thread Support** off. Commit `export_presets.cfg`. The important line is `variant/thread_support=false`.
3. Set `GODOT_VERSION` in the workflow to the editor the team uses. Minimum is 4.3. The Lost addon workspace currently uses 4.6. A pre-release uses the full tag, for example `4.8-beta1` or `4.7.2-rc1` (`GODOT_STATUS` is ignored in that case). Godot 4.8-beta1 with threads off is a working Pages target.
4. Push to `main`. The site is `https://<user>.github.io/<repo>/`. The checklist is `https://<user>.github.io/<repo>/assets/status.html`.

The workflow caches the Godot export with a hash of everything outside `assets/`. An upload that only touches that folder skips the export and only rebuilds the manifest.

Try a folder locally with `python3 -m http.server` and `godot -- --assets=http://127.0.0.1:8000/assets/`.

## Ship a build that does not need the network

Jam builds on itch.io should not depend on GitHub Pages.

1. Keep the real files as the `AssetEntry` resources, or copy the loose files to `res://placeholders/<id>.<ext>` (flat, original file name).
2. Set `lost_framework/asset_manager/remote_enabled` to false, or `base_url` to `off`.
3. Export normally. Imported `bgm` files do not loop by themselves; tick Loop on the import dock. Runtime `bgm_` / `bgm.` downloads loop without that tick.

## Godot versions

- Target for this integration: Godot 4.3 or newer. The Lost addon workspace is opened with 4.6. Godot 4.8-beta1 (`godot --version` reports `4.8.beta1.official…`) exports a threads-off web build that loads Pages assets through `fetch()`.
- Web export with threads off needs the 4.3+ `web_nothreads_*` templates. Godot 4.2 cannot produce that build, so GitHub Pages is not a supported target on 4.2.
- `AudioStreamOggVorbis.load_from_buffer` exists from 4.2. `AudioStreamWAV.load_from_buffer` is 4.4+. The loader still parses PCM and float WAV itself so 4.3 can play `.wav`.
- Stable workflow values: `GODOT_VERSION=4.6` and `GODOT_STATUS=stable`. That downloads `Godot_v4.6-stable_linux.x86_64.zip` from `godotengine/godot`. The export-template folder is `4.6.stable`.
- Pre-release workflow values: set `GODOT_VERSION` to the release tag (`4.8-beta1`, `4.7.2-rc1`, `4.8-dev7`). Those files are on `godotengine/godot-builds`, not `godotengine/godot`. The asset names keep the hyphen: `Godot_v4.8-beta1_linux.x86_64.zip` and `Godot_v4.8-beta1_export_templates.tpz`. The template folder uses the editor's own version string, with a dot: `4.8.beta1`, `4.7.2.rc1`. The workflow reads that folder name from `godot --version` (it strips the `.official…` suffix).

## What was checked, and what was not

Checked here with Godot 4.6.3 headless, plus the manifest unit tests, and again after the web `fetch()` change:

- URL priority, relative URL joining, and desktop rejection of a relative base URL.
- PNG, JPG, WebP, OGG, MP3, 8/16/24-bit WAV, `bgm_` / `bgm.` looping, and rejection of bad buffers.
- Opt-in default, `Assets.fetch` cache behavior, type-mismatch fallback, dotted ids, subfolder files, hash skip on `reload()`, failed manifest keeping the previous file, the concurrency cap, and `HotSwapSprite` / `HotSwapTextureRect` / `HotSwapAudio` updates.
- `AudioManager` resolving a remote stream for an `AssetEntry` key.
- Godot 4.8-beta1 web export with threads off (`GODOT_THREADS_ENABLED = false`), booted in headless Chrome. A same-origin gzip response makes `HTTPRequest` print the `err != 0 && err != 1` failure from `stream_peer_gzip.cpp` and return result 8 with HTTP 200 and an empty body. The same URL over plain HTTP/1.0 succeeds. `fetch()` and `RemoteAssetLoader` both decode that gzip manifest and a 1×1 PNG. `fetch()` also read the live Pages manifest at `https://slost.github.io/lost-hotswap-test/manifest.json` (HTTP 200, 951 bytes).
- Workflow tag rules, locally: `4.6` + `stable`, `4.6.1` + `stable`, `4.8-beta1`, `4.7.2-rc1`, and `4.8-dev7`. `godot --version` on the 4.8-beta1 editor is `4.8.beta1.official.4d10419ca`, and the template archive's `version.txt` is `4.8.beta1`.

Not checked:

- The GitHub Actions workflow has not been run on GitHub.
- `?assets=` through `JavaScriptBridge` was not run in a browser. On the web that is the same `URL` / `URLSearchParams` call as the starter kit; `join_url()` covers the non-JS fallback and was unit tested.
- This branch was not deployed to GitHub Pages, and the `slost/lost-hotswap-test` game was not rebuilt from it. `HTTPRequest` from the localhost probe to that Pages URL succeeded, because a cross-origin response hides `Content-Encoding`. A game hosted on Pages is same-origin with its assets, which is the gzip case above.
- Godot 4.2 and 4.3 editors were not installed in this run.

---

# แอสเซ็ตแบบ hot-swap

ตัวจัดการแอสเซ็ตของ Lost ยังใช้ `AssetEntry` ในเครื่องได้ตามเดิม และถ้าเกมเปิดตัวเลือกนี้ จะสลับ texture กับเสียงตอนรันจาก manifest ที่อยู่ข้างไฟล์เว็บ เพื่อนในทีมอัป `sfx_jump.ogg` หรือ `tex.hand.point.png` ผ่านหน้าเว็บ GitHub แล้ว GitHub Actions เผยแพร่ไซต์ใหม่ เกมที่เปิดอยู่จะเห็นไฟล์ใหม่เมื่อรีเฟรช ไม่ต้อง export Godot ใหม่ถ้าแก้แค่ไฟล์แอสเซ็ต

คิวดาวน์โหลด การกันแคชด้วยแฮช ตัวถอดรหัส และ workflow ของ Pages มาจากชุดเริ่มต้นที่เคยรันบน Godot 4.2/4.3 ทั้งเดสก์ท็อปและเว็บ เอกสารนี้คือการต่อชุดนั้นเข้ากับ Lost บนเว็บที่ export แล้ว ตัวโหลดอ่านไฟล์ด้วย `fetch()` เพราะ `HTTPRequest` ของ Godot บนเว็บจบงานจาก GitHub Pages ไม่ได้

## แนวทาง

การโหลดจากภายนอกเป็นชั้นทับใน `AssetManager` ไม่ได้เป็น autoload ก้อนที่สอง

- ไฟล์ `AssetEntry` ใน `res://lost/assets` ยังเป็นฐานข้อมูลในเอดิเตอร์และเป็น placeholder
- โหนดลูก (`RemoteAssetLoader`) จะดึง `manifest.json` ก็ต่อเมื่อเปิดโหมดรีโมต
- `Assets.fetch(key)` ไม่เปลี่ยนพฤติกรรมเมื่อปิดโหมดรีโมต เมื่อมีไฟล์ที่ชนิดตรงกัน ดาวน์โหลดเสร็จแล้ว คำสั่งนี้จะคืน texture หรือเสียงจากรีโมต และอัปเดตแคช
- ซีน นิยามไอเทม และทรัพยากรที่ไม่ใช่ภาพหรือเสียง จะไม่ถูกแทนที่ถ้าไฟล์รีโมตคนละชนิด ของในเครื่องยังอยู่ และจะเตือนครั้งเดียว
- `reload()` ดาวน์โหลดเฉพาะไฟล์ที่แฮชใน manifest เปลี่ยน
- บิลด์เว็บดาวน์โหลดด้วย `fetch()` ของเบราว์เซอร์ (`JavaScriptBridge`, `arrayBuffer`, base64, แล้ว `Marshalls.base64_to_raw`) เดสก์ท็อปและแพลตฟอร์มอื่นยังใช้ `HTTPRequest` คำขอฝั่งเว็บไม่ใส่เฮดเดอร์เอง การกันแคชยังอยู่ที่ query string (`?t=` สำหรับ manifest และ `?v=<hash>` สำหรับแต่ละไฟล์) เพดานจำนวนพร้อมกัน การข้ามไฟล์ที่แฮชเดิม เวลาหมด และ placeholder ใช้กับทั้งสองเส้นทาง
- ไอดีที่ขึ้นต้นด้วย `bgm_` หรือ `bgm.` จะเล่นวน เสียงอื่นไม่วน เว้นแต่รายการใน manifest ใส่ `"loop"` ไว้
- โหนดที่ก็อป texture ไปแล้วใน `_ready` จะไม่เปลี่ยนเอง ให้ใช้ `HotSwapSprite`, `HotSwapTextureRect` หรือ `HotSwapAudio` หรือเชื่อม `asset_updated` `AudioManager` จะเริ่มเพลงปัจจุบันใหม่เมื่อไอดีที่กำลังเล่นอัปเดต

## วิธีเปิด

Project Settings (ปลั๊กอิน Lost เป็นคนเพิ่มให้):

| ค่า | ค่าเริ่มต้น | ความหมาย |
|---|---|---|
| `lost_framework/asset_manager/remote_enabled` | `false` | เปิดใช้ บิลด์ปกติให้ปิดไว้ |
| `lost_framework/asset_manager/base_url` | `assets/` | โฟลเดอร์หรือ URL เต็ม `off` หรือ `none` คือปิดโหมดรีโมต |
| `lost_framework/asset_manager/max_concurrent` | `4` | จำนวนดาวน์โหลดพร้อมกัน ถูกจำกัดไว้ที่ 1–16 |

ลำดับ URL จากสำคัญสุด:

1. Web export: `?assets=` บน URL ของหน้า `?assets=off` ปิดโหมดรีโมตเฉพาะครั้งที่เปิดนั้น
2. เดสก์ท็อป: อาร์กิวเมนต์ `--assets=<url>` (`godot -- --assets=http://127.0.0.1:8000/assets/`)
3. `lost_framework/asset_manager/base_url`
4. `assets/` เมื่อเปิดโหมดรีโมตแล้วค่าใน setting ว่าง

ถ้าใส่ `?assets=` หรือ `--assets=` ชัดเจน จะถือว่าเปิดใช้เฉพาะรอบนั้น แม้ `remote_enabled` จะเป็น false URL แบบสัมพัทธ์บนเว็บจะถูกต่อกับ `window.location` ดังนั้น `assets/` แปลว่าโฟลเดอร์ `assets` ที่อยู่ข้างหน้านี้ บนเดสก์ท็อปดึง URL แบบสัมพัทธ์ไม่ได้ เกมจะใช้ placeholder ต่อและพิมพ์คำเตือน

GitHub Pages ที่ origin เดียวกันไม่ต้องตั้ง CORS ถ้าเอาไฟล์ไปไว้บน CDN หรือ bucket ต้องส่ง `Access-Control-Allow-Origin` ของโดเมนเกม ไม่งั้นเบราว์เซอร์จะบล็อกและเกมจะค้างที่ placeholder

GitHub Pages ตอบเป็น HTTP/2 และ `Content-Encoding: gzip` เบราว์เซอร์เห็น HTTP 200 แต่ `HTTPRequest` ยังล้มเหลว บน Godot 4.8-beta1 ไคลเอนต์เว็บคือ `HTTPClientWeb` และเอนจินพิมพ์ `Condition "err != 0 && err != 1" is true. Returning: FAILED` จาก `stream_peer_gzip.cpp` `request_completed` ได้ผลลัพธ์ 8 (คลายการบีบอัดไม่สำเร็จ) พร้อมเนื้อหาว่าง เพราะเอนจินพยายามคลายไบต์ที่เบราว์เซอร์คลายให้แล้ว เซิร์ฟเวอร์ในเครื่องที่ส่งเนื้อหาแบบไม่บีบอัดจะไม่เจอทางนี้ ตัวโหลดจึงไม่ใช้ `HTTPRequest` เมื่อ `OS.has_feature("web")` เป็นจริง อย่าใส่เฮดเดอร์ใน `fetch()` นั้น เฮดเดอร์ที่เพิ่มเองจะทำให้ GET กลายเป็น CORS preflight ซึ่ง Pages ไม่ตอบ ไฟล์ที่ล้มเหลวหรือหมดเวลาจะค้างที่ placeholder

## ไอดีและชื่อไฟล์

ไอดีคือชื่อไฟล์ไม่รวมนามสกุล และถูกทำให้เป็นตัวเล็ก

| ไฟล์ | ไอดี | หมายเหตุ |
|---|---|---|
| `sfx_jump.ogg` | `sfx_jump` | ชื่อแบบแจม |
| `sfx.scissors.use.ogg` | `sfx.scissors.use` | สตริงเดียวกับคีย์ของ AssetEntry เดิม |
| `bgm_menu.ogg` / `bgm.level1.ogg` | `bgm_menu` / `bgm.level1` | เล่นวน |
| `sfx/sfx_hit.wav` | `sfx_hit` | โฟลเดอร์ย่อยยังอยู่ใน URL ไอดียังเป็นชื่อไฟล์ |

อักขระที่ใช้ได้: ขึ้นต้นด้วยตัวอักษร ตามด้วย `a-z`, `0-9`, `_` และ `.segment` ที่ขึ้นต้นด้วยตัวอักษรเช่นกัน ห้ามเว้นวรรค ห้ามภาษาไทย ห้ามตัวพิมพ์ใหญ่ในชื่อไฟล์ (ตัวพิมพ์ใหญ่ยังถูกยอมรับแต่จะกลายเป็นไอดีตัวเล็ก และเครื่องมือ manifest จะเตือน)

นามสกุล: `.png`, `.webp`, `.jpg`, `.jpeg`, `.ogg`, `.mp3`, `.wav` ถ้าสองไฟล์ใช้ไอดีเดียวกัน จะเลือก `.ogg` ก่อน `.mp3` และ `.wav` แล้วค่อยเป็นรูป WAV ใช้ได้เฉพาะ PCM 8/16/24/32 บิต หรือ float 32 บิต โมโนหรือสเตอริโอ ไม่รองรับ ADPCM ให้ขอไฟล์ `.ogg`

คำนำหน้าที่รู้จัก (`tex_`, `spr_`, `ui_`, `bg_`, `sfx_`, `bgm_`, `vo_`, `amb_` และคำเดียวกันที่ตามด้วยจุด) เป็นคำใบ้สำหรับหน้าสถานะ ไอดีอื่นยังถูกส่งขึ้นได้ เครื่องมือแค่เตือน

## สิ่งที่เกมเรียกใช้

```gdscript
var tex := Assets.fetch("tex_player") as Texture2D
var sfx := Assets.fetch("sfx.scissors.use") as AudioStream
Assets.manager.asset_updated.connect(func(id: String) -> void:
    if id == "tex_player":
        sprite.texture = Assets.fetch("tex_player"))
Assets.manager.reload()
```

`Assets.fetch_texture` กับ `Assets.fetch_audio` ไม่คืน null จะลองไฟล์รีโมต แล้วรายการในเครื่อง แล้ว `res://placeholders/<id>.<ext>` แล้วภาพตารางสีชมพูหรือเสียงปิ๊บสั้น ๆ `Assets.fetch` ยังคืน null เมื่อไม่รู้จักคีย์ ตามสัญญาเดิม

`HotSwapSprite`, `HotSwapTextureRect` และ `HotSwapAudio` อ่าน `asset_id` แล้วอัปเดตเมื่อ `asset_updated` ดัง texture หรือสตรีมที่วางในเอดิเตอร์จะค้างไว้จนกว่าไฟล์รีโมตจะมา (`prefer_editor_texture` / `prefer_editor_stream`) ถ้าต้องการ `AudioStreamPlayer2D` หรือ `AudioStreamPlayer3D` ให้ก็อป `hot_swap_audio.gd` แล้วเปลี่ยน `extends`

สัญญาณบน `AssetManager`:

- `asset_updated(id)` — ไฟล์รีโมตแทน placeholder หรือแฮชเก่าแล้ว
- `manifest_loaded(ok)` — คำขอ manifest จบแล้ว `ok` เป็น false เมื่อคำขอล้มเหลว `reload()` แบบชัดเจนขณะปิดโหมดรีโมตก็ส่ง false เช่นกัน
- `all_loaded` — คิวของ `reload()` รอบนั้นจบ รวมกรณีล้มเหลว เพื่อให้หน้าโหลดไปต่อได้

ตอนเริ่มเกมจะไม่ส่งสัญญาณเหล่านี้ถ้าปิดโหมดรีโมต เกมที่ไม่ได้เปิดใช้จะได้พฤติกรรม `Assets.fetch` เดิม และไม่มีบรรทัดล็อกเพิ่ม

`Audio.play_music()` ที่รับ `AssetEntry` หรือสตรีมที่เป็นของคีย์แอสเซ็ต จะเริ่มแทร็กปัจจุบันใหม่เมื่อไอดีนั้นอัปเดต `play_sfx` / `play_ui` ที่ยิงครั้งเดียวจะไม่ถูกเล่นซ้ำ

## เทมเพลตสำหรับรีโปเกม

คัดลอกจาก `addons/lost_framework/resources/templates/hotswap/` ไปไว้ในรีโปของเกม:

| ในเทมเพลต | ที่วาง |
|---|---|
| `tools/` | `tools/` |
| `assets/` | `assets/` ที่รากของรีโป |
| `github/workflows/deploy.yml` | `.github/workflows/deploy.yml` |
| `export_presets.cfg.example` | ใช้อ่าน แล้วสร้าง preset ในเอดิเตอร์ |

`res://lost/assets` ยังเป็นที่เก็บไฟล์ `.tres` โฟลเดอร์ `assets/` ที่รากคือที่วางไฟล์อย่างเดียว และมี `.gdignore` เพื่อไม่ให้ Godot นำไฟล์ที่อัปเข้าไปใน `.pck` ถ้าเกมใช้ `res://assets` อยู่แล้วสำหรับอาร์ตที่ import ให้เลือกชื่อโฟลเดอร์วางไฟล์อีกชื่อ ชี้ `base_url` ไปที่นั่น แล้วแก้ขั้นก็อปใน workflow ไซต์ Pages ยังเสิร์ฟไฟล์ที่ `assets/` ข้าง `index.html` เมื่อ workflow ก็อปไปไว้ตรงนั้น

`assets/expected_ids.txt` คือรายการไอดีที่เกมต้องการ บรรทัดละหนึ่งไอดี `python3 tools/make_manifest.py assets/ --status assets/status.html` จะเขียน `manifest.json` (ใช้ sha1 ช่วงต้นของแต่ละไฟล์เป็น `?v=`) และหน้าสถานะสองภาษา `--strict` จะจบด้วยรหัส 1 เมื่อมีคำเตือน

ตั้ง Pages ครั้งเดียว:

1. Settings → Pages → Source = GitHub Actions
2. ใน Godot เพิ่ม preset เว็บชื่อ `Web` แล้วปิด **Thread Support** จากนั้น commit `export_presets.cfg` บรรทัดสำคัญคือ `variant/thread_support=false`
3. ตั้ง `GODOT_VERSION` ใน workflow ให้ตรงกับเอดิเตอร์ที่ทีมใช้ ต่ำสุดคือ 4.3 ตอนนี้ workspace ของ Lost ใช้ 4.6 ถ้าเป็นรุ่นก่อน stable ให้ใส่แท็กเต็ม เช่น `4.8-beta1` หรือ `4.7.2-rc1` (กรณีนี้ไม่ใช้ `GODOT_STATUS`) Godot 4.8-beta1 ที่ปิดเธรดใช้กับ Pages ได้
4. push ขึ้น `main` ไซต์อยู่ที่ `https://<user>.github.io/<repo>/` รายการเช็กอยู่ที่ `https://<user>.github.io/<repo>/assets/status.html`

workflow แคชผล export ของ Godot ด้วยแฮชของทุกไฟล์ที่อยู่นอก `assets/` การอัปที่แตะแค่โฟลเดอร์นั้นจะข้าม export แล้วสร้าง manifest ใหม่เท่านั้น

ลองโฟลเดอร์ในเครื่องด้วย `python3 -m http.server` และ `godot -- --assets=http://127.0.0.1:8000/assets/`

## บิลด์ที่ไม่ต้องพึ่งเน็ต

บิลด์ที่ส่งเข้า itch.io ไม่ควรพึ่ง GitHub Pages

1. เก็บไฟล์จริงไว้เป็นทรัพยากรของ `AssetEntry` หรือก็อปไฟล์ลอยไปที่ `res://placeholders/<id>.<ext>` (วางราบ ใช้ชื่อไฟล์เดิม)
2. ตั้ง `lost_framework/asset_manager/remote_enabled` เป็น false หรือตั้ง `base_url` เป็น `off`
3. export ตามปกติ ไฟล์ `bgm` ที่ import เข้า Godot จะไม่วนเอง ให้ติ๊ก Loop ที่ import dock ส่วนไฟล์ `bgm_` / `bgm.` ที่โหลดตอนรันจะวนโดยไม่ต้องติ๊ก

## เวอร์ชัน Godot

- เป้าหมายของการต่อครั้งนี้คือ Godot 4.3 ขึ้นไป workspace ของ Lost เปิดด้วย 4.6 Godot 4.8-beta1 (คำสั่ง `godot --version` รายงาน `4.8.beta1.official…`) export เว็บแบบปิดเธรดแล้วโหลดไฟล์จาก Pages ผ่าน `fetch()` ได้
- การ export เว็บแบบปิดเธรดต้องใช้เทมเพลต `web_nothreads_*` ของ 4.3 ขึ้นไป Godot 4.2 สร้างบิลด์แบบนั้นไม่ได้ ดังนั้น GitHub Pages ไม่ใช่เป้าหมายที่รองรับบน 4.2
- `AudioStreamOggVorbis.load_from_buffer` มีตั้งแต่ 4.2 `AudioStreamWAV.load_from_buffer` มาใน 4.4 ตัวโหลดยังแกะ WAV แบบ PCM และ float เอง เพื่อให้ 4.3 เล่น `.wav` ได้
- ค่า workflow ของรุ่น stable: `GODOT_VERSION=4.6` และ `GODOT_STATUS=stable` จะดาวน์โหลด `Godot_v4.6-stable_linux.x86_64.zip` จาก `godotengine/godot` โฟลเดอร์เทมเพลตคือ `4.6.stable`
- ค่า workflow ของรุ่นก่อน stable: ตั้ง `GODOT_VERSION` เป็นแท็กของรีลีส (`4.8-beta1`, `4.7.2-rc1`, `4.8-dev7`) ไฟล์เหล่านี้อยู่ที่ `godotengine/godot-builds` ไม่ใช่ `godotengine/godot` ชื่อไฟล์ยังใช้ขีด: `Godot_v4.8-beta1_linux.x86_64.zip` และ `Godot_v4.8-beta1_export_templates.tpz` โฟลเดอร์เทมเพลตใช้สตริงเวอร์ชันของเอดิเตอร์ ซึ่งเป็นจุด: `4.8.beta1`, `4.7.2.rc1` workflow อ่านชื่อโฟลเดอร์จาก `godot --version` (ตัดส่วน `.official…` ทิ้ง)

## สิ่งที่ตรวจแล้ว และสิ่งที่ยังไม่ได้ตรวจ

ตรวจในรอบนี้ด้วย Godot 4.6.3 แบบ headless พร้อมเทสต์หน่วยของ manifest และตรวจซ้ำหลังเปลี่ยนให้เว็บใช้ `fetch()`:

- ลำดับ URL การต่อ URL แบบสัมพัทธ์ และการไม่รับ base URL แบบสัมพัทธ์บนเดสก์ท็อป
- PNG, JPG, WebP, OGG, MP3, WAV 8/16/24 บิต การวนของ `bgm_` / `bgm.` และการปฏิเสธบัฟเฟอร์ที่เสีย
- ค่าเริ่มต้นแบบต้องเปิดเอง พฤติกรรมแคชของ `Assets.fetch` การถอยเมื่อชนิดไม่ตรง ไอดีที่มีจุด ไฟล์ในโฟลเดอร์ย่อย การข้ามไฟล์ที่แฮชไม่เปลี่ยนใน `reload()` การคงไฟล์เดิมเมื่อ manifest ล้มเหลว เพดานจำนวนดาวน์โหลดพร้อมกัน และการอัปเดตของ `HotSwapSprite` / `HotSwapTextureRect` / `HotSwapAudio`
- `AudioManager` อ่านสตรีมรีโมตจากคีย์ของ `AssetEntry`
- export เว็บของ Godot 4.8-beta1 แบบปิดเธรด (`GODOT_THREADS_ENABLED = false`) แล้วเปิดใน Chrome แบบ headless การตอบแบบ gzip จาก origin เดียวกันทำให้ `HTTPRequest` พิมพ์ความล้มเหลว `err != 0 && err != 1` จาก `stream_peer_gzip.cpp` และคืนผลลัพธ์ 8 พร้อม HTTP 200 และเนื้อหาว่าง URL เดียวกันผ่าน HTTP/1.0 แบบไม่บีบอัดสำเร็จ `fetch()` และ `RemoteAssetLoader` ถอดรหัส manifest ที่ถูก gzip และ PNG ขนาด 1×1 ได้ `fetch()` ยังอ่าน manifest จริงบน Pages ที่ `https://slost.github.io/lost-hotswap-test/manifest.json` (HTTP 200, 951 ไบต์)
- กฎแท็กของ workflow ในเครื่อง: `4.6` + `stable`, `4.6.1` + `stable`, `4.8-beta1`, `4.7.2-rc1`, และ `4.8-dev7` `godot --version` ของเอดิเตอร์ 4.8-beta1 คือ `4.8.beta1.official.4d10419ca` และ `version.txt` ในชุดเทมเพลตคือ `4.8.beta1`

ยังไม่ได้ตรวจ:

- workflow ของ GitHub Actions ยังไม่ได้รันบน GitHub
- `?assets=` ผ่าน `JavaScriptBridge` ยังไม่ได้รันในเบราว์เซอร์ บนเว็บนี่คือคำสั่ง `URL` / `URLSearchParams` ชุดเดียวกับชุดเริ่มต้น `join_url()` ครอบกรณีที่ไม่ใช้ JS และถูกเทสต์แล้ว
- สาขานี้ยังไม่ได้ถูก deploy ขึ้น GitHub Pages และไม่ได้สร้างเกม `slost/lost-hotswap-test` ใหม่จากสาขานี้ `HTTPRequest` จากเพจบน localhost ไปยัง URL ของ Pages นั้นสำเร็จ เพราะการตอบข้าม origin ไม่เปิดเผย `Content-Encoding` เกมที่โฮสต์บน Pages อยู่ origin เดียวกับไฟล์แอสเซ็ต ซึ่งคือกรณี gzip ด้านบน
- ไม่ได้ติดตั้งเอดิเตอร์ Godot 4.2 และ 4.3 ในรอบนี้
