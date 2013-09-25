#Requires -Modules DhcpServer


$Script:PrimaryDHCP = ""
$Script:SecondaryDHCP = ""
$FilterCache = @{}
$logger = Get-Logger "PoshDHCP"
$userName = $PSSenderInfo.ConnectedUser


Function Join-LogUser($function, $message)
{
 $jsonObject = New-Object PSObject
 $jsonObject | Add-Member -MemberType NoteProperty -Name "UserName" -Value "$userName"
 $jsonObject | Add-Member -MemberType NoteProperty -Name "Function" -Value "$function"
 $jsonObject | Add-Member -MemberType NoteProperty -Name "Message" -Value "$message"
 $timestamp = [System.DateTime]::UtcNow.ToString("o")
 $jsonObject | Add-Member -MemberType NoteProperty -Name "Timestamp" -Value "$timestamp"
 ConvertTo-Json $jsonObject
}


Function Write-LogInfo($function, $message)
{
    $logger.Info((Join-LogUser -function $function -message $message))
}

Function Write-LogWarn($function, $message)
{
    $logger.Warn((Join-LogUser -function $function -message $message))
}

Function Write-LogError($function, $message)
{
    $logger.Error((Join-LogUser -function $function -message $message))
}

Function Write-LogDebug($function, $message)
{
    $logger.Debug((Join-LogUser -function $function -message $message))
}

Function Write-LogTrace($function, $message)
{
    $logger.Trace((Join-LogUser -function $function -message $message))
}

Function Write-LogFatal($function, $message)
{
    $logger.Fatal((Join-LogUser -function $function -message $message))
}


#
<#
    .SYNOPSIS
    Sets the primary DHCP server for a failover relationship for the
    PdDHCP module.

    .DESCRIPTION
    Sets the primary DHCP server for a failover relationship for the
    PdDHCP module.
    The secondary DHCP server is determined from the primary.

    .PARAMETER ComputerName
    The computer name of the primary DHCP server.

    .EXAMPLE
    Set-DHCPPrimaryServer -ComputerName pddhcp01.contoso.com

#>
Function Set-DHCPPrimaryServer
{
    [cmdletbinding()]
    Param(
        [Parameter(Position=0,Mandatory=$true)]
        [string]$ComputerName
    )
    $Script:PrimaryDHCP = $ComputerName
    $Script:SecondaryDHCP = (get-dhcpserverv4failover -ComputerName $ComputerName).PartnerServer
}

Function Invoke-DHCPFailoverReplication
{
    [cmdletbinding()]
    Param(
        [Parameter(Position=0)]
        [System.Net.IPAddress]$ScopeID
    )
    if ($ScopeID)
    {
        Invoke-DhcpServerv4FailoverReplication -ComputerName $Script:PrimaryDHCP  -ScopeID $ScopeID
    }
    else
    {
        Invoke-DhcpServerv4FailoverReplication -ComputerName $Script:PrimaryDHCP 
    }
}

<#
    .SYNOPSIS
    Converts a MAC address into an appropriately delimited format.

    .DESCRIPTION
    Converts MAC addresses in the following formats:
        00:01:02:03:04:05
        00-01-02-03-04-05
        000102030405
    Into a canonical format separated by : or any other separator
    specified.

    .PARAMETER MacAddress
    The MAC address to be converted.

    .PARAMETER Separator
    The character to be used to separate the hexadecimal components

    .EXAMPLE
    ConvertTo-MacAddressCanonical 000102030405
    00-01-02-03-04-05

    .EXAMPLE
    ConvertTo-MacAddressCanonical 000102030405 -Separator ":"
    00:01:02:03:04:05
#>
Function ConvertTo-MacAddressCanonical
{
    [cmdletbinding()]
    Param(
        [Parameter(Position=0,Mandatory=$true)]
        [string]$MacAddress,
        [string]$Separator="-"
    )

    $MacRegex = '^([0-9a-fA-F]{2})[:-]([0-9a-fA-F]{2})[:-]([0-9a-fA-F]{2})[:-]([0-9a-fA-F]{2})[:-]([0-9a-fA-F]{2})[:-]([0-9a-fA-F]{2})$'
    $MacRegexNoSpace = '^([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$'
    if($MacAddress -match $MacRegex)
    {
    }
    elseif($MacAddress -match $MacRegexNoSpace)
    {
    }
    else
    {
        throw "MAC Address not in known format"
    }
    $finalString = $matches.1 + $separator + $matches.2 + $separator + $matches.3 + $separator + $matches.4 + $separator + $matches.5 + $separator + $matches.6
    $finalString

}

Function Add-DhcpReservation
{
    [cmdletbinding()]
    Param(
        [Parameter(Position=0,Mandatory=$true)]
        [string]$ClientID,
        [Parameter(Position=1,Mandatory=$true)]
        [System.Net.IPAddress]$IPAddress,
        [Parameter(Position=2,Mandatory=$true)]
        [System.Net.IPAddress]$ScopeID,
        [Parameter(Position=3,Mandatory=$true)]
        [string]$Name,
        [Parameter(Position=4,Mandatory=$true)]
        [string]$Description
    )
    Write-LogInfo("Add-DhcpReservation","Ran with ClientID=$ClientID, IPAddress=$IPAddress, ScopeID=$ScopeID, Name=$Name, Description=$Description")
    $CanonicalClientID = ConvertTo-MacAddressCanonical $ClientID
    Add-DhcpServerv4Reservation -ComputerName $Script:PrimaryDHCP -ClientId $CanonicalClientID -IPAddress $IPAddress -ScopeId $ScopeID -Name $Name -Description $Description
    Invoke-DHCPFailoverReplication -ScopeID $ScopeID
}

Function Set-DhcpReservation
{
    [cmdletbinding()]
    Param(
        [Parameter(Position=0,Mandatory=$true)]
        [System.Net.IPAddress]$IPAddress,
        [Parameter(Position=1)]
        [string]$ClientID,
        [Parameter(Position=2)]
        [string]$Name,
        [Parameter(Position=3)]
        [string]$Description
    )
    Write-LogInfo("Set-DhcpReservation","Ran with ClientID=$ClientID, IPAddress=$IPAddress, Name=$Name, Description=$Description")
    $Parameters = @{}
    $Parameters["IPAddress"] = $IPAddress
    if($ClientID){$Parameters["ClientID"] = (ConvertTo-MacAddressCanonical $ClientID)}
    if($Name){$Parameters["Name"] = $Name}
    if($Description){$Parameters["Description"] = $Description}
    Set-DhcpServerv4Reservation @Parameters -ComputerName $Script:PrimaryDHCP
    Invoke-DHCPFailoverReplication
}

Function Remove-DhcpReservation
{
    [cmdletbinding()]
    Param(
        [Parameter(Position=0,Mandatory=$true)]
        [System.Net.IPAddress]$IPAddress
    )
    Write-LogInfo("Remove-DhcpReservation","Ran with IPAddress=$IPAddress")
    Remove-DhcpServerv4Reservation -IPAddress $IPAddress -ComputerName $Script:PrimaryDHCP
    Invoke-DHCPFailoverReplication
}

Function Get-DhcpReservation
{
    [cmdletbinding()]
    [Parameter(Position=0,Mandatory=$true,ParameterSetName='ScopeID')]
    [System.Net.IPAddress]$ScopeID,
    [Parameter(Position=0,Mandatory=$true,ParameterSetName='ClientID')]
    [string[]]$ClientID,
    [Parameter(Position=1,Mandatory=$true,ParameterSetName='ClientID')]
    [System.Net.IPAddress]$ScopeID,
    [Parameter(Position=0,Mandatory=$true,ParameterSetName='IPAddress')]
    [System.Net.IPAddress]$IPAddress
    switch ($PsCmdlet.ParameterSetName)
    {
        "ScopeID" { 
            Get-DhcpServerv4Reservation -ScopeID $ScopeID  -ComputerName $Script:PrimaryDHCP
            Write-LogInfo("Get-DhcpReservation","Ran with ScopeID=$ScopeID")
        }
        "ClientID" {
            Get-DhcpServerv4Reservation -ScopeID $ScopeID -ClientID (ConvertTo-MacAddressCanonical $ClientID) -ComputerName $Script:PrimaryDHCP
            Write-LogInfo("Get-DhcpReservation","Ran with ScopeID=$ScopeID, ClientID=$ClientID")
        }
        "IPAddress" {
            Get-DhcpServerv4Reservation -IPAddress $IPAddress -ComputerName $Script:PrimaryDHCP
            Write-LogInfo("Get-DhcpReservation","Ran with IPAddress=$IPAddress")
        }

    }


}

<#
    .SYNOPSIS
    Adds a client MAC address to the DHCP servers so that they can receive
    dynamic or static leases.

    .DESCRIPTION
    Adds a client MAC address to the DHCP servers so that they can receive
    dynamic or static leases.
    This function will add the MAC address to the Allow filter of both DHCP
    servers.

    .PARAMETER ClientID
    The MAC address of the client to be added.

    .PARAMETER Name
    The preferred DNS name of the client.

    .PARAMETER Description
    Information to help local IT staff locate the client on the physical
    network.

    .EXAMPLE
    Add-DhcpClient -ClientID 00:AA:BB:CC:DD:EE -Group Podium -Name c00010001.ad.ucl.ac.uk -Description "An admin machine"
#>
Function Add-DhcpClient
{
    [cmdletbinding()]
    Param(
        [Parameter(Position=0,Mandatory=$true)]
        [string]$ClientID,
        [Parameter(Position=1,Mandatory=$true)]
        [string]$Name,
        [string]$Description
    )

    $CanonicalClientID = ConvertTo-MacAddressCanonical -MacAddress $ClientID 
    Add-DhcpServerv4Filter -ComputerName $Script:PrimaryDHCP -MacAddress $CanonicalClientID -Description "$Name;$Description" -List Allow
    Add-DhcpServerv4Filter -ComputerName $Script:SecondaryDHCP -MacAddress $CanonicalClientID -Description "$Name;$Description" -List Allow
    Write-LogInfo("Add-DhcpClient","Ran with ClientID=$ClientID, Name=$Name, Description=$Description")
}

<#
    .SYNOPSIS
    Sets the name and description for a client MAC address.

    .DESCRIPTION
    Removes the DHCP client from the DHCP servers and re-adds them using
    the new description.

    .PARAMETER ClientID
    The MAC address of the client to be modified.

    .PARAMETER Name
    The preferred DNS name of the client.

    .PARAMETER Description
    Information to help local IT staff locate the client on the physical
    network.

    .EXAMPLE
    Set-DhcpClient -ClientID 00:AA:BB:CC:DD:EE -Name c00010001.ad.ucl.ac.uk -Description "An admin machine"
#>
Function Set-DhcpClient
{
    [cmdletbinding()]
    Param(
        [Parameter(Position=0,Mandatory=$true)]
        [string]$ClientID,
        [Parameter(Position=1)]
        [string]$Name,
        [string]$Description
    )

    $CanonicalClientID = ConvertTo-MacAddressCanonical -MacAddress $ClientID 
    Remove-DhcpClient $CanonicalClientID
    
    Add-DhcpClient -Client $CanonicalClientID -Name $Name -Description $Description
    Write-LogInfo("Set-DhcpClient","Ran with ClientID=$ClientID, Name=$Name, Description=$Description")
}

<#
    .SYNOPSIS
    Remove a DHCP client from the DHCP servers.

    .DESCRIPTION
    Removes a MAC address from the filters of both servers.

    .PARAMETER ClientID
    The MAC address of the client to be modified.
#>
Function Remove-DhcpClient
{
    [cmdletbinding()]
    Param(
        [Parameter(Position=0,Mandatory=$true)]
        [string]$ClientID
    )
    $CanonicalClientID = ConvertTo-MacAddressCanonical -MacAddress $ClientID 
    Remove-DhcpServerv4Filter -ComputerName $Script:PrimaryDHCP -MacAddress $CanonicalClientID 
    Remove-DhcpServerv4Filter -ComputerName $Script:SecondaryDHCP -MacAddress $CanonicalClientID 
    Write-LogInfo("Remove-DhcpClient","Ran with ClientID=$ClientID")
}

<#
    .SYNOPSIS
    Get information on clients allowed to access DHCP.

    .DESCRIPTION
    Outputs the DHCP Allow filter on the primary server.

    .PARAMETER ClientID
    The MAC address of the DHCP client.

    .PARAMETER Group
    The host group of the DHCP client.

    .PARAMETER Verify
    Check that the client exists on both DHCP servers.

    .PARAMETER Leases
    Return information on leases.

#>
Function Get-DhcpClient
{
    [cmdletbinding()]
    Param(
        [Parameter(Position=0,Mandatory=$true,ParameterSetName='ClientID')]
        [string]$ClientID
         )
    if($ClientID)
    {
            $CanonicalClientID = ConvertTo-MacAddressCanonical -MacAddress $ClientID 
            Get-DhcpClientInformation $CanonicalClientID
    }
        $clients = Get-DhcpServerv4Filter -ComputerName $Script:PrimaryDHCP -List Allow
        foreach($client in $clients)
        {
           Get-DhcpClientInformation $client.MacAddress
        }

        Write-LogInfo("Get-DhcpClient","Ran with ClientID=$ClientID")
}

#gc ips | %{[Net.IPAddress]::Parse($_)} |   sort {$b=$_.GetAddressBytes();[array]::Reverse($b);[BitConverter]::ToUInt32($b,0)} |   ft IPAddressToString


Function Get-DhcpLease
{
    [cmdletbinding()]
    Param(
        [Parameter(Position=0,Mandatory=$true)]
        [string]$ScopeID
    )
    $results = Get-DhcpServerv4Lease -ComputerName $Script:PrimaryDHCP -ScopeId $ScopeID 
    $results |  sort {$b=$_.IPAddress.GetAddressBytes();[array]::Reverse($b);[BitConverter]::ToUInt32($b,0)} | Format-Table -AutoSize 
    Write-LogInfo("Get-DhcpLease","Ran with ScopeID=$ScopeID")
}

Function Get-DhcpReservation
{
    [cmdletbinding()]
    Param(
        [Parameter(Position=0,Mandatory=$true)]
        [string]$ScopeID
    )
    $results = Get-DhcpServerv4Reservation -ComputerName $Script:PrimaryDHCP -ScopeId $ScopeID 
    $results |  sort {$b=$_.IPAddress.GetAddressBytes();[array]::Reverse($b);[BitConverter]::ToUInt32($b,0)} | Format-Table -AutoSize 
    Write-LogInfo("Get-DhcpReservation","Ran with ScopeID=$ScopeID")
}

<#
    .SYNOPSIS
    Return a cached instance of Get-DhcpServerv4Filter

    .DESCRIPTION
    Stores instances of Get-DhcpServerv4Filter in a hashtable
    using the computername as the key.

    Same parameters as for Get-DhcpServerv4Filter

#>
Function Get-DhcpServerv4FilterCache
{
    Param(
        [Parameter(Position=0,Mandatory=$true)]
        [string]$ComputerName,
        [Parameter(Position=1,Mandatory=$true)]
        [string]$List
    )
    
    $results = $null
    if($FilterCache[$ComputerName].Time -gt (([System.DateTime]::Now).Ticks - 300E7))
    {
        $results = $FilterCache[$ComputerName].Cache
    }
    else
    {
        $results = Get-DhcpServerv4Filter -ComputerName $ComputerName -List $List 
        $Cache = @{
            "List" = $List
            "Cache" = $results
            "Time" = ([System.DateTime]::Now).Ticks
        }
        $FilterCache[$computername] = $Cache
    }
    return $results
}

<#
    .SYNOPSIS
    Get detailed information for a client.

    .DESCRIPTION 
    Get detailed information for a client. Includes:
        * MAC Address
        * All current leases on all scopes
        * All current reservations on all scopes
        * Last known lease and time
        * Host Group

    .PARAMETER ClientID
        MAC address of client

    .EXAMPLE
        Get-DhcpClientInformation 00-aa-bb-cc-dd-ee
#>
Function Get-DhcpClientInformation
{
    Param(
        [Parameter(Position=0,Mandatory=$true,ParameterSetName='ClientID')]
        [string]$ClientID
    )

    Write-LogInfo("Get-DhcpClientInformation","Ran with ClientID=$ClientID")

    # Get the standardised MAC Address
    $CanonicalClientID = ConvertTo-MacAddressCanonical -MacAddress $ClientID 

    # Create a new DHCP Client Info object
    $DHCPClientInfo = New-Object PSObject 

    # Add the MAC address to this object
    $DHCPClientInfo | Add-Member -MemberType NoteProperty -Name ClientID -TypeName "string" -Value $CanonicalClientID

    # Find out if the MAC address exists on the primary DHCP server and add it to a property
    $PrimaryStatus = $false
    $PrimaryFilterInfo = Get-DhcpServerv4FilterCache -ComputerName $Script:PrimaryDHCP -List Allow | where {$_.MacAddress -eq $CanonicalClientID}
    if($PrimaryFilterInfo)
    {
        $PrimaryStatus = $true
    }
    $DHCPClientInfo | Add-Member -MemberType NoteProperty -Name PrimaryStatus -TypeName "bool" -Value $PrimaryStatus
    
    # Find out if the MAC address exists on the secondary DHCP server and add it to a property
    $SecondaryStatus = $false
    if(Get-DhcpServerv4FilterCache -ComputerName $Script:SecondaryDHCP -List Allow | where {$_.MacAddress -eq $CanonicalClientID})
    {
        $SecondaryStatus = $true
    }
    $DHCPClientInfo | Add-Member -MemberType NoteProperty -Name SecondaryStatus -TypeName "bool" -Value $SecondaryStatus

    # Grab the description field on the MAC filter and break it up into "name" and "description" by splitting
    # on a semicolon
    $Name = ""
    $Description = ""
    if($PrimaryFilterInfo)
    {
        $Info = $PrimaryFilterInfo.Description.Split(";")
        $Name = $Info[0]
        $Description = $Info[1]
    }
    # Add the name and description as properties
    $DHCPClientInfo | Add-Member -MemberType NoteProperty -Name Name -TypeName "string" -Value $Name
    $DHCPClientInfo | Add-Member -MemberType NoteProperty -Name Description -TypeName "string" -Value $Description


    # Get all DHCP scopes
    $Scopes = Get-DhcpScope
    $leases = @()
    $reservations = @()

    # Iterate over each DHCP scope and find out if a lease exists for this client. If so, add it to an array.
    # Do the same for reservations.
    foreach($scope in $scopes)
    {
        $lease = Get-DhcpServerv4Lease -ClientId $CanonicalClientID -ComputerName $Script:PrimaryDHCP -ScopeId $scope
        if($lease)
        {
            $leases.add($lease)
        }
        $reservation = Get-DhcpServerv4Reservation -ClientId $CanonicalClientID  -ScopeId $scope
        if ($reservation)
        {
            $reservations.add($reservation)
        }
    }

    # Add the leases and reservations as properties.
    $DHCPClientInfo | Add-Member -MemberType NoteProperty -Name Leases -Value $leases
    $DHCPClientInfo | Add-Member -MemberType NoteProperty -Name Reservations -Value $reservations

    # Add the last known lease as a property    
    $LastLease = Get-DHCPClientHistory $ClientID -NoResults 1
    $DHCPClientInfo | Add-Member -MemberType NoteProperty -Name LastIssued -TypeName "System.DateTime" -Value $LastLease
    
}


<#
    .SYNOPSIS
    Gets DHCP scopes.

    .DESCRIPTION
    Gets DHCP scopes using Get-DhcpServerv4Scope.
#>
Function Get-DhcpScope
{
    [cmdletbinding()]
    Param(
        [Parameter(Position=0,Mandatory=$false)]
        [System.Net.IPAddress]$ScopeID
    )
    Write-LogInfo("Get-DhcpScope","Ran with ScopeID=$ScopeID")
    $results = @()
    if([System.String]::IsNullOrEmpty($ScopeID))
    {
     $results +=  Get-DhcpServerv4Scope  -ComputerName $Script:PrimaryDHCP
    }
    else
    {
      $results +=  Get-DhcpServerv4Scope -ScopeId $ScopeID -ComputerName $Script:PrimaryDHCP
    }
    $results
}

Function Get-DhcpFreeIPAddress
{
    [cmdletbinding()]
    Param(
        [Parameter(Position=0,Mandatory=$true)]
        [System.Net.IPAddress]$ScopeID
    )
    Write-LogInfo("Get-DhcpFreeIPAddress","Ran with ScopeID=$ScopeID")
    Get-DhcpServerv4FreeIPAddress -ComputerName $Script:PrimaryDHCP -ScopeId $ScopeID -NumAddress 1
}


Function Show-Menu($menu)
{
    Write-Host $menu.Title 
    write-host =============
    $menuoption = 1
    $menuDict = @{}
    foreach($option in $menu.Options.GetEnumerator())
    {
        $key = $option.key
        write-host $menuoption'.' $key
        $menuDict[$menuoption] = $key
        $menuoption++
    }
    $menuResult = $null
    while([System.String]::IsNullOrEmpty($menuResult))
    {
        try{
        $read = [int](Read-Host Please enter the number of the option you want to perform.)
        $menuResult = $menu.Options[$menuDict[$read]]
        }
        catch {}
    }
    return $menuResult
   
}

Function Show-DHCPMenu
{
    $menu = @{
        "Title"="DHCP Menu"
        "Options"= new-object 'system.collections.generic.dictionary[string,string]'
    }
    $menu.Options.Add("Add Client MAC to DHCP (Use 'View Scope' first to find a scope ID')","Show-DHCPAddClientMenu")
    $menu.Options.Add("Remove Client MAC from DHCP", "Show-DHCPRemoveClientMenu")
    $menu.options.Add("Create Static Reservation","Show-AddDHCPReservationMenu")
    $menu.options.Add("Remove Static Reservation","Show-RemoveDHCPReservationMenu")
    $menu.options.add("View Leases","Show-DHCPLeaseMenu")
    $menu.options.add("View Reservation","Show-DHCPReservationMenu")
    $menu.options.add("View Scope","Show-GetDHCPScope")
    $menu.options.add("Exit","Show-Exit")

    $command = Show-Menu $menu
    Invoke-Expression $command

}

Function Show-DHCPAddClientMenu
{
    Add-DhcpClient
    Show-DHCPMenu
}

Function Show-Exit
{
    
}

#Function Get-DHCPScopeIDByMenu
#{
#    $scopes = Get-DhcpServerv4Scope -ComputerName $Script:PrimaryDHCP
#    $menuID = 1
#    for($i =0; $i++; $i -lt $scopes.Count)
#    {
#        $scope = $scopes[$i]
#        $scopes[$i] = $scope | Add-Member -NotePropertyName MenuID -NotePropertyValue $menuID 
#    }
#    $scopes
#}

Function Show-DHCPReservationMenu
{
    Get-DhcpScope
    Write-Host "Please use a 'scope ID' from above"
    Get-DhcpReservation
    Show-DHCPMenu
}

Function Show-DHCPLeaseMenu
{
    Get-DhcpScope
    Write-Host "Please use a 'scope ID' from above"
    Get-DhcpLease
    Show-DHCPMenu
}


Function Show-DHCPRemoveClientMenu
{
    Remove-DhcpClient
    Show-DHCPMenu
}


Function Show-AddDHCPReservationMenu
{
    Get-DhcpScope
    Write-Host "Please use a 'scope ID' from above"
    Add-DhcpReservation
    Show-DHCPMenu
}


Function Show-RemoveDHCPReservationMenu
{
    Remove-DhcpReservation
    Show-DHCPMenu
}


Function Show-GetDHCPClientMenu
{
    Get-DhcpClient
    Show-DHCPMenu
}


Function Show-GetDHCPScope
{
    Get-DhcpScope 
    Show-DHCPMenu
}

