# Standalone smoke test that recreates the encoding graphs without launching the interactive toolkit menu.
param()

$ErrorActionPreference = "Stop"

function Resolve-ToolPath ($label, $commandName) {
    $path = Read-Host "$label executable path (Enter to search PATH)"
    if ([string]::IsNullOrWhiteSpace($path)) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if (-not $command) { throw "$label was not found on PATH; enter its full path and rerun." }
        return $command.Source
    }

    $path = $path.Trim('"').Trim("'").Trim()
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "$label was not found: $path"
    }
    return $path
}

function Get-VideoEncodingProfile {
    $encoderOutput = & $script:ffmpegPath -hide_banner -encoders 2>&1
    if ($LASTEXITCODE -ne 0) { throw "FFmpeg could not list its available encoders." }

    $available = @{}
    foreach ($line in $encoderOutput) {
        if ("$line" -match '^\s*V\S{5}\s+(\S+)') { $available[$matches[1]] = $true }
    }

    $softwareProfiles = @(
        @{ Encoder = "libx264"; Codec = "h264"; Label = "H.264 / libx264"; Preset = "fast"; Quality = "23"; QualityOption = "-crf"; Default = $true },
        @{ Encoder = "libx265"; Codec = "hevc"; Label = "H.265 / libx265"; Preset = "fast"; Quality = "28"; QualityOption = "-crf"; Default = $false }
    )
    $gpuProfiles = @(
        @{ Encoder = "h264_nvenc"; Codec = "h264"; Label = "H.264 / NVIDIA NVENC"; Preset = "p4"; Quality = "23"; QualityOption = "-cq"; Default = $true },
        @{ Encoder = "hevc_nvenc"; Codec = "hevc"; Label = "H.265 / NVIDIA NVENC"; Preset = "p4"; Quality = "28"; QualityOption = "-cq"; Default = $false },
        @{ Encoder = "h264_qsv"; Codec = "h264"; Label = "H.264 / Intel Quick Sync"; Preset = "medium"; Quality = "23"; QualityOption = "-global_quality"; Default = $false },
        @{ Encoder = "hevc_qsv"; Codec = "hevc"; Label = "H.265 / Intel Quick Sync"; Preset = "medium"; Quality = "28"; QualityOption = "-global_quality"; Default = $false },
        @{ Encoder = "h264_amf"; Codec = "h264"; Label = "H.264 / AMD AMF"; Preset = "balanced"; Quality = "23"; QualityOption = "-qp_p"; Default = $false },
        @{ Encoder = "hevc_amf"; Codec = "hevc"; Label = "H.265 / AMD AMF"; Preset = "balanced"; Quality = "28"; QualityOption = "-qp_p"; Default = $false }
    )

    $useGpu = (Read-Host "Enable GPU encoding? (Y/N, default N)") -match '^[YyΝν]$'
    $profiles = if ($useGpu) { $gpuProfiles } else { $softwareProfiles }
    $profiles = @($profiles | Where-Object { $available.ContainsKey($_.Encoder) })
    if ($profiles.Count -eq 0) {
        $kind = if ($useGpu) { "GPU" } else { "software" }
        throw "No supported $kind video encoder was found in this FFmpeg build."
    }
    if (-not ($profiles | Where-Object { $_.Default })) { $profiles[0].Default = $true }

    $encoderKind = if ($useGpu) { "GPU" } else { "software" }
    Write-Host "`nAvailable ${encoderKind} encoders:"
    for ($i = 0; $i -lt $profiles.Count; $i++) {
        $defaultText = if ($profiles[$i].Default) { " [DEFAULT]" } else { "" }
        Write-Host (" {0}. {1} — {2}, {3} {4}{5}" -f ($i + 1), $profiles[$i].Label, $profiles[$i].Preset, $profiles[$i].QualityOption, $profiles[$i].Quality, $defaultText)
    }

    $profileIndex = 0
    if ($profiles.Count -gt 1) {
        while ($true) {
            $selection = Read-Host "Select encoder (Enter for default)"
            if ([string]::IsNullOrWhiteSpace($selection)) { break }
            if ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $profiles.Count) {
                $profileIndex = [int]$selection - 1
                break
            }
            Write-Host "Invalid selection." -ForegroundColor Red
        }
    }

    $profile = $profiles[$profileIndex]
    if ($profile.QualityOption -eq "-crf") {
        $presetOptions = @("ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow", "placebo")
    } elseif ($profile.Encoder -match '_nvenc$') {
        $presetOptions = @("p1", "p2", "p3", "p4", "p5", "p6", "p7")
    } elseif ($profile.Encoder -match '_qsv$') {
        $presetOptions = @("veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow")
    } else {
        $presetOptions = @("speed", "balanced", "quality")
    }

    Write-Host "`nAvailable presets/modes: $($presetOptions -join ', ') (default: $($profile.Preset))"
    $preset = Read-Host "Preset/mode (Enter for $($profile.Preset))"
    if ([string]::IsNullOrWhiteSpace($preset)) { $preset = $profile.Preset }
    if ($preset -notin $presetOptions) { throw "Invalid preset/mode: $preset" }

    $qualityName = if ($profile.QualityOption -eq "-crf") { "CRF" } else { "quality" }
    $quality = Read-Host "$qualityName 0-51 (Enter for $($profile.Quality))"
    if ([string]::IsNullOrWhiteSpace($quality)) { $quality = $profile.Quality }
    if ($quality -notmatch '^\d+$' -or [int]$quality -lt 0 -or [int]$quality -gt 51) {
        throw "$qualityName must be an integer from 0 to 51."
    }

    $encoderArgs = @("-c:v", $profile.Encoder)
    if ($profile.QualityOption -eq "-crf") {
        $encoderArgs += @("-preset", $preset, "-crf", $quality)
    } elseif ($profile.Encoder -match '_nvenc$') {
        $encoderArgs += @("-preset", $preset, "-rc", "vbr", "-cq", $quality, "-b:v", "0")
    } elseif ($profile.Encoder -match '_qsv$') {
        $encoderArgs += @("-preset", $preset, "-global_quality", $quality)
    } else {
        $encoderArgs += @("-quality", $preset, "-qp_i", $quality, "-qp_p", $quality)
    }

    if ($useGpu) {
        $testArgs = @("-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "color=c=black:s=128x128:r=1", "-frames:v", "1") + $encoderArgs + @("-f", "null", "-")
        & $script:ffmpegPath @testArgs
        if ($LASTEXITCODE -ne 0) {
            throw "GPU encoder $($profile.Encoder) failed its initialization test; check the GPU/driver or rerun with CPU encoding."
        }
    }

    Write-Host "Selected encoder: $($profile.Encoder)" -ForegroundColor Green
    return @{ Args = $encoderArgs; Codec = $profile.Codec; Encoder = $profile.Encoder }
}

function Read-ExistingFile ($prompt) {
    while ($true) {
        $path = (Read-Host $prompt).Trim('"').Trim("'").Trim()
        if ([string]::IsNullOrWhiteSpace($path)) {
            Write-Host "A file path is required." -ForegroundColor Red
            continue
        }
        if (Test-Path -LiteralPath $path -PathType Leaf) { return (Get-Item -LiteralPath $path).FullName }
        Write-Host "File not found. Try again." -ForegroundColor Red
    }
}

function Read-CutRange {
    $timePattern = '^(?:\d+(?:\.\d+)?|\d+:\d+(?:\.\d+)?|\d+:\d+:\d+(?:\.\d+)?)$'
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    while ($true) {
        $start = Read-Host "Keep from time (seconds, mm:ss, or hh:mm:ss)"
        $end = Read-Host "Stop at time (seconds, mm:ss, or hh:mm:ss)"
        if ($start -notmatch $timePattern -or $end -notmatch $timePattern) {
            Write-Host "Enter valid time values." -ForegroundColor Red
            continue
        }
        $startSeconds = Convert-TestTimeToSeconds $start $culture
        $endSeconds = Convert-TestTimeToSeconds $end $culture
        if ($endSeconds -gt $startSeconds) {
            return @{ Start = $start; End = $end; StartSeconds = $startSeconds; EndSeconds = $endSeconds }
        }
        Write-Host "Stop time must be after start time." -ForegroundColor Red
    }
}

function Convert-TestTimeToSeconds ($value, $culture) {
    $parts = $value.Split(':')
    if ($parts.Count -eq 1) { return [double]::Parse($parts[0], $culture) }
    if ($parts.Count -eq 2) { return ([double]::Parse($parts[0], $culture) * 60) + [double]::Parse($parts[1], $culture) }
    return ([double]::Parse($parts[0], $culture) * 3600) + ([double]::Parse($parts[1], $culture) * 60) + [double]::Parse($parts[2], $culture)
}

function Get-MediaInfo ($path) {
    $probeArgs = @("-v", "error", "-show_streams", "-show_format", "-of", "json", $path)
    $probeOutput = & $script:ffprobePath @probeArgs 2>&1
    if ($LASTEXITCODE -ne 0) { throw "FFprobe could not inspect '$path': $($probeOutput -join ' ')" }
    return (($probeOutput -join [Environment]::NewLine) | ConvertFrom-Json)
}

function Get-VideoStream ($mediaInfo, $path) {
    $stream = $mediaInfo.streams | Where-Object { $_.codec_type -eq "video" } | Select-Object -First 1
    if (-not $stream) { throw "No video stream found in '$path'." }
    return $stream
}

function Invoke-TestFFmpeg ($arguments, $outputPath, $testName) {
    Write-Host "`nRunning $testName..." -ForegroundColor Cyan
    & $script:ffmpegPath @arguments
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) { throw "$testName failed: FFmpeg exited with code $exitCode." }
    if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) { throw "$testName failed: output was not created." }
    if ((Get-Item -LiteralPath $outputPath).Length -eq 0) { throw "$testName failed: output is empty." }
}

function Assert-Output ($path, $profile, $expectedDuration, $expectedWidth = $null, $expectedHeight = $null) {
    $info = Get-MediaInfo $path
    $video = Get-VideoStream $info $path
    if ($video.codec_name -ne $profile.Codec) {
        throw "Unexpected output codec '$($video.codec_name)'; expected '$($profile.Codec)'."
    }
    if ($null -ne $expectedWidth -and ($video.width -ne $expectedWidth -or $video.height -ne $expectedHeight)) {
        throw "Unexpected output dimensions $($video.width)x$($video.height); expected ${expectedWidth}x${expectedHeight}."
    }
    $duration = [double]::Parse($info.format.duration, [System.Globalization.CultureInfo]::InvariantCulture)
    if ([math]::Abs($duration - $expectedDuration) -gt 1.0) {
        throw ("Unexpected output duration {0:N2}s; expected about {1:N2}s." -f $duration, $expectedDuration)
    }
    Write-Host ("PASS: {0}; {1}x{2}; {3:N2}s; {4}" -f $path, $video.width, $video.height, $duration, $video.codec_name) -ForegroundColor Green
}

function Test-CropAndCut ($outputDir, $profile) {
    $inputPath = Read-ExistingFile "Path to a demo video for crop + cut"
    $sourceInfo = Get-MediaInfo $inputPath
    $sourceVideo = Get-VideoStream $sourceInfo $inputPath
    if ($sourceVideo.width -lt 1680 -or $sourceVideo.height -lt 1080) {
        throw "Crop + cut test requires a video at least 1680x1080 for crop=1440:1080:240:0."
    }
    $range = Read-CutRange
    $output = Join-Path $outputDir "crop-cut.mkv"
    $arguments = @("-hide_banner", "-y", "-i", $inputPath, "-ss", $range.Start, "-to", $range.End, "-vf", "crop=1440:1080:240:0") + $profile.Args + @("-c:a", "aac", "-b:a", "192k", "-benchmark", $output)
    Invoke-TestFFmpeg $arguments $output "single-pass crop + cut"
    Assert-Output $output $profile ($range.EndSeconds - $range.StartSeconds) 1440 1080
}

function Test-ConcatenateAndOverlay ($outputDir, $profile) {
    $count = 0
    while ($count -lt 2) {
        $value = Read-Host "How many demo clips to combine? (at least 2)"
        if ($value -match '^\d+$' -and [int]$value -ge 2) { $count = [int]$value }
        else { Write-Host "Enter a whole number of 2 or more." -ForegroundColor Red }
    }

    $segments = [System.Collections.Generic.List[object]]::new()
    $sourceInputArgs = [System.Collections.Generic.List[string]]::new()
    $graphParts = [System.Collections.Generic.List[string]]::new()
    $videoLabels = [System.Collections.Generic.List[string]]::new()
    $audioLabels = [System.Collections.Generic.List[string]]::new()
    $expectedDuration = 0.0
    $firstVideo = $null

    for ($i = 0; $i -lt $count; $i++) {
        $path = Read-ExistingFile "Path to demo clip $($i + 1)"
        $info = Get-MediaInfo $path
        $video = Get-VideoStream $info $path
        if (-not ($info.streams | Where-Object { $_.codec_type -eq "audio" } | Select-Object -First 1)) {
            throw "The full-pipeline test requires an audio stream in every clip: '$path'."
        }
        if (-not $firstVideo) { $firstVideo = $video }
        elseif ($video.width -ne $firstVideo.width -or $video.height -ne $firstVideo.height) {
            throw "The concat-filter test requires matching video dimensions. '$path' is $($video.width)x$($video.height), expected $($firstVideo.width)x$($firstVideo.height)."
        }

        $range = Read-CutRange
        $segments.Add(@{ File = $path; Range = $range })
        $sourceInputArgs.Add("-i")
        $sourceInputArgs.Add($path)
        $start = $range.StartSeconds.ToString("0.###", [System.Globalization.CultureInfo]::InvariantCulture)
        $end = $range.EndSeconds.ToString("0.###", [System.Globalization.CultureInfo]::InvariantCulture)
        $videoLabel = "test_v$i"
        $audioLabel = "test_a$i"
        $graphParts.Add("[${i}:v]trim=start=${start}:end=${end},setpts=PTS-STARTPTS[$videoLabel]")
        $graphParts.Add("[${i}:a]atrim=start=${start}:end=${end},asetpts=PTS-STARTPTS[$audioLabel]")
        $videoLabels.Add("[$videoLabel]")
        $audioLabels.Add("[$audioLabel]")
        $expectedDuration += $range.EndSeconds - $range.StartSeconds
    }

    $graphParts.Add("$($videoLabels -join '')concat=n=${count}:v=1:a=0[basev]")
    $graphParts.Add("$($audioLabels -join '')concat=n=${count}:v=0:a=1[basea]")
    $logoPath = Read-Host "Optional PNG/JPG logo path (Enter to use a test drawbox overlay)"
    if (-not [string]::IsNullOrWhiteSpace($logoPath)) {
        $logoPath = $logoPath.Trim('"').Trim("'").Trim()
        if (-not (Test-Path -LiteralPath $logoPath -PathType Leaf)) { throw "Logo file not found: $logoPath" }
        if ([System.IO.Path]::GetExtension($logoPath) -notmatch '^\.(png|jpe?g)$') { throw "Use a PNG or JPG logo for this test." }
        $sourceInputArgs.Add("-loop")
        $sourceInputArgs.Add("1")
        $sourceInputArgs.Add("-i")
        $sourceInputArgs.Add((Get-Item -LiteralPath $logoPath).FullName)
        $graphParts.Add("[${count}:v]scale=160:-2,format=yuva420p[watermark]")
        $graphParts.Add("[basev][watermark]overlay=x=20:y=20:shortest=1[outv]")
    } else {
        $graphParts.Add("[basev]drawbox=x=20:y=20:w=160:h=80:color=red@0.65:t=fill[outv]")
    }

    $output = Join-Path $outputDir "concat-overlay.mkv"
    $graph = $graphParts -join ";"
    $arguments = @("-hide_banner", "-y") + @($sourceInputArgs) + @("-filter_complex", $graph, "-map", "[outv]", "-map", "[basea]") + $profile.Args + @("-c:a", "aac", "-b:a", "192k", "-benchmark", $output)
    Invoke-TestFFmpeg $arguments $output "single-pass precise trim + concat + overlay"
    Assert-Output $output $profile $expectedDuration
}

$choice = Read-Host "Select test: 1) crop + cut  2) multi-clip + overlay  3) both"
if ($choice -notin @("1", "2", "3")) { throw "Select 1, 2, or 3." }

$script:ffmpegPath = Resolve-ToolPath "FFmpeg" "ffmpeg.exe"
$script:ffprobePath = Resolve-ToolPath "FFprobe" "ffprobe.exe"
$profile = Get-VideoEncodingProfile
$outputRoot = Read-Host "Output folder for test files (Enter for .\MediaToolkit-TestOutput)"
if ([string]::IsNullOrWhiteSpace($outputRoot)) { $outputRoot = Join-Path $PSScriptRoot "MediaToolkit-TestOutput" }
$outputRoot = $outputRoot.Trim('"').Trim("'").Trim()
$runName = "run-{0}" -f (Get-Date -Format "yyyyMMdd-HHmmss")
$outputDir = Join-Path $outputRoot $runName
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

Write-Host "`nTest outputs will be written to: $outputDir" -ForegroundColor Cyan
if ($choice -eq "1" -or $choice -eq "3") { Test-CropAndCut $outputDir $profile }
if ($choice -eq "2" -or $choice -eq "3") { Test-ConcatenateAndOverlay $outputDir $profile }
Write-Host "`nAll selected tests passed." -ForegroundColor Green
