[Environment]::CurrentDirectory = $PWD
Clear-Host

function Show-GenerateProgress ([timespan]$current, [timespan]$duration) {
    $percent = (($current.TotalSeconds * 100) / $duration.TotalSeconds)
    $percent = [math]::Round($percent, 2)

    Write-Progress -Id 1 -Activity "Generating MP4" -Status "Processing duration: $current of $duration ($percent%)" `
    -PercentComplete $percent -ParentId 0
}

function Show-FileProgress ([string]$filename, [int]$currentFile, [int]$filesCount) {
    Write-Progress -Id 0 -Activity "Processing file: $filename" -Status "File $currentFile of $filesCount" 
}

function Set-Output(){
    if (Test-Path converted){
        Remove-Item converted\*
    }else{
        New-Item -ItemType Directory converted | Out-Null
    }
}

try{
    Set-Output
    # [console]::TreatControlCAsInput = $true

    # [console]::TreatControlCAsInput = $true
    # while ($true) {
    #     write-host "Processing..."
    #     if ([console]::KeyAvailable) {
    #         $key = [system.console]::readkey($true)
    #         if (($key.modifiers -band [consolemodifiers]"control") -and
    #             ($key.key -eq "C")) {
    #             "Terminating..."
    #             break
    #         }
    #     }
    # }
    $currentDirectory = [Environment]::CurrentDirectory

    $files = @(Get-ChildItem $currentDirectory\* -Include *.wmv, *.mp4, *.avi, *.mpeg, *.mpg)

    if ($files.Length -eq 0){
        "There is no appicable file(-s) to process"
        exit
    }
    
    [int]$currentFileCounter = 0

    $files | ForEach-Object {
        $base = $_.Basename

        Show-FileProgress -filename $_ -currentFile (++$currentFileCounter) -filesCount $files.Length

        $psi = New-object System.Diagnostics.ProcessStartInfo 
        $psi.CreateNoWindow = $true 
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true 
        $psi.RedirectStandardError = $true 
        $psi.WorkingDirectory = $currentDirectory
        $psi.FileName = 'ffmpeg.exe' 
        $psi.Arguments = "-y -i ""$_"" -c:v libx264 -preset slow -crf 22 -pix_fmt yuv420p -c:a aac -b:a 128k ""converted\$base.mp4"""
        $process = New-Object System.Diagnostics.Process 
        $process.StartInfo = $psi 
        $process.Start() | Out-Null

        $duration = $null
        $start = [timespan]"00:00:00"
        $currentStep = $null

        do {
            $currentLine = $process.StandardError.ReadLine()

            if ($duration -eq $null){
                if ($currentLine -match 'Duration: (\d{2}:\d{2}:\d{2})'){
                    $duration = [timespan]$Matches[1]
                }
            }else{
                if ($currentLine -match 'time=(\d{2}:\d{2}:\d{2})'){
                    $currentStep = [timespan]$Matches[1]

                    Show-GenerateProgress -current $currentStep -duration $duration -filename $base
                    # Stop-Process -processname ffmpeg
                }
            }
            # $process.StandardOutput.ReadLineAsync()#.ReadLine()
        }
        while (!$process.HasExited)
    }
}
finally{
    # [console]::TreatControlCAsInput = $false
    # "ctrl-c clicked"
    "Finished processing existing files"
    pause
}
