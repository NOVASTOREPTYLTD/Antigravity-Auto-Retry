param(
    [int]$IntervalMilliseconds = 100,
    [int]$IntervalSeconds = 0,
    [string]$SignalDir = "",
    [int]$CooldownSeconds = 0,
    [int]$MaxBackoffSeconds = 1,
    [int]$ExitWhenIdeMissingSeconds = 0,
    [string]$AutoSelectPermission = "None",
    [switch]$Once,
    [switch]$DryRun
)

# Auto Retry for Antigravity IDE.
# This script uses Windows UI Automation InvokePattern. It does not move the
# mouse, type keys, or focus the chat panel.

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

# Win32 helpers removed since native retry is used

if ($IntervalSeconds -gt 0) {
    $IntervalMilliseconds = [Math]::Max(100, $IntervalSeconds * 1000)
}

if ($SignalDir -eq "") {
    $SignalDir = $PSScriptRoot
}

$logFile = Join-Path $SignalDir "auto-retry.log"
$root = [System.Windows.Automation.AutomationElement]::RootElement
$children = [System.Windows.Automation.TreeScope]::Children
$descendants = [System.Windows.Automation.TreeScope]::Descendants
$buttonType = [System.Windows.Automation.ControlType]::Button
$windowType = [System.Windows.Automation.ControlType]::Window
$trueCondition = [System.Windows.Automation.Condition]::TrueCondition

$lastRetryTime = [DateTime]::MinValue
$currentBackoffSeconds = 0
$hasSeenIdeWindow = $false
$lastIdeSeenTime = [DateTime]::MinValue



function Write-AutoRetryLog {
    param([string]$Message)

    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message
    Write-Host $line
    try {
        Add-Content -Path $logFile -Value $line -Encoding UTF8
    } catch {
        # Keep running even if logging fails.
    }
}

function Get-AntigravityWindows {
    $windowCondition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        $windowType
    )

    $windows = $root.FindAll($children, $windowCondition)
    $matches = @()

    foreach ($window in $windows) {
        try {
            $name = $window.Current.Name
            if ($name -like "*Antigravity*" -or $name -like "*gym_tracker*") {
                $matches += $window
            }
        } catch {
            # Skip stale UIA elements.
        }
    }

    return $matches
}

function Test-AgentErrorVisible {
    param([System.Windows.Automation.AutomationElement]$Window)

    try {
        $elements = $Window.FindAll($descendants, $trueCondition)
        foreach ($element in $elements) {
            try {
                $name = $element.Current.Name
                if ($name -like "*Agent terminated due to error*" -or
                    $name -like "*servers are experiencing high traffic*" -or
                    $name -like "*You can prompt the model to try again*") {
                    return $true
                }
            } catch {
                # Skip stale UIA elements.
            }
        }
    } catch {
        return $false
    }

    return $false
}

function Get-RetryButtons {
    param([System.Windows.Automation.AutomationElement]$Window)

    $buttonCondition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        $buttonType
    )
    $nameCondition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::NameProperty,
        "Retry"
    )
    $andCondition = New-Object System.Windows.Automation.AndCondition($buttonCondition, $nameCondition)

    $buttons = @()

    try {
        $found = $Window.FindAll($descendants, $andCondition)
        foreach ($button in $found) {
            try {
                $name = $button.Current.Name
                $rect = $button.Current.BoundingRectangle
                $enabled = $button.Current.IsEnabled
                if ($enabled -and $name -eq "Retry" -and $rect.Width -gt 0 -and $rect.Height -gt 0) {
                    $buttons += $button
                }
            } catch {
                # Skip stale UIA elements.
            }
        }
    } catch {
        # Ignore transient UIA failures.
    }

    return $buttons
}

function Try-AutoApprovePermission {
    if ($script:AutoSelectPermission -eq "None" -or $script:AutoSelectPermission -eq "") {
        return $false
    }

    $windows = @(Get-AntigravityWindows)
    foreach ($window in $windows) {
        try {
            $submitCondition = New-Object System.Windows.Automation.PropertyCondition(
                [System.Windows.Automation.AutomationElement]::NameProperty,
                "Submit"
            )
            $submitBtn = $window.FindFirst($descendants, $submitCondition)

            if ($submitBtn -and $submitBtn.Current.IsEnabled) {
                $allItems = $window.FindAll($descendants, $trueCondition)
                $foundOption = $null
                foreach ($item in $allItems) {
                    try {
                        $name = $item.Current.Name
                        if ($name -match "^$($script:AutoSelectPermission)\s+Yes" -or $name -match "^$($script:AutoSelectPermission)\s+No") {
                            $foundOption = $item
                            break
                        }
                    } catch {}
                }

                if ($foundOption) {
                    $selected = $false
                    try {
                        $selectionPattern = $foundOption.GetCurrentPattern([System.Windows.Automation.SelectionItemPatternIdentifiers]::Pattern)
                        $selectionPattern.Select()
                        $selected = $true
                    } catch {}
                    
                    if (-not $selected) {
                        try {
                            $invokePattern = $foundOption.GetCurrentPattern([System.Windows.Automation.InvokePatternIdentifiers]::Pattern)
                            $invokePattern.Invoke()
                            $selected = $true
                        } catch {}
                    }

                    if ($selected) {
                        Start-Sleep -Milliseconds 50
                        try {
                            $submitInvoke = $submitBtn.GetCurrentPattern([System.Windows.Automation.InvokePatternIdentifiers]::Pattern)
                            $submitInvoke.Invoke()
                            Write-AutoRetryLog "Auto-selected permission option '$($script:AutoSelectPermission)' and submitted."
                            return $true
                        } catch {}
                    }
                }
            }
        } catch {}
    }
    return $false
}

function Notify-RetryAction {
    Write-Host "[ACTION] RETRY_REQUESTED"
    return $true
}

function Try-Retry {
    $now = Get-Date
    $requiredDelay = [Math]::Max($CooldownSeconds, $currentBackoffSeconds)

    if (($now - $script:lastRetryTime).TotalSeconds -lt $requiredDelay) {
        return $false
    }



    $sawRetryButton = $false
    $windows = @(Get-AntigravityWindows)

    if ($windows.Count -gt 0) {
        $script:hasSeenIdeWindow = $true
        $script:lastIdeSeenTime = $now
    }

    foreach ($window in $windows) {
        $windowName = ""
        try { $windowName = $window.Current.Name } catch {}

        $retryButtons = Get-RetryButtons -Window $window
        if ($retryButtons.Count -eq 0) {
            continue
        }

        $sawRetryButton = $true

        if ($retryButtons.Count -gt 0) {
            $script:lastRetryTime = Get-Date
            $script:currentBackoffSeconds = 0
            Write-AutoRetryLog "Detected Retry in '$windowName', requesting native retry."
            return Notify-RetryAction
        }
    }

    if (-not $sawRetryButton) {
        $script:currentBackoffSeconds = 0
        return $false
    }

    if ($currentBackoffSeconds -eq 0) {
        $script:currentBackoffSeconds = 1
    } else {
        $script:currentBackoffSeconds = [Math]::Min($MaxBackoffSeconds, $currentBackoffSeconds * 2)
    }

    return $false
}

Write-AutoRetryLog "Auto Retry started (checking every ${IntervalMilliseconds}ms)."
Write-AutoRetryLog "This script passively detects the Retry button through UI Automation."
Write-AutoRetryLog "Log file: $logFile"
Write-AutoRetryLog "Press Ctrl+C to stop."

while ($true) {
    try {
        [void](Try-AutoApprovePermission)
        [void](Try-Retry)
    } catch {
        Write-AutoRetryLog "Loop error: $($_.Exception.Message)"
    }

    if ($ExitWhenIdeMissingSeconds -gt 0 -and
        $hasSeenIdeWindow -and
        ((Get-Date) - $lastIdeSeenTime).TotalSeconds -ge $ExitWhenIdeMissingSeconds) {
        Write-AutoRetryLog "Antigravity IDE has been closed for ${ExitWhenIdeMissingSeconds}s. Exiting."
        break
    }

    if ($Once) {
        break
    }

    Start-Sleep -Milliseconds $IntervalMilliseconds
}
