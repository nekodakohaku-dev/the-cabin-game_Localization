param([string]$GamePath)
$ErrorActionPreference='Stop'
try {
    $taskPackageRoot=Split-Path -Parent $PSScriptRoot
    if (-not $GamePath) {
        if (Test-Path -LiteralPath (Join-Path $taskPackageRoot 'the_cabin_game.exe')) {$GamePath=$taskPackageRoot}
        elseif (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $taskPackageRoot) 'the_cabin_game.exe')) {$GamePath=Split-Path -Parent $taskPackageRoot}
        else {$GamePath=Read-Host '貼上含有 the_cabin_game.exe 的遊戲資料夾完整路徑'}
    }
    $taskGameRoot=[IO.Path]::GetFullPath($GamePath.Trim('"'))
    if (-not (Test-Path -LiteralPath (Join-Path $taskGameRoot 'the_cabin_game.exe'))) {throw '遊戲資料夾不正確'}
    if (Get-Process -Name 'the_cabin_game-Win64-Shipping' -ErrorAction SilentlyContinue) {throw '請先完全關閉遊戲'}
    $taskRemoved=0
    foreach ($taskName in @('the_cabin_game-zhTW_P.pak','the_cabin_game-ja_P.pak','the_cabin_game-zhCN_P.pak')) {
        $taskTarget=Join-Path $taskGameRoot ('the_cabin_game\Content\Paks\'+$taskName)
        if (Test-Path -LiteralPath $taskTarget) {
            $taskBackups=Join-Path $taskGameRoot 'zhTW-backups'
            New-Item -ItemType Directory -Force -Path $taskBackups | Out-Null
            Move-Item -LiteralPath $taskTarget -Destination (Join-Path $taskBackups ($taskName+'-'+[Guid]::NewGuid().ToString('N')+'.disabled'))
            $taskRemoved++
        }
    }
    if ($taskRemoved) { Write-Host '已停用語言補丁。重新從 Steam 啟動即可恢復原版英文。' -ForegroundColor Green }
    else { Write-Host '目前沒有啟用這份語言補丁。' }
    exit 0
} catch { Write-Host ('失敗：'+$_.Exception.Message) -ForegroundColor Red;exit 1 }
