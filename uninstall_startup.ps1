# uninstall_startup.ps1
# タイピング練習アプリのスタートアップ登録を解除します。

$TaskName = "TypingPracticeEnforcer"

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "スタートアップから削除しました。" -ForegroundColor Yellow
} else {
    Write-Host "タスクが見つかりません（すでに削除済みです）。" -ForegroundColor Gray
}
