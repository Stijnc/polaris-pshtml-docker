
Write-Information 'Start docker run with latest tag'
$id = docker run -d eleu2018k8sweb:latest

Write-Information "retrieve IP and browse"
start-process "http://$((docker inspect $id | ConvertFrom-Json).networksettings.IPAddress):8080"

docker exec -it $id pwsh