# Attach-SonarQualityGate.ps1
param(
    [string]$ProjectKey = 'kalvinparker_Sonarcube',
    [string]$GateId     = '136670',
    [string]$ApiUrl     = 'https://sonarcloud.io/api/qualitygates/select',
    [string]$LogFile    = 'sonar-attach-log.txt'
)

function Write-Log { param($m) "$((Get-Date).ToString('o')) - $m" | Tee-Object -FilePath $LogFile -Append }

# Clean previous log
if (Test-Path $LogFile) { Remove-Item $LogFile -ErrorAction SilentlyContinue }

$organization = Read-Host 'Enter Sonar organization key (e.g. kalvinparker)'
$secureToken  = Read-Host 'Enter Sonar token (input hidden)' -AsSecureString

# Convert SecureString to plain text in memory (briefly)
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
$plainToken = [Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)

# Build Basic auth header safely
$bytes = [System.Text.Encoding]::ASCII.GetBytes($plainToken + ":")
$authHeader = 'Basic ' + [Convert]::ToBase64String($bytes)

# Clear the plain token variable as soon as it's used
$plainToken = $null
Remove-Variable bytes -ErrorAction SilentlyContinue

$body = @{
    projectKey   = $ProjectKey
    gateId       = $GateId
    organization = $organization
}

Write-Log "Attempting attach: gateId=$GateId projectKey=$ProjectKey organization=$organization"

try {
    # Use Invoke-WebRequest so we can capture full response on non-2xx
    $response = Invoke-WebRequest -Uri $ApiUrl -Method Post -Headers @{ Authorization = $authHeader } -Body $body -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop
    $statusCode = $response.StatusCode
    $content    = $response.Content
    Write-Log "HTTP Status: $statusCode"
    Write-Log "Response body: $content"
    Write-Host "HTTP Status: $statusCode"
    Write-Host "Response body:`n$content"
}
catch {
    Write-Log "Invoke-WebRequest threw exception"
    $err = $_.Exception
    $resp = $null
    try { $resp = $err.Response } catch {}
    if ($resp -ne $null) {
        try { $statusCode = $resp.StatusCode.value__ } catch { $statusCode = 'unknown' }
        $stream = $resp.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $content = $reader.ReadToEnd()
        $reader.Close()
        Write-Log "HTTP Status (from exception): $statusCode"
        Write-Log "Response body (from exception): $content"
        Write-Host "HTTP Status: $statusCode"
        Write-Host "Response body:`n$content"
    } else {
        Write-Log "No response object available in exception: $err"
        Write-Host "Request failed and no response body was found. Exception:"
        $err | Format-List -Force
    }
}
finally {
    # cleanup sensitive state
    Remove-Variable authHeader -ErrorAction SilentlyContinue
    Remove-Variable secureToken -ErrorAction SilentlyContinue
    Remove-Variable body -ErrorAction SilentlyContinue
    Write-Log "Finished."
}
