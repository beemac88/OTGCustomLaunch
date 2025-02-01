# 1
$scriptUrl = "https://raw.githubusercontent.com/beemac88/OTGCustomLaunch/main/OTGCustomLaunch.ps1"
$waitTime = 30
$defaultInstallLocation = Select-String -Path "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\Config\Windows\GameUserSettings.ini" -Pattern "DefaultAppInstallLocation" | ForEach-Object { $_.Line.Split('=')[1].Trim() }

# 2
$gameInstallFolder = Get-ChildItem -Path $defaultInstallLocation -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object {
    Test-Path -Path (Join-Path -Path $_.FullName -ChildPath "start_offthegrid.exe")
} | Select-Object -First 1 -ExpandProperty FullName

if (-not $gameInstallFolder) {
    Write-Output "Game install folder not found. Please ensure the game is installed correctly."
    pause
    exit
} else {
    Write-Host "Game install folder found at " -NoNewline; Write-Host $gameInstallFolder -ForegroundColor Yellow
}

$gameBinariesPath = Join-Path -Path $gameInstallFolder -ChildPath "G01\Binaries\Win64"
$global:gameProcessPath = Get-ChildItem -Path $gameBinariesPath -Filter *.exe | Select-Object -First 1 -ExpandProperty FullName

if (-not $global:gameProcessPath) {
    Write-Output "Executable not found in $gameBinariesPath. Please ensure the game is installed correctly."
    pause
    exit
} else {
    Write-Host "Game executable found at " -NoNewline; Write-Host $global:gameProcessPath -ForegroundColor Yellow
}

$moviesPath = Join-Path -Path $gameInstallFolder -ChildPath "G01\Content\Movies"

# 3
foreach ($pattern in @("OTG*.mp4", "UE*.mp4")) {
    $filesToDelete = Get-ChildItem -Path $moviesPath -Filter $pattern
    foreach ($file in $filesToDelete) {
        Remove-Item -Path $file.FullName -Force
        Write-Host "Deleted file: $($file.FullName)"
    }
}

# 4
$offlineScriptPath = Join-Path -Path $gameInstallFolder -ChildPath "OTGCustomLaunch.ps1"
$fileInfo = Get-Item -Path $offlineScriptPath -ErrorAction SilentlyContinue
if ($fileInfo) {
    $fileDateModified = $fileInfo.LastWriteTime
} else {
    $fileDateModified = (Get-Date).AddDays(-1)
}

try {
    $latestScript = Invoke-WebRequest -Uri $scriptUrl -UseBasicParsing
    if ($latestScript.StatusCode -eq 200) {
        $latestContent = $latestScript.Content

        Set-Content -Path $offlineScriptPath -Value $latestContent -Force
        
        $newFileInfo = Get-Item -Path $offlineScriptPath
        $newFilePath = $newFileInfo.FullName
        $newFileDateModified = $newFileInfo.LastWriteTime

        Write-Host "" -NoNewline; Write-Host $newFilePath -ForegroundColor Yellow -NoNewline; Write-Host " updated as of " -NoNewline; Write-Host $newFileDateModified -ForegroundColor Yellow

        if ($fileDateModified -lt (Get-Date).AddSeconds(-30)) {
            Write-Host "Restarting script to execute the latest version as of " -NoNewline; Write-Host $fileDateModified -ForegroundColor Yellow
            Start-Sleep -Seconds 1
            Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$newFilePath`""
            exit
        }
    } else {
        Write-Output "Failed to download the latest script version. Status code: $($latestScript.StatusCode)"
        Start-Sleep -Seconds 10
    }
} catch {
    Write-Output "An error occurred while trying to update the script: $_"
    Start-Sleep -Seconds 10
}

# 5
$desktop = [System.Environment]::GetFolderPath('Desktop')
$shortcutName = "OTG Custom Launch.lnk"
$shortcutPath = Join-Path -Path $desktop -ChildPath $shortcutName
$targetPath = [System.Environment]::ExpandEnvironmentVariables("%systemroot%\System32\WindowsPowerShell\v1.0\powershell.exe")
$arguments = "-ExecutionPolicy Bypass -File `"$offlineScriptPath`""
$workingDirectory = (Get-Item -Path $targetPath).Directory.FullName

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $targetPath
$shortcut.Arguments = $arguments
$shortcut.IconLocation = $global:gameProcessPath
$shortcut.WorkingDirectory = $workingDirectory
$shortcut.Save()

$shortcutNameWithoutExt = $shortcutName -replace '\.lnk$', ''

if (Test-Path -Path $shortcutPath -NewerThan (Get-Date).AddSeconds(-10)) {
    Write-Host $shortcutNameWithoutExt -ForegroundColor Yellow -NoNewline
    Write-Host " shortcut exists on Desktop."
}

# 6
$monitor = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID | ForEach-Object {
    [System.Text.Encoding]::ASCII.GetString($_.UserFriendlyName -ne 0)
} | Where-Object { $_ -eq "AW3423DWF" }

if ($monitor) {
    Write-Host $monitor -ForegroundColor Yellow -NoNewline; Write-Host " detected."
    
    # Adjust wait time for AW3423DWF monitor
    $waitTime = 22

    # Define the path to the JSON file and backup file
    $jsonFilePath = "$env:userprofile\Saved Games\OTG\GzGameUserSettings.json"
    $backupFilePath = "$env:userprofile\Saved Games\OTG\GzGameUserSettingsGOOD.json"

    try {
        # Check if the backup file exists
        if (-not (Test-Path -Path $backupFilePath)) {
            Write-Host "Backup file GzGameUserSettingsGOOD.json not found." -ForegroundColor Red
            throw [System.IO.FileNotFoundException]::new("Backup file not found")
        }
        
        # Copy the backup file to overwrite the JSON file with verbose output
        Copy-Item -Path $backupFilePath -Destination $jsonFilePath -Force -Verbose
        
    } catch {
        Write-Host "An error occurred while copying the backup file: $_" -ForegroundColor Red
        #Start-Sleep -Seconds 10
    }
    
    # Set a flag indicating the presence of the AW3423DWF monitor
    $global:IsAW3423DWFMonitorPresent = $true

    # Launch OBS Studio
    $obsPath = "C:\Program Files\obs-studio\bin\64bit"
    Start-Process "C:\Program Files\obs-studio\bin\64bit\obs64.exe" --disable-shutdown-check
    
} else {
    # Set a flag indicating the absence of the AW3423DWF monitor
    $global:IsAW3423DWFMonitorPresent = $false
}

# 7
$launchCommand = "com.epicgames.launcher://apps/c5e46dc234c449408ede15767c2c631e%3A4d313b3e706c487ebef57d3511f800d1%3Aec7eb1b404154fdeafcb44b02ff5a980?action=launch&silent=true"

function Launch-And-MonitorGame {
    param (
        [string]$gameProcessPath,
        [int]$maxRetries = 3,
        [int]$retryInterval = 5
    )

    $retries = 0
    $global:gameProcessName = [System.IO.Path]::GetFileNameWithoutExtension($gameProcessPath)
    Write-Host "Setting game process name to: " -NoNewLine; Write-Host $global:gameProcessName -ForegroundColor Green

    if (-not $global:gameProcessName) {
        Write-Host "Error: Game process name is not set!" -ForegroundColor Red
        pause
        exit
    }

    while ($retries -lt $maxRetries) {
        Write-Host "Launching game (attempt $($retries + 1) of $maxRetries)..."
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c start $launchCommand"

        Write-Host "Debug: Checking for process " -NoNewLine; Write-Host $global:gameProcessName -ForegroundColor Green
        while (-not (Get-Process -Name $global:gameProcessName -ErrorAction SilentlyContinue)) {
            Start-Sleep -Seconds 1
        }

        for ($i = $waitTime; $i -ge 0; $i--) {
            if (Get-Process -Name $global:gameProcessName -ErrorAction SilentlyContinue) {
                Write-Host -NoNewline "`rWaiting for " -ForegroundColor White
                Write-Host -NoNewline "$i" -ForegroundColor Blue
                Write-Host -NoNewline " seconds..." -ForegroundColor White

                # Sleep only if $i is greater than 0
                if ($i -gt 0) {
                    Start-Sleep -Seconds 1
                } else {
                    # On the last iteration, append the final message
                    Write-Host " $waitTime second countdown complete."
                }
            } else {
                Write-Host "$global:gameProcessName" -ForegroundColor Green
                Write-Host -NoNewLine " stopped prematurely. Retrying in $retryInterval seconds..."
                Start-Sleep -Seconds $retryInterval
                $retries++
                break
            }
        }

        if (Get-Process -Name $global:gameProcessName -ErrorAction SilentlyContinue) {
            Write-Host -NoNewLine "$global:gameProcessName" -ForegroundColor Green
            Write-Host " is running. Exiting countdown loop."
            return $true
        } else {
            Write-Host "$global:gameProcessName" -ForegroundColor Green -NoNewLine
            Write-Host " is not running. " -NoNewLine 
            Write-Host "Retrying..." -ForegroundColor Yellow
        }
    }

    Write-Host "$global:gameProcessName" -ForegroundColor Green -NoNewLine
    Write-Host " failed to start successfully after $maxRetries attempts." -ForegroundColor Red
    pause
    exit
}

Write-Host "Debug: Executing Launch-And-MonitorGame with path $global:gameProcessPath" -ForegroundColor Cyan
$success = Launch-And-MonitorGame -gameProcessPath $global:gameProcessPath

if (-not $success) {
    Write-Host "Exiting script due to repeated failure to launch the game." -ForegroundColor Red
    pause
    exit
}

# 8
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class User32 {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int count);
}
"@

function Get-ForegroundWindowTitle {
    $handle = [User32]::GetForegroundWindow()
    if ($handle -ne [IntPtr]::Zero) {
        $title = New-Object System.Text.StringBuilder 256
        [User32]::GetWindowText($handle, $title, $title.Capacity) | Out-Null
        return $title.ToString()
    }
    return $null
}

function Get-WindowHandleByTitle {
    param (
        [string]$windowTitle
    )
    
    $process = Get-Process | Where-Object { $_.MainWindowTitle -eq $windowTitle } | Select-Object -First 1
    if ($process) {
        return $process.MainWindowHandle
    }
    return [IntPtr]::Zero
}

$escKeyPressReps = 2

function Set-ForegroundWindowByGameProcess {
    param (
        [string]$gameProcessName
    )

    Write-Host "Setting foreground window for process: " -NoNewLine; Write-Host "$gameProcessName" -ForegroundColor Cyan

    $process = Get-Process | Where-Object { $_.ProcessName -eq $gameProcessName } | Select-Object -First 1
    if ($process) {
        Write-Host "Process found: $($process.Name)" -ForegroundColor Green

        $partialTitle = $process.MainWindowTitle
        Write-Host "Partial title: $partialTitle" -ForegroundColor Green

        if ($partialTitle) {
            $currentForegroundWindowTitle = Get-ForegroundWindowTitle
            Write-Host "Current foreground window title: $currentForegroundWindowTitle" -ForegroundColor Green

            $gameWindowHandle = Get-WindowHandleByTitle -windowTitle $partialTitle
            if ($currentForegroundWindowTitle -ne $partialTitle -and $gameWindowHandle -ne [IntPtr]::Zero) {
                [User32]::SetForegroundWindow($gameWindowHandle)
                Start-Sleep -Milliseconds 200
                Write-Host "Window " -NoNewline; Write-Host $partialTitle -ForegroundColor Yellow -NoNewline; Write-Host " should now be in the foreground."
            } else {
                Write-Host "Window " -NoNewline; Write-Host $partialTitle -ForegroundColor Yellow -NoNewline; Write-Host " is already in the foreground."
            }
        } else {
            Write-Host "No window title found for process " -ForegroundColor Red -NoNewline; Write-Host $gameProcessName -ForegroundColor Yellow
        }
    } else {
        Write-Host "No process found with name " -ForegroundColor Red -NoNewline; Write-Host $gameProcessName -ForegroundColor Yellow
    }
}

Write-Host "Confirming game process name: $global:gameProcessName" -ForegroundColor Cyan

if (-not $global:gameProcessName) {
    Write-Host "Error: Game process name is empty before calling Set-ForegroundWindowByGameProcess!" -ForegroundColor Red
    pause
    exit
}

Set-ForegroundWindowByGameProcess -gameProcessName $global:gameProcessName

Add-Type -AssemblyName 'System.Windows.Forms'

for ($i = 0; $i -lt $escKeyPressReps; $i++) {
    Start-Sleep -Milliseconds 250
    Write-Host "Simulating ESC key press..."
    [System.Windows.Forms.SendKeys]::SendWait("{ESC}")
}

#Write-Output "The game should've skipped the intro videos."

#if ($global:IsAW3423DWFMonitorPresent) { Stop-Process -Name "EpicGamesLauncher" }

Start-Sleep -Seconds 5
