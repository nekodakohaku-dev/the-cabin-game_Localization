function Ensure-CabinRuntime([string]$ToolsPath,[string]$Language='zhTW',
    [string]$Url='https://github.com/WorkingRobot/OodleUE/raw/refs/heads/main/Engine/Source/Programs/Shared/EpicGames.Oodle/Sdk/2.9.10/win/redist/oo2core_9_win64.dll',
    [string]$ExpectedHash='6f5d41a7892ea6b2db420f2458dad2f84a63901c9a93ce9497337b16c195f457') {
    $labels=@{
        zhTW=@('正在下載解壓縮元件','下載完成，正在驗證','元件已就緒','下載失敗，請檢查網路連線後重試','下載檔案驗證失敗')
        zhCN=@('正在下载解压缩组件','下载完成，正在验证','组件已就绪','下载失败，请检查网络连接后重试','下载文件验证失败')
        ja=@('展開用コンポーネントをダウンロード中','ダウンロード完了、検証中','コンポーネントの準備完了','ダウンロードに失敗しました。接続を確認して再試行してください','ダウンロードファイルの検証に失敗しました')
    }
    $text=$labels[$Language];if (-not $text) {$text=$labels.zhTW}
    $target=Join-Path $ToolsPath 'oo2core_9_win64.dll'
    if (Test-Path -LiteralPath $target) {
        if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $ExpectedHash) {throw $text[4]}
        Write-Host $text[2];return
    }
    $pending=Join-Path $ToolsPath ('oodle-'+[Guid]::NewGuid().ToString('N')+'.download')
    $response=$null;$stream=$null;$output=$null
    try {
        [Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Write-Host ($text[0]+' ...')
        Write-Progress -Id 9 -Activity $text[0] -Status '0 KB' -PercentComplete 0
        $request=[Net.WebRequest]::Create($Url);$request.Timeout=30000
        if ($request -is [Net.HttpWebRequest]) {$request.ReadWriteTimeout=30000;$request.UserAgent='CabinLocalizationInstaller/0.1.3'}
        $response=$request.GetResponse();$total=$response.ContentLength
        $stream=$response.GetResponseStream();$output=[IO.File]::Create($pending)
        $buffer=New-Object byte[] 32768;$received=0L;$lastPercent=-25;$lastLog=[DateTime]::UtcNow
        while (($count=$stream.Read($buffer,0,$buffer.Length)) -gt 0) {
            $output.Write($buffer,0,$count);$received+=$count
            $percent=-1;$status=('{0:N0} KB' -f ($received/1KB))
            if ($total -gt 0) {$percent=[Math]::Min(100,[int](100*$received/$total));$status=('{0}% ({1:N0}/{2:N0} KB)' -f $percent,($received/1KB),($total/1KB))}
            Write-Progress -Id 9 -Activity $text[0] -Status $status -PercentComplete $percent
            if (($percent -ge 0 -and $percent-$lastPercent -ge 25) -or ([DateTime]::UtcNow-$lastLog).TotalSeconds -ge 2) {
                Write-Host ($text[0]+': '+$status);$lastPercent=$percent;$lastLog=[DateTime]::UtcNow
            }
        }
        $output.Dispose();$output=$null
        if ($total -gt 0 -and $received -ne $total) {throw 'Incomplete download'}
        Write-Host $text[1]
        if ((Get-FileHash -LiteralPath $pending -Algorithm SHA256).Hash -ne $ExpectedHash) {throw $text[4]}
        Move-Item -LiteralPath $pending -Destination $target
        Write-Host $text[2]
    } catch {throw ($text[3]+': '+$_.Exception.Message)}
    finally {
        if ($output) {$output.Dispose()};if ($stream) {$stream.Dispose()};if ($response) {$response.Close()}
        Write-Progress -Id 9 -Activity $text[0] -Completed
        if (Test-Path -LiteralPath $pending) {Remove-Item -LiteralPath $pending -Force}
    }
}
