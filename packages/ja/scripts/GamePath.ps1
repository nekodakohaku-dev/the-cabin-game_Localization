function Test-CabinRoot([string]$Path) {
    return ($Path -and (Test-Path -LiteralPath (Join-Path $Path 'the_cabin_game.exe') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $Path 'the_cabin_game\Content\Paks\the_cabin_game-Windows.pak') -PathType Leaf))
}
function Find-CabinGame([string]$PackageRoot,[string[]]$SteamRoots) {
    # Local package placement, then Steam's registered game and library manifests.
    $localCandidates=@($PackageRoot,(Split-Path -Parent $PackageRoot))
    foreach ($candidate in $localCandidates) { if (Test-CabinRoot $candidate) { return [IO.Path]::GetFullPath($candidate) } }
    foreach ($reg in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 4406280','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 4406280')) {
        $item=Get-ItemProperty -LiteralPath $reg -ErrorAction SilentlyContinue
        if ($item -and $item.PSObject.Properties['InstallLocation']) {
            if (Test-CabinRoot $item.InstallLocation) { return [IO.Path]::GetFullPath($item.InstallLocation) }
        }
    }
    $roots=@($SteamRoots)
    foreach ($reg in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')) {
        $item=Get-ItemProperty -LiteralPath $reg -ErrorAction SilentlyContinue
        foreach ($property in @('SteamPath','InstallPath')) {
            if ($item -and $item.PSObject.Properties[$property]) { $roots+= [string]$item.$property }
        }
    }
    if (${env:ProgramFiles(x86)}) { $roots+=Join-Path ${env:ProgramFiles(x86)} 'Steam' }
    if ($env:ProgramFiles) { $roots+=Join-Path $env:ProgramFiles 'Steam' }
    $libraries=@($roots)
    foreach ($root in @($roots | Where-Object {$_} | Select-Object -Unique)) {
        $vdf=Join-Path $root 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) {
            $content=Get-Content -LiteralPath $vdf -Raw
            foreach ($match in [regex]::Matches($content,'"(?:path|[0-9]+)"\s+"([^"\r\n]+)"')) {
                $value=$match.Groups[1].Value.Replace('\\','\')
                if ([IO.Path]::IsPathRooted($value)) { $libraries+=$value }
            }
        }
    }
    $found=@()
    foreach ($library in @($libraries | Where-Object {$_} | Select-Object -Unique)) {
        $acf=Join-Path $library 'steamapps\appmanifest_4406280.acf'
        if (-not (Test-Path -LiteralPath $acf)) { continue }
        $content=Get-Content -LiteralPath $acf -Raw
        $match=[regex]::Match($content,'"installdir"\s+"([^"\r\n]+)"')
        if (-not $match.Success) { continue }
        $common=[IO.Path]::GetFullPath((Join-Path $library 'steamapps\common'))
        $candidate=[IO.Path]::GetFullPath((Join-Path $common $match.Groups[1].Value))
        if ($candidate.StartsWith($common+'\',[StringComparison]::OrdinalIgnoreCase) -and (Test-CabinRoot $candidate)) { $found+=$candidate }
    }
    $found=@($found | Select-Object -Unique)
    # If multiple installations are present, let the caller ask for an explicit path.
    if ($found.Count -eq 1) { return $found[0] }
    return $null
}
