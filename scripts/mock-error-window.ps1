Add-Type -AssemblyName PresentationFramework

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Antigravity - Mock Error Server Busy" Height="200" Width="400" Topmost="True">
    <StackPanel Margin="20" HorizontalAlignment="Center" VerticalAlignment="Center">
        <TextBlock Text="The servers are experiencing high traffic." Margin="0,0,0,20" TextWrapping="Wrap" FontSize="14" FontWeight="Bold"/>
        <Button Name="Retry" Content="Retry" Width="100" Height="30" />
    </StackPanel>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

$retryButton = $window.FindName("Retry")
$retryButton.add_Click({
    Write-Host "The mock 'Retry' button was successfully clicked by the UI automation script!" -ForegroundColor Green
    $window.Close()
})

Write-Host "Opening mock error window... Keep your Auto-Retry extension running to see if it catches it!" -ForegroundColor Cyan
$window.ShowDialog() | Out-Null
