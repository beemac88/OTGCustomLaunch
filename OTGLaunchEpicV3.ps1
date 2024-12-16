# Define the URL of the latest script version on GitHub
$scriptUrl = "https://raw.githubusercontent.com/beemac88/OTGCustomLaunch/main/OTGLaunchEpicV3.ps1"

# Define the path to the current script
$scriptPath = $MyInvocation.MyCommand.Path

# Download the latest script version
try {
    $latestScript = Invoke-WebRequest -Uri $scriptUrl -UseBasicParsing
    if ($latestScript.StatusCode -eq 200) {
        $latestContent = $latestScript.Content

        # Replace the current script with the latest version
        Set-Content -Path $scriptPath -Value $latestContent -Force
        Write-Output "The script has been updated to the latest version."
    } else {
        Write-Output "Failed to download the latest script version. Status code: $($latestScript.StatusCode)"
    }
} catch {
    Write-Output "An error occurred while trying to update the script: $_"
}

# Define the path to the JSON file
$jsonFilePath = "$env:userprofile\Saved Games\OTG\GzGameUserSettings.json"

# Desired ScreenResolution
$desiredScreenResolution = @{
    x = 3440
    y = 1440
}

# Desired UIAspectRatio
$desiredUIAspectRatio = 1.7777777910232544

# Read the JSON file as a string
$jsonContent = Get-Content -Path $jsonFilePath -Raw

# Ensure the "WindowMode" value is added before "ScreenResolution"
if ($jsonContent -notmatch '"WindowMode":\s*\d') {
    $jsonContent = $jsonContent -replace '^\{', "{`r`n`t`"WindowMode`": 1,"
} else {
    $jsonContent = $jsonContent -replace '"WindowMode":\s*\d+', '"WindowMode": 1'
}

# Ensure the "ScreenResolution" value is added between "WindowMode" and "DisplayIndex"
if ($jsonContent -notmatch '"ScreenResolution":\s*\{') {
    $jsonContent = $jsonContent -replace '"WindowMode": 1', "`t`"WindowMode`": 1,`r`n`t`"ScreenResolution`":{`"x`": 3440,`"y`": 1440},"
} else {
    $jsonContent = $jsonContent -replace '"ScreenResolution":\s*\{\s*"x":\s*\d+,\s*"y":\s*\d+\s*\}', '"ScreenResolution":{"x": 3440,"y": 1440}'
}

# Ensure the "UIAspectRatio" value is added between "RotationAccelerationMultiplierHipFirePitch" and "bShowComparisonTooltip"
if ($jsonContent -notmatch '"UIAspectRatio":\s*\d+\.\d+') {
    $jsonContent = $jsonContent -replace '(("RotationAccelerationMultiplierHipFirePitch":\s*\d+\.\d+,))', "`$1`r`n`t`"UIAspectRatio`": 1.7777777910232544,"
}

# Ensure the "DisplayIndex" value is added after "ScreenResolution"
if ($jsonContent -notmatch '"DisplayIndex":\s*\d') {
    $jsonContent = $jsonContent -replace '}\s*,\s*"AntiAliasingQuality"', "},`r`n`t`"DisplayIndex`": 1,`r`n`t`"AntiAliasingQuality`""
} else {
    $jsonContent = $jsonContent -replace '"DisplayIndex":\s*\d+', '"DisplayIndex": 1'
}

# Write the updated JSON content back to the file without a trailing newline
$jsonContent | Set-Content -Path $jsonFilePath -NoNewline

Write-Output "The JSON file has been updated successfully."

# Retrieve the DefaultAppInstallLocation from GameUserSettings.ini
$defaultInstallLocation = Select-String -Path "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\Config\Windows\GameUserSettings.ini" -Pattern "DefaultAppInstallLocation" | ForEach-Object { $_.Line.Split('=')[1].Trim() }

# Construct the path to the Off The Grid game install folder
$gameInstallFolder = Join-Path -Path $defaultInstallLocation -ChildPath "OffTheGrid"

# Construct the path to the start_offthegrid.exe executable
$executablePath = Join-Path -Path $gameInstallFolder -ChildPath "start_offthegrid.exe"

# Check if the executable exists and print the result
if (Test-Path $executablePath) {
    Write-Host "Off The Grid game install folder found: $gameInstallFolder"
    Write-Host "Executable exists: $executablePath"
    
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
} else {
    Write-Host "Off The Grid game install folder not found or executable does not exist."
}

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
