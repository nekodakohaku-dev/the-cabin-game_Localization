param([string]$GamePath,[switch]$VerifyOnly,[string]$VerificationOutput)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$taskPackageRoot=Split-Path -Parent $PSScriptRoot
$taskManifest=Get-Content -LiteralPath (Join-Path $taskPackageRoot 'data\manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
function Resolve-GamePath {
    if ($GamePath) { return [IO.Path]::GetFullPath($GamePath.Trim('"')) }
    if (Test-Path -LiteralPath (Join-Path $taskPackageRoot 'the_cabin_game.exe')) { return $taskPackageRoot }
    $taskParent=Split-Path -Parent $taskPackageRoot
    if (Test-Path -LiteralPath (Join-Path $taskParent 'the_cabin_game.exe')) { return $taskParent }
    $taskInput=Read-Host '貼上 Steam「瀏覽本機檔案」開啟的遊戲資料夾完整路徑'
    return [IO.Path]::GetFullPath($taskInput.Trim('"'))
}
function Check-Hash([string]$Path,[string]$Expected) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "缺少檔案：$Path" }
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Expected) { throw "檔案版本或內容不符：$Path。請使用本補丁支援的遊戲版本。" }
}
function Package-Path([string]$Relative) {
    $taskResolved=[IO.Path]::GetFullPath((Join-Path $taskPackageRoot $Relative))
    if (-not $taskResolved.StartsWith($taskPackageRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw '套件路徑無效' }
    return $taskResolved
}
$taskTemp=$null
try {
    $taskGameRoot=Resolve-GamePath
    if (-not (Test-Path -LiteralPath (Join-Path $taskGameRoot 'the_cabin_game.exe'))) { throw '這不是遊戲根目錄。請選擇含有 the_cabin_game.exe 的資料夾。' }
    if (-not $VerifyOnly -and (Get-Process -Name 'the_cabin_game-Win64-Shipping' -ErrorAction SilentlyContinue)) { throw '請先完全關閉遊戲，再執行安裝。' }
    foreach ($taskOriginal in $taskManifest.originalFiles) { Check-Hash (Join-Path $taskGameRoot $taskOriginal.path) $taskOriginal.sha256 }
    foreach ($taskPayload in $taskManifest.payloadFiles) { Check-Hash (Package-Path $taskPayload.path) $taskPayload.sha256 }
    $taskPatchNames=@('the_cabin_game-zhTW_P.pak','the_cabin_game-ja_P.pak','the_cabin_game-zhCN_P.pak')
    if ($taskManifest.patchFileName -notin $taskPatchNames) { throw '套件補丁名稱無效' }
    $taskRepak=Package-Path 'tools\repak.exe'
    Add-Type -Path (Package-Path 'scripts\ResourceTools.cs')
    $taskTemp=Join-Path ([IO.Path]::GetTempPath()) ('Cabin-zhTW-'+[Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $taskTemp | Out-Null
    $taskExtract=Join-Path $taskTemp 'original'
    $taskStage=Join-Path $taskTemp 'stage'
    $taskOriginalPak=Join-Path $taskGameRoot 'the_cabin_game\Content\Paks\the_cabin_game-Windows.pak'
    Write-Host '正在讀取你本機的原版語系檔。首次安裝可能需要連線下載 repak 的解壓縮元件。'
    & $taskRepak unpack $taskOriginalPak --output $taskExtract --include 'Engine/Content/Localization/Engine/en/Engine.locres'
    if ($LASTEXITCODE -ne 0) { throw '原版語系解壓失敗。請檢查網路連線或參閱使用說明。原始遊戲檔案沒有變更。' }
    $taskLocres=Join-Path $taskExtract 'Engine\Content\Localization\Engine\en\Engine.locres'
    Check-Hash $taskLocres $taskManifest.originalLocresSha256
    $taskTranslations=Get-Content -LiteralPath (Package-Path 'data\translations.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $taskEntries=@(foreach ($taskRow in $taskTranslations) {
        $taskEntry=New-Object TranslationEntry
        $taskEntry.Namespace=$taskRow.namespace;$taskEntry.Key=$taskRow.key
        $taskEntry.Hash=[uint32]$taskRow.hash;$taskEntry.Text=$taskRow.text
        $taskEntry
    })
    $taskEnglish=Join-Path $taskStage 'Engine\Content\Localization\Engine\en\Engine.locres'
    $taskTotal=[CabinLocres]::Merge($taskLocres,$taskEnglish,[TranslationEntry[]]$taskEntries)
    Check-Hash $taskEnglish $taskManifest.expectedMergedLocresSha256
    foreach ($taskCulture in $taskManifest.additionalCultures) {
        if ($taskCulture -notmatch '^[a-zA-Z-]+$') { throw '語系代碼無效' }
        $taskDestination=Join-Path $taskStage "Engine\Content\Localization\Engine\$taskCulture\Engine.locres"
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $taskDestination) | Out-Null
        Copy-Item -LiteralPath $taskEnglish -Destination $taskDestination
    }
    foreach ($taskFontPath in $taskManifest.fontPaths) {
        $taskDestination=[IO.Path]::GetFullPath((Join-Path $taskStage $taskFontPath))
        if (-not $taskDestination.StartsWith($taskStage+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw '字型目標路徑無效' }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $taskDestination) | Out-Null
        Copy-Item -LiteralPath (Package-Path 'data\CabinFont.ttf') -Destination $taskDestination
    }
    $taskBuiltPak=Join-Path $taskTemp $taskManifest.patchFileName
    & $taskRepak pack $taskStage $taskBuiltPak --version V11 --compression Zlib
    if ($LASTEXITCODE -ne 0) { throw '補丁封裝失敗；原始遊戲檔案沒有變更。' }
    $taskVerify=Join-Path $taskTemp 'verify'
    & $taskRepak unpack $taskBuiltPak --output $taskVerify
    if ($LASTEXITCODE -ne 0) { throw '補丁封包驗證失敗' }
    foreach ($taskFile in (Get-ChildItem -LiteralPath $taskStage -Recurse -File)) {
        $taskRelative=$taskFile.FullName.Substring($taskStage.Length+1)
        Check-Hash (Join-Path $taskVerify $taskRelative) (Get-FileHash -LiteralPath $taskFile.FullName -Algorithm SHA256).Hash
    }
    if ($VerifyOnly) {
        if ($VerificationOutput) { Copy-Item -LiteralPath $taskBuiltPak -Destination ([IO.Path]::GetFullPath($VerificationOutput)) -Force }
        Write-Host "驗證成功：$($taskEntries.Count) 筆譯文、$taskTotal 筆語系內容，尚未安裝。"
        exit 0
    }
    # All preparation and validation finish before touching the existing mod.
    $taskPaks=Join-Path $taskGameRoot 'the_cabin_game\Content\Paks'
    $taskTarget=Join-Path $taskPaks $taskManifest.patchFileName
    $taskPending=Join-Path $taskPaks ('cabin-zhTW-'+[Guid]::NewGuid().ToString('N')+'.tmp')
    $taskMovedBackups=@()
    Copy-Item -LiteralPath $taskBuiltPak -Destination $taskPending
    try {
        foreach ($taskName in $taskPatchNames) {
            $taskPrevious=Join-Path $taskPaks $taskName
            if (Test-Path -LiteralPath $taskPrevious) {
                $taskBackupRoot=Join-Path $taskGameRoot 'zhTW-backups'
                New-Item -ItemType Directory -Force -Path $taskBackupRoot | Out-Null
                $taskBackup=Join-Path $taskBackupRoot ($taskName+'-'+[Guid]::NewGuid().ToString('N')+'.disabled')
                Move-Item -LiteralPath $taskPrevious -Destination $taskBackup
                $taskMovedBackups+=@{original=$taskPrevious;backup=$taskBackup}
            }
        }
        Move-Item -LiteralPath $taskPending -Destination $taskTarget
    } catch {
        foreach ($taskMoved in $taskMovedBackups) {
            if (-not (Test-Path -LiteralPath $taskMoved.original)) { Move-Item -LiteralPath $taskMoved.backup -Destination $taskMoved.original }
        }
        if (Test-Path -LiteralPath $taskPending) { Remove-Item -LiteralPath $taskPending -Force }
        throw
    }
    Write-Host ('安裝完成：'+$taskManifest.languageName+'。照常從 Steam 開啟遊戲即可。') -ForegroundColor Green
    Write-Host '原始遊戲封包未修改。要恢復英文，請執行解除安裝。'
    exit 0
} catch {
    Write-Host ('失敗：'+$_.Exception.Message) -ForegroundColor Red
    exit 1
} finally {
    if ($taskTemp -and (Test-Path -LiteralPath $taskTemp)) {
        $taskTempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        $taskCleanup=[IO.Path]::GetFullPath($taskTemp)
        if ($taskCleanup.StartsWith($taskTempBase,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $taskCleanup) -match '^Cabin-zhTW-[a-f0-9]{32}$') { Remove-Item -LiteralPath $taskCleanup -Recurse -Force }
    }
}
