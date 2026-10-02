# 上傳 GitHub 與發布

## 儲存庫

建立 GitHub 儲存庫，例如 `the-cabin-game-localization`，上傳**這個資料夾裡面的內容**，README.md 應直接位於儲存庫根目錄。
可以使用 GitHub Desktop 將此資料夾作為 repository 後提交及推送。請勿將整個遊戲目錄作為 repository。

## Releases

執行 `python tools/build_release.py` 後，在 Releases → Draft a new release 建立發行版。
填寫新 tag（例如 `localization-2026-10-02`）、標題與更新紀錄，上傳 `dist/` 的三份 ZIP 及三份 `.sha256.txt`。
說明支援資源版本、安裝步驟、首次網路需求、已知問題與測試範圍。玩家下載對應語言 ZIP。
也可使用已提供的 release 資料夾中繁中 0.2.3、簡中 0.1.0、日文 0.1.1 的六份檔案。

## 不要上傳

遊戲原始 EXE、PAK、UCAS、UTOC、LOCRES、解包原文、遊戲安裝後生成的 PAK、備份或測試資料。
repak 首次使用下載的 Oodle DLL 也不要隨專案或新套件一起上傳。
