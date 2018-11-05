#import-module PSHTML
New-PolarisGetRoute -Path "/" -Scriptblock {
    $Response.SetContentType('text/html')
    $res = html {
        head -Content {
            Link -href "https://fonts.googleapis.com/css?family=Roboto" -rel "stylesheet"
            Link -href "assets/style.css" -rel "stylesheet"
        }
        body -Content {
            nav -Content {
                ul -Content {
                    li -Content {
                        a -href "/powershell" -Content "POWERSHELL"
                    }
                    li -Content {
                        a -href "/kubernetes" -Content "KUBERNETES"
                    }
                    li -Content {
                        a -href "/" -Content "HOME"
                    }
                }
            }
            header -Content {
                div -Class "logo" -Content {
                    img -src "https://csb43183080e3c5x4b05x802.blob.core.windows.net/k8s/xJPrlOfA_400x400.jpg" -alt "ExpertsLive EU"
                }

                h1 -Content {
                    "Hello,
                    <br />
                    Expertslive EU"
                }
            }
            div -Class "responsive" -Content {
                div -Class "gallery" -Content {
                    img -src "https://csb43183080e3c5x4b05x802.blob.core.windows.net/k8s/Kubernetes_container_engine.png" alt="Kubernetes" -width "400" -height "200"
                }
                div -Class "gallery" -Content {
                    img -src "https://csb43183080e3c5x4b05x802.blob.core.windows.net/k8s/1_lUNmBw_oyS2ADWqZs4DLOA.png" alt="Kubernetes" -width "400" -height "200"
                }
                div -Class "gallery" -Content {
                    img -src "https://csb43183080e3c5x4b05x802.blob.core.windows.net/k8s/core.jpg" alt="Kubernetes" -width "400" -height "200"
                }
            }
            div -Class "clearfix"
            footer -Content {
                $PSHTMLlink = a {"PSHTML"} -href "https://github.com/Stephanevg/PSHTML"
                $POLARISlink = a {"Polaris"} -href "https://github.com/PowerShell/Polaris"
                h2 -Content {"Generated with &#9829 using $($POLARISlink) + $($PSHTMLlink)"}
                h3 -Content {"I'm running on $($Env:HOSTNAME)"}
                p -Content {"Stijn.Callebaut[at]itnetx.be"}
            }
        }
    }
    $Response.Send($res)
}