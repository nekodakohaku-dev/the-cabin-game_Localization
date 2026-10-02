[繁體中文](README.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [English](README.en.md)

## English

This project is an **unofficial localization patch for The Cabin Game**, available in Traditional Chinese, Simplified Chinese, and Japanese. It translates text in menus, settings, cards, events, manuals, and other parts of the game.

### Installation / Updating

1. Download the ZIP for your preferred language from this project's **Releases**. Close the game completely and extract the entire ZIP.
2. Run `Install.cmd`. It automatically searches for the game's Steam installation. The first installation may require an internet connection.
3. If automatic detection fails, enter the path to **the folder containing `the_cabin_game.exe`** when prompted. Find it in Steam by right-clicking the game → Manage → Browse local files.
4. Once installation is complete, launch the game through Steam as usual and check that text displays correctly.

To update or switch languages, close the game and run `Install.cmd` from the new package.

### Uninstalling the Patch

1. Close the game completely and run `Uninstall.cmd` from the extracted folder.
2. It automatically searches for the game. If detection fails, enter the same game folder path used during installation.
3. Once the patch has been disabled, restart the game through Steam to restore the original English text.

Disabled language patches are moved to `zhTW-backups` in the game folder. Original game packages and save data are not modified. If a game update causes text or startup problems, uninstall the patch and wait for a compatible release.

### Reporting Issues

Please report bugs, untranslated text, awkward wording, or layout problems through this project's **Issues** page. You can also report problems in the Steam discussion thread for this patch.

Please include your language, patch and game versions, the scene or steps that caused the problem, and the original text or a screenshot where possible. For installation failures, include the error message shown in the installer window. Check and redact personal paths or other private information before posting.

### Third-Party Licenses and Source Code

This patch uses **repak** and **Noto Sans TC / SC / JP** fonts. Third-party licenses are included in the package's `licenses` folder. Installer source code is in this project's `src` folder; translation data and release package files for each language are in `packages`. Retain the relevant license notices when redistributing.

This is an unofficial patch and is not endorsed by the game's developer. It does not include the game itself or original game packages.
