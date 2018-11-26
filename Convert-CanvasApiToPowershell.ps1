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
<#
.Synopsis
    This project parses the Swagger specification for the Instructure Canvas
    learning management system API (https://canvas.instructure.com/doc/api/) to
    generate a PowerShell client for Canvas.
.Description
    This project parses the Swagger specification for the Instructure Canvas
    learning management system API (https://canvas.instructure.com/doc/api/) to
    generate a PowerShell client for Canvas.
.Example
    PS C:> . .\Convert-CanvasApiToPowershell.ps1
    PS C:> $Generated = Convert-CanvasApiToPowershell
    PS C:> $Generated | Out-File ".\CanvasApi.ps1"
#>

$BaseUri = "https://canvas.instructure.com/doc/api"

function Read-CanvasSwaggerDocs ($BaseUri) {
    $ApisList = Invoke-RestMethod -Uri "$BaseUri/api-docs.json"

    $ApisHash = @{}

    $ApisList | Add-Member -MemberType NoteProperty -Name "apiHash" -Value $ApisHash

    foreach ($SubApiList in $ApisList.apis) {
        $Result = (Invoke-RestMethod -Uri ($BaseUri + $SubApiList.path))
        $Result | Add-Member -MemberType NoteProperty -Name "parent" -Value $ApisList

        $ApisHash.Add($SubApiList.Description.Replace(" ",""),$Result) | Out-Null
        $SubApiList | Add-Member -MemberType NoteProperty -Name "api" -Value $Result

        foreach ($Api in $SubApiList.api.apis) {
            $Api | Add-Member -MemberType NoteProperty -Name "parent" -Value $SubApiList
        }
    }

    return $ApisList
}


function ConvertTo-TitleCase ($String, $Delimiter) {
    $String = $String.ToLower()

    if ($null -ne $Delimiter) {
        return ($String.Split($Delimiter) | ForEach-Object {(Get-Culture).TextInfo.ToTitleCase($_)}) -join ""
    } else {
        return (Get-Culture).TextInfo.ToTitleCase($String)
    }
}


function Get-UniqueCmdletName($Method) {
    $Words = @()
    $Params = @()
    $Split = $Method.path.Split("/")

    for ($i = 1; $i -lt $Split.Count; $i++) {
        if ($Split[$i] -match"{.*}") {
            $Params += (ConvertTo-TitleCase ($Split[$i] -replace "[{}]","") "_")
        } elseif (-not [string]::IsNullOrWhiteSpace($Split[$i])) {
            if("V1" -ne $Split[$i]) {
                $Words += (ConvertTo-TitleCase $Split[$i] "_")
            }
        }
    }

    $Verb = ConvertTo-TitleCase $Method.operations.method.ToLower()

    switch ($Verb) {
        Put { $Verb = "Update" }
        Post { $Verb = "New" }
    }

    $Noun = ($Words -join "")
    if ($Params.Count -gt 0) {
        $Noun += ("By" + ($Params -join "And"))
    }

    $Noun = $Noun -replace "_",""

    return $Verb + "-Canvas" + $Noun
}


function Format-ParamDescription ($ParamDescription) {
    $ParamDescription = $ParamDescription.Split("`r`n") -join "`r`n`t`t# " -replace "{","[" -replace "}","]"

    return $ParamDescription
}


function Convert-ParamNameToPoshString ($ParamName) {
    (ConvertTo-TitleCase $ParamName "_") -replace "\W|_",""
}


function Get-MethodParamTypeForPosh ($Param) {
    switch ($Param.type) {
        "Float" { "[float]" }
        "string" { "[string]" }
        "boolean" {"[bool]"}
        "integer" {"[int]"}
        default {$null}
    }
}


function New-MethodParamString ($Param) {
    $PString =  @'
        # {0}
        [Parameter(Mandatory=${1})]
        {3} ${2}
'@ -f (Format-ParamDescription $Param.description), $Param.required, (Convert-ParamNameToPoshString $Param.name),
    (Get-MethodParamTypeForPosh $Param)

    return $PString
}


function Convert-MethodParamsToString ($Method) {

    if ($Method.operations.parameters.Count -eq 0) { return $null }

    $Params = $Method.operations.parameters

    $ParamsString = New-Object System.Collections.ArrayList

    foreach ($P in $Params) {
        $ParamsString.Add((New-MethodParamString $P)) | Out-Null
    }

    $ParamString = @'
    Param (
{0}
    )
'@ -f ($ParamsString -join ",`r`n`r`n")


    return $ParamString
}


function Convert-MethodUri ($Method) {
    $Paths = $Method.path.Split("/")

    for ($i = 0; $i -lt $Paths.Length; $i++) {
        if ($Paths[$i][0] -eq '{' -and $Paths[$i][-1] -eq '}') {
            $Paths[$i] = '$' + (ConvertTo-TitleCase $Paths[$i].Replace('{','').Replace('}','') -Delimiter "_")
        }
    }

    return $Paths -join "/"
}


function New-MethodBodyParameter($Parameter) {

    $ParamTitle = Convert-ParamNameToPoshString $Parameter.name

    $string = '$Body["{0}"] = ${1}' -f $Parameter.name, $ParamTitle

    if (-not [bool]::Parse(($Parameter.required))) {
        $string = 'if (${0}) {{{{ {1} }}}}' -f $ParamTitle, $string
    }

    return "`t" + $string
}


function New-MethodBody ($Method) {
    if ($Method.operations.parameters.Count -eq 0) { return $null }

    $Params = New-Object System.Collections.ArrayList

    foreach ($P in $Method.operations.parameters) {
        $Params.Add((New-MethodBodyParameter $P)) | Out-Null
    }

    $string = @'
$Body = @{{{{}}}}

{0}

'@ -f ($Params -join "`r`n`r`n")

    return $string
}


function New-MethodExample ($Method, $MethodName) {

    $string = 'PS C:> {0}'

    if (($Method.operations.parameters | Where-Object {$_.required -eq $True} `
        | Measure-Object | Select-Object -ExpandProperty Count) -eq 0) {
        return $string
    }

    $params = New-Object System.Collections.ArrayList

    foreach ($P in $Method.operations.parameters) {
        if ([bool]::Parse($P.required)) {
            $PName = Convert-ParamNameToPoshString $P.name
            $params.Add('-{0} $Some{0}Obj' -f $PName) | Out-Null
        }
    }

    $string += " " + $params -join " "

    return $string
}


function Convert-MethodToPosh ($Method) {
    $MethodName = Get-UniqueCmdletName $Method

    $String = @'
<#
.Synopsis
   {0}
.Example
   {6}
#>
function {1} {{{{
[CmdletBinding()]
{2}

    $Uri = "/api{3}"

    {4}

    return Get-CanvasApiResult $Uri -Method {5} -RequestParameters $Body

}}}}
'@ -f ($Method.description -replace "{","[" -replace "}","]"),
        '{0}',
        (Convert-MethodParamsToString $Method),
        (Convert-MethodUri $Method),
        (New-MethodBody $Method),
        $Method.operations.method,
        (New-MethodExample $Method)

    return New-Object -TypeName psobject -Property (@{
        name = $MethodName
        body = $string
    })
}


function Convert-CanvasApiToPowershell {
    $Api = Read-CanvasSwaggerDocs $BaseUri

    $PoshMethodsInOrder = New-Object System.Collections.ArrayList
    $MethodsByName = @{}
    $Regions = @{}

    foreach ($A in $Api.apis) {
        foreach ($Method in $A.api.apis) {
            $Deprecated = ((($Method.description).ToLower()).StartsWith("deprecated"))
            if (-not $Exempt) {
                $M = (Convert-MethodToPosh $Method)
                $M | Add-Member -MemberType NoteProperty -Name "method" -Value $Method
                $PoshMethodsInOrder.Add($M) | Out-Null
                if (-not $MethodsByName.ContainsKey($M.name)) {
                    $MethodsByName.Add($M.name, (New-Object System.Collections.ArrayList)) | Out-Null
                }
                $MethodsByName[$M.name].Add($M) | Out-Null
            }
        }
    }

    $Doc = New-Object System.Collections.ArrayList

    $Doc.Add(@"
################################################################################
#
#  Generated by Convert-CanvasApiToPowershell {0}
#
#  Maintained by Steven Endres (rootalley) at
#  https://github.com/rootalley/Convert-CanvasApiToPowershell.
#
#  Forked from CanvasApis by Stuart Varney (squid808) at
#  https://github.com/squid808/CanvasApis.
#
#  Licensed under the GNU General Public License Version 3.
#
#  Use at your own risk!
#
################################################################################
"@ -f (Get-Date))

    $CM = get-content .\CanvasApiMain.ps1
    $Doc.Add($CM[($CM.IndexOf("#>") + 2)..($CM.Length-1)] -join "`r`n") | Out-Null

    foreach ($K in ($Regions.Keys | Sort-Object)) {
        $Doc.Add(("#region $K`r`n`r`n" + ($Regions[$K] -join "`r`n`r`n") + "`r`n`r`n#endregion")) | Out-Null
    }

    $Doc = $Doc -join "`r`n`r`n"

    return $Doc
}
