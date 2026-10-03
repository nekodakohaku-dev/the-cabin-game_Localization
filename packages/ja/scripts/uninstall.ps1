param([string]$GamePath)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'GamePath.ps1')
try {
    $taskPackageRoot=Split-Path -Parent $PSScriptRoot
    if (-not $GamePath) { $GamePath=Find-CabinGame -PackageRoot $taskPackageRoot }
    if (-not $GamePath) {
        if (Test-Path -LiteralPath (Join-Path $taskPackageRoot 'the_cabin_game.exe')) {$GamePath=$taskPackageRoot}
        elseif (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $taskPackageRoot) 'the_cabin_game.exe')) {$GamePath=Split-Path -Parent $taskPackageRoot}
        else {$GamePath=Read-Host 'the_cabin_game.exeがあるゲームフォルダーのパスを貼り付けてください'}
    }
    $taskGameRoot=[IO.Path]::GetFullPath($GamePath.Trim('"'))
    if (-not (Test-Path -LiteralPath (Join-Path $taskGameRoot 'the_cabin_game.exe'))) {throw 'ゲームフォルダーが正しくありません'}
    if (Get-Process -Name 'the_cabin_game-Win64-Shipping' -ErrorAction SilentlyContinue) {throw '先にゲームを完全に終了してください'}
    $taskRemoved=0
    foreach ($taskName in @('the_cabin_game-zhTW_P.pak','the_cabin_game-ja_P.pak','the_cabin_game-zhCN_P.pak','the_cabin_game-language-layout_P.pak','the_cabin_game-language-layout_P.utoc','the_cabin_game-language-layout_P.ucas','the_cabin_game-layout-test_P.pak','the_cabin_game-layout-test_P.utoc','the_cabin_game-layout-test_P.ucas')) {
        $taskTarget=Join-Path $taskGameRoot ('the_cabin_game\Content\Paks\'+$taskName)
        if (Test-Path -LiteralPath $taskTarget) {
            $taskBackups=Join-Path $taskGameRoot 'zhTW-backups'
            New-Item -ItemType Directory -Force -Path $taskBackups | Out-Null
            Move-Item -LiteralPath $taskTarget -Destination (Join-Path $taskBackups ($taskName+'-'+[Guid]::NewGuid().ToString('N')+'.disabled'))
            $taskRemoved++
        }
    }
    if ($taskRemoved) { Write-Host '言語パッチを無効にしました。Steamから再起動すると原版の英語表示に戻ります。' -ForegroundColor Green }
    else { Write-Host 'この言語パッチは現在有効になっていません。' }
    exit 0
} catch { Write-Host ('失敗：'+$_.Exception.Message) -ForegroundColor Red;exit 1 }
