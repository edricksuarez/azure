<#
.DESCRIPTION
    A runbook which starts or stops VMs based on the specific tags and schedule.

.NOTES
    AUTHOR: Edrick Ronald Suarez
    LASTEDIT: December 11, 2023
#>

#Due to a bug in the implementation of Runbooks in Azure, the parameter names need to be specified in lowercase only. See: "https://github.com/Azure/azure-sdk-for-go/issues/4780" for more information.
param (
    [Parameter(Mandatory=$true)]
    [String]$subscriptionid,

    [Parameter(Mandatory=$true)]
    [String]$tagname,

    [Parameter(Mandatory=$true)]
    [Boolean]$tagvalue
)

try {
    "Logging in to Azure..."
    Connect-AzAccount -Identity
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

# Set Azure Context
Set-AzContext -SubscriptionId $subscriptioniD

$zoneMappings = @{
  "America/Los_Angeles" = "Pacific Standard Time"
  "America/Vancouver" = "Pacific Standard Time"
  "America/Denver" = "Mountain Standard Time"  
  "America/Phoenix" = "US Mountain Standard Time"
  "America/Chicago" = "Central Standard Time"
  "America/New_York" = "Eastern Standard Time"  
  "America/Anchorage" = "Alaskan Standard Time"
  "America/Indianapolis" = "US Eastern Standard Time"

  "Australia/Brisbane" = "E. Australia Standard Time"
  "Australia/Adelaide" = "Cen. Australia Standard Time"
  "Australia/Sydney" = "AUS Eastern Standard Time"
  "Australia/Melbourne" = "AUS Eastern Standard Time"
  "Australia/Perth" = "W. Australia Standard Time"

  "Asia/Tokyo" = "Tokyo Standard Time"
  "Asia/Shanghai" = "China Standard Time"
  "Asia/Kolkata" = "India Standard Time"
  "Asia/Dubai" = "Arabian Standard Time"
  "Asia/Jerusalem" = "Israel Standard Time"

  "Europe/Berlin" = "W. Europe Standard Time"
  "Europe/Madrid" = "Romance Standard Time"
  "Europe/Moscow" = "Russian Standard Time"

  "Africa/Cairo" = "Egypt Standard Time"

  "Pacific/Auckland" = "New Zealand Standard Time"
  "Pacific/Honolulu" = "Hawaiian Standard Time"
  "Europe/London" = "GMT Standard Time"
  "Europe/Paris" = "Romance Standard Time" 
}

# Get VMs with the specified tags
$VMs = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines" -TagName $tagname -TagValue $tagvalue

foreach ($VM in $VMs) {
    # Get VM tags
    $tags = $VM.Tags

    if ($tags -and $tags.ContainsKey('Scheduler') -and $tags['Scheduler'] -eq 'true') {
        $ianaZone = $tags["Timezone"]
        $windowsTZ = $zoneMappings[$ianaZone]  
        $startTime = [DateTime]::ParseExact($tags['StartTime'], 'HH:mm', $null)
        $stopTime = [DateTime]::ParseExact($tags['StopTime'], 'HH:mm', $null)

        if ($tags -and $tags.ContainsKey('Timezone')) {
            $timezone = $tags['Timezone']

            $ianaZone = $tags["Timezone"]   
            $windowsTZ = $zoneMappings[$ianaZone]  

            #$currentTime = [System.DateTime]::Now.ToUniversalTime()
            #$currentTimeInTimeZone = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($currentTime, $timezone)

            #$currentHour = $currentTimeInTimeZone.Hour

            $currentTime = [DateTime]::UtcNow
            $currentTimeInTZ = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($currentTime, $windowsTZ) 
            $currentHour = $currentTimeInTZ.Hour
            $startHour = $startTime.Hour
            $stopHour = $stopTime.Hour
        }

        Write-Output "Current Time in Timezone: $($currentTimeInTZ.ToString('yyyy-MM-dd HH:mm:ss'))"
        Write-Output "Start Time: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))"
        Write-Output "Stop Time: $($stopTime.ToString('yyyy-MM-dd HH:mm:ss'))"

        if ($currentHour -eq $startHour) {
            Write-Output ("Starting " + $VM.Name)
            Start-AzVM -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName
        }
        elseif ($currentHour -eq $stopHour) {
            Write-Output ("Stopping " + $VM.Name)
            Stop-AzVM -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName -Force
        }

        #if ($currentTimeInTimeZone -ge $startTime) {
        #    Write-Output ("Starting " + $VM.Name)
        #    Start-AzVM -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName
        #}
        #elseif ($currentTimeInTimeZone -ge $stopTime) {
        #    Write-Output ("Stopping " + $VM.Name)
        #    Stop-AzVM -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName -Force
        #}
        else {
            Write-Output ("No action needed for " + $VM.Name)
        } 
    }
    else {
        Write-Output ("AutoStartStop is not set to 'true' for " + $VM.Name + ". Skipping VM operations.")
    }
}