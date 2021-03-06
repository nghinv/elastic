<# 
.SYNOPSIS
Quickly deploy or upgrade an Elasticsearch cluster

.DESCRIPTION
- Install plugins
- Deploy ES nodes
- Modify/Migrate ES config

Elasticsearch packages must be stored in the script folder
#>


# Variables contain script attributes
$me = $MyInvocation.MyCommand.Name
$scriptDir = Split-Path -parent $MyInvocation.MyCommand.Definition

# ---------------------- Script Configuration ----------------------

## Script global variables
$action = "RemoveService" # NewCluster UpgradeCluster RemoveService

$esHostID = "1"
$esClusterName = "Test"
$esRootDir = "C:\temp2\root"
$esVersion = "elasticsearch-2.3.3"
$esOldVersion = "elasticsearch-2.3.1" # if configs migrated from previous version
$esPlugins = "license-2.3.3", "marvel-agent-2.3.3"

# Specify the number of nodes
$esNodes = @{
    "M" = 2 # Master nodes
    "D" = 2 # Hot Data nodes
    "DA" = 2 # Warm data nodes
    "C" = 2 # Client Nodes
}

# ---------------------------------------------------------------------------
# ---------------------- DO NOT MODIFY BELOW THIS LINE ----------------------

# ---------------------- SCRIPT IMPLEMENTATION ----------------------

# Install ES plugins

# Generate node names
$esNodeNames = Enumerate-ESNode

## Check and run an action
If ($action -eq "NewCluster") {
    Create-ESNode
    Change-ESServiceName
} ElseIf ($action -eq "UpgradeCluster") {
    Create-ESNode
    Change-ESServiceName
    Copy-ESConfig
    Install-ESService
} ElseIf ($action -eq "RemoveService") {
    Remove-ESService
}

## Functions
Function Install-ESPlugin {
    If (Test-Path "$scriptDir\$esVersion") {
        foreach ($item in $esPlugins) {
            Invoke-Expression "$scriptDir\$esVersion\bin\plugin install file:$scriptDir\$item.zip"
        }
    

    } Else { 
        Write-Host "Please extract Elasticsearch package to script folder." -ForegroundColor Red
        Exit
    }
}

Function Enumerate-ESNode {
    $nodeNameArray = @()
    foreach ($nodeType in $esNodes.GetEnumerator()) {
        # Loop through ES node count >= 1
        If ($nodeType.Value -ge 1) {
            97..$($nodeType.Value + 96) | foreach {
                # Return node name
                $nodeNameArray = $nodeNameArray + "$esClusterName-$($nodeType.Name)$esHostID$([char]$_)"
            }
        }
        
    }
    return $nodeNameArray
}

Function Create-ESNode {
    foreach ($name in $esNodeNames) {
        if (-not (Test-Path "$esRootDir\$esVersion-$name")) {
            Copy-Item -Path "$scriptDir\$esVersion" -Destination "$esRootDir\$esVersion-$name" -Recurse
        }
        
    }
    
}

Function Change-ESServiceName {
    foreach ($name in $esNodeNames) {
        $targetFile = "$esRootDir\$esVersion-$name\bin\service.bat"
        
        # Search and replace default service name
        if (Test-Path $targetFile) {
            (Get-Content $targetFile) | foreach-object {$_ -replace "SERVICE_ID=elasticsearch-service-x64", "SERVICE_ID=$esVersion-$name"} | Set-Content $targetFile
        }
        
    }
    
}

Function Copy-ESConfig {
    foreach ($name in $esNodeNames) {
        $sourceFile = "$esRootDir\$esOldVersion-$name\config\elasticsearch.yml"
        $targetFile = "$esRootDir\$esVersion-$name\config\elasticsearch.yml"
        
        # Search and replace default service name
        if (Test-Path $sourceFile) {
            Copy-Item -Path $sourceFile -Destination $targetFile -Force
        }
        
    }
    
}

Function Install-ESService {
    foreach ($name in $esNodeNames) {
        $esServiceName = "$esVersion-$name"
        
        # If service does not exist, install service
        if (-not (Get-Service $esServiceName -ea SilentlyContinue)) {
            Invoke-Expression "$esRootDir\$esVersion-$name\bin\service.bat install"
            Invoke-Expression "$esRootDir\$esVersion-$name\bin\service.bat manager"
        }
        
    }
    
}

Function Remove-ESService {
    foreach ($name in $esNodeNames) {
        $esServiceName = "$esVersion-$name"
        
        # If service does not exist, install service
        if (Get-Service $esServiceName -ea SilentlyContinue) {
            Invoke-Expression "$esRootDir\$esVersion-$name\bin\service.bat stop"
            Invoke-Expression "$esRootDir\$esVersion-$name\bin\service.bat remove"
        }
        
    }
    
} 
