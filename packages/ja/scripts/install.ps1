param([string]$GamePath,[switch]$VerifyOnly,[string]$VerificationOutput)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'GamePath.ps1')
Set-StrictMode -Version Latest
$taskPackageRoot=Split-Path -Parent $PSScriptRoot
$taskManifest=Get-Content -LiteralPath (Join-Path $taskPackageRoot 'data\manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
function Resolve-GamePath {
    if ($GamePath) { return [IO.Path]::GetFullPath($GamePath.Trim('"')) }
    if (Test-Path -LiteralPath (Join-Path $taskPackageRoot 'the_cabin_game.exe')) { return $taskPackageRoot }
    $taskParent=Split-Path -Parent $taskPackageRoot
    if (Test-Path -LiteralPath (Join-Path $taskParent 'the_cabin_game.exe')) { return $taskParent }
    $taskDetected=Find-CabinGame -PackageRoot $taskPackageRoot
    if ($taskDetected) { return $taskDetected }
    $taskInput=Read-Host 'Steamの「ローカルファイルを閲覧」で開いたゲームフォルダーのパスを貼り付けてください'
    return [IO.Path]::GetFullPath($taskInput.Trim('"'))
}
function Check-Hash([string]$Path,[string]$Expected) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "ファイルがありません：$Path" }
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Expected) { throw "ファイルのバージョンまたは内容が一致しません：$Path。対応するゲームバージョンを使用してください。" }
}
function Package-Path([string]$Relative) {
    $taskResolved=[IO.Path]::GetFullPath((Join-Path $taskPackageRoot $Relative))
    if (-not $taskResolved.StartsWith($taskPackageRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'パッケージのパスが無効です' }
    return $taskResolved
}
$taskTemp=$null
try {
    $taskGameRoot=Resolve-GamePath
    if (-not (Test-Path -LiteralPath (Join-Path $taskGameRoot 'the_cabin_game.exe'))) { throw 'ゲームのルートフォルダーではありません。the_cabin_game.exeがあるフォルダーを選択してください。' }
    if (-not $VerifyOnly -and (Get-Process -Name 'the_cabin_game-Win64-Shipping' -ErrorAction SilentlyContinue)) { throw 'ゲームを完全に終了してからインストールしてください。' }
    foreach ($taskOriginal in $taskManifest.originalFiles) { Check-Hash (Join-Path $taskGameRoot $taskOriginal.path) $taskOriginal.sha256 }
    foreach ($taskPayload in $taskManifest.payloadFiles) { Check-Hash (Package-Path $taskPayload.path) $taskPayload.sha256 }
    $taskPatchNames=@('the_cabin_game-zhTW_P.pak','the_cabin_game-ja_P.pak','the_cabin_game-zhCN_P.pak')
    if ($taskManifest.patchFileName -notin $taskPatchNames) { throw 'パッチのファイル名が無効です' }
    $taskRepak=Package-Path 'tools\repak.exe'
    . (Package-Path 'scripts\DownloadRuntime.ps1')
    Ensure-CabinRuntime -ToolsPath (Split-Path -Parent $taskRepak) -Language $taskManifest.language
    Add-Type -Path (Package-Path 'scripts\ResourceTools.cs')
    $taskTemp=Join-Path ([IO.Path]::GetTempPath()) ('Cabin-zhTW-'+[Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $taskTemp | Out-Null
    $taskExtract=Join-Path $taskTemp 'original'
    $taskStage=Join-Path $taskTemp 'stage'
    $taskOriginalPak=Join-Path $taskGameRoot 'the_cabin_game\Content\Paks\the_cabin_game-Windows.pak'
    Write-Host '原版の言語リソースを読み込んでいます。初回はrepakの展開用コンポーネントをダウンロードする場合があります。'
    & $taskRepak unpack $taskOriginalPak --output $taskExtract --include 'Engine/Content/Localization/Engine/en/Engine.locres'
    if ($LASTEXITCODE -ne 0) { throw '原版の言語リソースを展開できません。ネットワーク接続と説明書を確認してください。原版のゲームファイルは変更していません。' }
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
        if ($taskCulture -notmatch '^[a-zA-Z-]+$') { throw '言語コードが無効です' }
        $taskDestination=Join-Path $taskStage "Engine\Content\Localization\Engine\$taskCulture\Engine.locres"
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $taskDestination) | Out-Null
        Copy-Item -LiteralPath $taskEnglish -Destination $taskDestination
    }
    foreach ($taskFontPath in $taskManifest.fontPaths) {
        $taskDestination=[IO.Path]::GetFullPath((Join-Path $taskStage $taskFontPath))
        if (-not $taskDestination.StartsWith($taskStage+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'フォントの保存先が無効です' }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $taskDestination) | Out-Null
        $taskFontSource='data\CabinFont.ttf'
        if ($taskFontPath -eq 'the_cabin_game/Content/MenuContent/Widgets/Achafont.ufont') { $taskFontSource='data\Achafont50.ttf' }
        Copy-Item -LiteralPath (Package-Path $taskFontSource) -Destination $taskDestination
    }
    $taskBuiltPak=Join-Path $taskTemp $taskManifest.patchFileName
    & $taskRepak pack $taskStage $taskBuiltPak --version V11 --compression Zlib
    if ($LASTEXITCODE -ne 0) { throw 'パッチの作成に失敗しました。原版のゲームファイルは変更していません。' }
    $taskVerify=Join-Path $taskTemp 'verify'
    & $taskRepak unpack $taskBuiltPak --output $taskVerify
    if ($LASTEXITCODE -ne 0) { throw 'パッチの検証に失敗しました' }
    foreach ($taskFile in (Get-ChildItem -LiteralPath $taskStage -Recurse -File)) {
        $taskRelative=$taskFile.FullName.Substring($taskStage.Length+1)
        Check-Hash (Join-Path $taskVerify $taskRelative) (Get-FileHash -LiteralPath $taskFile.FullName -Algorithm SHA256).Hash
    }
    . (Package-Path 'scripts\LayoutPatch.ps1')
    Build-CabinLayout -GameRoot $taskGameRoot -PackageRoot $taskPackageRoot -OutputRoot $taskTemp
    if ($VerifyOnly) {
        if ($VerificationOutput) { Copy-Item -LiteralPath $taskBuiltPak -Destination ([IO.Path]::GetFullPath($VerificationOutput)) -Force; foreach ($taskName in @('the_cabin_game-language-layout_P.pak','the_cabin_game-language-layout_P.utoc','the_cabin_game-language-layout_P.ucas')) { Copy-Item -LiteralPath (Join-Path $taskTemp $taskName) -Destination (Join-Path (Split-Path -Parent ([IO.Path]::GetFullPath($VerificationOutput))) $taskName) -Force } }
        Write-Host "検証成功：$($taskEntries.Count)件の翻訳、$($taskTotal)件の言語リソース。まだインストールしていません。"
        exit 0
    }
    # All preparation and validation finish before touching the existing mod.
    $taskPaks=Join-Path $taskGameRoot 'the_cabin_game\Content\Paks'
    $taskTarget=Join-Path $taskPaks $taskManifest.patchFileName
    $taskPending=Join-Path $taskPaks ('cabin-zhTW-'+[Guid]::NewGuid().ToString('N')+'.tmp')
    $taskMovedBackups=@()
    $taskLayoutPending=@()
    foreach ($taskName in @('the_cabin_game-language-layout_P.pak','the_cabin_game-language-layout_P.utoc','the_cabin_game-language-layout_P.ucas')) {
        $taskLayoutPending+=@{source=(Join-Path $taskTemp $taskName);pending=(Join-Path $taskPaks ('cabin-layout-'+[Guid]::NewGuid().ToString('N')+'.tmp'));target=(Join-Path $taskPaks $taskName)}
    }
    $taskInstalled=@()
    Copy-Item -LiteralPath $taskBuiltPak -Destination $taskPending
    try {
        foreach ($taskLayoutFile in $taskLayoutPending) { Copy-Item -LiteralPath $taskLayoutFile.source -Destination $taskLayoutFile.pending }
        foreach ($taskName in ($taskPatchNames+@('the_cabin_game-language-layout_P.pak','the_cabin_game-language-layout_P.utoc','the_cabin_game-language-layout_P.ucas','the_cabin_game-layout-test_P.pak','the_cabin_game-layout-test_P.utoc','the_cabin_game-layout-test_P.ucas'))) {
            $taskPrevious=Join-Path $taskPaks $taskName
            if (Test-Path -LiteralPath $taskPrevious) {
                $taskBackupRoot=Join-Path $taskGameRoot 'zhTW-backups'
                New-Item -ItemType Directory -Force -Path $taskBackupRoot | Out-Null
                $taskBackup=Join-Path $taskBackupRoot ($taskName+'-'+[Guid]::NewGuid().ToString('N')+'.disabled')
                Move-Item -LiteralPath $taskPrevious -Destination $taskBackup
                $taskMovedBackups+=@{original=$taskPrevious;backup=$taskBackup}
            }
        }
        foreach ($taskLayoutFile in $taskLayoutPending) { Move-Item -LiteralPath $taskLayoutFile.pending -Destination $taskLayoutFile.target; $taskInstalled+=$taskLayoutFile.target }
        Move-Item -LiteralPath $taskPending -Destination $taskTarget
        $taskInstalled+=$taskTarget
    } catch {
        foreach ($taskNew in $taskInstalled) { if (Test-Path -LiteralPath $taskNew) { Remove-Item -LiteralPath $taskNew -Force } }
        foreach ($taskLayoutFile in $taskLayoutPending) { if (Test-Path -LiteralPath $taskLayoutFile.pending) { Remove-Item -LiteralPath $taskLayoutFile.pending -Force } }
        foreach ($taskMoved in $taskMovedBackups) {
            if (-not (Test-Path -LiteralPath $taskMoved.original)) { Move-Item -LiteralPath $taskMoved.backup -Destination $taskMoved.original }
        }
        if (Test-Path -LiteralPath $taskPending) { Remove-Item -LiteralPath $taskPending -Force }
        throw
    }
    Write-Host ('インストール完了：'+$taskManifest.languageName+'。通常どおりSteamから起動してください。') -ForegroundColor Green
    Write-Host '原版のゲームパッケージは変更していません。英語に戻す場合はUninstall.cmdを実行してください。'
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
