class Polaris {

    [int]$Port
    [System.Collections.Generic.List[PolarisMiddleWare]]$RouteMiddleWare = [System.Collections.Generic.List[PolarisMiddleWare]]::new()
    [System.Collections.Generic.Dictionary[string, [System.Collections.Generic.Dictionary[string, scriptblock]]]]$ScriptblockRoutes = [System.Collections.Generic.Dictionary[string, [System.Collections.Generic.Dictionary[string, scriptblock]]]]::new()
    hidden [Action[string]]$Logger
    hidden [System.Net.HttpListener]$Listener
    hidden [bool]$StopServer = $False
    [string]$GetLogsString = "PolarisLogs"
    [string]$ClassDefinitions = $Script:ClassDefinitions
    $ContextHandler = (New-ScriptblockCallback -Callback {

            param(
                [System.IAsyncResult]
                $AsyncResult
            )

            [Polaris]$Polaris = $AsyncResult.AsyncState
            $Context = $Polaris.Listener.EndGetContext($AsyncResult)


            if ($Polaris.StopServer -or $null -eq $Context) {
                if ($null -ne $Polaris.Listener) {
                    $Polaris.Listener.Close()
                }
                break
            }

            $Polaris.Listener.BeginGetContext($Polaris.ContextHandler, $Polaris)

            [System.Net.HttpListenerRequest]$RawRequest = $Context.Request
            [System.Net.HttpListenerResponse]$RawResponse = $Context.Response

            $Polaris.Log("request came in: " + $RawRequest.HttpMethod + " " + $RawRequest.RawUrl)

            [PolarisRequest]$Request = [PolarisRequest]::new($RawRequest)
            [PolarisResponse]$Response = [PolarisResponse]::new()


            [string]$Route = $RawRequest.Url.AbsolutePath
            
            [System.Management.Automation.InformationRecord[]]$InformationVariable = @()

            if ([string]::IsNullOrEmpty($Route)) { $Route = "/" }

            try {

                # Run middleware in the order in which it was added
                foreach ($Middleware in $Polaris.RouteMiddleware) {
                    $InformationVariable += $Polaris.InvokeRoute(
                            $Middleware.Scriptblock,
                            $Null,
                            $Request,
                            $Response
                        )
                }

                $Polaris.Log("Parsed Route: $Route")
                $Polaris.Log("Request Method: $($RawRequest.HttpMethod)")
                $Routes = $Polaris.ScriptblockRoutes

                #
                # Searching for the first route that matches by the most specific route paths first.
                #
                $MatchingRoute = $Routes.keys | Sort-Object -Property Length -Descending | Where-Object { $Route -match [Polaris]::ConvertPathToRegex($_) } | Select-Object -First 1
                $Request.Parameters = ([PSCustomObject]$Matches)
                Write-Debug "Parameters: $Parameters"
                $MatchingMethod = $false

                if ($MatchingRoute) {
                    $MatchingMethod = $Routes[$MatchingRoute].keys -contains $Request.Method
                }

                if ($MatchingRoute -and $MatchingMethod) {
                    try {

                        $InformationVariable += $Polaris.InvokeRoute(
                            $Routes[$MatchingRoute][$Request.Method],
                            $Parameters,
                            $Request,
                            $Response
                        )
                        
                    }
                    catch {
                        $ErrorsBody += $_.Exception.ToString()
                        $ErrorsBody += $_.InvocationInfo.PositionMessage + "`n`n"
                        $Response.Send($ErrorsBody)
                        $Polaris.Log($_)
                        $Response.SetStatusCode(500)
                    }
                }
                elseif ($MatchingRoute) {
                    $Response.Send("Method not allowed")
                    $Response.SetStatusCode(405)
                }
                else {
                    $Response.Send("Not found")
                    $Response.SetStatusCode(404)
                }

                # Handle logs
                if ($Request.Query -and $Request.Query[$Polaris.GetLogsString]) {
                    $InformationBody = "`n"
                    for ([int]$i = 0; $i -lt $InformationVariable.Count; $i++) {
                        foreach ($tag in $InformationVariable[$i].Tags) {
                            $InformationBody += "[" + $tag + "]"
                        }

                        $InformationBody += $InformationVariable[$i].MessageData.ToString() + "`n"
                    }
                    $InformationBody += "`n"

                    # Set response to the logs and the actual response (could be errors)
                    $LogBytes = [System.Text.Encoding]::UTF8.GetBytes($InformationBody)
                    $Bytes = [byte[]]::new($LogBytes.Length + $Response.ByteResponse.Length)
                    $LogBytes.CopyTo($Bytes, 0)
                    $Response.ByteResponse.CopyTo($Bytes, $LogBytes.Length)
                    $Response.ByteResponse = $Bytes
                }
                [Polaris]::Send($RawResponse, $Response)

            }
            catch {
                $Polaris.Log(($_ | Out-String))
                $Response.SetStatusCode(500)
                $Response.Send($_)
                try{
                    [Polaris]::Send($RawResponse, $Response)
                } catch {
                    $Polaris.Log($_)
                }
                $Polaris.Log($_)
            }
        })

    hidden [object] InvokeRoute (
        [Scriptblock]$Route,
        [PSCustomObject]$Parameters,
        [PolarisRequest]$Request,
        [PolarisResponse]$Response
    ) {

        $InformationVariable = ""

        $Scriptblock = [scriptblock]::Create(
            "param(`$Parameters,`$Request,`$Response)`r`n" +
            $Route.ToString()
        )

        Invoke-Command -Scriptblock $Scriptblock `
            -ArgumentList @($Parameters, $Request, $Response) `
            -InformationVariable InformationVariable `
            -ErrorAction Stop
            
        return $InformationVariable
    }


    [void] AddRoute (
        [string]$Path,
        [string]$Method,
        [scriptblock]$Scriptblock
    ) {
        if ($null -eq $Scriptblock) {
            throw [ArgumentNullException]::new("scriptBlock")
        }

        [string]$SanitizedPath = [Polaris]::SanitizePath($Path)

        if (-not $this.ScriptblockRoutes.ContainsKey($SanitizedPath)) {
            $this.ScriptblockRoutes[$SanitizedPath] = [System.Collections.Generic.Dictionary[string, string]]::new()
        }
        $this.ScriptblockRoutes[$SanitizedPath][$Method] = $Scriptblock
    }

    RemoveRoute (
        [string]$Path,
        [string]$Method
    ) {
        if ($null -eq $Path) {
            throw [ArgumentNullException]::new("path")
        }
        if ($null -eq $Method) {
            throw [ArgumentNullException]::new("method")
        }

        [string]$SanitizedPath = [Polaris]::SanitizePath($Path)

        $this.ScriptblockRoutes[$SanitizedPath].Remove($Method)
        if ($this.ScriptblockRoutes[$SanitizedPath].Count -eq 0) {
            $this.ScriptblockRoutes.Remove($SanitizedPath)
        }
    }

    static [string] SanitizePath([string]$Path){
        $SanitizedPath = $Path.TrimEnd('/')

        if ([string]::IsNullOrEmpty($SanitizedPath)) { $SanitizedPath = "/" }

        return $SanitizedPath
    }

    static [RegEx] ConvertPathToRegex([string]$Path){
        Write-Debug "Path: $path"
        # Replacing all periods with an escaped period to prevent regex wildcard
        $path = $path -replace '\.', '\.'
        # Replacing all - with \- to escape the dash
        $path = $path -replace '-', '\-'
        # Replacing the wildcard character * with a regex aggressive match .*
        $path = $path -replace '\*', '.*'
        # Creating a strictly matching regular expression that must match beginning (^) to end ($)
        $path = "^$path$"
        # Creating a route based parameter
        #   Match any and all word based characters after the : for the name of the parameter
        #   Use the name in a named capture group that will show up in the $matches variable
        #   References:
        #       - https://docs.microsoft.com/en-us/dotnet/standard/base-types/grouping-constructs-in-regular-expressions#named_matched_subexpression
        #       - https://technet.microsoft.com/en-us/library/2007.11.powershell.aspx
        #       - https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables?view=powershell-6#matches
        $path = $path -replace ":(\w+)(\?{0,1})", '(?<$1>.+)$2'

        Write-Debug "Parsed Regex: $path"
        return [RegEx]::New($path)
    }

    static [RegEx] ConvertPathToRegex([RegEx]$Path){
        Write-Debug "Path is a RegEx"
        return $Path
    }

    AddMiddleware (
        [string]$Name,
        [scriptblock]$Scriptblock
    ) {
        if ($null -eq $Scriptblock) {
            throw [ArgumentNullException]::new("scriptBlock")
        }
        $this.RouteMiddleware.Add([PolarisMiddleware]@{
                'Name'        = $Name
                'Scriptblock' = $Scriptblock
            })
    }

    RemoveMiddleware ([string]$Name) {
        if ($null -eq $Name) {
            throw [ArgumentNullException]::new("name")
        }
        $this.RouteMiddleware.RemoveAll(
            [Predicate[PolarisMiddleWare]]([scriptblock]::Create("`$args[0].Name -eq '$Name'"))
        )
    }

    [void] Start (
        [int]$Port = 3000
    ) {
        $this.StopServer = $false
        $this.InitListener($Port)
        $this.Listener.BeginGetContext($this.ContextHandler, $this)
        $this.Log("App listening on Port: " + $Port + "!")
    }

    [void] Stop () {
        $this.StopServer = $true
        $this.Listener.Close()
        $this.Listener.Dispose()
        $this.Log("Server Stopped.")
        
    }
    [void] InitListener ([int]$Port) {
        $this.Port = $Port

        $this.Listener = [System.Net.HttpListener]::new()

        # If user is on a non-windows system or windows as administrator
        if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT -or
            ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT -and
                ([System.Security.Principal.WindowsPrincipal]::new([System.Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator))) {
            $this.Listener.Prefixes.Add("http://+:" + $this.Port + "/")
        }
        else {
            $this.Listener.Prefixes.Add("http://localhost:" + $this.Port + "/")
        }

        $this.Listener.IgnoreWriteExceptions = $true
        if([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT -and $this.Listener.TimeoutManager){
            $this.Listener.TimeoutManager.RequestQueue = [timespan]::FromMinutes(5)
            $this.Listener.TimeoutManager.IdleConnection = [timespan]::FromSeconds(45)
            $this.Listener.TimeoutManager.EntityBody = [timespan]::FromSeconds(50)
            $this.Listener.TimeoutManager.HeaderWait = [timespan]::FromSeconds(5)
        }

        $this.Listener.Start()
    }

    static [void] Send (
        [System.Net.HttpListenerResponse]$RawResponse, 
        [PolarisResponse]$Response
    ) {
        if ($Response.StreamResponse) {
            [Polaris]::Send(
                $RawResponse,
                $Response.StreamResponse,
                $Response.StatusCode,
                $Response.ContentType,
                $Response.Headers
            )
        }
        else {
            [Polaris]::Send(
                $RawResponse,
                $Response.ByteResponse,
                $Response.StatusCode,
                $Response.ContentType,
                $Response.Headers
            )
        }
    }

    static [void] Send (
        [System.Net.HttpListenerResponse]$RawResponse, 
        [byte[]]$ByteResponse, 
        [int]$StatusCode, 
        [string]$ContentType, 
        [System.Net.WebHeaderCollection]$Headers
    ) {
        $RawResponse.StatusCode = $StatusCode;
        $RawResponse.Headers = $Headers;
        $RawResponse.ContentType = $ContentType;
        $RawResponse.ContentLength64 = $ByteResponse.Length;
        $RawResponse.OutputStream.Write($ByteResponse, 0, $ByteResponse.Length);
        $RawResponse.OutputStream.Close();
    }
    
    static [void] Send (
        [System.Net.HttpListenerResponse]$RawResponse, 
        [System.IO.Stream]$StreamResponse, 
        [int]$StatusCode, 
        [string]$ContentType, 
        [System.Net.WebHeaderCollection]$Headers
    ) {
        $RawResponse.StatusCode = $StatusCode;
        $RawResponse.Headers = $Headers;
        $RawResponse.ContentType = $ContentType;
        $StreamResponse.CopyTo($RawResponse.OutputStream);
        $RawResponse.OutputStream.Close();
    }

    static [void] Send (
        [System.Net.HttpListenerResponse]$RawResponse,
        [byte[]]$ByteResponse,
        [int]$StatusCode,
        [string]$ContentType
    ) {
        [Polaris]::Send($RawResponse, $ByteResponse, $StatusCode, $ContentType, $Null)
    }

    [void] Log ([string]$LogString) {
        try {
            $this.Logger($LogString)
        }
        catch {
            Write-Host $_.Message
            Write-Host $LogString
        }
    }


    Polaris (
        [Action[string]]$Logger
    ) {
        if ($Logger) {
            $this.Logger = $Logger
        }
        else {
            $this.Logger = {
                param($LogItem)
                Write-Host $LogItem
            }
        }

    }
}

# SIG # Begin signature block
# MIIdjgYJKoZIhvcNAQcCoIIdfzCCHXsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUs7X35vuyK3x7I3t+as1p6qQY
# 2XOgghhqMIIE2jCCA8KgAwIBAgITMwAAAPQiWJXCqdgoJQAAAAAA9DANBgkqhkiG
# 9w0BAQUFADB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
# HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwHhcNMTgwODIzMjAxOTU2
# WhcNMTkxMTIzMjAxOTU2WjCByjELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEm
# MCQGA1UECxMdVGhhbGVzIFRTUyBFU046MERFOC0yREM1LTNDQTkxJTAjBgNVBAMT
# HE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggEiMA0GCSqGSIb3DQEBAQUA
# A4IBDwAwggEKAoIBAQDNssCk8xcNqZg5cv9CLBfQN1/FqbJES8lq1cKvcJGfWosz
# vi4I80YOp6/4bzyrdhKQzWR89DLE/QtFit5kwHAHS5NQVv8cKRl5WoLOWOHoPuIb
# XeN4eacvIf5MaEGeJ/ujYvo/fj+8wUDYnt4/q71FqINQ3Akur6lFGQWpI+mLQfLs
# dpEuwIlz0Cz/EqgzeIv3vOaD5ekDKE4DNO9vJfYmnIjMFXoEhDFC0Hlo4Gt6m2tL
# Qz27UYarDB/oosYj7uJTi0P4pCAMeVtj+dYuCF2HwE77mL9rKaNx+NIwnyYrD48D
# ve5I23Yas5RfkcA3nymMqz5omNxv0en8g8KA610VAgMBAAGjggEJMIIBBTAdBgNV
# HQ4EFgQUMmmXz5/LTAjYv0JFUU++Yx+PRFQwHwYDVR0jBBgwFoAUIzT42VJGcArt
# QPt2+7MrsMM1sw8wVAYDVR0fBE0wSzBJoEegRYZDaHR0cDovL2NybC5taWNyb3Nv
# ZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljcm9zb2Z0VGltZVN0YW1wUENBLmNy
# bDBYBggrBgEFBQcBAQRMMEowSAYIKwYBBQUHMAKGPGh0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2kvY2VydHMvTWljcm9zb2Z0VGltZVN0YW1wUENBLmNydDATBgNV
# HSUEDDAKBggrBgEFBQcDCDANBgkqhkiG9w0BAQUFAAOCAQEAAlo7EsFJzkwFItQp
# Kh4yLqH/HkBpvzxmb/onDYH8NJBfANtXU4ZuElA6MpZGj3NWnV8HGh7hsQb9l+Nz
# 9m9k/tjz0sWrVyM0ASaXD94u4/v/EldjPfEgZJyCQuv0AGpvPY1Hcqva5H5JStLu
# JY9JXqIpYhVVpBDZ6g5ANg4v5Q0kNeJBzGMUBGFFggxlfC5GB7zcAk5Sr7Or2b/V
# +GKVtiL590ReXfvqJOinn1WfNARvnrURqJke7CVv5QZ1VE+SlGYXea0axoJqkrdW
# hogrCMhiJTidxDkcy21X0X+O8hyy2cWb6evtJfcdZKTAUQbW661MndwIug1X1VXd
# UR4FezCCBf8wggPnoAMCAQICEzMAAAEDXiUcmR+jHrgAAAAAAQMwDQYJKoZIhvcN
# AQELBQAwfjELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYG
# A1UEAxMfTWljcm9zb2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMTAeFw0xODA3MTIy
# MDA4NDhaFw0xOTA3MjYyMDA4NDhaMHQxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpX
# YXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xHjAcBgNVBAMTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjCCASIw
# DQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANGUdjbmhqs2/mn5RnyLiFDLkHB/
# sFWpJB1+OecFnw+se5eyznMK+9SbJFwWtTndG34zbBH8OybzmKpdU2uqw+wTuNLv
# z1d/zGXLr00uMrFWK040B4n+aSG9PkT73hKdhb98doZ9crF2m2HmimRMRs621TqM
# d5N3ZyGctloGXkeG9TzRCcoNPc2y6aFQeNGEiOIBPCL8r5YIzF2ZwO3rpVqYkvXI
# QE5qc6/e43R6019Gl7ziZyh3mazBDjEWjwAPAf5LXlQPysRlPwrjo0bb9iwDOhm+
# aAUWnOZ/NL+nh41lOSbJY9Tvxd29Jf79KPQ0hnmsKtVfMJE75BRq67HKBCMCAwEA
# AaOCAX4wggF6MB8GA1UdJQQYMBYGCisGAQQBgjdMCAEGCCsGAQUFBwMDMB0GA1Ud
# DgQWBBRHvsDL4aY//WXWOPIDXbevd/dA/zBQBgNVHREESTBHpEUwQzEpMCcGA1UE
# CxMgTWljcm9zb2Z0IE9wZXJhdGlvbnMgUHVlcnRvIFJpY28xFjAUBgNVBAUTDTIz
# MDAxMis0Mzc5NjUwHwYDVR0jBBgwFoAUSG5k5VAF04KqFzc3IrVtqMp1ApUwVAYD
# VR0fBE0wSzBJoEegRYZDaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9j
# cmwvTWljQ29kU2lnUENBMjAxMV8yMDExLTA3LTA4LmNybDBhBggrBgEFBQcBAQRV
# MFMwUQYIKwYBBQUHMAKGRWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMv
# Y2VydHMvTWljQ29kU2lnUENBMjAxMV8yMDExLTA3LTA4LmNydDAMBgNVHRMBAf8E
# AjAAMA0GCSqGSIb3DQEBCwUAA4ICAQCf9clTDT8NJuyiRNgN0Z9jlgZLPx5cxTOj
# pMNsrx/AAbrrZeyeMxAPp6xb1L2QYRfnMefDJrSs9SfTSJOGiP4SNZFkItFrLTuo
# LBWUKdI3luY1/wzOyAYWFp4kseI5+W4OeNgMG7YpYCd2NCSb3bmXdcsBO62CEhYi
# gIkVhLuYUCCwFyaGSa/OfUUVQzSWz4FcGCzUk/Jnq+JzyD2jzfwyHmAc6bAbMPss
# uwculoSTRShUXM2W/aDbgdi2MMpDsfNIwLJGHF1edipYn9Tu8vT6SEy1YYuwjEHp
# qridkPT/akIPuT7pDuyU/I2Au3jjI6d4W7JtH/lZwX220TnJeeCDHGAK2j2w0e02
# v0UH6Rs2buU9OwUDp9SnJRKP5najE7NFWkMxgtrYhK65sB919fYdfVERNyfotTWE
# cfdXqq76iXHJmNKeWmR2vozDfRVqkfEU9PLZNTG423L6tHXIiJtqv5hFx2ay1//O
# kpB15OvmhtLIG9snwFuVb0lvWF1pKt5TS/joynv2bBX5AxkPEYWqT5q/qlfdYMb1
# cSD0UaiayunR6zRHPXX6IuxVP2oZOWsQ6Vo/jvQjeDCy8qY4yzWNqphZJEC4Omek
# B1+g/tg7SRP7DOHtC22DUM7wfz7g2QjojCFKQcLe645b7gPDHW5u5lQ1ZmdyfBrq
# UvYixHI/rjCCBgcwggPvoAMCAQICCmEWaDQAAAAAABwwDQYJKoZIhvcNAQEFBQAw
# XzETMBEGCgmSJomT8ixkARkWA2NvbTEZMBcGCgmSJomT8ixkARkWCW1pY3Jvc29m
# dDEtMCsGA1UEAxMkTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# MB4XDTA3MDQwMzEyNTMwOVoXDTIxMDQwMzEzMDMwOVowdzELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEhMB8GA1UEAxMYTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgUENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAn6Fssd/b
# SJIqfGsuGeG94uPFmVEjUK3O3RhOJA/u0afRTK10MCAR6wfVVJUVSZQbQpKumFww
# JtoAa+h7veyJBw/3DgSY8InMH8szJIed8vRnHCz8e+eIHernTqOhwSNTyo36Rc8J
# 0F6v0LBCBKL5pmyTZ9co3EZTsIbQ5ShGLieshk9VUgzkAyz7apCQMG6H81kwnfp+
# 1pez6CGXfvjSE/MIt1NtUrRFkJ9IAEpHZhEnKWaol+TTBoFKovmEpxFHFAmCn4Tt
# VXj+AZodUAiFABAwRu233iNGu8QtVJ+vHnhBMXfMm987g5OhYQK1HQ2x/PebsgHO
# IktU//kFw8IgCwIDAQABo4IBqzCCAacwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4E
# FgQUIzT42VJGcArtQPt2+7MrsMM1sw8wCwYDVR0PBAQDAgGGMBAGCSsGAQQBgjcV
# AQQDAgEAMIGYBgNVHSMEgZAwgY2AFA6sgmBAVieX5SUT/CrhClOVWeSkoWOkYTBf
# MRMwEQYKCZImiZPyLGQBGRYDY29tMRkwFwYKCZImiZPyLGQBGRYJbWljcm9zb2Z0
# MS0wKwYDVQQDEyRNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHmC
# EHmtFqFKoKWtTHNY9AcTLmUwUAYDVR0fBEkwRzBFoEOgQYY/aHR0cDovL2NybC5t
# aWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvbWljcm9zb2Z0cm9vdGNlcnQu
# Y3JsMFQGCCsGAQUFBwEBBEgwRjBEBggrBgEFBQcwAoY4aHR0cDovL3d3dy5taWNy
# b3NvZnQuY29tL3BraS9jZXJ0cy9NaWNyb3NvZnRSb290Q2VydC5jcnQwEwYDVR0l
# BAwwCgYIKwYBBQUHAwgwDQYJKoZIhvcNAQEFBQADggIBABCXisNcA0Q23em0rXfb
# znlRTQGxLnRxW20ME6vOvnuPuC7UEqKMbWK4VwLLTiATUJndekDiV7uvWJoc4R0B
# hqy7ePKL0Ow7Ae7ivo8KBciNSOLwUxXdT6uS5OeNatWAweaU8gYvhQPpkSokInD7
# 9vzkeJkuDfcH4nC8GE6djmsKcpW4oTmcZy3FUQ7qYlw/FpiLID/iBxoy+cwxSnYx
# PStyC8jqcD3/hQoT38IKYY7w17gX606Lf8U1K16jv+u8fQtCe9RTciHuMMq7eGVc
# WwEXChQO0toUmPU8uWZYsy0v5/mFhsxRVuidcJRsrDlM1PZ5v6oYemIp76KbKTQG
# dxpiyT0ebR+C8AvHLLvPQ7Pl+ex9teOkqHQ1uE7FcSMSJnYLPFKMcVpGQxS8s7Ow
# TWfIn0L/gHkhgJ4VMGboQhJeGsieIiHQQ+kr6bv0SMws1NgygEwmKkgkX1rqVu+m
# 3pmdyjpvvYEndAYR7nYhv5uCwSdUtrFqPYmhdmG0bqETpr+qR/ASb/2KMmyy/t9R
# yIwjyWa9nR2HEmQCPS2vWY+45CHltbDKY7R4VAXUQS5QrJSwpXirs6CWdRrZkocT
# dSIvMqgIbqBbjCW/oO+EyiHW6x5PyZruSeD3AWVviQt9yGnI5m7qp5fOMSn/DsVb
# XNhNG6HY+i+ePy5VFmvJE6P9MIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
# hkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEwOTA5WjB+MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQg
# Q29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+laUKq4BjgaBEm6f8MMHt03
# a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc6Whe0t+bU7IKLMOv2akr
# rnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4Ddato88tt8zpcoRb0Rrrg
# OGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+lD3v++MrWhAfTVYoonpy
# 4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nkkDstrjNYxbc+/jLTswM9
# sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6A4aN91/w0FK/jJSHvMAh
# dCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmdX4jiJV3TIUs+UsS1Vz8k
# A/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL5zmhD+kjSbwYuER8ReTB
# w3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zdsGbiwZeBe+3W7UvnSSmn
# Eyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3T8HhhUSJxAlMxdSlQy90
# lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS4NaIjAsCAwEAAaOCAe0w
# ggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRIbmTlUAXTgqoXNzcitW2o
# ynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQFTuHqp8cx0SOJNDBa
# BgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3JsMF4GCCsG
# AQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3J0MIGfBgNV
# HSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEFBQcCARYzaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1hcnljcHMuaHRtMEAGCCsG
# AQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkAYwB5AF8AcwB0AGEAdABl
# AG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn8oalmOBUeRou09h0ZyKb
# C5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7v0epo/Np22O/IjWll11l
# hJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0bpdS1HXeUOeLpZMlEPXh6
# I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/KmtYSWMfCWluWpiW5IP0
# wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvyCInWH8MyGOLwxS3OW560
# STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBpmLJZiWhub6e3dMNABQam
# ASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJihsMdYzaXht/a8/jyFqGa
# J+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYbBL7fQccOKO7eZS/sl/ah
# XJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbSoqKfenoi+kiVH6v7RyOA
# 9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sLgOppO6/8MO0ETI7f33Vt
# Y5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtXcVZOSEXAQsmbdlsKgEhr
# /Xmfwb1tbWrJUnMTDXpQzTGCBI4wggSKAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAAEDXiUcmR+jHrgAAAAAAQMwCQYFKw4DAhoFAKCB
# ojAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYK
# KwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUxIkb12MwRQUbYkWPMnOq1z7Oeusw
# QgYKKwYBBAGCNwIBDDE0MDKgFIASAE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbTANBgkqhkiG9w0BAQEFAASCAQDRA/7qEjJURXLr
# d09vrgxL47jmpMmBvHQspFzUXBpleinamfm43blGxjNax/ycZ07KSTXqV/O3HkMO
# V24WGcedQs4cmZPWMVGjj3z0Bo8sEIB0AL3+/yWk74PlzEDrcWN/BdpWS+zUATJR
# Spv1q+1U2ETkZFic6P0ahuH1/qqj4N8TMovR7Ga4MFAPXkUX9B4kD+17fNYqeoAm
# 0/HbrWNLvi28vwwRLN+aHZntl8tC+G+K07A/Eq99UdpQmm3k1MOvCXNHVZpRD9ip
# pFw9VPQ2BAP95GYRarlhMbKGM/DbIeHeDqMwgumgYx8IOnN4ByRt37tI7cYn9e+3
# XSXgOF5UoYICKDCCAiQGCSqGSIb3DQEJBjGCAhUwggIRAgEBMIGOMHcxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xITAfBgNVBAMTGE1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFBDQQITMwAAAPQiWJXCqdgoJQAAAAAA9DAJBgUrDgMCGgUA
# oF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTgw
# OTEzMTg1NjA4WjAjBgkqhkiG9w0BCQQxFgQUvQM6LYMaErW7IwXGuVGEyDJ6AHMw
# DQYJKoZIhvcNAQEFBQAEggEATqiOWpsSFmzwvl7pVmKhgAdWT0tQFVYMXg4rtJWf
# eUE2t2tpZoSOE68Ueedf/WHWy5WQPccQaGaa2y+8ZkAjdwWo8YaVIGqVawnQ8hhE
# EQwU2Rh5GQcBHqXNVVA7ehqamHnUlVZH2Zk1CMr6lMgfSrHJ1nXPywXH5KWUIyZe
# H0gIliaqJrwHERuT1EHKSLTYJKwQh5A9ksVviyiZfjYgEY+ZW7sfpBRzejaL689J
# Xj0wdZDnkF753FC/wAgD4HjMjcJ6ITmMVg6fQ97cqLhZJXrwzhZ1YYaJgYNCoz8A
# cJuhSnmIsOHB+MchJoHhvq8MmPakmQPoRIBmM6LxkpnxYQ==
# SIG # End signature block
