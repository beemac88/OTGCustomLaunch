$scriptUrl = "https://raw.githubusercontent.com/beemac88/OTGCustomLaunch/testing/OTGCustomLaunchB.ps1"
$waitTime = 30
$desktop = [System.Environment]::GetFolderPath('Desktop')
$shortcutName = "OTG Custom LaunchB.lnk"
$targetPath = [System.Environment]::ExpandEnvironmentVariables("%systemroot%\System32\WindowsPowerShell\v1.0\powershell.exe")
$launchCommand = "com.epicgames.launcher://apps/c5e46dc234c449408ede15767c2c631e%3A4d313b3e706c487ebef57d3511f800d1%3Aec7eb1b404154fdeafcb44b02ff5a980?action=launch&silent=true"
$escKeyPressReps = 2

$defaultInstallLocation = Select-String -Path "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\Config\Windows\GameUserSettings.ini" -Pattern "DefaultAppInstallLocation" | ForEach-Object { $_.Line.Split('=')[-1].Trim() }

$gameInstallFolder = Get-ChildItem -Path $defaultInstallLocation -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { Test-Path -Path (Join-Path -Path $_.FullName -ChildPath "start_offthegrid.exe") } | Select-Object -First 1 -ExpandProperty FullName

if (-not $gameInstallFolder) {
    Write-Output "Game install folder not found. Please ensure the game is installed correctly."
    pause
    exit
} else {
    Write-Host "Game install folder found at " -NoNewline; Write-Host $gameInstallFolder -ForegroundColor Yellow
}

$offlineScriptPath = Join-Path -Path $gameInstallFolder -ChildPath "OTGCustomLaunchB.ps1"

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

foreach ($pattern in @("OTG*.mp4", "UE*.mp4")) {
    $filesToDelete = Get-ChildItem -Path $moviesPath -Filter $pattern
    foreach ($file in $filesToDelete) {
        Remove-Item -Path $file.FullName -Force
        Write-Host "Deleted file: $($file.FullName)"
    }
}

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

$shortcutPath = Join-Path -Path $desktop -ChildPath $shortcutName
$workingDirectory = (Get-Item -Path $targetPath).Directory.FullName
$arguments = "-ExecutionPolicy Bypass -File `"$offlineScriptPath`""

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

$monitor = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID | ForEach-Object { [System.Text.Encoding]::ASCII.GetString($_.UserFriendlyName -ne 0) } | Where-Object { $_ -eq "AW3423DWF" }

if ($monitor) {
    Write-Host $monitor -ForegroundColor Yellow -NoNewline; Write-Host " detected."
    
    $waitTime = 22

    $jsonFilePath = "$env:userprofile\Saved Games\OTG\GzGameUserSettings.json"
    $backupFilePath = "$env:userprofile\Saved Games\OTG\GzGameUserSettingsGOOD.json"

    try {
        if (-not (Test-Path -Path $backupFilePath)) {
            Write-Host "Backup file GzGameUserSettingsGOOD.json not found." -ForegroundColor Red
            throw [System.IO.FileNotFoundException]::new("Backup file not found")
        }
        
        Copy-Item -Path $backupFilePath -Destination $jsonFilePath -Force -Verbose
        
    } catch {
        Write-Host "An error occurred while copying the backup file: $_" -ForegroundColor Red
    }
    
    $global:IsAW3423DWFMonitorPresent = $true
} else {
    $global:IsAW3423DWFMonitorPresent = $false
}

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

# Add the C# code to the PowerShell script
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Diagnostics;

public class WindowHelper {
    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("kernel32.dll")]
    private static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    private static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);

    const int SW_RESTORE = 9;

    public static bool BringWindowToFront(string processName) {
        Process[] processes = Process.GetProcessesByName(processName);
        if (processes.Length > 0) {
            IntPtr hWnd = processes[0].MainWindowHandle;
            if (hWnd != IntPtr.Zero) {
                uint foregroundThreadID;
                GetWindowThreadProcessId(GetForegroundWindow(), out foregroundThreadID);
                uint currentThreadID = GetCurrentThreadId();
                AttachThreadInput(currentThreadID, foregroundThreadID, true);
                ShowWindow(hWnd, SW_RESTORE);
                bool result = SetForegroundWindow(hWnd);
                AttachThreadInput(currentThreadID, foregroundThreadID, false);
                return result;
            }
        }
        return false;
    }
}
"@

# Function to call the C# method to bring the window to the foreground
function Set-ForegroundWindowByGameProcess {
    param (
        [string]$gameProcessName
    )

    Write-Host "Setting foreground window for process: " -NoNewLine; Write-Host "$gameProcessName" -ForegroundColor Green

    $result = [WindowHelper]::BringWindowToFront($gameProcessName)

    if ($result) {
        Write-Host "Window brought to the foreground successfully." -ForegroundColor Green
    } else {
        Write-Host "Failed to bring window to the foreground." -ForegroundColor Red
    }
}

Write-Host "Confirming game process name: " -NoNewLine; Write-Host "$global:gameProcessName" -ForegroundColor Green

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

#if ($global:IsAW3423DWFMonitorPresent) { Stop-Process -Name "EpicGamesLauncher" }

#Start-Sleep -Seconds 5
pause
#Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$newFilePath`""
