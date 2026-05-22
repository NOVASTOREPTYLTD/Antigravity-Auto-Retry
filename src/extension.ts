import * as vscode from 'vscode';
import { spawn, ChildProcess } from 'child_process';
import * as path from 'path';

let autoRetryProcess: ChildProcess | undefined;
let outputChannel: vscode.OutputChannel;
let statusBarItem: vscode.StatusBarItem;

export function activate(context: vscode.ExtensionContext) {
    outputChannel = vscode.window.createOutputChannel('Antigravity Auto Retry');
    
    statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
    statusBarItem.command = 'antigravityAutoRetry.toggle';
    context.subscriptions.push(statusBarItem);

    const startCmd = vscode.commands.registerCommand('antigravityAutoRetry.start', () => {
        startAutoRetry(context);
    });
    const stopCmd = vscode.commands.registerCommand('antigravityAutoRetry.stop', () => {
        stopAutoRetry();
    });
    const toggleCmd = vscode.commands.registerCommand('antigravityAutoRetry.toggle', () => {
        if (autoRetryProcess) {
            stopAutoRetry();
        } else {
            startAutoRetry(context);
        }
    });
    const settingsCmd = vscode.commands.registerCommand('antigravityAutoRetry.openSettings', () => {
        vscode.commands.executeCommand('workbench.action.openSettings', 'antigravityAutoRetry');
    });

    context.subscriptions.push(startCmd, stopCmd, toggleCmd, settingsCmd);

    // Watch for configuration changes
    context.subscriptions.push(vscode.workspace.onDidChangeConfiguration(e => {
        if (e.affectsConfiguration('antigravityAutoRetry')) {
            const config = vscode.workspace.getConfiguration('antigravityAutoRetry');
            if (config.get<boolean>('enabled')) {
                // Restart with new config
                stopAutoRetry();
                startAutoRetry(context);
            } else {
                stopAutoRetry();
            }
        }
    }));

    // Start automatically if enabled
    const config = vscode.workspace.getConfiguration('antigravityAutoRetry');
    if (config.get<boolean>('enabled')) {
        startAutoRetry(context);
    } else {
        updateStatusBar(false);
    }
}

function startAutoRetry(context: vscode.ExtensionContext) {
    if (autoRetryProcess) {
        return; // Already running
    }

    const config = vscode.workspace.getConfiguration('antigravityAutoRetry');
    const intervalMilliseconds = config.get<number>('intervalMilliseconds', 100);
    const autoSelectPermission = config.get<string>('autoSelectPermission', 'None');

    const scriptPath = path.join(context.extensionPath, 'scripts', 'auto-retry.ps1');
    
    const args = [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy', 'Bypass',
        '-File', scriptPath,
        '-IntervalMilliseconds', intervalMilliseconds.toString(),
        '-ExitWhenIdeMissingSeconds', '0',
        '-AutoSelectPermission', autoSelectPermission
    ];

    outputChannel.appendLine(`Starting Auto Retry with args: ${args.join(' ')}`);

    // Clean PSModulePath to avoid conflicts between different PowerShell versions
    const env = { ...process.env };
    delete env.PSModulePath;

    autoRetryProcess = spawn('powershell.exe', args, { env });

    autoRetryProcess.stdout?.on('data', (data) => {
        const msg = data.toString().trim();
        if (msg === '[ACTION] RETRY_REQUESTED') {
            vscode.commands.executeCommand('workbench.action.chat.submit', { inputValue: 'The previous request failed due to a transient error. Please try again.' });
            outputChannel.appendLine('[EXT] Received retry signal. Submitted follow-up natively.');
        } else if (msg) {
            outputChannel.appendLine(`[PS] ${msg}`);
        }
    });

    autoRetryProcess.stderr?.on('data', (data) => {
        const msg = data.toString().trim();
        if (msg) outputChannel.appendLine(`[ERR] ${msg}`);
    });

    const spawnedProcess = autoRetryProcess;
    spawnedProcess.on('close', (code) => {
        outputChannel.appendLine(`Auto Retry process exited with code ${code}`);
        if (autoRetryProcess === spawnedProcess) {
            autoRetryProcess = undefined;
            updateStatusBar(false);
        }
    });

    updateStatusBar(true);
}

function stopAutoRetry() {
    if (autoRetryProcess) {
        outputChannel.appendLine('Stopping Auto Retry...');
        // Kill the entire process tree to ensure PowerShell fully exits
        const cp = require('child_process');
        if (process.platform === 'win32') {
            cp.exec(`taskkill /pid ${autoRetryProcess.pid} /T /F`, (err: any) => {
                if (err) {
                    outputChannel.appendLine(`Failed to kill process tree: ${err}`);
                }
            });
        } else {
            autoRetryProcess.kill();
        }
        autoRetryProcess = undefined;
    }
    updateStatusBar(false);
}

function updateStatusBar(isRunning: boolean) {
    if (isRunning) {
        statusBarItem.text = '$(sync~spin) Auto Retry';
        statusBarItem.tooltip = 'Antigravity Auto Retry is active (Click to stop)';
        statusBarItem.show();
    } else {
        const config = vscode.workspace.getConfiguration('antigravityAutoRetry');
        if (config.get<boolean>('enabled')) {
            // Should be running but isn't
            statusBarItem.text = '$(error) Auto Retry Stopped';
            statusBarItem.tooltip = 'Antigravity Auto Retry is stopped (Click to start)';
            statusBarItem.show();
        } else {
            // Disabled in settings
            statusBarItem.hide();
        }
    }
}

export function deactivate() {
    stopAutoRetry();
}
