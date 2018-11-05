Import-Module Polaris -Verbose
Import-Module PSHTML -Verbose
New-PolarisGetRoute -path '/' -ScriptBlock {
    $Html = html {
        head {
            title "PSHTML + Polaris Demo"
        }
        body {
            h1 "Hello World!"
            p "$env:OS"
            img -src ".\ELeu18_stijn.png"
        }
    }
    $Response.SetContentType('text/html')
    $Response.Send($Html)
}

New-PolarisGetRoute -path '/about' -ScriptBlock {
    $Html = html {
        head {
            title "PSHTML + Polaris Demo"
        }
        body {
            h1 "Hello about!"
            p "$env:OS"
            img -src "c:\github\eleu2018-k8s-web\kubernetes-illustrated-guide-illustration-12.png"
        }
    }
    $Response.SetContentType('text/html')
    $Response.Send($Html)
}

Start-Polaris -Port 8080 -MinRunspaces 3 -MaxRunspaces 10
