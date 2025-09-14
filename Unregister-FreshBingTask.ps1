# Unregister-FreshBingTask.ps1
$taskName = "FreshBing"

if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "🗑️ Завдання '$taskName' успішно видалено."
} else {
    Write-Host "ℹ️ Завдання '$taskName' не знайдено."
}
