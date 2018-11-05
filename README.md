# PowerShell Polaris and PSHTML linux container

This repository contains a PowerShell Polaris PSHTML sample website Docker image.

## Building the sample website

To build the docker image, just execute the build script.

``` PowerShell
.\build.ps1
```

The script builds the dockerfile and produces 2 images.

- polaris-pshtml:latest
- polaris-pshtml:``<YOURCOMMITID>``

## Run the container locally

Starting a container instance from the latest tag is as easy as:

``` PowerShell
$id = docker run -d polaris-pshtml:latest
```

to view the website simple execute the following:

On Windows:

``` PowerShell
start-process "http://$((docker inspect $id | ConvertFrom-Json).networksettings.IPAddress):8080"
```

On Mac\Linux (with PowerShell Core):

``` PowerShell
Start-Process "http://localhost:8080"
```

## More information

For more information about the 2 powershell projects, hit the links below:

- [PowerShell Polaris](https://github.com/powershell/polaris)
- [PowerShell PSHTML](https://github.com/Stephanevg/PSHTML)

## Known issues

### PSReadline gives an access denied when running as non-root

when running as non-root PSReadline get's an access denied on path "/home/<USERNAME>/.local/share/powershell/PSReadLine/ConsoleHost_history.txt"

```PowerShell
docker exec -it <YOURCONTAINERID> pwsh

PS /app> get-process
Error reading or writing history file '/home/psuser/.local/share/powershell/PSReadLine/ConsoleHost_history.txt': Access to the path '/home/psuser/.local/share/powershell/PSReadLine' is
denied.
ưm
 NPM(K)    PM(M)      WS(M)     CPU(s)      Id  SI ProcessName
 ------    -----      -----     ------      --  -- -----------
      0     0.00     165.99       8.33       1   1 pwsh
      0     0.00      94.74       2.42    4324 324 pwsh
```
