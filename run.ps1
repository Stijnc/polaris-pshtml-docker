
Write-Information 'Start docker run with'
$id = docker run -d polaris-pshtml:latest

Write-Information ""
start-process "http://$((docker inspect $id | ConvertFrom-Json).networksettings.IPAddress):8080"