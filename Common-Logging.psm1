# Common-Logging.psm1
# PowerShell Module for Structured Logging
# Provides consistent logging across ADO to GitHub migration scripts

# Module variables for configuration
$script:LogFilePath = $null
$script:LogLevel = "INFO"
$script:EnableConsoleOutput = $true
$script:EnableFileLogging = $false

# Log level hierarchy
$script:LogLevels = @{
    "DEBUG" = 0
    "INFO"  = 1
    "WARN"  = 2
    "ERROR" = 3
}

# Color mapping for console output
$script:LogColors = @{
    "DEBUG" = "Gray"
    "INFO"  = "White"
    "WARN"  = "Yellow"
    "ERROR" = "Red"
}

<#
.SYNOPSIS
    Initializes the logging module with configuration options.

.DESCRIPTION
    Sets up the logging module with the specified configuration including log file path,
    minimum log level, and output options.

.PARAMETER LogFilePath
    Optional path to the log file. If not specified, only console logging will be used.

.PARAMETER MinimumLogLevel
    Minimum log level to output. Valid values: DEBUG, INFO, WARN, ERROR. Default is INFO.

.PARAMETER EnableConsole
    Whether to enable console output. Default is $true.

.EXAMPLE
    Initialize-Logging -LogFilePath "C:\Logs\migration.log" -MinimumLogLevel "INFO"
#>
function Initialize-Logging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$LogFilePath,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
        [string]$MinimumLogLevel = "INFO",
        
        [Parameter(Mandatory = $false)]
        [bool]$EnableConsole = $true
    )
    
    $script:LogLevel = $MinimumLogLevel
    $script:EnableConsoleOutput = $EnableConsole
    
    if ($LogFilePath) {
        $script:LogFilePath = $LogFilePath
        $script:EnableFileLogging = $true
        
        # Ensure log directory exists
        $logDir = Split-Path -Parent $LogFilePath
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        
        # Write initialization entry
        Write-Log "INFO" "Logging initialized. File: $LogFilePath, Level: $MinimumLogLevel"
    } else {
        $script:EnableFileLogging = $false
        Write-Log "INFO" "Console logging initialized. Level: $MinimumLogLevel"
    }
}

<#
.SYNOPSIS
    Core logging function that handles structured log output.

.DESCRIPTION
    Internal function that formats and outputs log messages to console and/or file
    based on the current configuration.

.PARAMETER Level
    Log level (DEBUG, INFO, WARN, ERROR)

.PARAMETER Message
    The log message content

.PARAMETER Source
    Optional source identifier (function name, script name, etc.)
#>
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
        [string]$Level,
        
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$Source
    )
    
    # Check if this log level should be output
    if ($script:LogLevels[$Level] -lt $script:LogLevels[$script:LogLevel]) {
        return
    }
    
    # Format timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    
    # Format source if provided
    $sourceText = if ($Source) { " [$Source]" } else { "" }
    
    # Create formatted log entry
    $logEntry = "[$timestamp] [$Level]$sourceText $Message"
    
    # Console output with colors
    if ($script:EnableConsoleOutput) {
        $color = $script:LogColors[$Level]
        Write-Host $logEntry -ForegroundColor $color
    }
    
    # File output
    if ($script:EnableFileLogging -and $script:LogFilePath) {
        try {
            $logEntry | Out-File -FilePath $script:LogFilePath -Append -Encoding UTF8
        }
        catch {
            Write-Warning "Failed to write to log file: $($_.Exception.Message)"
        }
    }
}

<#
.SYNOPSIS
    Writes a DEBUG level log message.
#>
function Write-LogDebug {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$Source
    )
    
    Write-Log -Level "DEBUG" -Message $Message -Source $Source
}

<#
.SYNOPSIS
    Writes an INFO level log message.
#>
function Write-LogInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$Source
    )
    
    Write-Log -Level "INFO" -Message $Message -Source $Source
}

<#
.SYNOPSIS
    Writes a WARN level log message.
#>
function Write-LogWarning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$Source
    )
    
    Write-Log -Level "WARN" -Message $Message -Source $Source
}

<#
.SYNOPSIS
    Writes an ERROR level log message.
#>
function Write-LogError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$Source,
        
        [Parameter(Mandatory = $false)]
        [switch]$TerminateScript
    )
    
    Write-Log -Level "ERROR" -Message $Message -Source $Source
    
    if ($TerminateScript) {
        exit 1
    }
}

<#
.SYNOPSIS
    Writes a progress message with step information.
#>
function Write-LogProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Activity,
        
        [Parameter(Mandatory = $true)]
        [string]$Status,
        
        [Parameter(Mandatory = $false)]
        [int]$PercentComplete = -1,
        
        [Parameter(Mandatory = $false)]
        [string]$Source
    )
    
    $progressMessage = "[$Activity] $Status"
    if ($PercentComplete -ge 0) {
        $progressMessage += " ($PercentComplete% complete)"
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
    }
    
    Write-LogInfo -Message $progressMessage -Source $Source
}

<#
.SYNOPSIS
    Finalizes logging and performs cleanup.
#>
function Close-Logging {
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Logging session ended"
    
    # Clear progress if it was used
    Write-Progress -Activity "Complete" -Completed
}

# Export module functions
Export-ModuleMember -Function @(
    'Initialize-Logging',
    'Write-LogDebug',
    'Write-LogInfo', 
    'Write-LogWarning',
    'Write-LogError',
    'Write-LogProgress',
    'Close-Logging'
) 