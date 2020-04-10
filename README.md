# configure-nsxt-loadbalancer

PowerShell Module for interacting with the NSX-T Policy API

Includes a script & sample JSON to configure an NSX-T Load Balancer for use with the VMware vRealize Suite

Created by Brian O'Connell

HCIBU

cmdlet support is currently limited to configuring the NSX-T load balancer

## IMPORTANT: JSON Entries that you may need to edit

lb_spec.lb_service.display_name  *(add desired load balancer name)*

lb_spec.lb_service.connectivity_path  *(add your Tier-1 Gateway name in the path /infra/tier-1s/your-T1-here)*

lb_spec.service_monitors.server_ssl_profile_binding.client_certificate_path  *(add your xRegion WSA Certificate Name that was used when importing the WSA cert to NSX-T)*


## Example usage

```powershell
#script & sample JSON to configure an NSX-T Load Balancer for use with the VMware vRealize Suite

### #User Variables
$NSXTManager = "sfo-m01-nsx01.sfo01.rainpole.io"
$NSXTManagerUserName = "admin"
$NSXTManagerPassword = "VMw@re1!VMw@re1!"

#Import the PowerNSX-T module

Import-Module -Name .\NSX-T-PS.psm1

#Connect to NSX-T Manager

Connect-NSXTManager -fqdn $NSXTManager -username $NSXTManagerUserName -password $NSXTManagerPassword

#Create the Load Balancer Service on the Tier-1 Gateway

New-NSXTLB -json .\NSX-LB-Spec.json

New-NSXTLBServiceMonitor -json .\NSX-LB-Spec.json

New-NSXTLBAppProfile -json .\NSX-LB-Spec.json

New-NSXTLBPool -json .\NSX-LB-Spec.json

New-NSXTLBVirtualServer -json .\NSX-LB-Spec.json
```


