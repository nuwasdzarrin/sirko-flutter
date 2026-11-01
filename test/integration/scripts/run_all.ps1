# Pembungkus PowerShell untuk run_all.sh (butuh Git for Windows).
# Pakai:  .\test\integration\scripts\run_all.ps1            # semua flow
#         .\test\integration\scripts\run_all.ps1 01 02 04   # sebagian
$bash = "C:\Program Files\Git\bin\bash.exe"
& $bash "$PSScriptRoot/run_all.sh" @args
exit $LASTEXITCODE
