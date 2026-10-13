$Commands = @{
    "build-deps" = @("dart run build_runner build --delete-conflicting-outputs")
    "clean"    = @("flutter clean", "flutter pub get")
    "test"     = @("flutter run")
    "build"    = @("flutter build apk", "Move-Item -Path 'build\app\outputs\apk\release\app-release.apk' -Destination '.\ovkflutter.apk' -Force")
    "build_splash" = @("dart run flutter_native_splash:create")
}

$Action = $args[0]

if ($null -eq $Action) {
    Write-Host "Доступные команды:" -ForegroundColor Cyan
    $Commands.Keys | Sort-Object | ForEach-Object { Write-Host " - $_" }
    exit
}

if ($Commands.ContainsKey($Action)) {
    Write-Host "--- Выполняю: $Action ---" -ForegroundColor Green
    
    foreach ($Cmd in $Commands[$Action]) {
        Write-Host "> $Cmd" -ForegroundColor Gray
        Invoke-Expression $Cmd
    }
} else {
    Write-Host "Ошибка: Команда '$Action' не найдена." -ForegroundColor Red
    exit 1
}