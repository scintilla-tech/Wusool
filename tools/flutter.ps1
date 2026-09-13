# WASL project-local Flutter wrapper (Windows PowerShell 5.1+).
# Discovers the existing Flutter SDK + toolchain (JDK 21 / Android SDK / pub cache)
# under the SnapSortTools directories used on this machine, then invokes flutter.
#
# Usage: .\tools\flutter.ps1 <flutter-args...>
#   e.g. .\tools\flutter.ps1 devices
#        .\tools\flutter.ps1 analyze
$ErrorActionPreference = 'Stop'

function Get-WaslToolRoots {
    $roots = @()
    if ($env:USERPROFILE) {
        $packages = Join-Path $env:USERPROFILE 'AppData/Local/Packages'
        if (Test-Path -LiteralPath $packages -PathType Container) {
            foreach ($pkg in @(Get-ChildItem -LiteralPath $packages -Directory -Filter 'OpenAI.Codex_*' -ErrorAction SilentlyContinue | Sort-Object Name)) {
                $roots += Join-Path $pkg.FullName 'LocalCache/Local/SnapSortTools'
            }
        }
        $roots += Join-Path $env:USERPROFILE 'AppData/Local/SnapSortTools'
    }
    if ($env:LOCALAPPDATA) { $roots += Join-Path $env:LOCALAPPDATA 'SnapSortTools' }
    $roots | Select-Object -Unique
}

function Find-FlutterBat {
    $cmd = Get-Command flutter.bat -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    foreach ($root in @(Get-WaslToolRoots)) {
        $candidate = Join-Path $root 'flutter/bin/flutter.bat'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    return $null
}

$previous = @{}
foreach ($name in @('JAVA_HOME', 'ANDROID_SDK_ROOT', 'ANDROID_HOME', 'PUB_CACHE', 'PATH')) {
    $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

function Restore-Env {
    foreach ($name in $previous.Keys) {
        if ($null -eq $previous[$name]) {
            Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
        } else {
            [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
        }
    }
}

$code = 1
try {
    $flutter = Find-FlutterBat
    if (-not $flutter) { throw 'Flutter SDK not found. Install Flutter or add flutter/bin to PATH.' }

    $managedRoot = $null
    foreach ($root in @(Get-WaslToolRoots)) {
        if ((Join-Path $root 'flutter/bin/flutter.bat') -eq $flutter) { $managedRoot = $root; break }
    }

    # Locate a JDK 21 (SnapSortTools/java/**) if present.
    if ($managedRoot) {
        $javaRoot = Join-Path $managedRoot 'java'
        if (Test-Path -LiteralPath $javaRoot -PathType Container) {
            $jdk = Get-ChildItem -LiteralPath $javaRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
            if ($jdk -and (Test-Path -LiteralPath (Join-Path $jdk.FullName 'bin/java.exe') -PathType Leaf)) {
                $env:JAVA_HOME = $jdk.FullName
            }
        }
        $sdkRoot = Join-Path $managedRoot 'android-sdk'
        if (Test-Path -LiteralPath $sdkRoot -PathType Container) {
            $env:ANDROID_SDK_ROOT = $sdkRoot
            $env:ANDROID_HOME = $sdkRoot
        }
        if (-not $env:PUB_CACHE) { $env:PUB_CACHE = Join-Path $managedRoot 'pub-cache' }
    }

    $env:PATH = (Split-Path -Parent $flutter) + ';' + $env:PATH
    & $flutter @args
    $code = $LASTEXITCODE
} catch {
    Write-Error -Message $_.Exception.Message -ErrorAction Continue
} finally {
    Restore-Env
}
exit $code
