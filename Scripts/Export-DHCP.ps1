$now = ([System.DateTime]::Now).ToString("yyyy'-'MM'-'dd HH'.'mm'.'ss'Z'")
Function Export-Server($server)
{
 mkdir -force C:\SATS\Data\DHCP\$now
 export-dhcpserver -leases -computername blah -file "C:\SATS\Data\DHCP\$now\$server.xml"
}
Export-Server blah.adtest.bcc.ac.uk
Export-Server blah.adtest.bcc.ac.uk

