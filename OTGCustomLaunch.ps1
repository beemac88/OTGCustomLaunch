# Define the URL of the latest script version on GitHub
$scriptUrl = "https://raw.githubusercontent.com/beemac88/OTGCustomLaunch/main/OTGCustomLaunch.ps1"

# Default wait time
$waitTime = 30

# Retrieve the DefaultAppInstallLocation from GameUserSettings.ini
$defaultInstallLocation = Select-String -Path "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\Config\Windows\GameUserSettings.ini" -Pattern "DefaultAppInstallLocation" | ForEach-Object { $_.Line.Split('=')[1].Trim() }

# Search for the game install folder by looking for start_offthegrid.exe
$gameInstallFolder = Get-ChildItem -Path $defaultInstallLocation -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object {
    Test-Path -Path (Join-Path -Path $_.FullName -ChildPath "start_offthegrid.exe")
} | Select-Object -First 1 -ExpandProperty FullName

if (-not $gameInstallFolder) {
    Write-Output "Game install folder not found. Please ensure the game is installed correctly."
    pause
    exit
} else {
    Write-Output "Game install folder found: $gameInstallFolder"
}

# Navigate to the game folder subdirectory G01\Content\Movies
$moviesPath = Join-Path -Path $gameInstallFolder -ChildPath "G01\Content\Movies"

# Delete specified .mp4 files in the Movies folder and display output for each file being deleted
foreach ($pattern in @("OTG*.mp4", "UE*.mp4")) {
    $filesToDelete = Get-ChildItem -Path $moviesPath -Filter $pattern
    foreach ($file in $filesToDelete) {
        Remove-Item -Path $file.FullName -Force
        Write-Host "Deleted file: $($file.FullName)"
    }
}

# Define the path to the script in the game install folder
$offlineScriptPath = Join-Path -Path $gameInstallFolder -ChildPath "OTGCustomLaunch.ps1"

# Download the latest script version and save it to the game install folder
try {
    $latestScript = Invoke-WebRequest -Uri $scriptUrl -UseBasicParsing
    if ($latestScript.StatusCode -eq 200) {
        $latestContent = $latestScript.Content

        # Save the downloaded script to the game install folder
        Set-Content -Path $offlineScriptPath -Value $latestContent -Force
        
        # Get the file information
        $fileInfo = Get-Item -Path $offlineScriptPath
        $filePath = $fileInfo.FullName
        $fileDateModified = $fileInfo.LastWriteTime

        Write-Output "$filePath updated as of $fileDateModified"

        # Debug output to check the condition
        Write-Output "Checking if the file was modified more than 30 seconds ago..."
        if ($fileDateModified -lt (Get-Date).AddSeconds(-30)) {
            Write-Output "Condition met. The file was modified more than 30 seconds ago."
            Write-Output "Restarting script to execute the latest version..."
            Start-Sleep -Seconds 5
            Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$filePath`""
            exit
        } else {
            Write-Output "Condition not met. The file was not modified more than 30 seconds ago."
        }
    } else {
        Write-Output "Failed to download the latest script version. Status code: $($latestScript.StatusCode)"
        Start-Sleep -Seconds 10
    }
} catch {
    Write-Output "An error occurred while trying to update the script: $_"
    Start-Sleep -Seconds 10
}

# Create or overwrite a shortcut on the desktop
$desktop = [System.Environment]::GetFolderPath('Desktop')
$shortcutName = "OTG Custom Launch.lnk"
$shortcutPath = Join-Path -Path $desktop -ChildPath $shortcutName
$targetPath = [System.Environment]::ExpandEnvironmentVariables("%systemroot%\System32\WindowsPowerShell\v1.0\powershell.exe")
$arguments = "-ExecutionPolicy Bypass -File `"$offlineScriptPath`""
$iconPath = "$gameInstallFolder\G01\Binaries\Win64\G01Client-Win64-Shipping.exe"
$workingDirectory = (Get-Item -Path $targetPath).Directory.FullName

# Create a WScript.Shell COM object to create the shortcut
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $targetPath
$shortcut.Arguments = $arguments
$shortcut.IconLocation = $iconPath
$shortcut.WorkingDirectory = $workingDirectory
$shortcut.Save()

# Output message
$shortcutNameWithoutExt = $shortcutName -replace '\.lnk$', ''

if (Test-Path -Path $shortcutPath -NewerThan (Get-Date).AddSeconds(-10)) {
    Write-Host $shortcutNameWithoutExt -ForegroundColor Yellow -NoNewline
    Write-Host " shortcut exists on Desktop."
}

# === Custom Section for AW3423DWF Monitor ===
# Check for the presence of the AW3423DWF monitor
$monitor = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID | ForEach-Object {
    [System.Text.Encoding]::ASCII.GetString($_.UserFriendlyName -ne 0)
} | Where-Object { $_ -eq "AW3423DWF" }

if ($monitor) {
    Write-Host $monitor -ForegroundColor Yellow -NoNewline; Write-Host " detected."
    
    # Adjust wait time for AW3423DWF monitor
    $waitTime = 19

    # Define the path to the JSON file and backup file
    $jsonFilePath = "$env:userprofile\Saved Games\OTG\GzGameUserSettings.json"
    $backupFilePath = "$env:userprofile\Saved Games\OTG\GzGameUserSettingsGOOD.json"

    try {
        # Check if the backup file exists
        if (-not (Test-Path -Path $backupFilePath)) {
            Write-Host "Backup file GzGameUserSettingsGOOD.json not found." -ForegroundColor Red
            throw [System.IO.FileNotFoundException]::new("Backup file not found")
        }
        
        # Copy the backup file to overwrite the JSON file
        Copy-Item -Path $backupFilePath -Destination $jsonFilePath -Force
        
        # Output the names of the files that were copied
        Write-Host "Copied:"; Write-Host $backupFilePath -ForegroundColor Yellow; Write-Host "to:"; Write-Host $jsonFilePath -ForegroundColor Yellow
    } catch {
        Write-Host "An error occurred while copying the backup file: $_" -ForegroundColor Red
        #Start-Sleep -Seconds 10
    }
}
# === End of Custom Section for AW3423DWF Monitor === #

# Define the Epic Games launch command as a URI
$launchCommand = "com.epicgames.launcher://apps/c5e46dc234c449408ede15767c2c631e%3A4d313b3e706c487ebef57d3511f800d1%3Aec7eb1b404154fdeafcb44b02ff5a980?action=launch&silent=true"

# Launch the game using the Epic Games launch command as an internet shortcut
Start-Process -FilePath "cmd.exe" -ArgumentList "/c start $launchCommand"

# Wait for the game process to start
$gameProcessName = "G01Client-Win64-Shipping"
while (-not (Get-Process -Name $gameProcessName -ErrorAction SilentlyContinue)) {
    Start-Sleep -Seconds 1
}

# Wait for the specified seconds after the game process has started with a countdown timer
if (Get-Process -Name $gameProcessName -ErrorAction SilentlyContinue) {
    for ($i = $waitTime; $i -gt 0; $i--) {
        Write-Host "Waiting for $i seconds..."
        Start-Sleep -Seconds 1
    }
} else {
    Write-Host "Process " -NoNewline; Write-Host $gameProcessName -ForegroundColor Yellow -NoNewline; Write-Host " not detected."
	pause
	exit
}

# Load the necessary assemblies for window manipulation
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

# Function to get the title of the foreground window
function Get-ForegroundWindowTitle {
    $handle = [User32]::GetForegroundWindow()
    if ($handle -ne [IntPtr]::Zero) {
        $title = New-Object System.Text.StringBuilder 256
        [User32]::GetWindowText($handle, $title, $title.Capacity) | Out-Null
        return $title.ToString()
    }
    return $null
}

# Function to get the handle of a window by its title
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

# Number of ESC key presses
$escKeyPressReps = 2

# Function to set the foreground window by dynamically retrieved title from game process name
function Set-ForegroundWindowByGameProcess {
    param (
        [string]$gameProcessName
    )

    $process = Get-Process | Where-Object { $_.ProcessName -eq $gameProcessName } | Select-Object -First 1

    if ($process) {
        $partialTitle = $process.MainWindowTitle

        if ($partialTitle) {
            $currentForegroundWindowTitle = Get-ForegroundWindowTitle
            $gameWindowHandle = Get-WindowHandleByTitle -windowTitle $partialTitle
            if ($currentForegroundWindowTitle -ne $partialTitle -and $gameWindowHandle -ne [IntPtr]::Zero) {
                [User32]::SetForegroundWindow($gameWindowHandle)
                Start-Sleep -Milliseconds 200 # Small delay to ensure SetForegroundWindow is processed
                Write-Host "Window " -NoNewline; Write-Host $partialTitle -ForegroundColor Yellow -NoNewline; Write-Host " should now be in the foreground."
            } else {
                Write-Host "Window " -NoNewline; Write-Host $partialTitle -ForegroundColor Yellow -NoNewline; Write-Host " is already in the foreground."
            }
        } else {
            Write-Host "No window title found for process " -NoNewline; Write-Host $gameProcessName -ForegroundColor Yellow
        }
    } else {
        Write-Host "No process found with name " -NoNewline; Write-Host $gameProcessName -ForegroundColor Yellow
    }
}

# Use the function to set the window with a dynamically retrieved title to the foreground
Set-ForegroundWindowByGameProcess -gameProcessName $gameProcessName

# Add-Type for SendKeys
Add-Type -AssemblyName 'System.Windows.Forms'

# Simulate pressing the ESC key multiple times with a 250ms delay prior and in between
for ($i = 0; $i -lt $escKeyPressReps; $i++) {
    Start-Sleep -Milliseconds 250
    Write-Host "Simulating ESC key press..."
    [System.Windows.Forms.SendKeys]::SendWait("{ESC}")
}

Write-Output "The game should've skipped the intro videos."
# Wait for 5 seconds to allow reading the console output
Start-Sleep -Seconds 5
