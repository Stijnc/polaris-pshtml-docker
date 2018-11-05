Function output {
    <#
    .SYNOPSIS
    Create a output tag in an HTML document.

    .Description

    The <output> tag represents the result of a calculation (like one performed by a script).

    .EXAMPLE
   
    output -Name "plop" -For "a b" -Form MyForm

    REturns:
    
    <output Form="MyForm" Name="plop" For="a b"  >
    </output>

    .EXAMPLE
    
    .NOTES
    Current version 2.0
       History:
            2018.10.10;stephanevg;Creation.
    .LINK
        https://github.com/Stephanevg/PSHTML
    #>
    [Cmdletbinding()]
    Param(

        [Parameter(Mandatory=$false)]
        [AllowEmptyString()]
        [AllowNull()]
        $Content,

        [Parameter(Mandatory=$false)]
        [AllowEmptyString()]
        [AllowNull()]
        [String]
        $Name,

        [Parameter(Mandatory=$false)]
        [AllowEmptyString()]
        [AllowNull()]
        [String]
        $Form,

        [Parameter(Mandatory=$false)]
        [AllowEmptyString()]
        [AllowNull()]
        [String]
        $For,

        [AllowEmptyString()]
        [AllowNull()]
        [String]$Class="",

        [String]$Id,

        [AllowEmptyString()]
        [AllowNull()]
        [String]$Style,

        [String]$title,

        [Hashtable]$Attributes
    )

    Process {

        $CommonParameters = @('tagname') + [System.Management.Automation.PSCmdlet]::CommonParameters + [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
        $CustomParameters = $PSBoundParameters.Keys | ? { $_ -notin $CommonParameters }
        
        $htmltagparams = @{}
        $tagname = "output"

        if($CustomParameters){

            foreach ($entry in $CustomParameters){


                if($entry -eq "content"){

                    
                    $htmltagparams.$entry = $PSBoundParameters[$entry]
                }else{
                    $htmltagparams.$entry = "{0}" -f $PSBoundParameters[$entry]
                }
                
    
            }

            if($Attributes){
                $htmltagparams += $Attributes
            }


        }
         Set-HtmlTag -TagName $tagname -Attributes $htmltagparams -TagType NonVoid   
    }
}
