# SysAdmin Toolkit

Набор PowerShell-скриптов для диагностики Windows 11.

## Требования

- Windows 11
- PowerShell 7
- Права администратора для некоторых диагностических операций

## Скрипты

### Get-SystemHealth.ps1

Собирает информацию о системе:
- Версия Windows и время работы
- Использование оперативной памяти
- Состояние дисков
- Сетевые адаптеры
- Процессы с наибольшим потреблением памяти

Запуск:

```powershell
.\Scripts\Get-SystemHealth.ps1
```

### Get-NetworkDiagnostics.ps1

Проверяет сетевые адаптеры, IP-конфигурацию,
маршруты, разрешение DNS-имён и доступность TCP-портов.

Пример:

```powershell
.\Scripts\Get-NetworkDiagnostics.ps1 `
    -Target microsoft.com `
    -Port 443
```

Проверка удалённого компьютера:

```powershell
.\Scripts\Get-NetworkDiagnostics.ps1 `
    -Target 192.168.130.251 `
    -Port 22,3389
```

### Get-ServiceHealth.ps1

Проверяет основные службы Windows и показывает
ошибки в системном журнале и журнале приложений.

Пример:

```powershell
.\Scripts\Get-ServiceHealth.ps1 `
    -Hours 24 `
    -MaxEvents 15
```

## Git

Проверка состояния репозитория:

```powershell
git status
```

История изменений:

```powershell
git log --oneline
```

## Безопасность

Скрипты предназначены для диагностики.
Перед изменением системных настроек, служб
или драйверов необходимо отдельно оценить последствия.

Не храните в репозитории пароли, приватные SSH-ключи
и другие секретные данные.

## Testing

Automated tests use Pester.

Run from the repository root in PowerShell 7:

```powershell
Import-Module Pester
Invoke-Pester -Path .\Tests\SysAdminToolkit.Tests.ps1 -Output Detailed
```
