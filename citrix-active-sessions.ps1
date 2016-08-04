#########################
# Variables
#########################

#Stratis Tenant Information
$appserver = 'demoapps.firescope.com'
$edge = ''
$account = ''

#Stratis Credentials
$user = ''
$pass = ''
$Headers = @{ Authorization = "Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$pass)))}

#uri's
$CitrixUrl = 'http://mz-sg-tel-xdc01/Citrix/Monitor/Odata/v1/Data/Sessions?$format=json&$select=LogOnDuration,ConnectionState,SessionKey,StartDate,EndDate,User/Id,User/UserName&$expand=User'
$CitrixSessionInfo = Invoke-RestMethod -uri $CitrixUrl -Method GET -UseDefaultCredentials
#$CitrixSessionInfo.value

$StratisUrl = "http://"+$appserver+":38050/web_services/ci?&account="+$account+"&edge_device="+$edge+"&name="+$ciName
$Time_Stamp = [int][double]::Parse((Get-Date (get-date).touniversaltime() -UFormat %s))

#########################
# Functions
#########################

function CIExists($SessionKey)
{
    # This function calls Stratis to see if the CI already exists.
    # Returns True if it does False if it doesn't. If the CI Exists,
    # also return the monitoring state and the logonduration which are
    # needed for later testing.

    $ThisCI = "http://"+$appserver+":38050/web_services/ci?&account="+$account+"&edge_device="+$edge+"&name="+$SessionKey
    $StratisCIInfo = Invoke-RestMethod -ContentType 'application/json'-uri $ThisCI -Method Get -Headers $Headers
    $StratisCI = $StratisCIInfo.ciname

    # At this point, the Stratis CI can be in three states.
    #
    # 1 - None existant
    # 2 - Exists but has no attrubute data
    # 3 - Fully populated
    # 
    # we need to return different data for each state...

    if ($StratisCI -ne $null)
    {
        # CI Exists
        if ($StratisCIInfo.ci_profile.custom_fields.Length -eq 0)
        {
            # CI Exists but has no attribute data yet. Setting the Logonduration to -1 here is simply a mechanism
            # that allows the calling code to detect this state.
            # write-host $SessionKey 'CI Exists but has no attributes'
            Return $True, $StratisCIInfo.status, -1 , $StratisCIInfo.ci_bp
        }
        else
        {
            # CI Exists and has attribute data so pass the actual Logonduration back to the calling code.
            write-host $SessionKey 'CI Exists and has attributes'

            # Find the LogOnDuration
            foreach ($CustomField in $StratisCIInfo.ci_profile.custom_fields)
            {
                if ($CustomField.Name -eq 'LogOnDuration')
                {
                    $ThisLogOnDuration = $CustomField.Value
                }
            }

            Return $True, $StratisCIInfo.status, $ThisLogOnDuration, $StratisCIInfo.ci_bp
        }
    }
    else
    {
        # CI Does not Exist
        write-host $SessionKey 'CI Does not Exist'
        Return $False, 0, 0, ""
    }
}


function SetLogonDuration($SessionKey)
{
 $body = "{ 'account_id':'$account',
            'edge_device_id':'$edge',
            'sn': 0,
            'attribute_result':[ {'aid': { 'ci' : '$SessionKey','attribute': 'LogOnDuration'},'lv': '$LogOnDuration' ,'lc':$Time_Stamp, 'ere': 0,'pt': 0,'rt': 0}]
            }"


    $url = "http://"+$appserver+":38050/web_services/attribute_results"
    Invoke-RestMethod -uri $url -Method Post -Body $body -Headers $Headers -ContentType "application/json"
}

function SetLogoffInfon($SessionKey)
{
 $body = "{ 'account_id':'$account',
            'edge_device_id':'$edge',
            'sn': 0,
            'attribute_result':[ {'aid': { 'ci' : '$SessionKey','attribute': 'LogOffTime'},'lv': '$Enddate' ,'lc':1470103682, 'ere': 0,'pt': 0,'rt': 0}]
            }"


    $url = "http://"+$appserver+":38050/web_services/attribute_results"
    Invoke-RestMethod -uri $url -Method Post -Body $body -Headers $Headers -ContentType "application/json"
}

function CreateCI($SessionKey)
{
    $body = "{ 'account_id' : '$account',
               'edge_device_id' : '$edge',
               'ciname' : '$SessionKey',
               'ip' : '127.0.0.1',
               'port' : '8042',
               'status' : '$StratisCIState',
               'useip' : '1',
               'ci_profile' : {'devicetype' : 'Server'}
             }"
        
    $url = "http://"+$appserver+":38050/web_services/ci"
    Invoke-RestMethod -uri $url -Method Post -Body $body -Headers $Headers -ContentType "application/json"

    write-host "Stratis - CI " $SessionKey " Created & is State Enabled? 0-on, 1-off " $Enabled
}

function ApplyBP($SessionKey)
{
$body = "{ 'account_id' : '$account',
           'blueprint_id' : 'CitrixDDA',
           'blueprint_type' : '0',
           'sync_type' : '0',
           'instance_id' : [{ 'edge_device' : '$edge' , 'ci' : '$SessionKey' }]
          }"

$url = "http://"+$appserver+":38050/web_services/bp_sync_job"
Invoke-RestMethod -uri $url -Method Post -Body $body -Headers $Headers -ContentType "application/json"

write-host "Stratis - Applied BP"

}

function DisableCI($SessionKey)
{
    $body = "{ 'account_id' : '$account',
               'edge_device_id' : '$edge',
               'ciname' : '$SessionKey',
               'ip' : '127.0.0.1',
               'port' : '8042',
               'status' : '1',
               'useip' : '1',
               'ci_profile' : {'devicetype' : 'Server'}
             }"
        
    $url = "http://"+$appserver+":38050/web_services/ci"
    Invoke-RestMethod -uri $url -Method Post -Body $body -Headers $Headers -ContentType "application/json"

    write-host "Stratis - CI " $SessionKey " Created & is State Enabled? 0-on, 1-off " $Enabled
}

function DDAUserID($SessionKey)
{
$body = "{ 'account_id':'$account',
            'edge_device_id':'$edge',
            'sn': 0,
            'attribute_result':[ {'aid': { 'ci' : '$SessionKey','attribute': 'Citrix User ID'},'lv': '$UserID' ,'lc':$Time_Stamp, 'ere': 0,'pt': 0,'rt': 0}]
            }"


    $url = "http://"+$appserver+":38050/web_services/attribute_results"
    Invoke-RestMethod -uri $url -Method Post -Body $body -Headers $Headers -ContentType "application/json"
}

function DDAUserName($SessionKey)
{
$body = "{ 'account_id':'$account',
            'edge_device_id':'$edge',
            'sn': 0,
            'attribute_result':[ {'aid': { 'ci' : '$SessionKey','attribute': 'Citrix User Name'},'lv': '$UserName' ,'lc':$Time_Stamp, 'ere': 0,'pt': 0,'rt': 0}]
            }"


    $url = "http://"+$appserver+":38050/web_services/attribute_results"
    Invoke-RestMethod -uri $url -Method Post -Body $body -Headers $Headers -ContentType "application/json"
}

function DDALogOnDuration($SessionKey)
{
$body = "{ 'account_id':'$account',
            'edge_device_id':'$edge',
            'sn': 0,
            'attribute_result':[ {'aid': { 'ci' : '$SessionKey','attribute': 'LogOnDuration'},'lv': '$LogOnDuration' ,'lc':$Time_Stamp, 'ere': 0,'pt': 0,'rt': 0}]
            }"


    $url = "http://"+$appserver+":38050/web_services/attribute_results"
    Invoke-RestMethod -uri $url -Method Post -Body $body -Headers $Headers -ContentType "application/json"
}


#########################
# Main Code
#########################

foreach ($Session in $CitrixSessionInfo.Value)
{
	$UserID = $Session.User.Id                       #MetaData & Attribute
	$UserName = $Session.User.UserName               #MetaData & Attribute
	$SessionKey = $Session.SessionKey                #CI
	$LogOnDuration = $Session.LogOnDuration          #Attribute
    $StartDate = $Session.StartDate                  #Attribute
    $EndDate = $Session.EndDate                      #Attribute
    $ConnectionState = $Session.ConnectionState      #sync with enabled/disabled

    #ConnectionState Values
    #0 = Unknown (placeholder - do not use)
    #1 = Connected
    #2 = Disconnected
    #3 = Terminated
    #4 = Preparing
    #5 = Active
    #6 = Reconnecting
    #7 = Non-brokered session
    #8 = Other
    #9 = Pending

    # Does CI Already Exist in Stratis? 
    $ReturnValues = CIExists($SessionKey)
    $StratisCIExists = $ReturnValues[0]
    $StratisCIState = $ReturnValues[1]
    $StratisCILogOnDuration = $ReturnValues[2]
    $StratisCIBluePrint = $ReturnValues[3]
    
    #If statement to say connection state is active, create session ID as CI via 
    If ($ConnectionState -eq 5)
    {
        # We have an active session. 
        # Create a Stratis CI if it doesnt already exist and populate the basic CI data
        
        write-host "Active Sessions --" $UserID, $UserName, $SessionKey, $LogOnDuration, $ConnectionState, $StratisCIState

        # Does CI Already Exist in Stratis?
        if (-not($StratisCIExists))
        {
            # No it doesn't so create it
            CreateCI $SessionKey $Enabled
            # And apply the blueprint
            ApplyBP($SessionKey)
        }
        else
        {
            # CI Exists, but we may not have written the attrubute data yet. This could not be written while creating the CI as
            # Stratis seems to take a while to attach the BluePrint. Therefore we need to do this the second time we see this session.
            if ($StratisCILogOnDuration -eq -1)
            {
                # Additional sanity check. Ensure the CI has a blueprint with the correct name, this would imply that the blueprint
                # Linking process has completed and we can now write the attributes.
                if ($StratisCIBluePrint -eq 'CitrixDDA')
                {
                    # Before we write the attribute data, ensure the LogonDuration received from Citrix is not null as it seems
                    # Admin session do not set this value.
                    if ($LogOnDuration -eq $null)
                    {
                        # Null Duration found. Zero it so it doesn't break our code the next time we read the CI
                        $LogOnDuration = 0
                    }

                    # This CI was created but has no attribute data so write it now.
                    DDAUserID $SessionKey $UserId
                    DDAUserName $SessionKey $UserName
                    DDALogOnDuration $SessionKey $LogOnDuration
                }
            }
            else
            {
                # It seems that Citrix can take a while to populate the LogOnDuration so it is possible
                # that we might see the session as active and create the CI before this data is available, so
                # test if it is now set and the CI isn't and set the CI if necessary
                if (($LogonDuration -gt 0) -and ($StratisCILogOnDuration -eq 0))
                {
                    DDALogOnDuration $SessionKey $LogOnDuration
                    write-host 'Stratis - Updated LogOnDuration'
                }
            }
        }
    }
    elseif ($ConnectionState -eq 3) 
    {
        # We have an inactive session. 
        write-host "InActive Sessions --" $UserID, $UserName, $SessionKey, $LogOnDuration, $ConnectionState, $StratisCIState
        $StratisCIState = 1
		# It is possible that the session has come and gone since the last time we updated Stratis
		# so check for the existance of the CI and create it if it doens't exist.
		if (-not($StratisCIExists))
		{
			# This IS a previously unseen session so create a 
            CreateCI $SessionKey $StratisCIState
            ApplyBP($SessionKey)
            # Applying the blueprint seems to takes some time, but we have no choice but to wait here. Allow 30 Seconds for Stratis.
            Start-Sleep 30
            DDAUserID $SessionKey
            DDAUserName $SessionKey
            DDALogOnDuration $SessionKey
			
			# And set the CI Variables so the following code closes down this CI
			#$StratisCIState = 0
		}
       else
        {
            # and there is a chance that the session ended after we created the CI but before we wrote the attributes, so we need
            # to test for that and write the attributes
            if ($StratisCILogOnDuration -eq -1)
            {
            CreateCI $SessionKey $StratisCIState
            ApplyBP($SessionKey)
            DDAUserID $SessionKey $UserId
            DDAUserName $SessionKey $UserName
            DDALogOnDuration $SessionKey $LogOnDuration
            }
        }
    
		# Update Stratis if the CI is still active
        if ($StratisCIState -eq 0)
        {
           # Update Stratis CI with Logoff data
            DisableCI $SessionKey
            #SetLogoffInfo $SessionKey $EndDate
            write-host 'Stratis - Made CI Inactive'
        }
    }
}
