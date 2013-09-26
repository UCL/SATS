#SATS
## SLMS Administrative Toolset. 

A way of giving delegated administration of Windows servers via PowerShell 

##Overview
There are lots of things in Windows which you'd like to delegate to front line staff.

Unfortunately, they require admin privileges in the normal run of things.

Fortunately, we can use a feature in PowerShell 3.0 known as constrained delegation.

SATS represents a first attempt at providing delegated tools to front line staff.

##Installation
1.  Copy everything to `C:\SATS`
1.  Take a look at `SessionConfiguration\SATS.pssc`, and tailor to your needs. You will probably need to do the following.
  1.  Change the modules you want to load. Note that these should be done in the order in which they're required.
1. Edit `StartupScripts\SATS.ps1` to your needs.
<strong>This file defines your security, so take care!</strong>
  1. `$CmdsToInclude` are the commands that should be visible to users using this delegation.
  1. `$CmdsToExclude` allows you to define a subset of the "Include" cmds to really exclude. In our setup, we have a module called "PoshDHCP" which has some commands only sysadmins should use.
1. Set up a constrained session configuration:
  `Register-PSSessionConfiguration -Name SATS -Path C:\SATS\SessionConfiguration\SATS.pssc <br/> -RunAsCredential <Admin Service Account> -ShowSecurityDescriptorUI`
1. Depending on your organisation size, change the WinRM limits.
  1. `winrm set winrm/config/winrs @{MaxShellsPerUser="100"}`
  1. `winrm set winrm/config/winrs @{MaxConcurrentUsers="100"}`
  1. `set-item WSMAN:\localhost\Plugin\SATS\Quotas\MaxConcurrentUsers 100`
  1. `set-item WSMAN:\localhost\Plugin\SATS\Quotas\MaxShellsPerUser 100`
  1. `set-item WSMAN:\localhost\Plugin\SATS\Quotas\MaxShells 100`
