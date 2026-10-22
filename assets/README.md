# assets/

Drop hot-swap files in this folder. `.gdignore` keeps Godot from packing them into the game. The Pages workflow publishes this folder beside the web build and writes `manifest.json` plus `status.html`.

The asset id is the file name without the extension.

- Lowercase. No spaces. Start with a letter, then `a-z`, `0-9`, or `_`.
- `tex_` and `ui_` are textures (`.png`, `.webp`, `.jpg`, `.jpeg`).
- `sfx_` is a sound effect (`.ogg`, `.mp3`, `.wav`).
- `bgm_` is music. Ids that start with `bgm_` loop.
- `assets/bgm_menu.ogg` becomes id `bgm_menu`. `assets/sfx_jump.ogg` becomes `sfx_jump`.

On GitHub: open this folder, choose **Add file > Upload files**, commit to `main`, wait for Actions, then refresh the game.

`expected_ids.txt` is optional. One id per line. The status page uses it. This file and `README.md` are not assets.
