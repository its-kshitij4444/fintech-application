# ============================================
# build.ps1 - One-click build and deploy script
# Run from project root: .\build.ps1
# ============================================

$ProjectRoot = $PSScriptRoot
$SrcJava = "$ProjectRoot\src\main\java\livepricetracker\*.java"
$Libs = "$ProjectRoot\src\main\webapp\WEB-INF\lib\*"
$BuildClasses = "$ProjectRoot\build\classes"
$WebInfClasses = "$ProjectRoot\src\main\webapp\WEB-INF\classes\livepricetracker"
$WebApp = "$ProjectRoot\src\main\webapp"
$WarFile = "$ProjectRoot\app.war"

Write-Host ""
Write-Host "Step 1: Compiling Java files..." -ForegroundColor Cyan
javac --release 17 -cp "$Libs;$BuildClasses" -d $BuildClasses $SrcJava

if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: Compilation failed! Fix errors above." -ForegroundColor Red
    exit 1
}
Write-Host "OK: Compilation successful!" -ForegroundColor Green

Write-Host ""
Write-Host "Step 2: Copying classes to WEB-INF..." -ForegroundColor Cyan
if (Test-Path $WebInfClasses) {
    Remove-Item -Recurse -Force $WebInfClasses
}
New-Item -ItemType Directory -Force $WebInfClasses | Out-Null
Copy-Item "$BuildClasses\livepricetracker\*" $WebInfClasses
Write-Host "OK: Classes copied!" -ForegroundColor Green

Write-Host ""
Write-Host "Step 3: Building app.war..." -ForegroundColor Cyan
Set-Location $WebApp
jar -cvf $WarFile . | Out-Null
Set-Location $ProjectRoot
Write-Host "OK: app.war created!" -ForegroundColor Green

Write-Host ""
Write-Host "Step 4: Pushing to GitHub..." -ForegroundColor Cyan
git add app.war
$msg = Read-Host "Enter commit message (or press Enter for default)"
if ([string]::IsNullOrWhiteSpace($msg)) { $msg = "Rebuild app.war" }
git commit -m $msg
git push

Write-Host ""
Write-Host "Done! Render will auto-deploy shortly." -ForegroundColor Green