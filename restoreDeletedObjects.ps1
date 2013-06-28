Param(
  [parameter(Mandatory=$true)]
  [string]$saAMAccountName,
  [parameter(Mandatory=$true)]
  [string]$server
)

function Reanimate-Object()
{
 Param
 (
	 [Parameter(Mandatory=$true)]
	 [String] $Dn,
	 
	 [Parameter(Mandatory=$true)]
	 [String] $NewDn,
	 
	 [Parameter(Mandatory=$true)]
	 [String] $LdapServer,
	 
	 [Int] $LdapPort = 389
	 )
	 
	try
	{
		# Delete the attribute isDeleted
		$LdapAttrIsDeleted = New-Object -TypeName System.DirectoryServices.Protocols.DirectoryAttributeModification
		$LdapAttrIsDeleted.Name = "isdeleted"
		$LdapAttrIsDeleted.Operation = "Delete"
		 
		# Replace the attribute distinguishedName
		$LdapAttrDn = New-Object -TypeName System.DirectoryServices.Protocols.DirectoryAttributeModification
		$LdapAttrDn.Name ="distinguishedname"
		$LdapAttrDn.Add($NewDn) | Out-Null
		$LdapAttrDn.Operation = "Replace"
		 
		# Create modify request
	    $LdapModifyRequest = New-Object -TypeName System.DirectoryServices.Protocols.ModifyRequest($Dn,@($LdapAttrIsDeleted,$LdapAttrDn))
		$LdapModifyRequest.Controls.Add((New-Object System.DirectoryServices.Protocols.ShowDeletedControl)) | Out-Null
		 
		# Establish connection to Active Directory
		$LdapConnection = new-object System.DirectoryServices.Protocols.LdapConnection(new-object System.DirectoryServices.Protocols.LdapDirectoryIdentifier($LdapServer))
		 
		# Send modify request
		[System.DirectoryServices.Protocols.DirectoryResponse]$modifyResponse = $ldapConnection.SendRequest($ldapModifyRequest)
		 
		# Return result
		if ( $modifyResponse.ResultCode -eq "Success" )
		{
		 exit 0
		}
		else
		{
		 throw "$($modifyResponse.ErrorMessage)"
		}
	}
	catch
	{
		throw "$($_.Exception.Message)"
	}
}

# Load Active Directory Module for Windows PowerShell
Import-Module ActiveDirectory
 
# Load assemblies
[System.Reflection.assembly]::LoadWithPartialName("system.directoryservices") | Out-Null
[System.Reflection.assembly]::LoadWithPartialName("system.directoryservices.protocols") | Out-Null
 
# Find the deleted object
$ADObject = Get-ADObject -Filter {sAMAccountName -eq $saAMAccountName}.GetNewClosure() -Server $server -IncludeDeletedObjects -Properties lastknownParent
 
# Define regular expression to capture CN attribute
[regex] $RegexDnTombstones = "(?<CN>CN=.*)\\0ADEL.*"
 
# Define new distinguishedName attribute based on captured CN attribute and lastKnownParent attribute
$NewDn = (($RegexDnTombstones.Match($ADObject.distinguishedName)).Groups["CN"].value)+","+($ADObject.lastKnownParent)
 
# Call reanimate function
Reanimate-Object $ADObject.distinguishedName $NewDn $server