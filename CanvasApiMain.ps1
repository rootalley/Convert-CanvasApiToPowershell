################################################################################
#
#  Convert-CanvasApiToPowershell
#
#  Maintained by Steven Endres (rootalley) at
#  https://github.com/rootalley/Convert-CanvasApiToPowershell.
#
#  Forked from CanvasApis by Spencer Varney (squid808) at
#  https://github.com/squid808/CanvasApis. Kudos to Spencer!
#
#  Licensed under the GNU General Public License Version 3.
#
#  Use at your own risk, or contribute to the project and make it better!
#
################################################################################

#region Base Canvas API Methods
function Get-CanvasCredentials(){
    if ($null -eq $global:CanvasApiTokenInfo) {

        $ApiInfoPath = "$env:USERPROFILE\Documents\CanvasApiCreds.json"

        #TODO: Once this is a module, load it from the module path: $PSScriptRoot or whatever that is
        if (-not (test-path $ApiInfoPath)) {
            $Token = Read-Host "Please enter your Canvas API API Access Token"
            $BaseUri = Read-Host "Please enter your Canvas API Base URI (for example, https://domain.beta.instructure.com)"

            $ApiInfo = [ordered]@{
                Token = $Token
                BaseUri = $BaseUri
            }

            $ApiInfo | ConvertTo-Json | Out-File -FilePath $ApiInfoPath
        }

        #load the file
        $global:CanvasApiTokenInfo = Get-Content -Path $ApiInfoPath | ConvertFrom-Json
    }

    return $global:CanvasApiTokenInfo
}

function Get-CanvasAuthHeader($Token) {
    return @{"Authorization"="Bearer "+$Token}
}

function Get-CanvasApiResult(){

    Param(
        $Uri,

        $RequestParameters,

        [ValidateSet("GET", "POST", "PUT", "DELETE")]
        $Method="GET"
    )

    $AuthInfo = Get-CanvasCredentials

    if ($null -eq $RequestParameters) { $RequestParameters = @{} }

    $RequestParameters["per_page"] = "10000"

    $Headers = (Get-CanvasAuthHeader $AuthInfo.Token)

    try {
    $Results = Invoke-WebRequest -Uri ($AuthInfo.BaseUri + $Uri) -ContentType "multipart/form-data" `
        -Headers $headers -Method $Method -Body $RequestParameters
    } catch {
        throw $_.Exception.Message
    }

    $Content = $Results.Content | ConvertFrom-Json

    #Either PSCustomObject or Object[]
    if ($Content.GetType().Name -eq "PSCustomObject") {
        return $Content
    }

    $JsonResults = New-Object System.Collections.ArrayList

    $JsonResults.AddRange(($Results.Content | ConvertFrom-Json))

    if ($null -ne $Results.Headers.link) {
        $NextUriLine = $Results.Headers.link.Split(",") | Where-Object {$_.Contains("rel=`"next`"")}

        if (-not [string]::IsNullOrWhiteSpace($NextUriLine)) {
            while ($Results.Headers.link.Contains("rel=`"next`"")) {

                $nextUri = $Results.Headers.link.Split(",") | `
                            Where-Object {$_.Contains("rel=`"next`"")} | `
                            ForEach-Object {$_ -replace ">; rel=`"next`""} |
                            ForEach-Object {$_ -replace "<"}

                #Write-Progress
                Write-Host $nextUri

                $Results = Invoke-WebRequest -Uri $nextUri -Headers $headers -Method Get -Body $RequestParameters -ContentType "multipart/form-data" `

                $JsonResults.AddRange(($Results.Content | ConvertFrom-Json))
            }
        }
    }

    return $JsonResults
}

#endregion