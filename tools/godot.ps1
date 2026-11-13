# Runs Godot on this project with a time limit and without stdin (Windows PowerShell; the
# same as tools/godot.sh), so a stuck run (a script error before quit(), a dialog, a hanging
# import) can never block the terminal. Its output (stdout and stderr together) comes out
# line by line, so another script can read it (tests/run_integration_tests.ps1).
#
#   tools\godot.ps1 --headless --script tools/build/build_city.gd
#   $env:GODOT_TIMEOUT = 1200; tools\godot.ps1 --headless --import
#
# $env:GODOT: the Godot binary (else: godot / godot4 on the PATH, the console build first,
# then the usual places). $env:GODOT_TIMEOUT: seconds before the run is stopped (default
# 600); the exit code is then 124 and a message says so.
$root = Split-Path -Parent $PSScriptRoot
$limit = 600
if ($env:GODOT_TIMEOUT) { $limit = [int]$env:GODOT_TIMEOUT }

function Find-Godot {
	if ($env:GODOT) { return $env:GODOT }
	# the console build prints to the terminal; the plain one opens its own window for it
	foreach ($name in @('godot_console', 'godot4_console', 'godot', 'godot4')) {
		$found = Get-Command $name -ErrorAction SilentlyContinue
		if ($found) { return $found.Source }
	}
	$folders = @("$env:ProgramFiles\Godot", "$env:LOCALAPPDATA\Programs\Godot", "$env:USERPROFILE\scoop\apps\godot\current",
		"$env:USERPROFILE\Godot", "C:\Godot")
	foreach ($folder in $folders) {
		if (-not (Test-Path $folder)) { continue }
		$binaries = Get-ChildItem -Path $folder -Filter 'Godot*.exe' -ErrorAction SilentlyContinue | Sort-Object Name
		$console = $binaries | Where-Object { $_.Name -like '*console*' } | Select-Object -Last 1
		if ($console) { return $console.FullName }
		$plain = $binaries | Select-Object -Last 1
		if ($plain) { return $plain.FullName }
	}
	return $null
}

$godot = Find-Godot
if (-not $godot) {
	[Console]::Error.WriteLine('godot.ps1: Godot not found: set $env:GODOT to the Godot (console) executable')
	exit 127
}

# one command line for cmd, every argument quoted; cmd joins stderr into stdout (2>&1)
function Quote-Argument([string]$argument) {
	return '"' + ($argument -replace '"', '\"') + '"'
}
$arguments = @('--path', $root) + $args
$line = (Quote-Argument $godot) + ' ' + (($arguments | ForEach-Object { Quote-Argument $_ }) -join ' ')
$start = New-Object System.Diagnostics.ProcessStartInfo
$start.FileName = $env:ComSpec
$start.Arguments = '/d /s /c "' + $line + ' 2>&1"'
$start.UseShellExecute = $false
$start.RedirectStandardInput = $true
$start.RedirectStandardOutput = $true
$start.CreateNoWindow = $true
$process = [System.Diagnostics.Process]::Start($start)
$process.StandardInput.Close()

$deadline = (Get-Date).AddSeconds($limit)
$timed_out = $false
$reading = $process.StandardOutput.ReadLineAsync()
while ($true) {
	if ($reading.Wait(200)) {
		$text = $reading.Result
		if ($null -eq $text) { break }
		Write-Output $text
		$reading = $process.StandardOutput.ReadLineAsync()
	} elseif ((Get-Date) -gt $deadline) {
		$timed_out = $true
		# the whole tree: cmd and the Godot under it
		& taskkill /PID $process.Id /T /F 2>$null | Out-Null
		break
	}
}
if ($timed_out) {
	[Console]::Error.WriteLine("godot.ps1: Godot stopped after $limit s (time limit)")
	exit 124
}
$process.WaitForExit()
exit $process.ExitCode
