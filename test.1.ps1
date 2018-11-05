$res = html {
    head -Content {
        Link -href "https://fonts.googleapis.com/css?family=Roboto" -rel "stylesheet"
        style -content {
            "body {
                font-family: 'Roboto', serif;
            }
            ul {
                font-size: 1.5em;
                list-style-type: none;
                margin: 0;
                padding: 0;
                overflow: hidden;
            }
            .resources {
                font-size: 1.5em;
                margin: 0;
                padding: 0;
                overflow: hidden;
                text-align: left;
                list-style-item: circle;
            }
            .resourceitem {
                text-align: left;
            }
            nav li {
                float: right;
            }

            li a {
                display: block;
                color: #333;
                text-align: center;
                padding: 14px 16px;
                text-decoration: none;
            }
            .resourcelink {
                text-align: left;
                display: block;
                color: #333;
                padding: 14px 16px;
                text-decoration: none;

            }
            li a:hover {
                background-color: white;
            }
            div.gallery {
                display: block;
                margin: 5px;
                border: 1px solid #ccc;
                float: left;
                width: 200px;
            }
            div.gallery:hover {
                border: 1px solid #777;
            }
            div.gallery img {
                width: 100%;
                min-height: 200px;
                height: auto;
            }
            .responsive {
                display: block;
                margin-left: auto;
                margin-right: auto;
                width: 30%;
            }
            header {
                padding-left: 1.5em;
                font-size: 48px;
            }
            div.logo {
                float: left;
            }
            .clearfix:after {
                content: '';
                display: table;
                clear: both;
            }
            footer {
                display: block;
                margin-left: auto;
                margin-right: auto;
                width: 40%;
                text-align: center;
                position: fixed;
                left: 0;
                bottom: 0;
                width: 100%;
                background-color: #777;
            }
            footer p h3{
                text-align: center;
            }"
        }
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
            h1 -Content {
                "kubernetes"
            }
        }
        div -Class "responsive" -Content {
           h3 -Content "a list of resources"
           ul -class "resources" -Content {
                li -class "resourceitem" -Content {
                    a -Class "resourcelink" -href "https://kubernetes.io/" -Content "Kubernetes"
                }
                li -class "resourceitem" -Content {
                    a  -Class "resourcelink" -href "https://azure.microsoft.com/en-us/services/kubernetes-service/" -Content "AKS (Azure kubernetes service)"
                }
               li -class "resourceitem" -Content {
                   a  -Class "resourcelink" -href "https://github.com/kelseyhightower/kubernetes-the-hard-way" -Content "Kubernetes the hard way"
               }
               li -class "resourceitem" -Content {
                a  -Class "resourcelink" -href "https://azure.microsoft.com/en-us/resources/videos/the-illustrated-children-s-guide-to-kubernetes/" -Content "The illustrated children's guide to kubernetes"
                }
                li -class "resourceitem" -Content {
                    a  -Class "resourcelink" -href "https://github.com/Stephanevg/PSHTML" -Content "Children's guide to kubernetes"
                    }
           }

           h3 -Content {
               "Does it end here? no, this is only the beginning!  (think security, management, ...)"
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

$res > test.kubernetes.htm