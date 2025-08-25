# ==================== CONFIGURATION ====================
$Repo = "itsdanitobg/uploads"      # Format: owner/repo
$Branch = "main"
$UploadToken = $env:UPLOAD_TOKEN   # Set this in your environment/session for safety

# ==================== GET FILE FROM ARGUMENTS ====================
if ($args.Count -eq 0) {
    Write-Host "❌ Drag a file onto this script to upload to GitHub."
    exit 1
}
$FilePath = $args[0]
if (-not (Test-Path $FilePath)) {
    Write-Host "❌ File does not exist: $FilePath"
    exit 1
}
$FileName = [IO.Path]::GetFileName($FilePath)

# ==================== READ AND ENCODE FILE CONTENT ====================
try {
    $ContentBytes = [IO.File]::ReadAllBytes($FilePath)
    $Base64Content = [Convert]::ToBase64String($ContentBytes)
} catch {
    Write-Host "❌ Failed to read file: $FilePath"
    exit 1
}

# ==================== CHECK IF FILE EXISTS (to get SHA if updating) ====================
$ApiUrl = "https://api.github.com/repos/$Repo/contents/$FileName"
$Headers = @{
    "Authorization" = "token $UploadToken"
    "User-Agent"    = "powershell-github-uploader"
    "Accept"        = "application/vnd.github.v3+json"
}
$Sha = $null
try {
    $Resp = Invoke-RestMethod -Uri "$ApiUrl?ref=$Branch" -Headers $Headers -Method Get -ErrorAction Stop
    $Sha = $Resp.sha
    Write-Host "ℹ️ File exists on GitHub, will update."
} catch {
    Write-Host "ℹ️ File does not exist on GitHub, will create."
}

# ==================== BUILD BODY ====================
$Body = @{
    message = "Upload $FileName via PowerShell script"
    content = $Base64Content
    branch  = $Branch
}
if ($Sha) { $Body.sha = $Sha }
$BodyJson = $Body | ConvertTo-Json

# ==================== UPLOAD OR UPDATE FILE ====================
try {
    $Result = Invoke-RestMethod -Uri $ApiUrl -Headers $Headers -Method Put -Body $BodyJson
    Write-Host "✅ Uploaded $FileName to $Repo on branch $Branch."
} catch {
    Write-Host "❌ Failed to upload $FileName: $($_.Exception.Message)"
    exit 1
}