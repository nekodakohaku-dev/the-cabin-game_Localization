function Build-CabinLayout([string]$GameRoot,[string]$PackageRoot,[string]$OutputRoot) {
    $taskRetoc=Join-Path $PackageRoot 'tools\retoc.exe'
    $taskClean=Join-Path $GameRoot ('Cabin-layout-build-'+[Guid]::NewGuid().ToString('N'))
    $taskOriginal=Join-Path $OutputRoot 'layout-original'
    $taskStage=Join-Path $OutputRoot 'layout-stage'
    $taskPaks=Join-Path $GameRoot 'the_cabin_game\Content\Paks'
    try {
        New-Item -ItemType Directory -Path $taskClean | Out-Null
        foreach ($taskName in @('global.utoc','global.ucas','the_cabin_game-Windows.utoc','the_cabin_game-Windows.ucas')) {
            # A same-volume hard link exposes only the original containers without copying 10 GB.
            New-Item -ItemType HardLink -Path (Join-Path $taskClean $taskName) -Target (Join-Path $taskPaks $taskName) | Out-Null
        }
        foreach ($taskFilter in @('WBP_Pause_Menu','LobbyCode_WBP','WBP_Spectate','MenuCardProfile_W','WBP_TempClueBoard','WBP_ManualPage_HowTo_02','WBP_ManualPage_ClueOverview','MenuCardProfile_WBP')) {
            & $taskRetoc to-legacy $taskClean $taskOriginal --filter $taskFilter --no-shaders --version UE5_5
            if ($LASTEXITCODE -ne 0) { throw 'Layout resource extraction failed.' }
        }
        $taskDelta=Get-Content (Join-Path $PackageRoot 'data\layout-delta.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($taskRow in $taskDelta.files) {
            $taskInput=[IO.Path]::GetFullPath((Join-Path $taskOriginal $taskRow.path))
            $taskOutput=[IO.Path]::GetFullPath((Join-Path $taskStage $taskRow.path))
            if (-not $taskInput.StartsWith($taskOriginal+'\',[StringComparison]::OrdinalIgnoreCase) -or -not $taskOutput.StartsWith($taskStage+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid layout path.' }
            Check-Hash $taskInput $taskRow.baseSha256
            $taskBytes=[IO.File]::ReadAllBytes($taskInput)
            $taskStream=New-Object IO.MemoryStream
            try {
                foreach ($taskOp in $taskRow.operations) {
                    if ($taskOp.kind -eq 'copy') {
                        if ($taskOp.offset -lt 0 -or $taskOp.length -lt 0 -or ($taskOp.offset+$taskOp.length) -gt $taskBytes.Length) { throw 'Invalid layout copy range.' }
                        $taskStream.Write($taskBytes,[int]$taskOp.offset,[int]$taskOp.length)
                    } elseif ($taskOp.kind -eq 'insert') {
                        $taskInsert=[Convert]::FromBase64String($taskOp.data)
                        $taskStream.Write($taskInsert,0,$taskInsert.Length)
                    } else { throw 'Invalid layout operation.' }
                }
                New-Item -ItemType Directory -Path (Split-Path -Parent $taskOutput) -Force | Out-Null
                [IO.File]::WriteAllBytes($taskOutput,$taskStream.ToArray())
            } finally { $taskStream.Dispose() }
            Check-Hash $taskOutput $taskRow.targetSha256
        }
        $taskLayout=Join-Path $OutputRoot 'the_cabin_game-language-layout_P.utoc'
        & $taskRetoc to-zen $taskStage $taskLayout --version UE5_5
        if ($LASTEXITCODE -ne 0) { throw 'Layout packaging failed.' }
        & $taskRetoc verify $taskLayout
        if ($LASTEXITCODE -ne 0) { throw 'Layout container verification failed.' }
        # Unreal mounts the matching IoStore files alongside this PAK.
        $taskLayoutPak=Join-Path $OutputRoot 'the_cabin_game-language-layout_P.pak'
        $taskRepak=Join-Path $PackageRoot 'tools\repak.exe'
        & $taskRepak pack $taskStage $taskLayoutPak --version V11 --compression Zlib
        if ($LASTEXITCODE -ne 0) { throw 'Layout PAK packaging failed.' }
        $taskLayoutVerify=Join-Path $OutputRoot 'layout-pak-verify'
        & $taskRepak unpack $taskLayoutPak --output $taskLayoutVerify
        if ($LASTEXITCODE -ne 0) { throw 'Layout PAK readback failed.' }
        foreach ($taskFile in (Get-ChildItem -LiteralPath $taskStage -Recurse -File)) {
            $taskRelative=$taskFile.FullName.Substring($taskStage.Length+1)
            Check-Hash (Join-Path $taskLayoutVerify $taskRelative) (Get-FileHash -LiteralPath $taskFile.FullName -Algorithm SHA256).Hash
        }
        foreach ($taskExt in @('pak','utoc','ucas')) { if (-not (Test-Path (Join-Path $OutputRoot ('the_cabin_game-language-layout_P.'+$taskExt)))) { throw 'Missing layout output.' } }
    } finally {
        if ($taskClean.StartsWith($GameRoot+'\',[StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $taskClean) -match '^Cabin-layout-build-[a-f0-9]{32}$' -and (Test-Path $taskClean)) { Remove-Item -LiteralPath $taskClean -Recurse -Force }
    }
}
