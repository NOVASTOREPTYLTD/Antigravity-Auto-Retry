Add-Type -AssemblyName PresentationFramework

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Antigravity - Mock Error Server Busy" Height="250" Width="400" Topmost="False" WindowStartupLocation="CenterScreen">
    <StackPanel Margin="20" HorizontalAlignment="Center" VerticalAlignment="Center">
        <TextBlock Text="The servers are experiencing high traffic." Margin="0,0,0,20" TextWrapping="Wrap" FontSize="14" FontWeight="Bold"/>
        <TextBlock Text="FOCUS TEST: Quickly click back into VS Code. When the extension automatically clicks Retry in the background, your focus shouldn't change!" Margin="0,0,0,20" TextWrapping="Wrap" FontSize="12" Foreground="DarkOrange"/>
        <Button Name="Retry" Content="Retry" Width="100" Height="30" />
    </StackPanel>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

$retryButton = $window.FindName("Retry")
$retryButton.add_Click({
    Write-Host "The mock 'Retry' button was successfully clicked by the UI automation script!" -ForegroundColor Green
    Write-Host "Check your screen: If VS Code is still your active window, the background click was successful!" -ForegroundColor Yellow
    $window.Close()
})

Write-Host "Opening mock error window..." -ForegroundColor Cyan
Write-Host "1. Quickly click back into VS Code to make it your active window." -ForegroundColor Yellow
Write-Host "2. Watch the Antigravity Auto Retry logs in the VS Code Output panel." -ForegroundColor Cyan
$window.ShowDialog() | Out-Null
