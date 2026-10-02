# 維護與建置

## 重新打包目前版本

安裝 Python 3.10 以上，在儲存庫根目錄執行：

```powershell
python tools/build_release.py
```

不需 Python 額外套件。輸出 ZIP 與校驗檔到 `dist/`。此工具只重新封裝目前已驗證的套件，不讀遊戲、不擷取新文字、不更新字型或合併語系。
譯文、資源雜湊或其他受驗證檔案有異動時會拒絕打包，以免發布不一致的補丁。

## 安裝程式如何運作

1. 驗證使用者遊戲 PAK、UTOC 版本與套件內容 SHA256。
2. repak 從玩家自己的 PAK 讀取引擎英文語系。
3. C# 程式以 namespace/key 對應譯文，保留原版其他條目，輸出並回讀驗證語系。
4. 核對合併語系的預期 SHA256，加入字型與文化代碼資源。
5. 建立 PAK，再解包核對每個資源。
6. 備份並停用已知三種語言補丁，安裝新補丁；失敗時嘗試回復舊補丁。

## 驗證而不安裝

在對應套件資料夾，使用 Windows PowerShell 5.1：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1 -GamePath "E:\SteamLibrary\steamapps\common\the cabin game" -VerifyOnly
```

將範例路徑換成自己的遊戲資料夾。此流程需要玩家已安裝相容的正版遊戲。

## 修改與更新的限制

`translations.json` 的 hash 是原文雜湊，不是譯文雜湊。不要任意更改 namespace、key 或 hash。
字型已裁切；新增字元可能缺字。修改譯文也會改變合併語系 SHA256，而 manifest 中保存舊值，因此安裝會停止。
維護者需從自己的遊戲重新擷取／比對識別碼、產生語系及字型、更新 manifest、實測，再發布。
這些開發階段工具尚未整理成可攜的公開建置流程；本儲存庫不宣稱能僅憑 Python 指令重建新版翻譯。

共用 `src/` 與套件 `scripts/` 為不同用途；變更共用程式不會自動同步到三種發布套件。發布前需同步、更新驗證資料並測試。
