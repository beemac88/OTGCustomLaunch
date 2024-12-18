Copy the line below. Press WIN + R to open a Run box, paste in the line, then hit Enter.

**powershell -Command "iex (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/beemac88/OTGCustomLaunch/main/OTGCustomLaunch.ps1').Content"**

If that doesn't appear to work, or you get a quick flash of a window popping up without any chance to read anything, try this alternative method.

Search for Windows PowerShell in your Start Menu and open it, then paste the following line into that Window and hit Enter:

**powershell -ExecutionPolicy Bypass -Command "iex (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/beemac88/OTGCustomLaunch/main/OTGCustomLaunch.ps1').Content"**
