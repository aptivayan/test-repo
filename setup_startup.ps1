# setup_startup.ps1
# タイピング練習アプリをWindowsログオン時に自動起動するよう
# タスクスケジューラに登録します。管理者権限で実行してください。

$ErrorActionPreference = "Stop"
$TaskName  = "TypingPracticeEnforcer"

$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnforcerPath = Join-Path $ScriptDir "typing_enforcer.ps1"

if (-not (Test-Path $EnforcerPath)) {
    Write-Error "typing_enforcer.ps1 が見つかりません: $EnforcerPath"
    exit 1
}

Write-Host "スクリプト: $EnforcerPath"

# 既存タスクがあれば先に削除
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

$PwshPath = (Get-Command pwsh.exe -ErrorAction SilentlyContinue)?.Source
if (-not $PwshPath) { $PwshPath = "powershell.exe" }

$psArgs = "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$EnforcerPath`""

$Action   = New-ScheduledTaskAction -Execute $PwshPath -Argument $psArgs
$Trigger  = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$Settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
    -MultipleInstances  IgnoreNew `
    -StartWhenAvailable

Register-ScheduledTask `
    -TaskName    $TaskName `
    -Action      $Action `
    -Trigger     $Trigger `
    -Settings    $Settings `
    -Description "ログオン時にタイピング練習を1分間強制するアプリ" |
    Out-Null

Write-Host ""
Write-Host "登録完了！" -ForegroundColor Green
Write-Host "タスク名  : $TaskName"
Write-Host "実行条件  : $env:USERNAME がログオンしたとき"
Write-Host "次回ログイン時から自動起動します。"
Write-Host ""
Write-Host "今すぐ動作確認する場合:"
Write-Host "  powershell -ExecutionPolicy Bypass -File `"$EnforcerPath`""
