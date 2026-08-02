param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $FlutterArgs
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$env:PUB_CACHE = Join-Path $ProjectRoot ".pub-cache"

New-Item -ItemType Directory -Force -Path $env:PUB_CACHE | Out-Null

& "C:\flutter-sdk\bin\flutter.bat" @FlutterArgs
exit $LASTEXITCODE
