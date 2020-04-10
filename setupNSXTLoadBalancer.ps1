#Script to setup the NSX-T Load Balancer for the vRealize Suite & Workspace ONE Access
#Aligns to VMware Validated Design 6.0 & VMware Cloud Foundation 4.0 Guidance

##User Variables
$NSXTManager = "sfo-m01-nsx01.sfo.rainpole.io"
$NSXTManagerUserName = "admin"
$NSXTManagerPassword = "VMw@re1!VMw@re1!"



#Import the NSX-T Functions module
Import-Module -Name .\NSX-T-PS.psm1
#Connect to NSX-T Manager
Connect-NSXTManager -fqdn $NSXTManager -username $NSXTManagerUserName -password $NSXTManagerPassword
#Create the Load Balancer Service on the Tier-1 Gateway

New-NSXTLB -json .\NSX-LB-Spec.json
New-NSXTLBServiceMonitor -json .\NSX-LB-Spec.json
New-NSXTLBAppProfile -json .\NSX-LB-Spec.json
New-NSXTLBPool -json .\NSX-LB-Spec.json
New-NSXTLBVirtualServer -json .\NSX-LB-Spec.json
