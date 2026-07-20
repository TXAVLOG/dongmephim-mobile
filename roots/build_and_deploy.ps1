# build_and_deploy.ps1
# Automates builds for Android, Smart TV, and Windows, then uploads to Cloudflare R2.
# Default target is "all"

param(
    [string]$Target = "all",
    [switch]$SkipBuild,
    [switch]$BuildAAB
)

$ErrorActionPreference = "Stop"

# Define Paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectDir = Resolve-Path (Join-Path $ScriptDir "..")
$OutputDir = Join-Path $ScriptDir "Output"

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Resolve Inno Setup
$ISCC = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $ISCC)) {
    $ISCC = "C:\Program Files\Inno Setup 6\ISCC.exe"
}

# Helper to show beautiful error and exit without ugly system traceback
function Show-Error {
    param(
        [string]$Message
    )
    Write-Host "`nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" -ForegroundColor Red
    Write-Host "❌ LỖI HỆ THỐNG" -ForegroundColor Red
    Write-Host "👉 Chi tiết: $Message" -ForegroundColor Red
    Write-Host "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`n" -ForegroundColor Red
    Exit 1
}

# Check Pre-requisites
$PythonCmd = ""
function Check-Env {
    Write-Host "Checking environment tools..." -ForegroundColor Cyan
    if (-not (Get-Command "flutter" -ErrorAction SilentlyContinue)) {
        Show-Error "Flutter CLI not found in PATH! Vui lòng cài đặt Flutter trước."
    }
    
    $script:PythonCmd = ""
    if (Get-Command "py" -ErrorAction SilentlyContinue) {
        $script:PythonCmd = "py"
    } elseif (Get-Command "python" -ErrorAction SilentlyContinue) {
        $script:PythonCmd = "python"
    } else {
        Show-Error "Python (py/python) không tìm thấy trong PATH! Vui lòng cài đặt Python trước."
    }
    Write-Host "  Using Python: $script:PythonCmd" -ForegroundColor Green
}

# Helper to run commands and fail script if error
function Run-Command {
    param(
        [string]$Title,
        [scriptblock]$Action
    )
    Write-Host "`n==================================================" -ForegroundColor Yellow
    Write-Host ">>> BẮT ĐẦU TÁC VỤ: $Title" -ForegroundColor Yellow
    Write-Host "==================================================" -ForegroundColor Yellow
    
    & $Action
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" -ForegroundColor Red
        Write-Host "❌ LỖI: Tác vụ '$Title' thất bại!" -ForegroundColor Red
        Write-Host "👉 Mã thoát (Exit Code): $LASTEXITCODE" -ForegroundColor Red
        Write-Host "Vui lòng xem log chi tiết phía trên để tìm nguyên nhân." -ForegroundColor Red
        Write-Host "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`n" -ForegroundColor Red
        Exit $LASTEXITCODE
    }
    
    Write-Host "`n==================================================" -ForegroundColor Green
    Write-Host "✅ HOÀN THÀNH TÁC VỤ: $Title" -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor Green
}


# Parse Version
$PubspecPath = Join-Path $ProjectDir "pubspec.yaml"
$PubspecContent = Get-Content $PubspecPath -Raw
if ($PubspecContent -notmatch 'version:\s*([^\s]+)') {
    Show-Error "Không thể đọc thông tin version từ file pubspec.yaml."
}
$Version = $Matches[1]
$PureVersion = $Version.Split('+')[0]

Check-Env

$BuildReports = @()

# 1. BUILD ANDROID APK (Mobile & Smart TV share the same build)
$BuildApk = $false
if ($Target -eq "all" -or $Target -eq "android" -or $Target -eq "tv") {
    $BuildApk = $true
}

if ($BuildApk) {
    if (-not $SkipBuild) {
        Run-Command "Stopping Existing Gradle Daemons (Releasing Locks)" {
            $OriginalErrorAction = $ErrorActionPreference
            $ErrorActionPreference = "SilentlyContinue"
            Write-Host "Killing Gradle Java processes..." -ForegroundColor Yellow
            Get-Process -Name "java" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            $ErrorActionPreference = $OriginalErrorAction
            $global:LASTEXITCODE = 0
        }
        Run-Command "Building Android Release APK" {
            flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols --android-skip-build-dependency-validation
        }
    } else {
        Write-Host "[SkipBuild] Bỏ qua bước build Android, sử dụng file APK có sẵn..." -ForegroundColor Green
    }
    
    $SourceApk = Join-Path $ProjectDir "build\app\outputs\flutter-apk\app-release.apk"
    if (-not (Test-Path $SourceApk)) {
        Show-Error "Không tìm thấy file APK đã build tại $SourceApk! Vui lòng bỏ -SkipBuild để build lại."
    }

    # Android Mobile
    if ($Target -eq "all" -or $Target -eq "android") {
        $DestMobileApk = Join-Path $OutputDir "DongMePhim-Mobile.apk"
        Copy-Item $SourceApk $DestMobileApk -Force
        $BuildReports += @{
            Name = "DongMePhim-Mobile.apk"
            Path = $DestMobileApk
            Type = "Android Mobile"
        }
    }

    # Android Smart TV
    if ($Target -eq "all" -or $Target -eq "tv") {
        $DestTvApk = Join-Path $OutputDir "DongMePhim-TV.apk"
        Copy-Item $SourceApk $DestTvApk -Force
        $BuildReports += @{
            Name = "DongMePhim-TV.apk"
            Path = $DestTvApk
            Type = "Smart TV"
        }
    }
}

# 1.5. BUILD ANDROID APP BUNDLE (.aab) FOR GOOGLE PLAY CONSOLE
$doBuildAAB = $false
if ($BuildAAB) {
    $doBuildAAB = $true
} elseif ($Target -eq "aab") {
    $doBuildAAB = $true
} elseif ($Target -eq "all" -or $Target -eq "android") {
    Write-Host "`n--------------------------------------------------" -ForegroundColor Cyan
    Write-Host "📱 Đã xử lý xong Android APK!" -ForegroundColor Green
    $answer = Read-Host "👉 Bạn có muốn build thêm Android App Bundle (.aab) cho Google Play Console không? (y/N)"
    if ($answer -match "^[yY]([eE][sS])?$") {
        $doBuildAAB = $true
    }
}

if ($doBuildAAB) {
    if (-not $SkipBuild) {
        Run-Command "Building Android App Bundle (.aab) for Google Play Console" {
            flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols --android-skip-build-dependency-validation
        }
    } else {
        Write-Host "[SkipBuild] Bỏ qua bước build AAB, sử dụng file .aab có sẵn..." -ForegroundColor Green
    }
    
    $SourceAab = Join-Path $ProjectDir "build\app\outputs\bundle\release\app-release.aab"
    if (-not (Test-Path $SourceAab)) {
        Show-Error "Không tìm thấy file App Bundle đã build tại $SourceAab! Vui lòng bỏ -SkipBuild để build lại."
    }

    $DestAab = Join-Path $OutputDir "DongMePhim-AppBundle.aab"
    Copy-Item $SourceAab $DestAab -Force
    $BuildReports += @{
        Name = "DongMePhim-AppBundle.aab"
        Path = $DestAab
        Type = "Google Play AppBundle"
    }
}

# 2. BUILD WINDOWS & INNO SETUP
if ($Target -eq "all" -or $Target -eq "windows") {
    if (-not $SkipBuild) {
        Run-Command "Building Windows Release Binary" {
            flutter build windows --release
        }
    } else {
        Write-Host "[SkipBuild] Bỏ qua bước build Windows binary..." -ForegroundColor Green
    }

    $DestWindowsExe = Join-Path $OutputDir "DongMePhim_v${PureVersion}_Setup.exe"
    if (-not $SkipBuild -or -not (Test-Path $DestWindowsExe)) {
        if (-not (Test-Path $ISCC)) {
            Show-Error "Inno Setup compiler (ISCC.exe) không tìm thấy! Không thể đóng gói bộ cài Windows."
        }
        Run-Command "Compiling Inno Setup Windows Installer" {
            & $ISCC "/DMyAppVersion=$PureVersion" (Join-Path $ScriptDir "DongMePhim.iss")
        }
    } else {
        Write-Host "[SkipBuild] Sử dụng file cài đặt Windows Setup (.exe) đã có sẵn..." -ForegroundColor Green
    }

    if (-not (Test-Path $DestWindowsExe)) {
        Show-Error "Không tìm thấy file Windows setup tại $DestWindowsExe!"
    }

    $BuildReports += @{
        Name = "DongMePhim_v${PureVersion}_Setup.exe"
        Path = $DestWindowsExe
        Type = "Windows Desktop"
    }
}

# 3. UPLOAD TO R2 & CALCULATE METADATA
$UploadedItems = @()
foreach ($Report in $BuildReports) {
    Write-Host "`n=== Uploading $($Report.Name) to Cloudflare R2 ===" -ForegroundColor Yellow
    
    # Calculate metadata
    $FileInfo = Get-Item $Report.Path
    $SizeBytes = $FileInfo.Length
    $SizeMB = [Math]::Round($SizeBytes / 1MB, 2)
    $Hash = (Get-FileHash -Path $Report.Path -Algorithm SHA256).Hash.ToLower()
    
    # Run Python upload script and capture output
    $UploadPy = Join-Path $ScriptDir "upload_r2.py"
    $Output = & $PythonCmd $UploadPy $Report.Path 2>&1
    
    # Print python stdout
    foreach ($Line in $Output) {
        Write-Host $Line
    }
    
    # Check upload exit status
    if ($LASTEXITCODE -ne 0) {
        Show-Error "Tải $($Report.Name) lên Cloudflare R2 thất bại!"
    }
    
    # Parse direct URL
    $DirectUrl = ""
    foreach ($Line in $Output) {
        if ($Line -match "^\[RESULT_URL\]\s*(.+)") {
            $DirectUrl = $Matches[1].Trim()
        }
    }
    
    if ($DirectUrl -eq "") {
        Show-Error "Không thể phân tích URL R2 từ kết quả tải lên!"
    }
    
    $UploadedItems += @{
        Name = $Report.Name
        Type = $Report.Type
        Size = "$SizeMB MB"
        Hash = $Hash
        Url = $DirectUrl
    }
}

# 4. GENERATE REPORT
$Today = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$ReportHtmlPath = Join-Path $OutputDir "build_report.html"

$HtmlCards = ""
foreach ($Item in $UploadedItems) {
    $CardClass = "card"
    $IconHtml = ""
    if ($Item.Type -eq "Android Mobile") {
        $CardClass = "card card-mobile"
        $IconHtml = '<svg viewBox="0 0 24 24" fill="none" stroke="#10B981" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="width:20px;height:20px;vertical-align:middle;margin-right:8px;display:inline-block;"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"></rect><line x1="12" y1="18" x2="12.01" y2="18"></line></svg>'
    } elseif ($Item.Type -eq "Google Play AppBundle") {
        $CardClass = "card card-aab"
        $IconHtml = '<svg viewBox="0 0 24 24" fill="none" stroke="#F59E0B" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="width:20px;height:20px;vertical-align:middle;margin-right:8px;display:inline-block;"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path><polyline points="3.27 6.96 12 12.01 20.73 6.96"></polyline><line x1="12" y1="22.08" x2="12" y2="12"></line></svg>'
    } elseif ($Item.Type -eq "Smart TV") {
        $CardClass = "card card-tv"
        $IconHtml = '<svg viewBox="0 0 24 24" fill="none" stroke="#8B5CF6" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="width:20px;height:20px;vertical-align:middle;margin-right:8px;display:inline-block;"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"></rect><line x1="8" y1="21" x2="16" y2="21"></line><line x1="12" y1="17" x2="12" y2="21"></line></svg>'
    } else {
        $CardClass = "card card-windows"
        $IconHtml = '<svg viewBox="0 0 24 24" fill="none" stroke="#3B82F6" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="width:20px;height:20px;vertical-align:middle;margin-right:8px;display:inline-block;"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"></rect><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>'
    }

    $HtmlCards += @"
        <div class="$CardClass">
            <div class="card-header">
                <span class="title">$IconHtml$($Item.Type)</span>
                <span class="badge">Hoàn thành</span>
            </div>
            <div class="info-list">
                <div class="info-row"><span class="info-label">Tên file:</span><span class="info-value">$($Item.Name)</span></div>
                <div class="info-row"><span class="info-label">Dung lượng:</span><span class="info-value">$($Item.Size)</span></div>
                <div class="info-row"><span class="info-label">SHA256:</span><span class="info-value" style="font-size: 11px;">$($Item.Hash)</span></div>
                <div class="info-row"><span class="info-label">Link tải direct:</span><span class="info-value"><a href="$($Item.Url)" target="_blank" class="link-url">$($Item.Url)</a></span></div>
            </div>
            <div class="action-group">
                <a class="btn btn-primary" href="$($Item.Url)" target="_blank">Tải Xuống</a>
                <button class="btn btn-secondary" onclick="copyLink('$($Item.Url)')">Sao Chép Link</button>
            </div>
        </div>
"@
}

$HtmlTemplate = @"
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DongMePhim - Báo Cáo Phát Hành</title>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-color: #0B0F19;
            --card-bg: rgba(22, 28, 45, 0.45);
            --border-color: rgba(255, 255, 255, 0.05);
            --text-primary: #F8FAFC;
            --text-secondary: #94A3B8;
            --primary: #F59E0B;
            --primary-hover: #D97706;
            --success: #10B981;
        }
        body {
            background-color: var(--bg-color);
            color: var(--text-primary);
            font-family: 'Plus Jakarta Sans', sans-serif;
            padding: 50px 20px;
            margin: 0;
            background-image: radial-gradient(circle at 10% 20%, rgba(245, 158, 11, 0.04) 0%, transparent 40%),
                              radial-gradient(circle at 90% 80%, rgba(99, 102, 241, 0.04) 0%, transparent 40%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            box-sizing: border-box;
        }
        .container {
            width: 100%;
            max-width: 750px;
            background: rgba(17, 24, 39, 0.7);
            backdrop-filter: blur(20px);
            -webkit-backdrop-filter: blur(20px);
            padding: 35px;
            border-radius: 28px;
            border: 1px solid var(--border-color);
            box-shadow: 0 30px 60px rgba(0, 0, 0, 0.5);
            box-sizing: border-box;
        }
        .header {
            text-align: center;
            margin-bottom: 35px;
        }
        .header h1 {
            font-size: 28px;
            font-weight: 800;
            background: linear-gradient(135deg, #F59E0B 0%, #EC4899 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin: 0 0 10px 0;
            letter-spacing: -0.5px;
        }
        .header p {
            color: var(--text-secondary);
            font-size: 13.5px;
            margin: 0;
        }
        .meta-info {
            display: flex;
            justify-content: center;
            gap: 15px;
            margin-top: 15px;
            font-size: 12.5px;
            flex-wrap: wrap;
        }
        .meta-tag {
            background: rgba(255, 255, 255, 0.03);
            padding: 6px 14px;
            border-radius: 20px;
            border: 1px solid rgba(255, 255, 255, 0.05);
            color: var(--text-secondary);
        }
        .meta-tag b {
            color: var(--text-primary);
        }
        .grid {
            display: flex;
            flex-direction: column;
            gap: 20px;
        }
        .card {
            background: var(--card-bg);
            border-radius: 20px;
            border: 1px solid var(--border-color);
            padding: 24px;
            position: relative;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            overflow: hidden;
        }
        .card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            width: 4px;
            height: 100%;
        }
        .card-mobile::before { background: #10B981; }
        .card-aab::before { background: #F59E0B; }
        .card-tv::before { background: #8B5CF6; }
        .card-windows::before { background: #3B82F6; }

        .card:hover {
            transform: translateY(-4px);
            border-color: rgba(255, 255, 255, 0.12);
        }
        .card-mobile:hover { box-shadow: 0 10px 30px rgba(16, 185, 129, 0.12); }
        .card-aab:hover { box-shadow: 0 10px 30px rgba(245, 158, 11, 0.12); }
        .card-tv:hover { box-shadow: 0 10px 30px rgba(139, 92, 246, 0.12); }
        .card-windows:hover { box-shadow: 0 10px 30px rgba(59, 130, 246, 0.12); }

        .card-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 16px;
        }
        .title {
            font-size: 17px;
            font-weight: 700;
            display: flex;
            align-items: center;
        }
        .badge {
            background: rgba(16, 185, 129, 0.1);
            color: var(--success);
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 11px;
            font-weight: 700;
            letter-spacing: 0.5px;
            text-transform: uppercase;
        }
        .info-list {
            margin-bottom: 20px;
        }
        .info-row {
            display: flex;
            justify-content: space-between;
            padding: 10px 0;
            border-bottom: 1px solid rgba(255, 255, 255, 0.03);
            font-size: 13px;
        }
        .info-row:last-child {
            border-bottom: none;
        }
        .info-label {
            color: var(--text-secondary);
        }
        .info-value {
            font-family: monospace;
            color: var(--text-primary);
            text-align: right;
            word-break: break-all;
            max-width: 70%;
        }
        .link-url {
            color: var(--primary) !important;
            text-decoration: none;
            transition: color 0.2s;
        }
        .link-url:hover {
            color: var(--primary-hover) !important;
            text-decoration: underline;
        }
        .action-group {
            display: flex;
            gap: 12px;
        }
        .btn {
            flex: 1;
            display: flex;
            justify-content: center;
            align-items: center;
            gap: 8px;
            padding: 12px;
            border-radius: 10px;
            font-weight: 700;
            font-size: 13.5px;
            text-decoration: none;
            transition: all 0.2s;
            cursor: pointer;
            border: none;
            box-sizing: border-box;
        }
        .btn-primary {
            background: var(--primary);
            color: #0B0F19;
        }
        .btn-primary:hover {
            background: var(--primary-hover);
            transform: translateY(-1px);
        }
        .btn-secondary {
            background: rgba(255, 255, 255, 0.05);
            color: var(--text-primary);
            border: 1px solid rgba(255, 255, 255, 0.08);
        }
        .btn-secondary:hover {
            background: rgba(255, 255, 255, 0.08);
            border-color: rgba(255, 255, 255, 0.12);
            transform: translateY(-1px);
        }
        .toast {
            position: fixed;
            bottom: 30px;
            left: 50%;
            transform: translateX(-50%) translateY(100px);
            background: #10B981;
            color: white;
            padding: 10px 20px;
            border-radius: 30px;
            font-size: 13px;
            font-weight: bold;
            box-shadow: 0 10px 25px rgba(16, 185, 129, 0.3);
            transition: all 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275);
            opacity: 0;
            z-index: 1000;
        }
        .toast.show {
            transform: translateX(-50%) translateY(0);
            opacity: 1;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>DongMePhim - Phát Hành Thành Công</h1>
            <p>Toàn bộ tài nguyên đã được biên dịch và đẩy lên máy chủ lưu trữ Cloudflare R2.</p>
            <div class="meta-info">
                <div class="meta-tag">Phiên bản: <b>$PureVersion ($Version)</b></div>
                <div class="meta-tag">Thời gian: <b>$Today</b></div>
            </div>
        </div>
        <div class="grid">
            $HtmlCards
        </div>
    </div>
    <div id="toast" class="toast">Đã sao chép liên kết tải trực tiếp!</div>
    <script>
        function copyLink(url) {
            navigator.clipboard.writeText(url).then(function() {
                var toast = document.getElementById("toast");
                toast.classList.add("show");
                setTimeout(function() {
                    toast.classList.remove("show");
                }, 2000);
            });
        }
    </script>
</body>
</html>
"@

Set-Content -LiteralPath $ReportHtmlPath -Value $HtmlTemplate -Encoding UTF8
Write-Host "`n🎉 DEPLOYMENT COMPLETE! Report generated at: $ReportHtmlPath" -ForegroundColor Green

# Open report
Start-Process $ReportHtmlPath

