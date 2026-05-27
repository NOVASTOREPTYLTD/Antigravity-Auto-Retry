param(
    [int]$IntervalMilliseconds = 100,
    [int]$IntervalSeconds = 0,
    [string]$SignalDir = "",
    [int]$CooldownSeconds = 0,
    [int]$MaxBackoffSeconds = 1,
    [int]$ExitWhenIdeMissingSeconds = 0,
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

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class MouseHelper {
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, int dwExtraInfo);
    public const uint MOUSEEVENTF_LEFTDOWN = 0x02;
    public const uint MOUSEEVENTF_LEFTUP = 0x04;
    public static void Click(int x, int y) {
        SetCursorPos(x, y);
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
    }
}
"@

# Helper to save/restore the foreground window so clicking Retry
# does not bring Antigravity IDE to the front of the screen.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class FocusHelper {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@


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
            
            $button = $retryButtons[0]
            # Save the currently focused window so we can restore it after clicking
            $previousForeground = [FocusHelper]::GetForegroundWindow()
            try {
                $invokePattern = $button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern) -as [System.Windows.Automation.InvokePattern]
                if ($null -ne $invokePattern) {
                    Write-AutoRetryLog "Detected Retry in '$windowName', clicking it via UI Automation InvokePattern!"
                    $invokePattern.Invoke()
                } else {
                    throw "No InvokePattern available"
                }
            } catch {
                Write-AutoRetryLog "Detected Retry in '$windowName', InvokePattern failed. Falling back to MouseHelper."
                try {
                    $rect = $button.Current.BoundingRectangle
                    $cx = [int]($rect.Left + ($rect.Width / 2))
                    $cy = [int]($rect.Top + ($rect.Height / 2))
                    [MouseHelper]::Click($cx, $cy)
                    Write-AutoRetryLog "Clicked coordinates $cx, $cy via MouseHelper."
                } catch {
                    Write-AutoRetryLog "MouseHelper fallback also failed: $_"
                }
            }
            # Restore the previously focused window so the IDE doesn't steal focus
            if ($previousForeground -ne [IntPtr]::Zero) {
                Start-Sleep -Milliseconds 50
                [void][FocusHelper]::SetForegroundWindow($previousForeground)
            }
            return $true
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

try {
    while ($true) {
        try {
            [void](Try-Retry)
        } catch {
            Write-AutoRetryLog "Loop error: $($_.Exception.Message)"
            Write-AutoRetryLog $_.ScriptStackTrace
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
} catch {
    Write-AutoRetryLog "Fatal error: $_"
    Write-AutoRetryLog $_.ScriptStackTrace
    exit 1
}
