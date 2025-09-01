cd C:\Users\matid\flostay
Write-Host "Arrêt des processus Java..." -ForegroundColor Yellow
Get-Process java -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host "Nettoyage du projet Flutter..." -ForegroundColor Yellow
flutter clean
Write-Host "Suppression du cache Gradle..." -ForegroundColor Yellow
Get-ChildItem $HOME\.gradle\caches -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
Write-Host "Suppression du dossier .gradle local..." -ForegroundColor Yellow
Remove-Item -Force -Recurse android\.gradle -ErrorAction SilentlyContinue
Write-Host "Réinstallation des dépendances..." -ForegroundColor Yellow
flutter pub get
Write-Host "Processus terminé! Essayez maintenant: flutter run" -ForegroundColor Green
