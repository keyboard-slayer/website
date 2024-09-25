function IsEverythingInstalled {
    $python = ((Get-Command python).path) -like "*\WindowsApps\*"

    return -not $python
}


if ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains 'S-1-5-32-544') {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        if (((Get-Command python).path) -like "*\WindowsApps\*") {
            choco install python3 -y
        }

        Write-Host "Installation complete"
        Start-Sleep -Seconds 5
        exit
    }

    Write-Host "Please run this script as a normal user"
    Start-Sleep -Seconds 5
    exit
}

if ($null -eq $env:CUTEKIT_VERSION) {
    $env:CUTEKIT_VERSION = "stable"
}

Set-Variable -Name "ChocoInstalled" -Value $false
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Set-Variable -Name "ChocoInstalled" -Value $true
}

if (!(IsEverythingInstalled)) {
    if ($ChocoInstalled) {
        $script = $PSScriptRoot + "\build.ps1"
        Start-Process -FilePath powershell.exe @("-NoExit", "-ExecutionPolicy", "Bypass", "-File", $script) -Verb RunAs
        Write-Host "When all dependencies are installed, please exit this window and run the script again"
        exit
    }
    else {
        Write-Host "Some dependencies are missing"
        Write-Host "You can install Chocolatey and this script will install all the dependencies for you"
    }
}

python -m cutekit 2> $null | Out-Null
Set-Variable -Name "CutekitInstalled" -Value $?

python -m venv -h 2> $null | Out-Null
Set-Variable -Name "VenvInstalled" -Value $?

if (-not $VenvInstalled) {
    python -m pip install virtualenv
}

if (-not $CutekitInstalled) {
    if (!(Test-Path -Path ".\.cutekit\env")) {
        python -m venv .\.cutekit\env
        .\.cutekit\env\Scripts\pip install "git+https://github.com/cute-engineering/cutekit.git@$($env:CUTEKIT_VERSION)" markdown
    }

    .\.cutekit\env\Scripts\Activate.ps1
}

python -m cutekit $args