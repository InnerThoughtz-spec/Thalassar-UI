param(
    [string]$WorkspacePath = 'C:\matcha\workspace',
    [string]$PythonPath,
    [ValidatePattern('^[A-Za-z0-9_-]+$')][string]$Prefix = 'Thalassar-UI',
    [switch]$Once
)
$ErrorActionPreference = 'Stop'
$helperPath = Join-Path $PSScriptRoot 'wheel_helper.py'
if (-not $PythonPath) {
    $pythonCommand = Get-Command python.exe -ErrorAction SilentlyContinue
    if (-not $pythonCommand) { throw 'Python 3.10+ was not found. Pass -PythonPath with its full path.' }
    $PythonPath = $pythonCommand.Source
}
if (-not (Test-Path -LiteralPath $PythonPath -PathType Leaf)) { throw "Python was not found at $PythonPath" }
if (-not (Test-Path -LiteralPath $WorkspacePath -PathType Container)) { throw "Matcha workspace was not found at $WorkspacePath" }
$pythonAbsolute = (Resolve-Path -LiteralPath $PythonPath).Path
$helperAbsolute = (Resolve-Path -LiteralPath $helperPath).Path
$workspaceAbsolute = (Resolve-Path -LiteralPath $WorkspacePath).Path
$arguments = @('"' + $helperAbsolute + '"', '--workspace', '"' + $workspaceAbsolute + '"', '--prefix', $Prefix)
if (-not $Once) { $arguments += '--watch' }
$process = Start-Process -FilePath $pythonAbsolute -ArgumentList $arguments -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru
Write-Output "UI wheel companion started (PID $($process.Id)). It idles between UI sessions."
