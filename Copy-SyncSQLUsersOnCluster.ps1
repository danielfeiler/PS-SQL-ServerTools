<#
.SYNOPSIS
Keep SQL server logins in sync
.DESCRIPTION
Checking all nodes in a availability group if all SQL server logins exists. If not it copies all sql server logins to the other servers with the same password hash and same sid
.PARAMETER DomainFQDN
FQDN of the domain e.g. mydomain.local
.PARAMETER SQLAGName
The name of the sql availability group e.g. FIRSTAG01
.PARAMETER RunDirectOnSQLServer
indicates if the script is executed on a SQL Server who is member of the failover cluster of the availability group. If is set to true the SQL server logins will only by syncronized if teh server is the PRIMARY server of the availability group.
But anyway it will sync the sql server logins betwean all servers of this availability group
.NOTES
Created by Daniel Feiler0 2017-12-21
.EXAMPLE
.\Copy-SyncSQLUsersOnCluster -DomainFQDN "mydomain.local" -SQLAGName "FIRSTAG01" -RunDirectOnSQLServer:$true
.EXAMPLE
.\Copy-SyncSQLUsersOnCluster -DomainFQDN "mydomain.local" -SQLAGName "FIRSTAG01" -RunDirectOnSQLServer:$false
#>
#Requires -Version 5.0
#>
param(
[parameter(Mandatory=$true)]
[string] $DomainFQDN,
[parameter(Mandatory=$true)]
[string]$SQLAGName,
[parameter(Mandatory=$false)]
[switch]$RunDirectOnSQLServer=$false
)
[string] $Database = "master"

#SQL Query to get all SQL userlogins excepting windows based and disabled logins
<#
[string]$SQLUserToCopyQuery= $("SELECT sp.[name] AS [UserName], N'0x'+
       CONVERT(nvarchar(max), l.password_hash, 2) AS [UserPasswordHash],
       N'0x'+CONVERT(nvarchar(max), sp.[sid], 2) AS [UserSID]
FROM master.sys.server_principals AS sp
INNER JOIN master.sys.sql_logins AS l ON sp.[sid]=l.[sid]
WHERE sp.[type]='S' AND sp.is_disabled=0 AND sp.[sid] != 1;" )
#SQL Query to get all SQL userlogins including disabled excepting windows based logins
[string]$SQLUserToCompareQuery= $("SELECT sp.[name] AS [UserName], N'0x'+
       CONVERT(nvarchar(max), l.password_hash, 2) AS [UserPasswordHash],
       N'0x'+CONVERT(nvarchar(max), sp.[sid], 2) AS [UserSID]
FROM master.sys.server_principals AS sp
INNER JOIN master.sys.sql_logins AS l ON sp.[sid]=l.[sid]
WHERE sp.[type]='S' AND sp.[sid] != 1;" )
#>
[string]$SQLUserToCopyQuery= $("SELECT sp.[name] AS [UserName], N'0x'+
       CONVERT(nvarchar(max), l.password_hash, 2) AS [UserPasswordHash],
       N'0x'+CONVERT(nvarchar(max), sp.[sid], 2) AS [UserSID], sp.is_disabled,sp.[type],
	   l.modify_date as [login_modify_date],sp.modify_date as [principal_modify_date], LOGINPROPERTY(sp.[name], 'PasswordLastSetTime') AS PasswordLastSetTime
FROM master.sys.server_principals AS sp
left JOIN master.sys.sql_logins AS l ON sp.sid=l.sid
WHERE sp.[sid] != 1 and sp.type in('U','S','G');")

[string]$SQLUserToCompareQuery= $("SELECT sp.[name] AS [UserName], N'0x'+
       CONVERT(nvarchar(max), l.password_hash, 2) AS [UserPasswordHash],
       N'0x'+CONVERT(nvarchar(max), sp.[sid], 2) AS [UserSID], sp.is_disabled,sp.[type],
	   l.modify_date as [login_modify_date],sp.modify_date as [principal_modify_date], LOGINPROPERTY(sp.[name], 'PasswordLastSetTime') AS PasswordLastSetTime
FROM master.sys.server_principals AS sp
left JOIN master.sys.sql_logins AS l ON sp.sid=l.sid
WHERE sp.[sid] != 1 and sp.type in('U','S','G');")

# SQL Query to get all servers who are involved in the given availability group
[string]$ServersSQLQuery=$("IF SERVERPROPERTY ('IsHadrEnabled') = 1
BEGIN
SELECT
   AGC.name -- Availability Group
 , RCS.replica_server_name -- SQL cluster node name
 ,case
	when (CHARINDEX(N'\',RCS.replica_server_name) > 0) THEN
	 LEFT(RCS.replica_server_name,CHARINDEX(N'\',RCS.replica_server_name)-1)   -- SQL cluster node name-1
	 ELSE
	 RCS.replica_server_name
	 END AS hostname
,CASE
	WHEN (CHARINDEX(N'\',RCS.replica_server_name) > 0) THEN
		 RIGHT(RCS.replica_server_name,(LEN(RCS.replica_server_name)-CHARINDEX(N'\',RCS.replica_server_name))) 
	ELSE
		NULL
	END AS instancename
 ,ARS.role
 , ARS.role_desc  -- Replica Role
 , AGL.dns_name  -- Listener Name
FROM
 sys.availability_groups_cluster AS AGC
  INNER JOIN sys.dm_hadr_availability_replica_cluster_states AS RCS
   ON
    RCS.group_id = AGC.group_id
  INNER JOIN sys.dm_hadr_availability_replica_states AS ARS
   ON
    ARS.replica_id = RCS.replica_id
  INNER JOIN sys.availability_group_listeners AS AGL
   ON
    AGL.group_id = ARS.group_id
WHERE
 --ARS.role_desc = 'PRIMARY'
 AGC.name = '"+$SQLAGName+"'
END")

function Get-ScriptNameOnly {
    $ScriptName=$(Split-Path $PSCommandPath -Leaf)
    [string]$newScriptName=$null
    if(($ScriptName.LastIndexOf(".") -ne -1) -and ($ScriptName.LastIndexOf(".") -gt 0)) {
        $newScriptName=$($ScriptName.Substring(0, ($ScriptName.LastIndexOf(".") )))
    } else {
        $newScriptName = $ScriptName
    }
    return $newScriptName
}

function Get-SQLServerFullName {
param(
    [parameter(Mandatory=$true)]
    [System.Data.DataRow]$SQLServerDataRow,
    [parameter(Mandatory=$true)]
    [string]$DomainFQDN,
    [parameter(Mandatory=$false)]
    [string]$HostColumnName="hostname",
    [parameter(Mandatory=$false)]
    [string]$InstanceColumnName="instancename",
    [parameter(Mandatory=$true)]
    [bool]$RunOnSqlServer=$true
)
            $SQLServerHostName=$SQLServerDataRow[$HostColumnName]
            $SQLServerInstanceName=$SQLServerDataRow[$InstanceColumnName]
            
                
            if($SQLServerInstanceName -ne ([System.DBNull]::Value))
            {
                if($RunOnSqlServer) {
                    $SQLServerFullName=$SQLServerHostName+"\"+$SQLServerInstanceName
                }
                else
                {
                    $SQLServerFullName=$SQLServerHostName+"."+$DomainFQDN+"\"+$SQLServerInstanceName
                }
            }
            else
            {
                if($RunOnSqlServer) {
                    $SQLServerFullName=$SQLServerHostName
                }
                else
                {
                    $SQLServerFullName=$SQLServerHostName+"."+$DomainFQDN
                }
            }
    return $SQLServerFullName
}

# executes a SQL query and returns a System.Data.DataTable object
function ExecuteSqlQuery ($Server, $Database, $SQLQuery) {
    $ScriptNameOnly=get-ScriptNameOnly
     if( -not ([System.Diagnostics.EventLog]::SourceExists($ScriptNameOnly))) {
            New-EventLog -Source $ScriptNameOnly -LogName Application
     }
    #$SQLQuerySuccessful=$false
    $Datatable = New-Object System.Data.DataTable
    $Connection = New-Object System.Data.SQLClient.SQLConnection
    $Connection.ConnectionString = "server='$Server';database='$Database';trusted_connection=true;"
    try {
    $Connection.Open()
    } catch {
        $EventMsg=$("Could not connect to database "+$Database+" on Server: "+$Server+"`r`n"+$Error[0].FullyQualifiedErrorId+"`r`nError source: "+$Error[0].Exception.InnerException.Source+"`r`nError number: "`
        +$Error[0].Exception.InnerException.Number+"`r`n"+$Error[0].Exception.InnerException.Message+"`r`nServer: "+$Error[0].Exception.InnerException.Server+"`r`n`r`n"`
        +"If the specified Servernode is in faild state or offline because of maintenance, this event is expected and can be ignored.")
        Write-EventLog -LogName Application -Source $ScriptNameOnly -EventId 2101 -EntryType Warning -Message $EventMsg -Category 0
        if(($Connection.State)) 
        {
            $Connection.Close()
        }
    }
    if(($Connection.State)) 
    {
        $Command = New-Object System.Data.SQLClient.SQLCommand
        $Command.Connection = $Connection
        $Command.CommandText = $SQLQuery
        try 
        {
            $Reader = $Command.ExecuteReader()
     
        }
        catch
        {
            $EventMsg=$("Could not execute SQL-Query: `r`n"+$Error[0].Exception)
            Write-EventLog -LogName Application -Source $ScriptNameOnly -EventId 2102 -EntryType Warning -Message $EventMsg -Category 0
        }
        if(-not ($Reader.IsClosed)) 
        {
            $Datatable.Load($Reader)
        }
        $Connection.Close()
    }
    #if not place a , in fron the of the DataTable to return, Powershell convert the DataTable to a System.Arry containing DataRow Objects. If this happens you could not use any of the DataTable specific methods or properties 
    return ,[System.Data.DataTable]$Datatable
}

function ExecuteSqlNonQuery ($Server, $Database, $SQLQuery) {
    [int32]$RowsAffected=0
    $ScriptNameOnly=get-ScriptNameOnly
     if( -not ([System.Diagnostics.EventLog]::SourceExists($ScriptNameOnly))) {
            New-EventLog -Source $ScriptNameOnly -LogName Application
     }
    $Datatable = New-Object System.Data.DataTable
    $Connection = New-Object System.Data.SQLClient.SQLConnection
    $Connection.ConnectionString = "server='$Server';database='$Database';trusted_connection=true;"
    try
    {
        $Connection.Open()
    }
    catch
    {
        $EventMsg=$("Could not connect to database "+$Database+" on Server: "+$Server+"`r`n"+$Error[0].FullyQualifiedErrorId+"`r`nError source: "+$Error[0].Exception.InnerException.Source+"`r`nError number: "`
        +$Error[0].Exception.InnerException.Number+"`r`n"+$Error[0].Exception.InnerException.Message+"`r`nServer: "+$Error[0].Exception.InnerException.Server+"`r`n`r`n"`
        +"If the specified Servernode is in faild state or offline because of maintenance, this event is expected and can be ignored.")
        Write-EventLog -LogName Application -Source $ScriptNameOnly -EventId 2101 -EntryType Warning -Message $EventMsg -Category 0
    }
    if(($Connection.State)) 
    {
        $Command = New-Object System.Data.SQLClient.SQLCommand
        $Command.Connection = $Connection
        $Command.CommandText = $SQLQuery
        try
        {
            $RowsAffected = $Command.ExecuteNonQuery()
        }
        catch
        {
            $EventMsg=$("Could not execute SQL-Query: `r`n"+$Error[0].Exception)
            Write-EventLog -LogName Application -Source $ScriptNameOnly -EventId 2103 -EntryType Warning -Message $EventMsg -Category 0
        }
        $Connection.Close()
    }    
    return $RowsAffected
}

#get the scriptname and check if the eventlog source entry exist, if not create the event log source entry
    $ScriptNameOnly=get-ScriptNameOnly
     if( -not ([System.Diagnostics.EventLog]::SourceExists($ScriptNameOnly))) {
            New-EventLog -Source $ScriptNameOnly -LogName Application
     }

[bool]$isPrimary=$false
[string]$localServerName=$($env:computername).ToUpper()
# declaration not necessary, but good practice
$ServerResultTable=New-Object System.Data.DataTable
$UserResultsDataTable = New-Object System.Data.DataTable
$TmpUserResultsDataTable = New-Object System.Data.DataTable
# Query all server involved in availability group
if($RunDirectOnSQLServer)
{
    $ServerResultTable=[System.Data.DataTable]$(ExecuteSqlQuery $($SQLAGName) $Database $ServersSQLQuery)
}
else
{
    $ServerResultTable=[System.Data.DataTable]$(ExecuteSqlQuery $($SQLAGName+"."+$DomainFQDN) $Database $ServersSQLQuery)
}
#Check if flag RunDirectOnSQLServer is set to True
if($ServerResultTable.rows.count -gt 0)
{
    if($RunDirectOnSQLServer) {
        #if script run direct on sql-server chek if the current server is involved in availability group
        if($ServerResultTable.hostname.Contains($localServerName)) {
            #Chek if current server is the PRIMARY Server of the availability group
            if($($ServerResultTable.role_desc[$ServerResultTable.hostname.IndexOf($localServerName)]) -eq "PRIMARY") {
                #Set the isPrimary falg to True
                 $isPrimary=$true
            }
            else
            {
                #Set the isPrimary falg to False
                 $isPrimary=$false
            }
        }
    }
    #Check if the RunDirectOnSQLServer flag and the isPrimary flag both set to True
    if(($RunDirectOnSQLServer -and $isPrimary))
    {
        $DoSQLUserSync=$true
    }
    #if at least one of the flags isPrimary or RunDirectOnSQLServer is set to False, check if flag RunDirectOnSQLServer is set to False.
    elseif( -not ($RunDirectOnSQLServer))
    {
        $DoSQLUserSync=$true
    }
    else
    {
        $DoSQLUserSync=$false
    }
    #check if flag DoSQLUserSync is set to True
    if($DoSQLUserSync)
    {
#region initialize SyncUsersDatatable in memory
        $SyncUserDatatable = New-Object System.Data.DataTable
        $UserIdColumn=$SyncUserDatatable.Columns.Add("UserID",[int32])
        $UserIdColumn.AutoIncrement=$true
        $UserIdColumn.AutoIncrementSeed=1
        $UserIdColumn.AutoIncrementStep=1
        $SourceServerColumn=$SyncUserDatatable.Columns.Add("SourceServer",[string]) 
        $TargetServerColumn=$SyncUserDatatable.Columns.Add("TargetServer",[string])
        $UserNameColumn=$SyncUserDatatable.Columns.Add("UserName",[string])
#endregion initialize SyncUsersDatatable in memory

        $EventMsg=$("Start User Sync for availability group: "+$SQLAGName)
        Write-EventLog -LogName Application -Source $ScriptNameOnly -EventId 2030 -EntryType Information -Message $EventMsg -Category 0
        #Loop through all servers in availability group
        foreach($SQLServer in $ServerResultTable)
        {
            # query all enabled sql users from current server
            $SQLServerFullName=Get-SQLServerFullName -SQLServerDataRow $SQLServer -DomainFQDN $DomainFQDN -RunOnSqlServer $RunDirectOnSQLServer
            $UserResultsDataTable = [System.Data.DataTable]$(ExecuteSqlQuery $($SQLServerFullName) $Database $SQLUserToCopyQuery)
            #Loop through all servers in availability group
            foreach($SQLServerToCheck in $ServerResultTable) 
            {
            $SQLServerToCheckFullName=Get-SQLServerFullName -SQLServerDataRow $SQLServerToCheck -DomainFQDN $DomainFQDN -RunOnSqlServer $RunDirectOnSQLServer
                #Check if the current server is not the server to check
                if ($($SQLServer.replica_server_name) -ne $($SQLServerToCheck.replica_server_name))
                {
                    #get all users from the server to verify if all users exists
                    $TmpUserResultsDataTable = [System.Data.DataTable]$(ExecuteSqlQuery $($SQLServerToCheckFullName) $Database $SQLUserToCompareQuery)
                    #Chek if there are users in the table to verify
                    if($TmpUserResultsDataTable.Rows.Count -gt 0)
                    {
                        foreach($SQLUserLogin in $UserResultsDataTable) 
                        {
                            #Check if the user from the source server do not exist on target server
                            if(-not ($TmpUserResultsDataTable.UserName.Contains($SQLUserLogin.UserName)))
                            {
                                #if the user do not exist on target server, create the SQL CREATE LOGIN query
                                if($SQLUserLogin.type -eq 'S') {
                                    [string]$SQLUserLoginCreateSQL="CREATE LOGIN ["+$($SQLUserLogin.UserName)+"] WITH PASSWORD="+$($SQLUserLogin.UserPasswordHash)+" HASHED, CHECK_POLICY=OFF, SID="+$($SQLUserLogin.UserSID)+";"
                                }
                                elseif(($SQLUserLogin.type -eq 'U') -or ($SQLUserLogin.type -eq 'G'))
                                {
                                    [string]$SQLUserLoginCreateSQL="CREATE LOGIN ["+$($SQLUserLogin.UserName)+"] FROM WINDOWS;"
                                }
                                #Execute the CREATE LOGIN Query
                                $RowsAffected=ExecuteSqlNonQuery $($SQLServerToCheckFullName) $Database $SQLUserLoginCreateSQL
                                if($RowsAffected -ne 0) 
                                {
                                   $UserSyncRow=$SyncUserDatatable.NewRow()
                                   $UserSyncRow["SourceServer"]=$($SQLServer.replica_server_name)
                                   $UserSyncRow["TargetServer"]=$($SQLServerToCheck.replica_server_name)
                                   $UserSyncRow["UserName"]=$($SQLUserLogin.UserName)
                                   $SyncUserDatatable.Rows.Add($UserSyncRow)
                                }
                            }

                        }
                    }
                }
            }
        }
        if(($SyncUserDatatable.Rows.Count) -gt 0) 
        {
            $EventMsg=$("The following users are synced successfully:`r`n")
            $eventMsgUsers="Source Server            Target Server            User Name`r`n"
            foreach($SyncRow in $SyncUserDatatable.Rows)
            {
                $eventMsgUsers=$eventMsgUsers+$($SyncRow["SourceServer"])+"            "+$($SyncRow["TargetServer"])+"            "+$($SyncRow["UserName"])+"`r`n"
            }
            $EventMsg=$EventMsg+$eventMsgUsers
            Write-EventLog -LogName Application -Source $ScriptNameOnly -EventId 2000 -EntryType Information -Message $EventMsg -Category 0
        }
        else
        {
            $EventMsg=$("No Users must be synced for availability group: "+$SQLAGName)
            Write-EventLog -LogName Application -Source $ScriptNameOnly -EventId 2001 -EntryType Information -Message $EventMsg -Category 0
        }
        $EventMsg=$("End User Sync")
        Write-EventLog -LogName Application -Source $ScriptNameOnly -EventId 2060 -EntryType Information -Message $EventMsg -Category 0
    }
}
else
{
	$EventMsg=$("Could not connect to availability group: "+$SQLAGName+"`r`n With FQDN: "+$($SQLAGName+"."+$DomainFQDN))
    Write-EventLog -LogName Application -Source $ScriptNameOnly -EventId 2199 -EntryType Error -Message $EventMsg -Category 0

}