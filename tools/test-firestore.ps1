$ErrorActionPreference = 'Stop'
$workspacePath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue) {
  throw 'Port 8080 is already in use. Stop the existing emulator before running the isolated tests.'
}
$testStartedAt = Get-Date
$testExitCode = 1
Push-Location -LiteralPath $workspacePath
try {
  & firebase.cmd emulators:exec --project orglink-dev --only firestore 'node --test --test-concurrency=1 firebase/tests/profile.rules.test.mjs firebase/tests/organization.rules.test.mjs firebase/tests/event.rules.test.mjs tools/admin/provision-demo.emulator.test.mjs'
  $testExitCode = $LASTEXITCODE
} finally {
  # On Windows, a Java child can outlive the CLI shutdown. Clean up only test
  # emulator processes created by this invocation, using these repository rules.
  Get-CimInstance Win32_Process -Filter "Name = 'java.exe'" | Where-Object {
    $_.CreationDate -ge $testStartedAt -and
    $_.CommandLine -like '*cloud-firestore-emulator*' -and
    $_.CommandLine -like '*--project_id orglink-dev*' -and
    $_.CommandLine.Contains((Join-Path $workspacePath 'firebase\firebase.rules'))
  } | ForEach-Object { Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }
  Pop-Location
}
exit $testExitCode
