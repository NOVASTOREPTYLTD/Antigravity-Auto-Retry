# Antigravity Auto Retry

Automatically clicks the "Retry" button when an Antigravity IDE agent session fails due to a transient error (e.g., rate limits, internal server errors). 

## How it works

This extension silently monitors the Antigravity IDE for failure states and automatically sends the native VS Code command to retry (`workbench.action.chat.submit`). This keeps your long-running agent tasks flowing without manual intervention.

* **Native Integration:** Directly triggers the retry command instead of clicking the UI.
* **Non-intrusive:** Never steals your mouse or window focus.
* **Smart Backoff:** Uses exponential backoff if the retry keeps failing.

## Requirements

* **Windows OS:** The underlying mechanism uses Windows UI Automation (`UIAutomationClient`).

## Extension Settings

This extension contributes the following settings:

* `antigravityAutoRetry.enabled`: Enable or disable the auto-retry monitor.
* `antigravityAutoRetry.intervalMilliseconds`: Check interval in milliseconds (default: `500`).

## Commands

You can run any of these by opening the Command Palette (`Ctrl+Shift+P` on Windows/Linux, or `Cmd+Shift+P` on Mac) and typing:

* **Antigravity Auto Retry: Start**
* **Antigravity Auto Retry: Stop**
* **Antigravity Auto Retry: Toggle** (Also available directly from the status bar)
* **Antigravity Auto Retry: Open Settings** (Quickly open settings to edit retry speed)

## Support Development

This tool is provided by **NOVASTORE (PTY) LTD**.
* Web Design: [versysmedia.com](https://versysmedia.com)
* Online Store: [novastoretech.co.za](https://novastoretech.co.za)
* Gym Tracker App: [novastore.co.za](https://novastore.co.za)

If you find this project useful and would like to support further development, you can donate ETH to the following address:

* **ETH Address:**<br>`0x56DC29495FAeB3B4331cE32A2190096C071f18e7`

Your contributions will be greatly appreciated and will help in maintaining and improving this project. Thank you for your support!

## Disclaimer

This is a community-created tool and is not officially affiliated with Google or the Antigravity team.
