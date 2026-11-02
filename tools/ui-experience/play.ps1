param([string]$GodotPath = '', [string]$Save = '')
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$candidates = @($GodotPath, $env:GODOT_EXECUTABLE, 'E:\Program Files\Godot\Godot_v4.7.2-stable_win64.exe')
$engine = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
if (-not $engine) {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) { $engine = $command.Source }
}
if (-not $engine) { throw '未找到 Godot。请使用 -GodotPath 指定 Godot 4.7.2 可执行文件。' }
$arguments = @('--path', ('"' + $workspace + '"'), 'res://src/presentation/experience_root.tscn')
if ($Save) { $arguments += @('--', ('"--experience-save=' + $Save + '"')) }
Start-Process -FilePath $engine -ArgumentList $arguments
