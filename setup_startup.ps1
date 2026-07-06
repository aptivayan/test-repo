# setup_startup.ps1
# タイピング練習アプリを、以下のタイミングで自動起動するよう
# タスクスケジューラに登録します。管理者権限で実行してください。
#   1. ログオン時
#   2. スリープ／休止からの復帰時   （← 今回追加。一番多いケース）
#   3. ロック解除時                 （← 復帰時にロック画面が出る設定向け）

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
$Action = New-ScheduledTaskAction -Execute $PwshPath -Argument $psArgs

# ---- トリガー1: ログオン時 ----
$trigLogon = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

# ---- トリガー2: スリープ／休止からの復帰時 ----
# 電源イベント（Power-Troubleshooter, EventID 1 = システムがスリープから再開）を拾う
$resumeXml = @"
<QueryList>
  <Query Id="0" Path="System">
    <Select Path="System">*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and EventID=1]]</Select>
  </Query>
</QueryList>
"@
$cimEvent  = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler
$trigResume = New-CimInstance -CimClass $cimEvent -ClientOnly
$trigResume.Enabled      = $true
$trigResume.Subscription = $resumeXml

# ---- トリガー3: ロック解除時 ----
# StateChange = 8 (TASK_SESSION_UNLOCK)
$cimSession = Get-CimClass -ClassName MSFT_TaskSessionStateChangeTrigger -Namespace Root/Microsoft/Windows/TaskScheduler
$trigUnlock = New-CimInstance -CimClass $cimSession -ClientOnly
$trigUnlock.Enabled     = $true
$trigUnlock.StateChange = 8
$trigUnlock.UserId      = $env:USERNAME

$Triggers = @($trigLogon, $trigResume, $trigUnlock)

$Settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
    -MultipleInstances  IgnoreNew `
    -StartWhenAvailable

Register-ScheduledTask `
    -TaskName    $TaskName `
    -Action      $Action `
    -Trigger     $Triggers `
    -Settings    $Settings `
    -Description "ログオン・スリープ復帰・ロック解除時にタイピング練習を1分間強制するアプリ" |
    Out-Null

Write-Host ""
Write-Host "登録完了！" -ForegroundColor Green
Write-Host "タスク名  : $TaskName"
Write-Host "実行条件  : $env:USERNAME の ログオン / スリープ復帰 / ロック解除 時"
Write-Host ""
Write-Host "動作確認（今すぐ手動起動）:"
Write-Host "  powershell -ExecutionPolicy Bypass -File `"$EnforcerPath`""
Write-Host "スリープ復帰の確認は、実際にスリープ→復帰させるのが確実です。"
