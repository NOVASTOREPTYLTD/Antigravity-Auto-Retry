# Antigravity Auto Retry

Automatically clicks the "Retry" button when an Antigravity IDE agent session fails due to a transient error (e.g., rate limits, internal server errors). 

## How it works

This extension silently monitors the Antigravity IDE for failure states and automatically sends the native VS Code command to retry (`workbench.action.chat.submit`). This keeps your long-running agent tasks flowing without manual intervention.

* **Native Integration:** Directly triggers the retry command instead of clicking the UI.
* **Non-intrusive:** Never steals your mouse or window focus.
* **Smart Backoff:** Uses exponential backoff if the retry keeps failing.
* **Status Indicator:** Shows a spinning icon in your bottom-right status bar so you always know when it's actively scanning.

## Installation

1. Open VS Code or Antigravity IDE.
2. Go to the Extensions view (`Ctrl+Shift+X`).
3. Search for **Novastore Antigravity Auto Retry**.
4. Click **Install**.
5. The auto-retry monitor will start automatically!

## Requirements

* **Windows OS:** The underlying mechanism uses Windows UI Automation (`UIAutomationClient`).

## Extension Settings

This extension contributes the following settings:

* `antigravityAutoRetry.enabled`: Enable or disable the auto-retry monitor.
* `antigravityAutoRetry.intervalMilliseconds`: Check interval in milliseconds (default: `500`).

You can easily access and configure these by opening the Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P`) and running the **Antigravity Auto Retry: Open Settings** command. You can also find them under the IDE's main Settings page by searching for "Antigravity Auto Retry".

## Commands

You can run any of these by opening the Command Palette (`Ctrl+Shift+P` on Windows/Linux, or `Cmd+Shift+P` on Mac) and typing:

* **Antigravity Auto Retry: Start**
* **Antigravity Auto Retry: Stop**
* **Antigravity Auto Retry: Toggle** (Also available directly from the status bar)
* **Antigravity Auto Retry: Open Settings** (Quickly open settings to edit retry speed)

## Viewing Logs

You can monitor the live activity of the auto-retry script to verify it is scanning and clicking correctly:

1. Go to **View** -> **Output** in the top menu (or press `Ctrl+Shift+U`). This will open the Terminal area.
2. In the terminal section at the top right, click the dropdown menu.
3. Select **Antigravity Auto Retry**.

If the extension is working properly, you will see `[PS] Auto Retry started` when it begins scanning, and `[EXT] Received retry signal. Submitted follow-up natively.` whenever it successfully clicks the retry button.

## Support Development

This tool is provided by **NOVASTORE (PTY) LTD**.
* Web Design: [versysmedia.com](https://versysmedia.com)
* Online Store: [novastoretech.co.za](https://novastoretech.co.za)
* Gym Tracker App: [novastore.co.za](https://novastore.co.za)


## Disclaimer

This is a community-created tool and is not officially affiliated with Google or the Antigravity team.
