# Register-FreshBingTask.ps1
$ErrorActionPreference = 'Stop'

# Директорія, де лежить цей реєстраційний скрипт
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Шлях до основного FreshBing скрипта (відносно цього файлу)
$scriptPath = Join-Path $scriptDir "FreshBing_2025.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Error "❌ Не знайдено файл FreshBing_2025.ps1 у $scriptDir"
    exit 1
}

# Шлях до поточної pwsh.exe (portable-friendly)
$pwshPath = Join-Path $PSHOME "pwsh.exe"

if (-not (Test-Path $pwshPath)) {
    Write-Error "❌ Не знайдено pwsh.exe у $PSHOME"
    exit 1
}

# Дія: запуск FreshBing_2025.ps1 у прихованому режимі
$action = New-ScheduledTaskAction -Execute $pwshPath -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""

# Тригери: щодня о 9:00 і при вході користувача
$triggerDaily = New-ScheduledTaskTrigger -Daily -At 9am
$triggerLogon = New-ScheduledTaskTrigger -AtLogOn

# Принципал: поточний користувач
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

# Реєстрація завдання
Register-ScheduledTask `
    -TaskName "FreshBing" `
    -Description "Daily Bing desktop wallpaper (PowerShell 7)" `
    -Action $action `
    -Trigger $triggerDaily, $triggerLogon `
    -Principal $principal `
    -Force

# Одразу запускаємо після реєстрації
Start-ScheduledTask -TaskName "FreshBing"

Write-Host "✅ Завдання 'FreshBing' успішно створено і запущено."
