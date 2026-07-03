# Install-MarkItDown.ps1
# Installs Microsoft MarkItDown for Windows using a dedicated Python virtual environment.
# Uses Python 3.10 through 3.13 only.
# Avoids Python 3.14 due to current dependency problems.
# Optionally installs FFmpeg to avoid pydub audio/video warnings.
# Adds a Windows right-click menu option named "MarkItDown" for converting files to Markdown.

[CmdletBinding()]
param(
    [string]$InstallRoot = "$env:USERPROFILE\MarkItDown",
    [switch]$SkipPythonInstall,
    [switch]$NoPathUpdate,
    [switch]$SkipFFmpegInstall
)

$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Message)

    Write-Host ""
    Write-Host "==== $Message ====" -ForegroundColor Cyan
}

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [string[]]$Arguments = @(),

        [Parameter(Mandatory = $true)]
        [string]$FailureMessage,

        [switch]$IgnoreFailure
    )

    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()

    try {
        $argLine = ($Arguments | ForEach-Object {
            if ($_ -match '\s') {
                '"' + ($_ -replace '"', '\"') + '"'
            }
            else {
                $_
            }
        }) -join " "

        $process = Start-Process `
            -FilePath $FilePath `
            -ArgumentList $argLine `
            -NoNewWindow `
            -Wait `
            -PassThru `
            -RedirectStandardOutput $stdoutFile `
            -RedirectStandardError $stderrFile

        $stdout = Get-Content -Path $stdoutFile -Raw -ErrorAction SilentlyContinue
        $stderr = Get-Content -Path $stderrFile -Raw -ErrorAction SilentlyContinue

        if ($stdout) {
            Write-Host $stdout.TrimEnd()
        }

        if ($stderr) {
            Write-Host $stderr.TrimEnd() -ForegroundColor Yellow
        }

        if ($process.ExitCode -ne 0 -and -not $IgnoreFailure) {
            throw "$FailureMessage Exit code: $($process.ExitCode)"
        }

        return $process.ExitCode
    }
    finally {
        Remove-Item -Path $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
    }
}

function Test-PythonExe {
    param([string]$PythonExe)

    try {
        $version = & $PythonExe -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>$null

        if (-not $version) {
            return $false
        }

        $parts = $version.Split(".")
        $major = [int]$parts[0]
        $minor = [int]$parts[1]

        if ($major -eq 3 -and $minor -ge 10 -and $minor -le 13) {
            return $true
        }

        return $false
    }
    catch {
        return $false
    }
}

function Get-PythonVersion {
    param([string]$PythonExe)

    try {
        return & $PythonExe -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>$null
    }
    catch {
        return $null
    }
}

function Get-GoodPython {
    Write-Section "Checking for Python 3.10 through 3.13"

    $preferredVersions = @("3.12", "3.13", "3.11", "3.10")
    $pyLauncher = Get-Command py.exe -ErrorAction SilentlyContinue

    if ($pyLauncher) {
        foreach ($ver in $preferredVersions) {
            try {
                $exe = & py "-$ver" -c "import sys; print(sys.executable)" 2>$null | Select-Object -First 1

                if ($exe -and (Test-Path -LiteralPath $exe -PathType Leaf) -and (Test-PythonExe -PythonExe $exe)) {
                    $actualVersion = Get-PythonVersion -PythonExe $exe
                    Write-Host "Using Python $actualVersion at: $exe" -ForegroundColor Green
                    return [string]$exe
                }
            }
            catch {
                # Keep checking other versions.
            }
        }
    }

    $pythonCmd = Get-Command python.exe -ErrorAction SilentlyContinue

    if ($pythonCmd -and (Test-PythonExe -PythonExe $pythonCmd.Source)) {
        $actualVersion = Get-PythonVersion -PythonExe $pythonCmd.Source
        Write-Host "Using Python $actualVersion at: $($pythonCmd.Source)" -ForegroundColor Green
        return [string]$pythonCmd.Source
    }

    $knownPaths = @(
        "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python310\python.exe",
        "$env:ProgramFiles\Python312\python.exe",
        "$env:ProgramFiles\Python313\python.exe",
        "$env:ProgramFiles\Python311\python.exe",
        "$env:ProgramFiles\Python310\python.exe"
    )

    foreach ($path in $knownPaths) {
        if ((Test-Path -LiteralPath $path -PathType Leaf) -and (Test-PythonExe -PythonExe $path)) {
            $actualVersion = Get-PythonVersion -PythonExe $path
            Write-Host "Using Python $actualVersion at: $path" -ForegroundColor Green
            return [string]$path
        }
    }

    return $null
}

function Install-Python312 {
    if ($SkipPythonInstall) {
        throw "Python 3.10 through 3.13 was not found. Install Python 3.12 manually, then rerun this script."
    }

    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue

    if (-not $winget) {
        throw "Python 3.10 through 3.13 was not found, and winget is not available. Install Python 3.12 manually, then rerun this script."
    }

    Write-Section "Installing Python 3.12 using winget"

    $null = Invoke-ExternalCommand `
        -FilePath "winget.exe" `
        -Arguments @(
            "install",
            "--exact",
            "--id", "Python.Python.3.12",
            "--source", "winget",
            "--accept-package-agreements",
            "--accept-source-agreements"
        ) `
        -FailureMessage "winget failed to install Python 3.12."

    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"

    $foundPython = Get-GoodPython

    if ($foundPython) {
        return [string]$foundPython
    }

    return $null
}

function Resolve-CleanPythonPath {
    param(
        [Parameter(Mandatory = $true)]
        $PythonCandidate
    )

    $cleanPath = @($PythonCandidate) |
        Where-Object {
            $_ -is [string] -and
            $_.Trim() -ne "" -and
            (Test-Path -LiteralPath $_ -PathType Leaf)
        } |
        Select-Object -First 1

    if (-not $cleanPath) {
        return $null
    }

    return [string]$cleanPath
}

function Test-FFmpeg {
    $ffmpeg = Get-Command ffmpeg.exe -ErrorAction SilentlyContinue

    if ($ffmpeg) {
        return $true
    }

    return $false
}

function Install-FFmpeg {
    if ($SkipFFmpegInstall) {
        Write-Host "Skipping FFmpeg install because -SkipFFmpegInstall was used." -ForegroundColor Yellow
        return
    }

    if (Test-FFmpeg) {
        Write-Host "FFmpeg already appears to be installed." -ForegroundColor Green
        return
    }

    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue

    if (-not $winget) {
        Write-Host "winget is not available. Skipping FFmpeg install." -ForegroundColor Yellow
        Write-Host "MarkItDown can still work for PDFs, Word docs, Excel files, PowerPoint files, and text files."
        Write-Host "Audio/video conversion may complain until FFmpeg is installed."
        return
    }

    Write-Section "Installing FFmpeg using winget"

    $exitCode = Invoke-ExternalCommand `
        -FilePath "winget.exe" `
        -Arguments @(
            "install",
            "--exact",
            "--id", "Gyan.FFmpeg",
            "--source", "winget",
            "--accept-package-agreements",
            "--accept-source-agreements"
        ) `
        -FailureMessage "winget failed to install FFmpeg." `
        -IgnoreFailure

    if ($exitCode -ne 0) {
        Write-Host "FFmpeg install did not complete. Continuing anyway." -ForegroundColor Yellow
        Write-Host "This is not fatal for normal document conversion."
        return
    }

    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"

    if (Test-FFmpeg) {
        Write-Host "FFmpeg installed successfully." -ForegroundColor Green
    }
    else {
        Write-Host "FFmpeg may have installed, but it was not found in PATH yet." -ForegroundColor Yellow
        Write-Host "Close and reopen PowerShell after this script finishes."
    }
}

function Add-ToUserPath {
    param([string]$Folder)

    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")

    if (-not $currentPath) {
        $currentPath = ""
    }

    $parts = $currentPath.Split(";") | Where-Object { $_ -and $_.Trim() -ne "" }

    $alreadyExists = $false

    foreach ($part in $parts) {
        if ($part.TrimEnd("\") -ieq $Folder.TrimEnd("\")) {
            $alreadyExists = $true
            break
        }
    }

    if (-not $alreadyExists) {
        $newPath = if ($currentPath.Trim()) { "$currentPath;$Folder" } else { $Folder }
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        $env:Path = "$Folder;$env:Path"

        Write-Host "Added to user PATH: $Folder" -ForegroundColor Green
    }
    else {
        Write-Host "Already in user PATH: $Folder" -ForegroundColor Green
    }
}

function Install-MarkItDownContextMenu {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallRoot,

        [Parameter(Mandatory = $true)]
        [string]$VenvMarkItDown
    )

    Write-Section "Installing Windows right-click menu"

    if (-not (Test-Path -LiteralPath $VenvMarkItDown -PathType Leaf)) {
        throw "Cannot install right-click menu because MarkItDown was not found: $VenvMarkItDown"
    }

    New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null

    $ContextScriptPath = Join-Path $InstallRoot "Convert-With-MarkItDown.ps1"

    $contextScriptContent = @'
param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile
)

$ErrorActionPreference = "Stop"

try {
    if (-not (Test-Path -LiteralPath $InputFile -PathType Leaf)) {
        throw "Input file was not found: $InputFile"
    }

    $sourceItem = Get-Item -LiteralPath $InputFile
    $markitdownExe = Join-Path $PSScriptRoot ".venv\Scripts\markitdown.exe"

    if (-not (Test-Path -LiteralPath $markitdownExe -PathType Leaf)) {
        throw "MarkItDown executable was not found: $markitdownExe"
    }

    $outputFile = Join-Path $sourceItem.DirectoryName ($sourceItem.BaseName + ".md")

    if ($sourceItem.FullName -ieq $outputFile) {
        $outputFile = Join-Path $sourceItem.DirectoryName ($sourceItem.BaseName + ".converted.md")
    }

    & $markitdownExe $sourceItem.FullName -o $outputFile

    if ($LASTEXITCODE -ne 0) {
        throw "MarkItDown failed with exit code $LASTEXITCODE."
    }

    if (-not (Test-Path -LiteralPath $outputFile -PathType Leaf)) {
        throw "MarkItDown finished, but the output file was not created: $outputFile"
    }

    Add-Type -AssemblyName System.Windows.Forms

    [System.Windows.Forms.MessageBox]::Show(
        "Created:`r`n$outputFile",
        "MarkItDown complete",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}
catch {
    Add-Type -AssemblyName System.Windows.Forms

    [System.Windows.Forms.MessageBox]::Show(
        $_.Exception.Message,
        "MarkItDown failed",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null

    exit 1
}
'@

    Set-Content -Path $ContextScriptPath -Value $contextScriptContent -Encoding UTF8

    $ShellKey = "HKCU:\Software\Classes\*\shell\MarkItDown"
    $CommandKey = "$ShellKey\command"

    New-Item -Path $ShellKey -Force | Out-Null
    New-Item -Path $CommandKey -Force | Out-Null

    New-ItemProperty -Path $ShellKey -Name "MUIVerb" -Value "MarkItDown" -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $ShellKey -Name "Icon" -Value "powershell.exe" -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $ShellKey -Name "Position" -Value "Top" -PropertyType String -Force | Out-Null

    $CommandValue = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ContextScriptPath`" `"%1`""

    Set-Item -Path $CommandKey -Value $CommandValue

    Write-Host "Right-click menu installed successfully." -ForegroundColor Green
    Write-Host "Use: Right-click a file > Show more options > MarkItDown"
}

Write-Section "Starting MarkItDown install"

$PythonExe = Get-GoodPython

if (-not $PythonExe) {
    $PythonExe = Install-Python312
}

$PythonExe = Resolve-CleanPythonPath -PythonCandidate $PythonExe

if (-not $PythonExe) {
    throw "Could not find or install a supported Python version. Use Python 3.12 for best results."
}

Write-Host "Final Python executable selected:"
Write-Host "  $PythonExe" -ForegroundColor Green

Write-Section "Creating install folder"

New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null

$VenvDir = Join-Path $InstallRoot ".venv"
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"
$VenvMarkItDown = Join-Path $VenvDir "Scripts\markitdown.exe"

if (-not (Test-Path -LiteralPath $VenvPython -PathType Leaf)) {
    Write-Host "Creating virtual environment at: $VenvDir"

    Invoke-ExternalCommand `
        -FilePath $PythonExe `
        -Arguments @("-m", "venv", $VenvDir) `
        -FailureMessage "Failed to create Python virtual environment."
}
else {
    Write-Host "Virtual environment already exists: $VenvDir"
}

Write-Section "Upgrading pip tools"

Invoke-ExternalCommand `
    -FilePath $VenvPython `
    -Arguments @("-m", "pip", "install", "--upgrade", "pip", "setuptools", "wheel", "--no-cache-dir") `
    -FailureMessage "pip tool upgrade failed."

Write-Section "Clearing pip cache"

Invoke-ExternalCommand `
    -FilePath $VenvPython `
    -Arguments @("-m", "pip", "cache", "purge") `
    -FailureMessage "pip cache purge failed." `
    -IgnoreFailure | Out-Null

Write-Section "Installing MarkItDown"

Invoke-ExternalCommand `
    -FilePath $VenvPython `
    -Arguments @("-m", "pip", "install", "--upgrade", "markitdown[all]", "--no-cache-dir") `
    -FailureMessage "MarkItDown pip install failed."

if (-not (Test-Path -LiteralPath $VenvMarkItDown -PathType Leaf)) {
    throw "MarkItDown installed, but markitdown.exe was not found where expected: $VenvMarkItDown"
}

Write-Section "Installing optional FFmpeg dependency"

Install-FFmpeg

Write-Section "Creating command launcher"

$CmdPath = Join-Path $InstallRoot "markitdown.cmd"

$cmdContent = @"
@echo off
setlocal
"%~dp0.venv\Scripts\markitdown.exe" %*
endlocal
"@

Set-Content -Path $CmdPath -Value $cmdContent -Encoding ASCII

Write-Host "Command launcher created:"
Write-Host "  $CmdPath" -ForegroundColor Green

Install-MarkItDownContextMenu -InstallRoot $InstallRoot -VenvMarkItDown $VenvMarkItDown

if (-not $NoPathUpdate) {
    Write-Section "Updating user PATH"
    Add-ToUserPath -Folder $InstallRoot
}

Write-Section "Testing MarkItDown"

$TestInput = Join-Path $InstallRoot "markitdown-test.txt"
$TestOutput = Join-Path $InstallRoot "markitdown-test.md"

"MarkItDown install test." | Set-Content -Path $TestInput -Encoding UTF8

# Suppress harmless dependency warnings during the basic text-file test.
$oldPythonWarnings = $env:PYTHONWARNINGS
$env:PYTHONWARNINGS = "ignore"

try {
    Invoke-ExternalCommand `
        -FilePath $CmdPath `
        -Arguments @($TestInput, "-o", $TestOutput) `
        -FailureMessage "MarkItDown test conversion failed."
}
finally {
    $env:PYTHONWARNINGS = $oldPythonWarnings
}

if (-not (Test-Path -LiteralPath $TestOutput -PathType Leaf)) {
    throw "Test conversion failed. MarkItDown did not create the test markdown file."
}

Write-Host ""
Write-Host "MarkItDown installed successfully." -ForegroundColor Green
Write-Host ""
Write-Host "Install folder:"
Write-Host "  $InstallRoot"
Write-Host ""
Write-Host "Python virtual environment:"
Write-Host "  $VenvDir"
Write-Host ""
Write-Host "Command launcher:"
Write-Host "  $CmdPath"
Write-Host ""
Write-Host "Right-click conversion script:"
Write-Host "  $(Join-Path $InstallRoot "Convert-With-MarkItDown.ps1")"
Write-Host ""
Write-Host "Right-click menu:"
Write-Host "  Right-click a file > Show more options > MarkItDown"
Write-Host ""
Write-Host "Test output:"
Write-Host "  $TestOutput"
Write-Host ""
Write-Host "Usage examples:"
Write-Host '  markitdown "C:\Path\To\File.pdf" -o "C:\Path\To\File.md"'
Write-Host '  markitdown "C:\Path\To\File.docx" -o "C:\Path\To\File.md"'
Write-Host '  markitdown "C:\Path\To\File.xlsx" -o "C:\Path\To\File.md"'
Write-Host '  markitdown "C:\Path\To\File.pptx" -o "C:\Path\To\File.md"'
Write-Host ""
Write-Host "If the markitdown command is not found right away, close and reopen PowerShell."
Write-Host "If FFmpeg was installed but not detected right away, close and reopen PowerShell."
Write-Host "If the right-click option does not appear immediately, restart File Explorer or sign out and back in."
