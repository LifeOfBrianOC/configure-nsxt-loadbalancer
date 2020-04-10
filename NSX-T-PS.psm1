if ($PSEdition -eq 'Core') {
$PSDefaultParameterValues.Add("Invoke-RestMethod:SkipCertificateCheck",$true)
}

if ($PSEdition -eq 'Desktop') {
# Enable communication with self signed certs when using Windows Powershell
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;

add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertificatePolicy : ICertificatePolicy {
        public TrustAllCertificatePolicy() {}
		public bool CheckValidationResult(
            ServicePoint sPoint, X509Certificate certificate,
            WebRequest wRequest, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertificatePolicy
}

####  Do not modify anything below this line. All user variables are in the accompanying JSON files #####

Function createHeader {
    $Global:headers = @{"Accept" = "application/json"}
    $Global:headers.Add("Authorization", "Basic $base64AuthInfo")
  }

  Function ResponseException {
    #Get response from the exception
    $response = $_.exception.response
    if ($response) {
      Write-Host ""
      Write-Host "Oops something went wrong, please check your API call" -ForegroundColor Red -BackgroundColor Black
      Write-Host ""
      $responseStream = $_.exception.response.GetResponseStream()
      $reader = New-Object system.io.streamreader($responseStream)
      $responseBody = $reader.readtoend()
      $ErrorString = "Exception occured calling invoke-restmethod. $($response.StatusCode.value__) : $($response.StatusDescription) : Response Body: $($responseBody)"
      Throw $ErrorString
      Write-Host ""
    }
    else {
      Throw $_
    }
  } 

Function Connect-NSXTManager {
<#
  .SYNOPSIS
  Connects to the specified NSX-T Manager and stores the credentials in a base64 string

  .DESCRIPTION
  The Connect-NSXTManager cmdlet connects to the specified NSX-T Manager and stores the credentials
	in a base64 string. It is required once per session before running all other cmdlets

  .EXAMPLE
	PS C:\> Connect-NSXTManager -fqdn sfo-m01-nsx01.sfo.rainpole.local -username admin -password VMw@re1!VMw@re1!
  This example shows how to connect to NSX-T Manager
#>

  Param (
    [Parameter (Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string]$fqdn,
		[Parameter (Mandatory=$false)]
      [ValidateNotNullOrEmpty()]
      [string]$username,
		[Parameter (Mandatory=$false)]
      [ValidateNotNullOrEmpty()]
      [string]$password
  )

  if ( -not $PsBoundParameters.ContainsKey("username") -or ( -not $PsBoundParameters.ContainsKey("username"))) {
    # Request Credentials
    $creds = Get-Credential
    $username = $creds.UserName.ToString()
    $password = $creds.GetNetworkCredential().password
  }

  $Global:NSXTManager = $fqdn
  $Global:base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username,$password))) # Create Basic Authentication Encoded Credentials

  # Validate credentials by executing an API call
  $headers = @{"Accept" = "application/json"}
  $headers.Add("Authorization", "Basic $base64AuthInfo")
  $uri = "https://$NSXTManager/api/v1/logical-ports"

  Try {
    # Checking against the NSX-T-managers API
    # PS Core has -SkipCertificateCheck implemented, PowerShell 5.x does not
    if ($PSEdition -eq 'Core') {
      $response = Invoke-WebRequest -Method GET -Uri $uri -Headers $headers -SkipCertificateCheck
    }
    else {
      $response = Invoke-WebRequest -Method GET -Uri $uri -Headers $headers
    }
    if ($response.StatusCode -eq 200) {
      Write-Host " Successfully connected to NSX-T Manager:" $sddcManager -ForegroundColor Yellow
    }
  }
  Catch {
    Write-Host "" $_.Exception.Message -ForegroundColor Red
    Write-Host " Credentials provided did not return a valid API response (expected 200). Retry Connect-NSXTManager cmdlet" -ForegroundColor Red
  }
}
Export-ModuleMember -Function Connect-NSXTManager

Function New-NSXTLBServiceMonitor {
    <#
        .SYNOPSIS
        Connects to the specified NSX-T Manager & creates a load balancer monitor.
    
        .DESCRIPTION
        The New-NSXTLBServiceMonitor cmdlet connects to the specified NSX-T Manager
        & creates a load balancer monitor.
    
        .EXAMPLE
        PS C:\> New-NSXTLBServiceMonitor -json .\WorkloadDomain\workloadDomainSpec.json
        This example shows how to create a Workload Domain from a json spec
    #>
    
        Param (
        [Parameter (Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [string]$json
        )
    
        if (!(Test-Path $json)) {
        Throw "JSON File Not Found"
        }
        else {
        # Read the json file contents into the $ConfigJson variable
        $ConfigJson = (Get-Content $json) | ConvertFrom-Json
        createHeader # Calls Function createHeader to set Accept & Authorization
        foreach ($monitor in $ConfigJson.lb_spec.service_monitors) {
        Try {
            $body = $monitor | ConvertTo-Json -Depth 10
        $uri = "https://$NSXTManager/policy/api/v1/infra/lb-monitor-profiles/$($monitor.display_name)"
        $response = Invoke-WebRequest -Method PATCH -URI $uri -ContentType application/json -headers $headers -body $body
        $response
        Write-Host ""
        }
        Catch {
        ResponseException # Call Function ResponseException to get error response from the exception
        }
    }
}
}
Export-ModuleMember -Function New-NSXTLBServiceMonitor
Function New-NSXTLBAppProfile {
    <#
      .SYNOPSIS
      Connects to the specified NSX-T Manager & creates a load balancer Application Profile.
    
      .DESCRIPTION
      The New-NSXTLBAppProfile cmdlet connects to the specified NSX-T Manager
        & creates a load balancer Application Profile.
    
      .EXAMPLE
        PS C:\> New-NSXTLBAppProfile -json .\WorkloadDomain\workloadDomainSpec.json
      This example shows how to create a Workload Domain from a json spec
    #>
    
        Param (
        [Parameter (Mandatory=$true)]
          [ValidateNotNullOrEmpty()]
          [string]$json
      )
    
      if (!(Test-Path $json)) {
        Throw "JSON File Not Found"
      }
      else {
        # Read the json file contents into the $ConfigJson variable
        $ConfigJson = (Get-Content -Raw $json) | ConvertFrom-Json
        createHeader # Calls Function createHeader to set Accept & Authorization
        foreach ($profile in $ConfigJson.lb_spec.app_profiles) {
        Try {
            $body = $profile | ConvertTo-Json
        $uri = "https://$NSXTManager/policy/api/v1/infra/lb-app-profiles/$($profile.display_name)"
        $response = Invoke-WebRequest -Method PATCH -URI $uri -ContentType application/json -headers $headers -body $body
        $response
        Write-Host ""
        }
        Catch {
        ResponseException # Call Function ResponseException to get error response from the exception
        }
    }
    # Create Persistence Profiles   
    foreach ($profile in $ConfigJson.lb_spec.persistence_profiles) {
        Try {
            $body = $profile | ConvertTo-Json
        $uri = "https://$NSXTManager/policy/api/v1/infra/lb-persistence-profiles/$($profile.display_name)"
        $response = Invoke-WebRequest -Method PATCH -URI $uri -ContentType application/json -headers $headers -body $body
        $response
        Write-Host ""
        }
        Catch {
        ResponseException # Call Function ResponseException to get error response from the exception
        }
    }
}
}
Export-ModuleMember -Function New-NSXTLBAppProfile

Function New-NSXTLBPool {
    <#
        .SYNOPSIS
        Connects to the specified NSX-T Manager & creates a load balancer monitor.
    
        .DESCRIPTION
        The New-NSXTLBPool cmdlet connects to the specified NSX-T Manager
        & creates a load balancer monitor.
    
        .EXAMPLE
        PS C:\> New-NSXTLBPool -json .\WorkloadDomain\workloadDomainSpec.json
        This example shows how to create a Workload Domain from a json spec
    #>
    
        Param (
        [Parameter (Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [string]$json
        )
    
        if (!(Test-Path $json)) {
        Throw "JSON File Not Found"
        }
        else {
        # Read the json file contents into the $ConfigJson variable
        $ConfigJson = (Get-Content $json) | ConvertFrom-Json
        createHeader # Calls Function createHeader to set Accept & Authorization
        foreach ($pool in $ConfigJson.lb_spec.pools) {
        Try {
            $body = $pool | ConvertTo-Json
        $uri = "https://$NSXTManager/policy/api/v1/infra/lb-pools/$($pool.display_name)"
        $response = Invoke-WebRequest -Method PATCH -URI $uri -ContentType application/json -headers $headers -body $body
        $response
        Write-Host ""
        }
        Catch {
        ResponseException # Call Function ResponseException to get error response from the exception
        }
    }
}
}
Export-ModuleMember -Function New-NSXTLBPool

Function New-NSXTLBVirtualServer {
    <#
        .SYNOPSIS
        Connects to the specified NSX-T Manager & creates a load balancer monitor.
    
        .DESCRIPTION
        The New-NSXTLBVirtualServer cmdlet connects to the specified NSX-T Manager
        & creates a load balancer monitor.
    
        .EXAMPLE
        PS C:\> New-NSXTLBVirtualServer -json .\WorkloadDomain\workloadDomainSpec.json
        This example shows how to create a Workload Domain from a json spec
    #>
    
        Param (
        [Parameter (Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [string]$json
        )
    
        if (!(Test-Path $json)) {
        Throw "JSON File Not Found"
        }
        else {
        # Read the json file contents into the $ConfigJson variable
        $ConfigJson = (Get-Content $json) | ConvertFrom-Json
        createHeader # Calls Function createHeader to set Accept & Authorization
        foreach ($virtualServer in $ConfigJson.lb_spec.virtual_Servers) {
        Try {
            $body = $virtualServer | ConvertTo-Json -Depth 10
        $uri = "https://$NSXTManager/policy/api/v1/infra/lb-virtual-servers/$($virtualServer.display_name)"
        $response = Invoke-WebRequest -Method PATCH -URI $uri -ContentType application/json -headers $headers -body $body
        $response
        Write-Host ""
        }
        Catch {
        ResponseException # Call Function ResponseException to get error response from the exception
        }
    }
}
}
Export-ModuleMember -Function New-NSXTLBVirtualServer

Function New-NSXTLB {
    <#
        .SYNOPSIS
        Connects to the specified NSX-T Manager & creates a load balancer service.
    
        .DESCRIPTION
        The New-NSXTLB cmdlet connects to the specified NSX-T Manager
        & creates a load balancer monitor.
    
        .EXAMPLE
        PS C:\> New-NSXTLB -json .\WorkloadDomain\workloadDomainSpec.json
        This example shows how to create a Workload Domain from a json spec
    #>
    
        Param (
        [Parameter (Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [string]$json
        )
    
        if (!(Test-Path $json)) {
        Throw "JSON File Not Found"
        }
        else {
        # Read the json file contents into the $ConfigJson variable
        $ConfigJson = (Get-Content $json) | ConvertFrom-Json
        createHeader # Calls Function createHeader to set Accept & Authorization
        foreach ($lb_service in $ConfigJson.lb_spec.lb_service) {
        Try {
            $body = $lb_service | ConvertTo-Json
        $uri = "https://$NSXTManager/policy/api/v1/infra/lb-services/$($lb_service.display_name)"
        $response = Invoke-WebRequest -Method PATCH -URI $uri -ContentType application/json -headers $headers -body $body
        $response
        Write-Host ""
        }
        Catch {
        ResponseException # Call Function ResponseException to get error response from the exception
        }
    }
}
}
Export-ModuleMember -Function New-NSXTLB
