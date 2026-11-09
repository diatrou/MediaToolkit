# ==========================================
# ΕΡΓΑΛΕΙΟ ΕΠΕΞΕΡΓΑΣΙΑΣ BINTEO & ΗΧΟΥ (FFMPEG TOOLKIT)
# ==========================================

# --- ΣΥΝΑΡΤΗΣΕΙΣ ΕΙΔΟΠΟΙΗΣΕΩΝ (SYSTEM TOAST NOTIFICATIONS) ---
function Send-WindowsNotification ($title, $message, $type = "Success") {
    try {
        [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

        $template = @"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>$title</text>
            <text>$message</text>
        </binding>
    </visual>
</toast>
"@
        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($template)
        $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("FFmpeg Toolkit").Show($toast)
    } catch {
        if ($type -eq "Success") {
            [Console]::Beep(1000, 150)
            Start-Sleep -Milliseconds 100
            [Console]::Beep(1000, 150)
        } else {
            [Console]::Beep(400, 500)
        }
    }
}

function Notify-Success ($msg = "Η διεργασία ολοκληρώθηκε με επιτυχία!") {
    Send-WindowsNotification -title "FFmpeg Toolkit - Επιτυχία" -message $msg -type "Success"
}

function Notify-Error ($msg = "Προέκψε σφάλμα κατά την εκτέλεση.") {
    Send-WindowsNotification -title "FFmpeg Toolkit - Σφάλμα" -message $msg -type "Error"
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if ([string]::IsNullOrWhiteSpace($scriptDir)) { $scriptDir = $PSScriptRoot }
if ([string]::IsNullOrWhiteSpace($scriptDir)) { $scriptDir = Get-Location }

$configFile = Join-Path $scriptDir "config.json"

# Προεπιλεγμένες τιμές
$defaultFFmpeg         = "C:\Users\Δημήτρης\Downloads\ffmpeg-2026-08-06-git-95c43d7df7-essentials_build\bin\ffmpeg.exe"
$defaultFFprobe        = "C:\Users\Δημήτρης\Downloads\ffmpeg-2026-08-06-git-95c43d7df7-essentials_build\bin\ffprobe.exe"
$defaultLogoDir        = "C:\Users\Δημήτρης\Desktop"
$defaultFadeOut        = "00:00:05.000"
$defaultPosition       = "99:79"
$defaultLogoWidth      = "196"
$defaultLogoOpacity    = "100"
$defaultLogoSchedules  = @(@{ File = ""; Start = "00:00:00.000"; Duration = "99:59:59.000"; FadeIn = "0"; FadeOut = "0" })
$defaultBannerPosition = "314:79"
$defaultBannerWidth    = "220"
$defaultBannerHeight   = "50"
$defaultBannerOpacity  = "100"
$defaultPreviewTime    = "00:00:05.000"

function Convert-TimeToSeconds ($timeStr) {
    if ([string]::IsNullOrWhiteSpace($timeStr)) { return 0.0 }
    if ($timeStr -match '^\d+(\.\d+)?$') { return [double]$timeStr }
    
    try {
        # Αν η συμβολοσειρά είναι της μορφής mm:ss.fff ή hh:mm:ss.fff
        $parts = $timeStr.Split(':')
        if ($parts.Length -eq 2) {
            # Μορφή mm:ss.fff
            $m = [double]$parts[0]
            $s = [double]$parts[1]
            return ($m * 60) + $s
        }
        elseif ($parts.Length -eq 3) {
            # Μορφή hh:mm:ss.fff
            $h = [double]$parts[0]
            $m = [double]$parts[1]
            $s = [double]$parts[2]
            return ($h * 3600) + ($m * 60) + $s
        }
        
        # Εναλλακτική προσπάθεια με TimeSpan αν αποτύχουν τα παραπάνω
        $ts = [TimeSpan]::Parse($timeStr)
        return $ts.TotalSeconds
    } catch {
        return 0.0
    }
}

function Load-Config {
    if (Test-Path -LiteralPath $configFile) {
        try {
            $config = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json
            $script:ffmpegPath     = if ($config.ffmpegPath)     { $config.ffmpegPath }     else { $defaultFFmpeg }
            $script:ffprobePath    = if ($config.ffprobePath)    { $config.ffprobePath }    else { $defaultFFprobe }
            $script:logoDirPath    = if ($config.logoDirPath)    { $config.logoDirPath }    else { $defaultLogoDir }
            $script:logoFadeOut    = if ($config.logoFadeOut)    { $config.logoFadeOut }    else { $defaultFadeOut }
            $script:logoPosition   = if ($config.logoPosition)   { $config.logoPosition }   else { $defaultPosition }
            $script:logoWidth      = if ($config.logoWidth)      { $config.logoWidth }      else { $defaultLogoWidth }
            $script:logoOpacity    = if ($config.logoOpacity)    { $config.logoOpacity }    else { $defaultLogoOpacity }
            $script:logoSchedules  = if ($config.logoSchedules)  { $config.logoSchedules }  else { $defaultLogoSchedules }
            $script:bannerPosition = if ($config.bannerPosition) { $config.bannerPosition } else { $defaultBannerPosition }
            $script:bannerWidth    = if ($config.bannerWidth)    { $config.bannerWidth }    else { $defaultBannerWidth }
            $script:bannerHeight   = if ($config.bannerHeight)   { $config.bannerHeight }   else { $defaultBannerHeight }
            $script:bannerOpacity  = if ($config.bannerOpacity)  { $config.bannerOpacity }  else { $defaultBannerOpacity }
            $script:previewTime    = if ($config.previewTime)    { $config.previewTime }    else { $defaultPreviewTime }
        } catch {
            $script:ffmpegPath     = $defaultFFmpeg
            $script:ffprobePath    = $defaultFFprobe
            $script:logoDirPath    = $defaultLogoDir
            $script:logoFadeOut    = $defaultFadeOut
            $script:logoPosition   = $defaultPosition
            $script:logoWidth      = $defaultLogoWidth
            $script:logoOpacity    = $defaultLogoOpacity
            $script:logoSchedules  = $defaultLogoSchedules
            $script:bannerPosition = $defaultBannerPosition
            $script:bannerWidth    = $defaultBannerWidth
            $script:bannerHeight   = $defaultBannerHeight
            $script:bannerOpacity  = $defaultBannerOpacity
            $script:previewTime    = $defaultPreviewTime
        }
    } else {
        $script:ffmpegPath     = $defaultFFmpeg
        $script:ffprobePath    = $defaultFFprobe
        $script:logoDirPath    = $defaultLogoDir
        $script:logoFadeOut    = $defaultFadeOut
        $script:logoPosition   = $defaultPosition
        $script:logoWidth      = $defaultLogoWidth
        $script:logoOpacity    = $defaultLogoOpacity
        $script:logoSchedules  = $defaultLogoSchedules
        $script:bannerPosition = $defaultBannerPosition
        $script:bannerWidth    = $defaultBannerWidth
        $script:bannerHeight   = $defaultBannerHeight
        $script:bannerOpacity  = $defaultBannerOpacity
        $script:previewTime    = $defaultPreviewTime
    }
}

function Save-Config {
    $configData = @{
        ffmpegPath     = $script:ffmpegPath
        ffprobePath    = $script:ffprobePath
        logoDirPath    = $script:logoDirPath
        logoFadeOut    = $script:logoFadeOut
        logoPosition   = $script:logoPosition
        logoWidth      = $script:logoWidth
        logoOpacity    = $script:logoOpacity
        logoSchedules  = $script:logoSchedules
        bannerPosition = $script:bannerPosition
        bannerWidth    = $script:bannerWidth
        bannerHeight   = $script:bannerHeight
        bannerOpacity  = $script:bannerOpacity
        previewTime    = $script:previewTime
    }
    $configData | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configFile -Encoding utf8
    Write-Host "`nΤο αρχείο config.json ενημερώθηκε επιτυχώς στη διαδρομή: $configFile" -ForegroundColor Green
    Notify-Success "Οι ρυθμίσεις αποθηκεύτηκαν επιτυχώς."
    Start-Sleep -Seconds 1
}

# --- ΣΥΝΑΡΤΗΣΕΙΣ ΡΥΘΜΙΣΕΩΝ ---
function Set-FFmpegPath {
    Write-Host "`n========================================================" -ForegroundColor Yellow
    Write-Host "             ΡΥΘΜΙΣΗ ΔΙΑΔΡΟΜΗΣ FFMPEG                    " -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host "Τρέχουσα διαδρομή FFmpeg: $script:ffmpegPath" -ForegroundColor Gray
    Write-Host ""
    $newVal = Read-Host "Εισάγετε τη νέα διαδρομή για το ffmpeg.exe (Enter για διατήρηση)"
    $newVal = $newVal.Trim('"').Trim("'")
    if (-not [string]::IsNullOrWhiteSpace($newVal)) {
        if (Test-Path -LiteralPath $newVal) {
            $script:ffmpegPath = $newVal
            Save-Config
        } else {
            Write-Host "Σφάλμα: Το αρχείο δεν βρέθηκε στη συγκεκριμένη διαδρομή!" -ForegroundColor Red
            Notify-Error "Το αρχείο FFmpeg δεν βρέθηκε."
            Start-Sleep -Seconds 2
        }
    }
}

function Set-FFprobePath {
    Write-Host "`n========================================================" -ForegroundColor Yellow
    Write-Host "             ΡΥΘΜΙΣΗ ΔΙΑΔΡΟΜΗΣ FFPROBE                   " -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host "Τρέχουσα διαδρομή FFprobe: $script:ffprobePath" -ForegroundColor Gray
    Write-Host ""
    $newVal = Read-Host "Εισάγετε τη νέα διαδρομή για το ffprobe.exe (Enter για διατήρηση)"
    $newVal = $newVal.Trim('"').Trim("'")
    if (-not [string]::IsNullOrWhiteSpace($newVal)) {
        if (Test-Path -LiteralPath $newVal) {
            $script:ffprobePath = $newVal
            Save-Config
        } else {
            Write-Host "Σφάλμα: Το αρχείο δεν βρέθηκε στη συγκεκριμένη διαδρομή!" -ForegroundColor Red
            Notify-Error "Το αρχείο FFprobe δεν βρέθηκε."
            Start-Sleep -Seconds 2
        }
    }
}

function Set-LogoDirPath {
    Write-Host "`n========================================================" -ForegroundColor Yellow
    Write-Host "           ΡΥΘΜΙΣΗ ΦΑΚΕΛΟΥ ΛOΓΟΤΥΠΩΝ                     " -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host "Τρέχων φάκελος Λογοτύπων: $script:logoDirPath" -ForegroundColor Gray
    Write-Host ""
    $newVal = Read-Host "Εισάγετε το νέο φάκελο λογοτύπων (Enter για διατήρηση)"
    $newVal = $newVal.Trim('"').Trim("'")
    if (-not [string]::IsNullOrWhiteSpace($newVal)) {
        if (Test-Path -LiteralPath $newVal -PathType Container) {
            $script:logoDirPath = $newVal
            Save-Config
        } else {
            Write-Host "Σφάλμα: Ο φάκελος δεν υπάρχει!" -ForegroundColor Red
            Notify-Error "Ο φάκελος λογοτύπων δεν υπάρχει."
            Start-Sleep -Seconds 2
        }
    }
}

function Set-LogoFadeOut {
    Write-Host "`n========================================================" -ForegroundColor Yellow
    Write-Host "         ΡΥΘΜΙΣΗ ΧΡΟΝΟΥ FADE-OUT BANNER                 " -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host "Τρέχων χρόνος Fade-Out Banner: $script:logoFadeOut" -ForegroundColor Gray
    Write-Host ""
    $newVal = Read-Host "Εισάγετε νέο χρόνο Fade-Out στη μορφή HH:MM:SS.mmm (Enter για διατήρηση: $script:logoFadeOut)"
    $newVal = $newVal.Trim('"').Trim("'")
    if (-not [string]::IsNullOrWhiteSpace($newVal)) {
        $script:logoFadeOut = $newVal
        Save-Config
    }
}

function Set-LogoPosition {
    Write-Host "`n========================================================" -ForegroundColor Yellow
    Write-Host "     [LOGO] ΡΥΘΜΙΣΗ ΘΕΣΗΣ (X:Y)                         " -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host "Τρέχουσα θέση Logo: $script:logoPosition" -ForegroundColor Gray
    Write-Host ""
    $newVal = Read-Host "Εισάγετε νέα θέση στη μορφή X:Y (Enter για διατήρηση: $script:logoPosition)"
    $newVal = $newVal.Trim('"').Trim("'").Trim()
    if (-not [string]::IsNullOrWhiteSpace($newVal)) {
        if ($newVal -match '^\d+:\d+$') {
            $script:logoPosition = $newVal
            Save-Config
        } else {
            Write-Host "Σφάλμα: Η μορφή πρέπει να είναι X:Y (π.χ. 99:79)!" -ForegroundColor Red
            Notify-Error "Λανθασμένη μορφή θέσης logo."
            Start-Sleep -Seconds 2
        }
    }
}

function Set-LogoWidth {
    Write-Host "`n========================================================" -ForegroundColor Yellow
    Write-Host "     [LOGO] ΡΥΘΜΙΣΗ ΠΛΑΤΟΥΣ (PX)                        " -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host "Τρέχον πλάτος Logo: $script:logoWidth px" -ForegroundColor Gray
    Write-Host ""
    $newVal = Read-Host "Εισάγετε νέο πλάτος σε pixels (Enter για διατήρηση: $script:logoWidth)"
    $newVal = $newVal.Trim('"').Trim("'").Trim()
    if (-not [string]::IsNullOrWhiteSpace($newVal)) {
        if ($newVal -match '^\d+$') {
            $script:logoWidth = $newVal
            Save-Config
        } else {
            Write-Host "Σφάλμα: Η τιμή πρέπει να είναι αριθμός!" -ForegroundColor Red
            Notify-Error "Μη έγκυρο πλάτος logo."
            Start-Sleep -Seconds 2
        }
    }
}

function Set-LogoOpacity {
    Write-Host "`n========================================================" -ForegroundColor Yellow
    Write-Host "     [LOGO] ΡΥΘΜΙΣΗ ΔΙΑΦΑΝΕΙΑΣ (0 - 100)               " -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host "Τρέχουσα διαφάνεια Logo: $script:logoOpacity %" -ForegroundColor Gray
    Write-Host ""
    $newVal = Read-Host "Εισάγετε ποσοστό αδιαφάνειας 0-100 (Enter για διατήρηση: $script:logoOpacity)"
    $newVal = $newVal.Trim('"').Trim("'").Trim()
    if (-not [string]::IsNullOrWhiteSpace($newVal)) {
        if ($newVal -match '^\d+$' -and [int]$newVal -ge 0 -and [int]$newVal -le 100) {
            $script:logoOpacity = $newVal
            Save-Config
        } else {
            Write-Host "Σφάλμα: Εισάγετε ακέραιο αριθμό από 0 έως 100!" -ForegroundColor Red
            Notify-Error "Μη έγκυρο ποσοστό διαφάνειας logo."
            Start-Sleep -Seconds 2
        }
    }
}

function Select-LogoFile {
    if (-not (Test-Path -LiteralPath $script:logoDirPath)) {
        Write-Host "Σφάλμα: Ο φάκελος λογοτύπων δεν υπάρχει: $script:logoDirPath" -ForegroundColor Red
        Notify-Error "Ο φάκελος λογοτύπων δεν βρέθηκε."
        Start-Sleep -Seconds 2
        return $null
    }

    $logoFiles = Get-ChildItem -LiteralPath $script:logoDirPath -File | Where-Object { $_.Extension -match '\.(mp4|mkv|mov|avi|ts|jpg|jpeg|png)$' }

    if ($logoFiles.Count -eq 0) {
        Write-Host "Δεν βρέθηκαν αρχεία βίντεο ή εικόνων λογοτύπου στον φάκελο: $script:logoDirPath" -ForegroundColor Red
        Notify-Error "Δεν βρέθηκαν λογότυπα στον φάκελο."
        Start-Sleep -Seconds 2
        return $null
    }

    Write-Host "`n--- Διαθέσιμα Αρχεία Λογοτύπου (Βίντεο & Εικόνες) ---" -ForegroundColor Cyan
    for ($i = 0; $i -lt $logoFiles.Count; $i++) {
        Write-Host " [$($i + 1)] $($logoFiles[$i].Name)" -ForegroundColor Yellow
    }

    while ($true) {
        $selection = Read-Host "Επιλέξτε αριθμό αρχείου λογοτύπου (1-$($logoFiles.Count))"
        if ($selection -match '^\d+$') {
            $index = [int]$selection - 1
            if ($index -ge 0 -and $index -lt $logoFiles.Count) {
                return $logoFiles[$index].FullName
            }
        }
        Write-Host "Μη έγκυρη επιλογή. Παρακαλώ προσπαθήστε ξανά." -ForegroundColor Red
    }
}

function Set-LogoSchedules {
    while ($true) {
        Clear-Host
        Write-Host "`n========================================================" -ForegroundColor Yellow
        Write-Host "     [LOGO] ΔΙΑΧΕΙΡΙΣΗ ΧΡΟΝΙΚΩΝ ΔΙΑΣΤΗΜΑΤΩΝ & LOGO      " -ForegroundColor Yellow
        Write-Host "========================================================" -ForegroundColor Yellow
        Write-Host "Τρέχοντα χρονικά διαστήματα και αρχεία logo:" -ForegroundColor Cyan
        
        for ($i = 0; $i -lt $script:logoSchedules.Count; $i++) {
            $s = $script:logoSchedules[$i]
            $fileName = if ($s.File) { [System.IO.Path]::GetFileName($s.File) } else { "[Εξ 'ορισμού]" }
            Write-Host " [$($i+1)] Αρχείο: $fileName | Έναρξη: $($s.Start) | Διάρκεια: $($s.Duration) | Fade-In: $($s.FadeIn)s | Fade-Out: $($s.FadeOut)s" -ForegroundColor Green
        }
        
        Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
        Write-Host " 1. Προσθήκη νέου χρονικού διαστήματος"
        Write-Host " 2. Διαγραφή συγκεκριμένου διαστήματος"
        Write-Host " 3. Ολική επαναφορά σε 1 προεπιλεγμένο διάστημα"
        Write-Host " Q. Επιστροφή στο κυρίως μενού"
        Write-Host "========================================================" -ForegroundColor Cyan

        $opt = Read-Host "Επιλέξτε ενέργεια (1-3 ή Q)"

        if ($opt -eq 'q' -or $opt -eq 'Q') { break }

        switch ($opt) {
            "1" {
                Write-Host "`nΕπιλέξτε το αρχείο logo για αυτό το διάστημα:" -ForegroundColor Yellow
                $chosenLogo = Select-LogoFile
                if (-not $chosenLogo) { continue }

                $schedStart = Read-Host "Χρόνος έναρξης (π.χ. 00:00:00.000)"
                $schedDur   = Read-Host "Διάρκεια προβολής (π.χ. 00:01:30.000 ή 99:59:59.000)"
                $schedFadeI = Read-Host "Διάρκεια Fade-In σε δευτερόλεπτα (π.χ. 1)"
                $schedFadeO = Read-Host "Διάρκεια Fade-Out σε δευτερόλεπτα (π.χ. 1)"

                if ([string]::IsNullOrWhiteSpace($schedStart)) { $schedStart = "00:00:00.000" }
                if ([string]::IsNullOrWhiteSpace($schedDur))   { $schedDur = "99:59:59.000" }
                if ([string]::IsNullOrWhiteSpace($schedFadeI)) { $schedFadeI = "0" }
                if ([string]::IsNullOrWhiteSpace($schedFadeO)) { $schedFadeO = "0" }

                if ($script:logoSchedules.Count -eq 1 -and [string]::IsNullOrWhiteSpace($script:logoSchedules[0].File)) {
                    $script:logoSchedules = @(@{ File = $chosenLogo; Start = $schedStart; Duration = $schedDur; FadeIn = $schedFadeI; FadeOut = $schedFadeO })
                } else {
                    $script:logoSchedules += @{ File = $chosenLogo; Start = $schedStart; Duration = $schedDur; FadeIn = $schedFadeI; FadeOut = $schedFadeO }
                }
                Save-Config
                Write-Host "Το νέο διάστημα προστέθηκε επιτυχώς!" -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            "2" {
                if ($script:logoSchedules.Count -le 1) {
                    Write-Host "Υπάρχει μόνο 1 διάστημα. Δεν μπορείτε να διαγράψετε άλλο." -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                    continue
                }

                $delNum = Read-Host "Εισάγετε τον αριθμό του διαστήματος που θέλετε να διαγράψετε (1-$($script:logoSchedules.Count))"
                if ($delNum -match '^\d+$') {
                    $idx = [int]$delNum - 1
                    if ($idx -ge 0 -and $idx -lt $script:logoSchedules.Count) {
                        $script:logoSchedules = @($script:logoSchedules | Where-Object { $_ -ne $script:logoSchedules[$idx] })
                        Save-Config
                        Write-Host "Το διάστημα διαγράφηκε επιτυχώς! Απέμειναν $($script:logoSchedules.Count) διαστήματα." -ForegroundColor Green
                    } else {
                        Write-Host "Μη έγκυρος αριθμός." -ForegroundColor Red
                    }
                }
                Start-Sleep -Seconds 2
            }
            "3" {
                $script:logoSchedules = @(@{ File = ""; Start = "00:00:00.000"; Duration = "99:59:59.000"; FadeIn = "0"; FadeOut = "0" })
                Save-Config
                Write-Host "Έγινε επαναφορά στις προεπιλογές (1 διάστημα)." -ForegroundColor Green
                Start-Sleep -Seconds 2
            }
        }
    }
}

function Set-BannerPosition {
    Write-Host "`n========================================================" -ForegroundColor Yellow
    Write-Host "     [BANNER] ΡΥΘΜΙΣΗ ΘΕΣΗΣ (X:Y)                       " -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host "Τρέχουσα θέση Banner: $script:bannerPosition" -ForegroundColor Gray
    Write-Host ""
    $newVal = Read-Host "Εισάγετε νέα θέση στη μορφή X:Y (Enter για διατήρηση: $script:bannerPosition)"
    $newVal = $newVal.Trim('"').Trim("'").Trim()
    if (-not [string]::IsNullOrWhiteSpace($newVal)) {
        if ($newVal -match '^\d+:\d+$') {
            $script:bannerPosition = $newVal
            Save-Config
        } else {
            Write-Host "Σφάλμα: Η μορφή πρέπει να είναι X:Y (π.χ. 314:79)!" -ForegroundColor Red
            Notify-Error "Λανθασμένη μορφή θέσης banner."
            Start-Sleep -Seconds 2
        }
    }
}

function Set-BannerWidth {
    Write-Host "`n========================================================" -ForegroundColor Yellow
    Write-Host "     [BANNER] ΡΥΘΜΙΣΗ ΠΛΑΤΟΥΣ (PX)                      " -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host "Τρέχον πλάτος Banner: $script:bannerWidth px" -ForegroundColor Gray
    Write-Host ""
    $newVal = Read-Host "Εισάγετε νέο πλάτος σε pixels (Enter για διατήρηση: $script:bannerWidth)"
    $newVal = $newVal.Trim('"').Trim("'").Trim()
    if (-not [string]::IsNullOrWhiteSpace($newVal)) {
        if ($newVal -match '^\d+$') {
            $script:bannerWidth = $newVal
            $script:bannerHeight = [math]::Round([int]$newVal / 4.4).ToString()
            Save-Config
        } else {
            Write-Host "Σφάλμα: Η τιμή πρέπει να είναι αριθμός!" -ForegroundColor Red
            Notify-Error "Μη έγκυρο πλάτος banner."
            Start-Sleep -Seconds 2
        }
    }
}

function Set-BannerOpacity {
    Write-Host "`n========================================================" -ForegroundColor Yellow
    Write-Host "     [BANNER] ΡΥΘΜΙΣΗ ΔΙΑΦΑΝΕΙΑΣ (0 - 100)              " -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host "Τρέχουσα διαφάνεια Banner: $script:bannerOpacity %" -ForegroundColor Gray
    Write-Host ""
    $newVal = Read-Host "Εισάγετε ποσοστό αδιαφάνειας 0-100 (Enter για διατήρηση: $script:bannerOpacity)"
    $newVal = $newVal.Trim('"').Trim("'").Trim()
    if (-not [string]::IsNullOrWhiteSpace($newVal)) {
        if ($newVal -match '^\d+$' -and [int]$newVal -ge 0 -and [int]$newVal -le 100) {
            $script:bannerOpacity = $newVal
            Save-Config
        } else {
            Write-Host "Σφάλμα: Εισάγετε ακέραιο αριθμό από 0 έως 100!" -ForegroundColor Red
            Notify-Error "Μη έγκυρο ποσοστό διαφάνειας banner."
            Start-Sleep -Seconds 2
        }
    }
}

function Set-PreviewTime {
    Write-Host "`n========================================================" -ForegroundColor Yellow
    Write-Host "       ΡΥΘΜΙΣΗ ΧΡΟΝΟΥ ΠΡΟΕΠΙΣΚΟΠΗΣΗΣ (PREVIEW)           " -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host "Τρέχων χρόνος Preview: $script:previewTime" -ForegroundColor Gray
    Write-Host ""
    $newVal = Read-Host "Εισάγετε νέο χρόνο Preview στη μορφή HH:MM:SS.mmm (Enter για διατήρηση: $script:previewTime)"
    $newVal = $newVal.Trim('"').Trim("'").Trim()
    if (-not [string]::IsNullOrWhiteSpace($newVal)) {
        $script:previewTime = $newVal
        Save-Config
    }
}

# Αρχική φόρτωση ρυθμίσεων
Load-Config

# --- ΒOΗΘΗΤΙΚΕΣ ΣΥΝΑΡΤΗΣΕΙΣ ---
function Get-ValidInputFile ($prompt) {
    while ($true) {
        $raw = Read-Host $prompt
        $path = $raw.Trim('"').Trim("'").Trim()
        if ([string]::IsNullOrWhiteSpace($path)) { return $null }
        
        if (Test-Path -LiteralPath $path -PathType Container) {
            $mediaFiles = Get-ChildItem -LiteralPath $path -File | Where-Object { $_.Extension -match '\.(mp4|mkv|avi|mov|ts)$' }
            
            if ($mediaFiles.Count -eq 0) {
                Write-Host "Σφάλμα: Ο φάκελος δεν περιέχει υποστηριζόμενα αρχεία βίντεο!" -ForegroundColor Red
                Notify-Error "Δεν βρέθηκαν βίντεο στον επιλεγμένο φάκελο."
                Start-Sleep -Seconds 2
                continue
            }
            elseif ($mediaFiles.Count -eq 1) {
                $selected = $mediaFiles[0].FullName
                Write-Host "`n[INFO] Βρέθηκε 1 βίντεο στον φάκελο: " -NoNewline -ForegroundColor Cyan
                Write-Host "$($mediaFiles[0].Name)" -ForegroundColor Green
                return $selected
            }
            else {
                Write-Host "`n--- Βρέθηκαν $($mediaFiles.Count) αρχεία βίντεο στον φάκελο ---" -ForegroundColor Cyan
                for ($i = 0; $i -lt $mediaFiles.Count; $i++) {
                    Write-Host " [$($i + 1)] $($mediaFiles[$i].Name)" -ForegroundColor Yellow
                }
                
                while ($true) {
                    $selection = Read-Host "Επιλέξτε αριθμό βίντεο (1-$($mediaFiles.Count))"
                    if ($selection -match '^\d+$') {
                        $idx = [int]$selection - 1
                        if ($idx -ge 0 -and $idx -lt $mediaFiles.Count) {
                            $selected = $mediaFiles[$idx].FullName
                            Write-Host "`n[INFO] Επιλέξατε το αρχείο: " -NoNewline -ForegroundColor Cyan
                            Write-Host "$($mediaFiles[$idx].Name)" -ForegroundColor Green
                            return $selected
                        }
                    }
                    Write-Host "Μη έγκυρη επιλογή. Προσπαθήστε ξανά." -ForegroundColor Red
                }
            }
        }
        
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $fileName = [System.IO.Path]::GetFileName($path)
            Write-Host "`n[INFO] Επιλέχθηκε το αρχείο: " -NoNewline -ForegroundColor Cyan
            Write-Host "$fileName" -ForegroundColor Green
            return $path
        }
        
        Notify-Error "Η διαδρομή δεν υπάρχει ή δεν είναι έγκυρο αρχείο."
        Write-Host "Σφάλμα: Η διαδρομή δεν υπάρχει ή δεν είναι έγκυρο αρχείο/φάκελος!" -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
}

function Get-ValidOutputDir ($defaultDir) {
    $raw = Read-Host "Διαδρομή φακέλου αποθήκευσης τελικών αρχείων (Enter για προεπιλογή: $defaultDir)"
    $path = $raw.Trim('"').Trim("'").Trim()
    if ([string]::IsNullOrWhiteSpace($path)) { return $defaultDir }
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
    return $path
}

# --- ΑΣΦΑΛΗΣ ΔΙΑΓΡΑΦΗ ΕΝΔΙΑΜΕΣΩΝ ΑΡΧΕΙΩΝ ---
function Safe-Clear-TempFiles ($fixedFiles, $finalFiles, $mergedFile, $overlayFile, $targetOverlayPath) {
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host "           ΕΛΕΓΧΟΣ & ΚΑΘΑΡΙΣΜΟΣ ΠΡΟΣΩΡΙΝΩΝ ΑΡΧΕΙΩΝ        " -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan

    $hasErrors = $false

    if ($targetOverlayPath -and (-not ($overlayFile -and (Test-Path -LiteralPath $overlayFile)))) {
        Write-Host "[ΣΦΑΛΜΑ D-1] ΔΕΝ δημιουργήθηκε το τελικό αρχείο Overlay:" -ForegroundColor Red
        Write-Host "             -> $targetOverlayPath" -ForegroundColor Yellow
        $hasErrors = $true
    }

    if ($mergedFile -ne $null -and (-not (Test-Path -LiteralPath $mergedFile))) {
        Write-Host "[ΣΦΑΛΜΑ D-2] ΔΕΝ δημιουργήθηκε το συνενωμένο αρχείο (Merged):" -ForegroundColor Red
        Write-Host "             -> $mergedFile" -ForegroundColor Yellow
        $hasErrors = $true
    }

    if ($finalFiles -and $finalFiles.Count -gt 0) {
        foreach ($fn in $finalFiles) {
            if (-not (Test-Path -LiteralPath $fn)) {
                Write-Host "[ΣΦΑΛΜΑ D-3] ΔΕΝ δημιουργήθηκε το κεκομμένο αρχείο:" -ForegroundColor Red
                Write-Host "             -> $fn" -ForegroundColor Yellow
                $hasErrors = $true
            }
        }
    }

    if ($hasErrors) {
        Write-Host "`n--------------------------------------------------------" -ForegroundColor Red
        Write-Host "[ΠΡΟΣΤΑΣΙΑ ΑΡΧΕΙΩΝ] Λόγω σφάλματος στα επόμενα στάδια, ΔΕΝ ΔΙΑΓΡΑΦΗΚΑΝ:" -ForegroundColor Yellow
        Notify-Error "Εντοπίστηκαν σφάλματα. Τα ενδιάμεσα αρχεία διατηρήθηκαν."
        
        if ($mergedFile -and (Test-Path -LiteralPath $mergedFile)) {
            Write-Host "  [*] ΔΙΑΤΗΡΕΙΤΑΙ (Merged): $mergedFile" -ForegroundColor Green
        }
        if ($finalFiles) {
            foreach ($fn in $finalFiles) {
                if (Test-Path -LiteralPath $fn) {
                    Write-Host "  [*] ΔΙΑΤΗΡΕΙΤΑΙ (Final Cut): $fn" -ForegroundColor Green
                }
            }
        }
        if ($fixedFiles) {
            foreach ($fx in $fixedFiles) {
                if (Test-Path -LiteralPath $fx) {
                    Write-Host "  [*] ΔΙΑΤΗΡΕΙΤΑΙ (Fixed): $fx" -ForegroundColor Green
                }
            }
        }
        Write-Host "--------------------------------------------------------" -ForegroundColor Red
        return
    }

    $ans = Read-Host "`nΌλα τα στάδια ολοκληρώθηκαν επιτυχώς! Θέλετε να διαγράψετε τα ενδιάμεσα προσωρινά αρχεία; (Y/N)"
    if ($ans -match '^[YyΝν]$') {
        Write-Host ""
        if ($fixedFiles) {
            foreach ($f in $fixedFiles) {
                if ($f -and (Test-Path -LiteralPath $f)) {
                    Remove-Item -LiteralPath $f -Force
                    Write-Host "[ΔΙΑΓΡΑΦΗΚΕ]: $f" -ForegroundColor Gray
                }
            }
        }
        if ($finalFiles -and $mergedFile -and (Test-Path -LiteralPath $mergedFile)) {
            foreach ($f in $finalFiles) {
                if ($f -and (Test-Path -LiteralPath $f)) {
                    Remove-Item -LiteralPath $f -Force
                    Write-Host "[ΔΙΑΓΡΑΦΗΚΕ]: $f" -ForegroundColor Gray
                }
            }
        }
        if ($mergedFile -and $overlayFile -and (Test-Path -LiteralPath $overlayFile)) {
            if (Test-Path -LiteralPath $mergedFile) {
                Remove-Item -LiteralPath $mergedFile -Force
                Write-Host "[ΔΙΑΓΡΑΦΗΚΕ]: $mergedFile" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "[INFO] Όλα τα ενδιάμεσα αρχεία διατηρήθηκαν κατόπιν επιλογής χρήστη." -ForegroundColor Cyan
    }
}

# 1. Επιδιόρθωση (Lossless remuxing)
function Repair-Video ($inputFile) {
    $dir = Split-Path $inputFile -Parent
    $name = [System.IO.Path]::GetFileNameWithoutExtension($inputFile)
    $output = Join-Path $dir "$name`_fixed.mkv"
    Write-Host "`n>>> ΣΤΑΔΙΟ: Επιδιόρθωση αρχείου: $inputFile" -ForegroundColor Green
    
    $ffArgs = @("-y", "-i", $inputFile, "-c", "copy", $output)
    & "$script:ffmpegPath" @ffArgs

    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $output)) {
        Write-Host "`n[ΕΠΙΤΥΧΙΑ] Η επιδιόρθωση ολοκληρώθηκε: $output" -ForegroundColor Green
        Notify-Success "Η επιδιόρθωση βίντεο ολοκληρώθηκε."
        Start-Sleep -Seconds 2
        return $output
    }
    Notify-Error "Απέτυχε η επιδιόρθωση του αρχείου."
    Write-Host "`n[ΣΦΑΛΜΑ] Απέτυχε η επιδιόρθωση του $inputFile" -ForegroundColor Red
    Start-Sleep -Seconds 2
    return $null
}

# 2. Αφαίρεση Διαφημίσεων / Κοπή
function Cut-Video ($inputFile, $containerExt, $aspectChoice) {
    Write-Host "`n>>> ΣΤΑΔΙΟ: Κοπή & Αφαίρεση Διαφημίσεων" -ForegroundColor Green
    $startTime = Read-Host "Χρόνος τέλους διαφημίσεων αρχής (δηλαδή 00:02.635)"
    $endTime = Read-Host "Χρόνος έναρξης διαφημίσεων τέλους (δηλαδή 00:30:39.634)"
    
    if ([string]::IsNullOrWhiteSpace($containerExt)) {
        $containerInput = Read-Host "Επιλογή τύπου αρχείου (mkv ή mp4 - Πατήστε Enter για mkv)"
        $containerExt = if ($containerInput -match "mp4") { "mp4" } else { "mkv" }
    }

    if ([string]::IsNullOrWhiteSpace($aspectChoice)) {
        Write-Host "Επιλογή αναλογίας: 1. Default, 2. 16:9, 3. 4:3"
        $aspectChoice = Read-Host "Επέλεξε (1-3)"
    }

    $aspectParam = if ($aspectChoice -eq "2") { @("-aspect", "16:9") } elseif ($aspectChoice -eq "3") { @("-aspect", "4:3") } else { @() }

    $dir = Split-Path $inputFile -Parent
    $name = [System.IO.Path]::GetFileNameWithoutExtension($inputFile) -replace '_fixed$', ''
    $output = Join-Path $dir "$name`_final.$containerExt"

    Write-Host "`n>>> Εκτέλεση Κοπής..." -ForegroundColor Green
    
    $ffArgs = @("-y", "-i", $inputFile, "-ss", $startTime, "-to", $endTime, "-c:v", "libx264", "-preset", "ultrafast", "-crf", "23") + $aspectParam + @("-c:a", "aac", "-b:a", "192k", $output)
    & "$script:ffmpegPath" @ffArgs

    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $output)) {
        Write-Host "`n[ΕΠΙΤΥΧΙΑ] Η κοπή ολοκληρώθηκε: $output" -ForegroundColor Green
        Notify-Success "Η κοπή του βίντεο ολοκληρώθηκε."
        Start-Sleep -Seconds 2
        return $output
    }
    Notify-Error "Απέτυχε η κοπή του αρχείου."
    Write-Host "`n[ΣΦΑΛΜΑ] Απέτυχε η κοπή του αρχείου!" -ForegroundColor Red
    Start-Sleep -Seconds 2
    return $null
}

# 3. Συνένωση Αρχείων (Concat)
function Concat-Videos ($fileList, $outputDir, $containerExt) {
    if ($fileList.Count -lt 2) {
        Write-Host "Απαιτούνται τουλάχιστον 2 αρχεία για συνένωση." -ForegroundColor Yellow
        return $fileList[0]
    }
    if ([string]::IsNullOrWhiteSpace($containerExt)) { $containerExt = "mkv" }

    $listFilePath = Join-Path $outputDir "concat_list.txt"
    $listContent = foreach ($f in $fileList) { "file '$($f -replace "'", "''")'" }
    Set-Content -LiteralPath $listFilePath -Value $listContent -Encoding utf8

    $mergedOutput = Join-Path $outputDir "Merged_Final.$containerExt"
    Write-Host "`n>>> ΣΤΑΔΙΟ: Συνένωση αρχείων στο: $mergedOutput" -ForegroundColor Green
    
    $ffArgs = @("-y", "-f", "concat", "-safe", "0", "-i", $listFilePath, "-c", "copy", $mergedOutput)
    & "$script:ffmpegPath" @ffArgs

    if (Test-Path -LiteralPath $listFilePath) { Remove-Item -LiteralPath $listFilePath -Force }

    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $mergedOutput)) {
        Write-Host "`n[ΕΠΙΤΥΧΙΑ] Η συνένωση ολοκληρώθηκε: $mergedOutput" -ForegroundColor Green
        Notify-Success "Η συνένωση αρχείων ολοκληρώθηκε."
        Start-Sleep -Seconds 2
        return $mergedOutput
    }
    Notify-Error "Απέτυχε η συνένωση αρχείων."
    Write-Host "`n[ΣΦΑΛΜΑ] Απέτυχε η συνένωση των αρχείων!" -ForegroundColor Red
    Start-Sleep -Seconds 2
    return $null
}

# 4. Επικάλυψη Logo & Banner (Με Δυναμική Υποστήριξη Διαφορετικού Logo ανά Διάστημα)
# 4. Επικάλυψη Logo & Banner (Οριστική Διόρθωση με Case-Insensitive Dictionary)
function Apply-OverlayBanner ($inputFile, $outputDir) {
    Write-Host "`n>>> ΣΤΑΔΙΟ: Επικάλυψη Logo & Banner" -ForegroundColor Green
    Write-Host "`n-- Επιλογή τύπου επικάλυψης --" -ForegroundColor Yellow
    Write-Host " 1. Μόνο Logo (Εφαρμογή των προγραμματισμένων schedules)"
    Write-Host " 2. Logo Schedules + Banner Τίτλου (Λευκό πλαίσιο με κείμενα)"
    $subChoice = Read-Host "Επιλέξτε (1 ή 2)"

    if ([string]::IsNullOrWhiteSpace($outputDir)) { $outputDir = Split-Path $inputFile -Parent }
    $output = Join-Path $outputDir "Merged_Final_noSign.mkv"
    $previewImage = Join-Path $outputDir "preview.jpg"

    $seasonText = " "
    $epTitle = " "
    $textFilePath = Join-Path $scriptDir "ep_text.txt"

    # Καθαρισμός και φιλτράρισμα έγκυρων schedules
    $validSchedules = [System.Collections.Generic.List[object]]::new()
    if ($script:logoSchedules) {
        foreach ($sched in $script:logoSchedules) {
            if ($sched -and -not [string]::IsNullOrWhiteSpace($sched.File) -and (Test-Path -LiteralPath $sched.File)) {
                $validSchedules.Add($sched)
            }
        }
    }

    if ($validSchedules.Count -eq 0) {
        Write-Host "`n[INFO] Δεν βρέθηκαν έγκυρα αρχεία logo στα Schedules. Παρακαλώ επιλέξτε ένα εξ' ορισμού logo:" -ForegroundColor Yellow
        $defaultLogo = Select-LogoFile
        if (-not $defaultLogo) { return $null }
        $validSchedules.Add(@{ File = $defaultLogo; Start = "00:00:00.000"; Duration = "99:59:59.000"; FadeIn = "0"; FadeOut = "0" })
    }

    if ($subChoice -eq "2") {
        $seasonText = Read-Host "`nΕισάγετε κείμενο κύκλου (δηλαδή 2ος ΚΥΚΛΟΣ - Ε19)"
        if ([string]::IsNullOrWhiteSpace($seasonText)) { $seasonText = " " }

        $epTitle = Read-Host "Εισάγετε τίτλο επεισοδίου (δηλαδή House vs. God)"
        if ([string]::IsNullOrWhiteSpace($epTitle)) { $epTitle = " " }
        [System.IO.File]::WriteAllText($textFilePath, $epTitle, (New-Object System.Text.UTF8Encoding $false))
    }

    $previewLoop = $true
    while ($previewLoop) {
		# --- ΕΝΑΡΞΗ PREVIEW ---
        $script:IsRunningPreview = $true
        # ---------------------
		
        $fadeOutSec = Convert-TimeToSeconds $script:logoFadeOut
		
		$previewSec = Convert-TimeToSeconds $script:previewTime

        $posCoords = $script:logoPosition.Split(':')
        $logoX = $posCoords[0]
        $logoY = $posCoords[1]
        $lWidth = [int]$script:logoWidth
        $logoAlpha = ([double]$script:logoOpacity / 100.0).ToString("0.00", [System.Globalization.CultureInfo]::InvariantCulture)

        $bannerCoords = $script:bannerPosition.Split(':')
        $bannerX = $bannerCoords[0]
        $bannerY = $bannerCoords[1]
        $bWidth  = [int]$script:bannerWidth
        $bHeight = [math]::Round($bWidth / 4.4)
        $script:bannerHeight = $bHeight.ToString()
        $bannerAlpha = ([double]$script:bannerOpacity / 100.0).ToString("0.00", [System.Globalization.CultureInfo]::InvariantCulture)

        $scaleFactor = $bWidth / 220.0
        $fontSize1   = [math]::Round(22 * $scaleFactor)
        $fontSize2   = [math]::Round(20 * $scaleFactor)
        $textX       = [math]::Round(12 * $scaleFactor)
        $textY1      = [math]::Round(6 * ($bHeight / 50.0))
        $textY2      = [math]::Round(28 * ($bHeight / 50.0))

        $logoInputArgs = [System.Collections.Generic.List[string]]::new()
        $filterParts = [System.Collections.Generic.List[string]]::new()
        $finalFilterParts = [System.Collections.Generic.List[string]]::new()
        $currentVideoInput = "0:v"
        
        $schedCount = $validSchedules.Count

        # Χρήση Case-Insensitive Dictionary για απόλυτη ασφάλεια στις διαδρομές αρχείων
        $fileToIndex = [System.Collections.Generic.Dictionary[string, int]]::new([StringComparer]::OrdinalIgnoreCase)
        $inputIdx = 1

        foreach ($sched in $validSchedules) {
            $resolvedPath = (Get-Item -LiteralPath $sched.File).FullName
            if (-not $fileToIndex.ContainsKey($resolvedPath)) {
                $fileToIndex[$resolvedPath] = $inputIdx

                $isImg = $resolvedPath -match '\.(jpg|jpeg|png)$'
                if ($isImg) {
                    $logoInputArgs.Add("-loop")
                    $logoInputArgs.Add("1")
                } else {
                    $logoInputArgs.Add("-stream_loop")
                    $logoInputArgs.Add("-1")
                }
                $logoInputArgs.Add("-i")
                $logoInputArgs.Add($resolvedPath)

                $inputIdx++
            }
        }

        for ($i = 0; $i -lt $schedCount; $i++) {
            $sched = $validSchedules[$i]
            $resolvedPath = (Get-Item -LiteralPath $sched.File).FullName
            
            $fileIdx = [int]$fileToIndex[$resolvedPath]

            # --- ΕΛΕΓΧΟΣ DEBUGGING ---
            Write-Host "DEBUG -> Index: $i | File: $resolvedPath | Resolved Index: $fileIdx" -ForegroundColor Magenta
            # --------------------------

            if (-not $fileIdx -or $fileIdx -lt 1) {
                Write-Host "[ΣΦΑΛΜΑ] Μη έγκυρος δείκτης εισόδου για το αρχείο: $resolvedPath" -ForegroundColor Red
                return $null
            }

            $startTimeSec = Convert-TimeToSeconds $sched.Start
            $durSec       = Convert-TimeToSeconds $sched.Duration
            $fadeInSec    = [double]$sched.FadeIn
            $fadeOutLogoSec = [double]$sched.FadeOut

            # --- ΠΡΟΣΘΕΣΤΕ ΑΥΤΗ ΤΗ ΓΡΑΜΜΗ ΓΙΑ ΕΛΕΓΧΟ ---
            Write-Host "DEBUG SCHED -> Start: $($sched.Start) => Sec: $startTimeSec | Duration: $($sched.Duration) => Sec: $durSec" -ForegroundColor Yellow
            # ---------------------------------------------
            
            $enableExpr = "between(t + $previewSec,$startTimeSec,$($startTimeSec + $durSec))"

			$fadeFilter = ""
			if ($fadeInSec -gt 0) {
				$fadeFilter = ",fade=t=in:st=" + $startTimeSec + ":d=" + $fadeInSec + ":alpha=1"
			}
			if ($fadeOutLogoSec -gt 0) {
				$fadeOutStart = $startTimeSec + $durSec - $fadeOutLogoSec
				if ($fadeOutStart -ge $startTimeSec) {
					$fadeFilter += ",fade=t=out:st=" + $fadeOutStart + ":d=" + $fadeOutLogoSec + ":alpha=1"
				}
			}

            $finalFadeFilter = $fadeFilter
            if ($script:IsRunningPreview) {
                $fadeFilter = ""
            }

			Write-Host "TEST FADE -> fadeInSec: $fadeInSec | startTimeSec: $startTimeSec | fadeFilter: $fadeFilter" -ForegroundColor Cyan

			$pipName = "pip$i"
			$isLastLogo = ($i -eq $schedCount - 1)
			if ($isLastLogo -and $subChoice -eq "1") {
				$nextVideoInput = "final"
			} else {
				$nextVideoInput = "v_logo_$i"
			}

            $filterPart = "[${fileIdx}:v]scale=${lWidth}:-1,format=yuva420p,colorchannelmixer=aa=$logoAlpha${fadeFilter}[$pipName];[$currentVideoInput][$pipName]overlay=x=$logoX`:y=$logoY`:enable='$enableExpr':shortest=1[$nextVideoInput]"
            $finalFilterPart = "[${fileIdx}:v]scale=${lWidth}:-1,format=yuva420p,colorchannelmixer=aa=$logoAlpha${finalFadeFilter}[$pipName];[$currentVideoInput][$pipName]overlay=x=$logoX`:y=$logoY`:enable='$enableExpr':shortest=1[$nextVideoInput]"
            $filterParts.Add($filterPart)
            $finalFilterParts.Add($finalFilterPart)

			$currentVideoInput = $nextVideoInput
        }
		
		
        if ($subChoice -eq "2") {
            $escapedEpPath = ($textFilePath -replace '\\', '/').Replace(':', '\:')
            $bannerFinalInput = "final"

            $filterParts.Add("color=c=white@${bannerAlpha}:s=${bWidth}x${bHeight}[box]")
            $filterParts.Add("[box]drawtext=fontfile='C\:/Windows/Fonts/arialbd.ttf':text='$seasonText':x=$textX`:y=$textY1`:fontsize=$fontSize1`:fontcolor=black[tb1]")
            $filterParts.Add("[tb1]drawtext=fontfile='C\:/Windows/Fonts/arialbd.ttf':textfile='$escapedEpPath':x=$textX`:y=$textY2`:fontsize=$fontSize2`:fontcolor=black[tb2]")
            $filterParts.Add("[tb2]format=yuva420p,fade=t=out:st=$fadeOutSec`:d=1:alpha=1[banner]")
            $filterParts.Add("[$currentVideoInput][banner]overlay=x=$bannerX`:y=$bannerY`:shortest=1[$bannerFinalInput]")
            $finalFilterParts.Add("[tb2]format=yuva420p,fade=t=out:st=$fadeOutSec`:d=1:alpha=1[banner]")
            $finalFilterParts.Add("[$currentVideoInput][banner]overlay=x=$bannerX`:y=$bannerY`:shortest=1[$bannerFinalInput]")
        }

        $filter = $filterParts -join ";"

        # --- ΕΛΕΓΧΟΣ DEBUGΓING ΦΙΛΤΡΟΥ ---
        Write-Host "DEBUG FILTER -> $filter" -ForegroundColor Yellow
        # -----------------------------------

        Write-Host "`n>>> Δημιουργία εικόνας προεπισκόπησης (Preview JPG στο $script:previewTime)..." -ForegroundColor Cyan
        
        # [ΑΦΑΙΡΕΘΗΚΕ ΕΔΩ] Ο υπολογισμός δεν χρειάζεται να ξαναγίνει εδώ, υπάρχει ήδη πιο πάνω!
		# $previewSec = Convert-TimeToSeconds $script:previewTime
		
		
		# 1. Βήμα 1: Αστραπιαία εξαγωγή του καθαρού καρέ βίντεο με Fast Seek
		Write-Host "`n>>> Δημιουργία καθαρού καρέ προεπισκόπησης (Fast Seek στο $script:previewTime)..." -ForegroundColor Cyan

		$rawPreviewArgs = @(
			"-hide_banner", "-loglevel", "error", "-y",
			"-ss", $script:previewTime,
			"-i", $inputFile,
			"-vframes", "1",
			"-q:v", "2",
			$previewImage
		)
		& "$script:ffmpegPath" @rawPreviewArgs

        if (Test-Path -LiteralPath $previewImage) {
            # Αντικαθιστούμε το input του βίντεο (0) με την ίδια την εικόνα preview 
            # ώστε να «καεί» πάνω της το λογότυπο απευθείας για το οπτικό αποτέλεσμα.
			
			# 2. Βήμα 2: Εφαρμογή των φίλτρων overlay απευθείας πάνω στο απομονωμένο καρέ
            Write-Host "`n>>> Εφαρμογή λογότυπου στην εικόνα προεπισκόπησης..." -ForegroundColor Cyan
						
            $overlayPreviewArgs = @(
                "-hide_banner", "-loglevel", "error", "-y",
                "-i", $previewImage
            ) + @($logoInputArgs) + @(
                "-filter_complex", $filter,
                "-map", "[final]",
                "-vframes", "1",
                "-q:v", "2",
                $previewImage
            )
            & "$script:ffmpegPath" @overlayPreviewArgs
        
		
		
            Write-Host "`n[INFO] Άνοιγμα εικόνας προεπισκόπησης: $previewImage" -ForegroundColor Green
            Invoke-Item -LiteralPath $previewImage
            
            $confirm = Read-Host "`nΕγκρίνετε το αποτέλεσμα της προεπισκόπησης για έναρξη κωδικοποίησης; (Y: Έναρξη / N: Διορθώσεις / Q: Ακύρωση)"
            if ($confirm -match '^[YyΝν]$') {
				# --- ΤΕΛΟΣ PREVIEW (Ξεκινάει η κανονική κωδικοποίηση) ---
                $script:IsRunningPreview = $false

                $previewLoop = $false
            }
            elseif ($confirm -match '^[Qq]$') {
                Write-Host "[ΑΚΥΡΩΣΗ] Η διαδικασία κωδικοποίησης ακυρώθηκε από τον χρήστη." -ForegroundColor Yellow
                if (Test-Path -LiteralPath $previewImage) { Remove-Item -LiteralPath $previewImage -Force }
                return $null
            }
            else {
                $inSubMenu = $true
                while ($inSubMenu) {
                    Write-Host "`n========================================================" -ForegroundColor Yellow
                    Write-Host "             ΥΠΟΜΕΝΟΥ ΔΙOΡΘΩΣΕΩΝ PREVIEW                " -ForegroundColor Yellow
                    Write-Host "========================================================" -ForegroundColor Yellow
                    Write-Host " 1. Αλλαγή Χρόνου Preview          [Τρέχων: $script:previewTime]"
                    Write-Host " 2. [LOGO] Θέση & Πλάτους          [Θέση: $script:logoPosition | W: $script:logoWidth px]"
                    Write-Host " 3. [BANNER] Θέση & Πλάτους         [Θέση: $script:bannerPosition | W: $script:bannerWidth px]"
                    if ($subChoice -eq "2") {
                        Write-Host " 4. Διόρθωση Κειμένων Banner        [Κύκλος: $seasonText | Τίτλος: $epTitle]"
                    }
                    Write-Host " R. Δημιουργία Νέου Preview (Επανέλεγχος)" -ForegroundColor Green
                    Write-Host " Q. Ακύρωση Διαδικασίας" -ForegroundColor Red
                    Write-Host "========================================================" -ForegroundColor Yellow
                    
                    $modChoice = Read-Host "Επιλέξτε ρύθμιση για αλλαγή (1-4, R για νέο preview, Q για ακύρωση)"
                    
                    switch ($modChoice) {
                        "1" { Set-PreviewTime }
                        "2" {
                            Set-LogoPosition
                            Set-LogoWidth
                        }
                        "3" {
                            Set-BannerPosition
                            Set-BannerWidth
                        }
                        "4" {
                            if ($subChoice -eq "2") {
                                $newSeason = Read-Host "Νέο κείμενο κύκλου (Enter για διατήρηση: $seasonText)"
                                if (-not [string]::IsNullOrWhiteSpace($newSeason)) { $seasonText = $newSeason }

                                $newTitle = Read-Host "Νέος τίτλος επεισοδίου (Enter για διατήρηση: $epTitle)"
                                if (-not [string]::IsNullOrWhiteSpace($newTitle)) {
                                    $epTitle = $newTitle
                                    [System.IO.File]::WriteAllText($textFilePath, $epTitle, (New-Object System.Text.UTF8Encoding $false))
                                }
                            }
                        }
                        "r" { $inSubMenu = $false }
                        "R" { $inSubMenu = $false }
                        "q" {
                            Write-Host "[ΑΚΥΡΩΣΗ] Η διαδικασία ακυρώθηκε από τον χρήστη." -ForegroundColor Yellow
                            if (Test-Path -LiteralPath $previewImage) { Remove-Item -LiteralPath $previewImage -Force }
                            return $null
                        }
                        "Q" {
                            Write-Host "[ΑΚΥΡΩΣΗ] Η διαδικασία ακυρώθηκε από τον χρήστη." -ForegroundColor Yellow
                            if (Test-Path -LiteralPath $previewImage) { Remove-Item -LiteralPath $previewImage -Force }
                            return $null
                        }
                        default { Write-Host "Μη έγκυρη επιλογή." -ForegroundColor Red }
                    }
                }
            }
        } else {
            Write-Host "[ΠΡΟΕΙΔOΠΟΙΗΣΗ] Απέτυχε η δημιουργία εικόνας προεπισκόπησης. Συνέχεια με κωδικοποίηση..." -ForegroundColor Yellow
            $previewLoop = $false
        }
    }

    Write-Host "`n>>> Επεξεργασία σε εξέλιξη (Εφαρμογή Overlay)... Παρακαλώ περιμένετε." -ForegroundColor Cyan

    $filter = $finalFilterParts -join ";"
    
    # --- ΔΙΟΡΘΩΣΗ ΧΡΟΝΙΣΜΟΥ LOGO SCHEDULE ---
    # Το Preview χρησιμοποιεί στατικό καρέ, άρα το φίλτρο του χρειάζεται
    # μετατόπιση με Preview Time. Στην τελική κωδικοποίηση, το t είναι ήδη
    # ο χρόνος του αρχικού βίντεο. Αφαιρούμε τη μετατόπιση πάντα, ακόμη κι
    # αν το Preview απέτυχε ή παρακάμφθηκε.
    $filter = $filter -replace 'between[(]t [+] [^,]+,', 'between(t,'
    # ------------------------------------------

    $ffArgs = @("-y", "-i", $inputFile) + @($logoInputArgs) + @("-filter_complex", $filter, "-map", "[final]", "-map", "0:a", "-c:a", "copy", $output)
    & "$script:ffmpegPath" @ffArgs

    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $output)) {
        if (Test-Path -LiteralPath $previewImage) { Remove-Item -LiteralPath $previewImage -Force }
        Write-Host "`n========================================================" -ForegroundColor Green
        Write-Host " [ΕΠΙΤΥΧΙΑ] Η εφαρμογή Overlay ολοκληρώθηκε!" -ForegroundColor Green
        Write-Host " Αρχείο: $output" -ForegroundColor Gray
        Write-Host "========================================================" -ForegroundColor Green
        
        Notify-Success "Η εφαρμογή Overlay ολοκληρώθηκε επιτυχώς!"
        Start-Sleep -Seconds 2
        return $output
    }

    Write-Host "`n========================================================" -ForegroundColor Red
    Write-Host " [ΣΦΑΛΜΑ] Η διαδικασία Apply-OverlayBanner απέτυχε!" -ForegroundColor Red
    Write-Host "========================================================" -ForegroundColor Red
    Notify-Error "Απέτυχε η διαδικασία Apply-OverlayBanner."
    Start-Sleep -Seconds 2
    return $null
}

# 5. Διπλός Ήχος / Stereo Dialog Boost
function Apply-AudioBooster ($inputFile, $outputDir) {
    if ([string]::IsNullOrWhiteSpace($outputDir)) { $outputDir = Split-Path $inputFile -Parent }
    $name = [System.IO.Path]::GetFileNameWithoutExtension($inputFile)
    $output = Join-Path $outputDir "$name - double audio.mkv"

    $channels = & "$script:ffprobePath" -v error -select_streams a:0 -show_entries stream=channels -of default=noprint_wrappers=1:nokey=1 "$inputFile"
    $CompandFilter = "compand=attacks=0.02:decays=0.2:points=-60/-60|-40/-34|-20/-20|0/-10"
    $LimiterFilter = "alimiter=level_in=1:level_out=1:limit=0.89:attack=5:release=50:asc=1"

    if ([int]$channels -ge 6) {
        $AudioFilter = "[0:a]pan=stereo|c0=0.5*L+0.8*C+0.3*SR|c1=0.5*R+0.8*C+0.3*SL,$CompandFilter,dynaudnorm=f=150:g=15,$LimiterFilter[norma]"
    } else {
        $AudioFilter = "[0:a]highpass=f=200,equalizer=f=2000:width_type=h:width=1000:g=6,$CompandFilter,dynaudnorm=f=150:g=15,$LimiterFilter[norma]"
    }

    Write-Host "`n>>> ΣΤΑΔΙO: Επεξεργασία Ήχου & Δημιουργία Δεύτερου Καναλιού..." -ForegroundColor Green
    
    $ffArgs = @("-y", "-i", $inputFile, "-filter_complex", $AudioFilter, "-map", "0:v", "-c:v", "copy", "-map", "0:a", "-c:a:0", "copy", "-map", "[norma]", "-c:a:1", "aac", "-b:a:1", "192k", "-metadata:s:a:0", "title=Original Audio", "-metadata:s:a:1", "title=Stereo Dialog Boost (Limited)", $output)
    & "$script:ffmpegPath" @ffArgs

    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $output)) {
        Write-Host "`n[ΕΠΙΤΥΧΙΑ] Η επεξεργασία ήχου ολοκληρώθηκε: $output" -ForegroundColor Green
        Notify-Success "Η ενίσχυση ήχου ολοκληρώθηκε."
        Start-Sleep -Seconds 2
        return $output
    }
    Notify-Error "Απέτυχε η επεξεργασία ήχου."
    Write-Host "`n[ΣΦΑΛΜΑ] Απέτυχε η επεξεργασία ήχου!" -ForegroundColor Red
    Start-Sleep -Seconds 2
    return $null
}

# 6. Μετατροπή Crop 16:9 σε 4:3 (Περικοπή μαύρων μπαρών)
function Convert-Crop43 ($inputFile, $outputDir) {
    if ([string]::IsNullOrWhiteSpace($outputDir)) { $outputDir = Split-Path $inputFile -Parent }
    $output = Join-Path $outputDir "Output_43_Cleaned.mkv"
    Write-Host "`n>>> ΣΤΑΔΙO: Μετατροπή Aspect Ratio (Crop 1440x1080 σε 4:3) στο: $output" -ForegroundColor Green
    
    $ffArgs = @("-y", "-i", $inputFile, "-vf", "crop=1440:1080:240:0", "-c:v", "libx264", "-crf", "18", "-preset", "fast", "-c:a", "copy", $output)
    & "$script:ffmpegPath" @ffArgs

    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $output)) {
        Write-Host "`n[ΕΠΙΤΥΧΙΑ] Το Crop 4:3 ολοκληρώθηκε: $output" -ForegroundColor Green
        Notify-Success "Το Crop 4:3 ολοκληρώθηκε επιτυχώς."
        Start-Sleep -Seconds 2
        return $output
    }
    Notify-Error "Απέτυχε το Crop 4:3."
    Write-Host "`n[ΣΦΑΛΜΑ] Απέτυχε το Crop 4:3!" -ForegroundColor Red
    Start-Sleep -Seconds 2
    return $null
}

# --- ΚΥΡΙΩΣ ΜΕΝΟΥ ---
while ($true) {
    Clear-Host
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "          FFMPEG MEDIA TOOLKIT - ΚΥΡΙO ΜΕΝΟΥ           " -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host " -- ΡΥΘΜΙΣΕΙΣ LOGO (Αρχεία, θέσεις, πλάτη & χρονισμοί) --" -ForegroundColor Magenta
    Write-Host " 01. Ορισμός Διαδρομής FFmpeg       [$script:ffmpegPath]"
    Write-Host " 02. Ορισμός Διαδρομής FFprobe      [$script:ffprobePath]"
    Write-Host " 03. Ορισμός Φακέλου Λογοτύπων     [$script:logoDirPath]"
    Write-Host " 04. Ορισμός Θέσης Logo (X:Y)       [$script:logoPosition]"
    Write-Host " 05. Ορισμός Πλάτους Logo (px)      [$script:logoWidth px]"
    Write-Host " 06. Ορισμός Διαφάνειας Logo (%)    [$script:logoOpacity %]"
    Write-Host " 07. Διαχείριση Schedules Logo      [Σύνολο: $($script:logoSchedules.Count) διαστήματα]" -ForegroundColor Green
    Write-Host ""
    Write-Host " -- ΡΥΘΜΙΣΕΙΣ BANNER (Λευκό πλαίσιο με κείμενα τίτλων) --" -ForegroundColor Magenta
    Write-Host " 08. Ορισμός Θέσης Banner (X:Y)     [$script:bannerPosition]"
    Write-Host " 09. Ορισμός Πλάτους Banner (px)    [$script:bannerWidth px]"
    Write-Host " 10. Ορισμός Διαφάνειας Banner (%)  [$script:bannerOpacity %]"
    Write-Host " 11. Ορισμός Χρόνου Fade-Out Banner [$script:logoFadeOut]"
    Write-Host " 12. Ορισμός Χρόνου Preview         [$script:previewTime]"
    Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " -- ΜΕΜOΝΩΜΕΝΕΣ ΛΕΙΤΟΥΡΓΙΕΣ --" -ForegroundColor Yellow
    Write-Host " 1. Επιδιόρθωση Βίντεο (Lossless Fix)"
    Write-Host " 2. Αφαίρεση Διαφημίσεων / Κοπή (Επιλογή mkv/mp4 & 16:9/4:3/Default)"
    Write-Host " 3. Συνένωση Βίντεο (Concat)"
    Write-Host " 4. Επικάλυψη Logo & Banner (Με Preview Frame)"
    Write-Host " 5. Ενίσχυση Διαλόγων / Διπλό Κανάλι Ήχου"
    Write-Host " 6. Μετατροπή 16:9 σε 4:3 (Crop 1440x1080)"
    Write-Host ""
    Write-Host " -- ΣΥΝΔΥΑΣΤΙΚΕΣ ΛΕΙΤΟΥΡΓΙΕΣ (Προεπιλογές: Φορμά .mkv, Αρχική Αναλογία) --" -ForegroundColor Yellow
    Write-Host " 7. Pipeline 1: [Επιδιόρθωση -> Κοπή -> Συνένωση]"
    Write-Host " 8. Pipeline 2: [Επιδιόρθωση -> Κοπή -> Συνένωση -> Τελικό Crop 16:9 σε 4:3]"
    Write-Host " 9. Full TV Pipeline: [Επιδιόρθωση -> Κοπή -> Συνένωση -> Logo/Banner Overlay]"
    Write-Host " 10. Full TV Pipeline + Audio: [Επιδιόρθωση -> Κοπή -> Συνένωση -> Logo/Banner Overlay -> Audio Boost]"
    Write-Host ""
    Write-Host " Q. Έξοδος" -ForegroundColor Red
    Write-Host "========================================================" -ForegroundColor Cyan

    $choice = Read-Host "Επιλέξτε λειτουργία (01-12, 1-10 ή Q)"

    if ($choice -eq 'q' -or $choice -eq 'Q') { break }

    switch ($choice) {
        "01" { Set-FFmpegPath }
        "02" { Set-FFprobePath }
        "03" { Set-LogoDirPath }
        "04" { Set-LogoPosition }
        "05" { Set-LogoWidth }
        "06" { Set-LogoOpacity }
        "07" { Set-LogoSchedules }
        "08" { Set-BannerPosition }
        "09" { Set-BannerWidth }
        "10" { Set-BannerOpacity }
        "11" { Set-LogoFadeOut }
        "12" { Set-PreviewTime }
        "1" {
            $f = Get-ValidInputFile "Σύρετε το αρχείο ή τον φάκελο βίντεο:"
            if ($f) { Repair-Video $f }
            Read-Host "`nΠιέστε Enter για να επιστρέψετε στο μενού..."
        }
        "2" {
            $f = Get-ValidInputFile "Σύρετε το αρχείο ή τον φάκελο βίντεο:"
            if ($f) { Cut-Video $f "" "" }
            Read-Host "`nΠιέστε Enter για να επιστρέψετε στο μενού..."
        }
        "3" {
            $files = [System.Collections.Generic.List[string]]::new()
            do {
                $f = Get-ValidInputFile "Σύρετε αρχείο/φάκελο για συνένωση (Enter για τέλος):"
                if (-not $f) { break }
                $files.Add($f)
            } while ($true)
            if ($files.Count -gt 0) {
                $outDir = Get-ValidOutputDir (Split-Path $files[0] -Parent)
                Concat-Videos $files $outDir "mkv"
            }
            Read-Host "`nΠιέστε Enter για να επιστρέψετε στο μενού..."
        }
        "4" {
            $f = Get-ValidInputFile "Σύρετε το αρχείο ή τον φάκελο βίντεο:"
            if ($f) {
                $outDir = Get-ValidOutputDir (Split-Path $f -Parent)
                Apply-OverlayBanner $f $outDir
            }
            Read-Host "`nΠιέστε Enter για να επιστρέψετε στο μενού..."
        }
        "5" {
            $f = Get-ValidInputFile "Σύρετε το αρχείο ή τον φάκελο βίντεο:"
            if ($f) {
                $outDir = Get-ValidOutputDir (Split-Path $f -Parent)
                Apply-AudioBooster $f $outDir
            }
            Read-Host "`nΠιέστε Enter για να επιστρέψετε στο μενού..."
        }
        "6" {
            $f = Get-ValidInputFile "Σύρετε το αρχείο ή τον φάκελο βίντεο:"
            if ($f) {
                $outDir = Get-ValidOutputDir (Split-Path $f -Parent)
                Convert-Crop43 $f $outDir
            }
            Read-Host "`nΠιέστε Enter για να επιστρέψετε στο μενού..."
        }
        "7" {
            $files = [System.Collections.Generic.List[string]]::new()
            do {
                $f = Get-ValidInputFile "Σύρετε αρχείο/φάκελο βίντεο (Enter για τέλος):"
                if (-not $f) { break }
                $files.Add($f)
            } while ($true)
            
            if ($files.Count -gt 0) {
                $outDir = Get-ValidOutputDir (Split-Path $files[0] -Parent)
                $fixedFiles = [System.Collections.Generic.List[string]]::new()
                $finalFiles = [System.Collections.Generic.List[string]]::new()

                foreach ($f in $files) {
                    $repaired = Repair-Video $f
                    if ($repaired) {
                        $fixedFiles.Add($repaired)
                        $cut = Cut-Video $repaired "mkv" "1"
                        if ($cut) { $finalFiles.Add($cut) }
                    }
                }
                
                $merged = $null
                if ($finalFiles.Count -gt 0) {
                    $merged = Concat-Videos $finalFiles $outDir "mkv"
                }
                
                Safe-Clear-TempFiles $fixedFiles $finalFiles $merged $null $null
            }
            Read-Host "`nΠιέστε Enter για να επιστρέψετε στο μενού..."
        }
        "8" {
            $files = [System.Collections.Generic.List[string]]::new()
            do {
                $f = Get-ValidInputFile "Σύρετε αρχείο/φάκελο βίντεο (Enter για τέλος):"
                if (-not $f) { break }
                $files.Add($f)
            } while ($true)

            if ($files.Count -gt 0) {
                $outDir = Get-ValidOutputDir (Split-Path $files[0] -Parent)
                $fixedFiles = [System.Collections.Generic.List[string]]::new()
                $finalFiles = [System.Collections.Generic.List[string]]::new()

                foreach ($f in $files) {
                    $repaired = Repair-Video $f
                    if ($repaired) {
                        $fixedFiles.Add($repaired)
                        $cut = Cut-Video $repaired "mkv" "1"
                        if ($cut) { $finalFiles.Add($cut) }
                    }
                }
                
                $merged = $null
                if ($finalFiles.Count -gt 0) {
                    $merged = Concat-Videos $finalFiles $outDir "mkv"
                    if ($merged) {
                        Convert-Crop43 $merged $outDir
                    }
                }
                
                Safe-Clear-TempFiles $fixedFiles $finalFiles $merged $null $null
            }
            Read-Host "`nΠιέστε Enter για να επιστρέψετε στο μενού..."
        }
        "9" {
            $files = [System.Collections.Generic.List[string]]::new()
            do {
                $f = Get-ValidInputFile "Σύρετε αρχείο/φάκελο βίντεο (Enter για τέλος):"
                if (-not $f) { break }
                $files.Add($f)
            } while ($true)

            if ($files.Count -gt 0) {
                $outDir = Get-ValidOutputDir (Split-Path $files[0] -Parent)
                $fixedFiles = [System.Collections.Generic.List[string]]::new()
                $finalFiles = [System.Collections.Generic.List[string]]::new()

                foreach ($f in $files) {
                    $repaired = Repair-Video $f
                    if ($repaired) {
                        $fixedFiles.Add($repaired)
                        $cut = Cut-Video $repaired "mkv" "1"
                        if ($cut) { $finalFiles.Add($cut) }
                    }
                }

                $merged = $null
                $overlayed = $null
                $targetOverlayPath = Join-Path $outDir "Merged_Final_noSign.mkv"

                if ($finalFiles.Count -gt 0) {
                    $merged = Concat-Videos $finalFiles $outDir "mkv"
                    if ($merged) {
                        $overlayed = Apply-OverlayBanner $merged $outDir
                    }
                }

                Safe-Clear-TempFiles $fixedFiles $finalFiles $merged $overlayed $targetOverlayPath
            }
            Read-Host "`nΠιέστε Enter για να επιστρέψετε στο μενού..."
        }
        default {
            if ($choice -eq "10") {
                $files = [System.Collections.Generic.List[string]]::new()
                do {
                    $f = Get-ValidInputFile "Σύρετε αρχείο/φάκελο βίντεο (Enter για τέλος):"
                    if (-not $f) { break }
                    $files.Add($f)
                } while ($true)

                if ($files.Count -gt 0) {
                    $outDir = Get-ValidOutputDir (Split-Path $files[0] -Parent)
                    $fixedFiles = [System.Collections.Generic.List[string]]::new()
                    $finalFiles = [System.Collections.Generic.List[string]]::new()

                    foreach ($f in $files) {
                        $repaired = Repair-Video $f
                        if ($repaired) {
                            $fixedFiles.Add($repaired)
                            $cut = Cut-Video $repaired "mkv" "1"
                            if ($cut) { $finalFiles.Add($cut) }
                        }
                    }

                    $merged = $null
                    $overlayed = $null
                    $targetOverlayPath = Join-Path $outDir "Merged_Final_noSign.mkv"

                    if ($finalFiles.Count -gt 0) {
                        $merged = Concat-Videos $finalFiles $outDir "mkv"
                        if ($merged) {
                            $overlayed = Apply-OverlayBanner $merged $outDir
                            if ($overlayed) {
                                Apply-AudioBooster $overlayed $outDir
                            }
                        }
                    }

                    Safe-Clear-TempFiles $fixedFiles $finalFiles $merged $overlayed $targetOverlayPath
                }
                Read-Host "`nΠιέστε Enter για να επιστρέψετε στο μενού..."
            } else {
                Write-Host "Μη έγκυρη επιλογή. Πιέστε Enter για συνέχεια..." -ForegroundColor Red
                Read-Host
            }
        }
    }
}