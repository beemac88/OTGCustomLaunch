# Define the URL of the latest script version on GitHub
$scriptUrl = "https://raw.githubusercontent.com/beemac88/OTGCustomLaunch/main/OTGCustomLaunch.ps1"

# Retrieve the DefaultAppInstallLocation from GameUserSettings.ini
$defaultInstallLocation = Select-String -Path "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\Config\Windows\GameUserSettings.ini" -Pattern "DefaultAppInstallLocation" | ForEach-Object { $_.Line.Split('=')[1].Trim() }

# Search for the game install folder by looking for start_offthegrid.exe
$gameInstallFolder = Get-ChildItem -Path $defaultInstallLocation -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object {
    Test-Path -Path (Join-Path -Path $_.FullName -ChildPath "start_offthegrid.exe")
} | Select-Object -First 1 -ExpandProperty FullName

if (-not $gameInstallFolder) {
    Write-Output "Game install folder not found. Please ensure the game is installed correctly."
    exit
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
        Write-Output "The script has been updated to the latest version and saved to the game install folder."
    } else {
        Write-Output "Failed to download the latest script version. Status code: $($latestScript.StatusCode)"
    }
} catch {
    Write-Output "An error occurred while trying to update the script: $_"
}

# Create a shortcut on the desktop
$desktop = [System.Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path -Path $desktop -ChildPath "OTG Custom Launch.lnk"
$targetPath = [System.Environment]::ExpandEnvironmentVariables("%systemroot%\System32\WindowsPowerShell\v1.0\powershell.exe")
$arguments = "-ExecutionPolicy Bypass -File `"$offlineScriptPath`""

if (-not (Test-Path -Path $shortcutPath)) {
    # Create a WScript.Shell COM object to create the shortcut
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $targetPath
    $shortcut.Arguments = $arguments
    $shortcut.IconLocation = "$gameInstallFolder\G01\Binaries\Win64\G01Client-Win64-Shipping.exe"
    $shortcut.WorkingDirectory = $gameInstallFolder
    $shortcut.Save()

    Write-Output "Offline copy of the script created and shortcut added to the desktop."
} else {
    Write-Output "Shortcut already exists on the desktop."
}
# === End of Self-Copy and Shortcut Creation ===

# Define the Epic Games launch command as a URI
$launchCommand = "com.epicgames.launcher://apps/c5e46dc234c449408ede15767c2c631e%3A4d313b3e706c487ebef57d3511f800d1%3Aec7eb1b404154fdeafcb44b02ff5a980?action=launch&silent=true"

# Launch the game using the Epic Games launch command as an internet shortcut
Start-Process -FilePath "cmd.exe" -ArgumentList "/c start $launchCommand"

# Wait for the game process to start
$gameProcessName = "G01Client-Win64-Shipping"
while (-not (Get-Process -Name $gameProcessName -ErrorAction SilentlyContinue)) {
    Start-Sleep -Seconds 1
}

# Wait for an additional 23 seconds after the game process has started with a countdown timer
for ($i = 23; $i -gt 0; $i--) {
    Write-Host "Waiting for $i seconds..."
    Start-Sleep -Seconds 1
}

# Function to set the foreground window by dynamically retrieved title from game process name
function Set-ForegroundWindowByGameProcess {
    param (
        [string]$gameProcessName
    )

    $process = Get-Process | Where-Object { $_.ProcessName -eq $gameProcessName } | Select-Object -First 1

    if ($process) {
        $partialTitle = $process.MainWindowTitle

        if ($partialTitle) {
            $shell = New-Object -ComObject "WScript.Shell"
            $shell.AppActivate($partialTitle)
            Start-Sleep -Milliseconds 100 # Small delay to ensure AppActivate is processed
            $shell.SendKeys('%') # Send Alt key to bring the window to the foreground
			$shell.AppActivate($partialTitle)
            Start-Sleep -Milliseconds 100 # Sleep second time
            $shell.SendKeys('%') # Send Alt key second time
            $shell.AppActivate($partialTitle)
            Start-Sleep -Milliseconds 100 # Sleep third time
            $shell.SendKeys('%') # Send Alt key third time
            Write-Host "Window '$partialTitle' should now be in the foreground."
        } else {
            Write-Host "No window title found for process '$gameProcessName'."
        }
    } else {
        Write-Host "No process found with name '$gameProcessName'."
    }
}

# Use the function to set the window with a dynamically retrieved title to the foreground
Set-ForegroundWindowByGameProcess -gameProcessName $gameProcessName

# Simulate pressing the ESC key twice with a 250ms delay prior and in between
Start-Sleep -Milliseconds 250
Add-Type -AssemblyName 'System.Windows.Forms'
Write-Host "Simulating ESC key press..."
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
Start-Sleep -Milliseconds 250
Write-Host "Simulating ESC key press again..."
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")

Write-Output "The game should've skipped the intro videos."
# Wait for 5 seconds to allow reading the console output
Start-Sleep -Seconds 5
