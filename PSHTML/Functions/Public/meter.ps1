Function meter {
    <#
    .SYNOPSIS
    Create a meter tag in an HTML document.

    .DESCRIPTION

    The <meter> tag defines a scalar measurement within a known range, or a fractional value. This is also known as a gauge.

    Examples: Disk usage, the relevance of a query result, etc.

    Note: The <meter> tag should not be used to indicate progress (as in a progress bar). For progress bars, use the <progress> tag.

    .EXAMPLE
    
    <meter Min="0" Value="58" Max="100"  >
    Represents 58%
    </meter>

    .EXAMPLE
     meter -Value 0.75

     Returns:

    <meter Value="0.75"  >
    </meter>

    .NOTES
    Current version 2.0
       History:

            2018.10.10;stephanevg;Creation.
    .LINK
        https://github.com/Stephanevg/PSHTML
    #>
    [Cmdletbinding()]
    Param(

        [Parameter(
            ValueFromPipeline = $true,
            Mandatory = $false,
            Position = 0
        )]
        [AllowEmptyString()]
        [AllowNull()]
        $Content,

        [Parameter(Mandatory=$false)]
        [AllowEmptyString()]
        [AllowNull()]
        [String]
        $Value,

        [Parameter(Mandatory=$false)]
        [AllowEmptyString()]
        [AllowNull()]
        [String]
        $Min,

        [Parameter(Mandatory=$false)]
        [AllowEmptyString()]
        [AllowNull()]
        [String]
        $Max,

        [string]$cite,

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
        $tagname = "meter"

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
