$CommandTopicTokens = @("Commands.*:$")
$UsageTopicTokens = "Usage:"
$GroupTopicTokens   = @()

class Topic {
    [string]$Usage
    [string[]]$Options
    [string[]]$Examples
    [string]$Description
}

class ExampleInfo {
    [string]$Description
    [string]$Command
    ExampleInfo([string[]]$text) {
        foreach ( $line in $text ) {
            if ( "${line}".Trim() -match "^#" ) {
                $this.Description += "${line}".Trim(" #")
            }
            else {
                $this.Command += "${line}".Trim()
            }
        }
    }
    static [ExampleInfo[]]GetExamples([string[]]$text) {
        [ExampleInfo[]]$examples = @()
        $getExamples = $false
        for ( $i = 0; $i -lt $text.Length; $i++) {
            if ( $text[$i] -match "^Examples:" ) {
                $getExamples = $true
                continue
            }
            if ( $getExamples ) {
                if ( $text[$i][0] -match "^[A-Z]" ) {
                    break
                }
                if ( $text[$i].Length -eq 0 ) {
                    continue
                }
                if ( $text[$i].Trim() -match "^#" ) {
                    $examples += [ExampleInfo]::new($text[$i..++$i])
                }
            }
        }
        return $examples
    }
}

class CommandBase {
    [string]$Command
    [string[]]$CommandElements
    [string]$Description
    [ParameterInfo[]]$Parameters
    [ExampleInfo[]]$Examples
    hidden [string]$originalText

    CommandBase ([string]$text ) {
        $c,$d = "$text".Trim().Split("  ", 2, [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {"$_".Trim()}
        $this.Command = $c
        $this.Description = $d
        $this.originalText = $text
    }

    # not all commands support -o json. We need a way to add it or not when we execute
    # the only way we can know is by going through the options
    [bool]SupportsJsonOutput() {
        return ($null -ne $this.Parameters.Where({$_.OriginalParameterName -eq "o" -and $_.Description -match "json"}))
    }


}

class Command : CommandBase {

    Command([string]$text) : base($text) { }

    [string]CreateParamStatement() {
        return "param (`n{0} )" -f $this.Parameters.Foreach({$_.ToString}) -join ",`n"
    }

    [string]CreateProxyFunction() {
        [string[]]$s = .{
            'function Invoke-Kube{0}' -f $this.Name
            '{'
            $this.CreateParamStatement()
            $commandArguments = $this.GetCommandArguments()
            if ( $this.SupportsJsonOutput ) {
                "kubectl $commandArguments -o json"
            }
            else {
                "kubectl $commandArguments"
            }
            '}'
        }
        return ($s -join [environment]::NewLine)

    }
    # this captures the information about the parameters in a .psd block.
    # this is needed when we want to take the parameters that the user provided and turn them back into the
    # strings we need when we call the actual command
    [string]GetParameterMap() {
        [string[]]$parameterStrings = '$_parameterMap = @{ '
        foreach ( $parameter in $this.Parameters ) {
            $parameterStrings += "'{0}' = '{1}'"
        }
        return ($parameterStrings -join [Environment]::NewLine)
    }
}

class CommandInfo {
    [string[]]$SubCommands
    [string]$Usage
    [ExampleInfo[]]$Examples
    [ParameterInfo[]]$Options
    [ScriptBlock]$proxyFunction
}

class GroupCommandInfo {
    [string]$Usage
    [Command[]]$Commands
}

# note that for PowerShell, we won't have parameter aliases
# An option takes the shape of '--<name>=<defaultvalue>: <description>"
# it can also look like '-<n>, --<name>=<defaultvalue>: <description>" where '-<n>' is an option alias
# we through away the aliases
# The <defaultvalue> might be something that we can interpret, so try
# also, some options can be converted to powershell switches (their default value is True or False).
# if the default value is 'True',
# convert that to "No<name>" when building the string which represents the option
class ParameterInfo {
    # we need to track the original name of the parameter
    [string]$OriginalParameterName
    [string]$Name
    [string]$Description
    [object]$DefaultValue
    [type]$ValueType
    [bool]$IsMandatory
    hidden [bool]$Parsed
    hidden [string]$originalText
    ParameterInfo ([string]$text, [bool]$isMandatory = $false) {
        $this.originalText = $text
        if ( $text -match ".* --(?<option>.*): (?<Description>.*)" ) {
            $pname,$default = $matches['option'] -split "="
            $this.OriginalParameterName = "--${pname}"
            $pDefaultValue = $default.Trim("'")
            $this.Name = "${pname}" # .Trim() -replace "-(.)",{($_ -replace "-").ToUpper()} -replace "^(.)",{"$_".ToUpper()}
            $this.Description = $matches['Description'].Trim()
            $this.IsMandatory = $isMandatory
            $this.Parsed = $true
            $v = $null
            if ( [string]::isnullOrEmpty($pDefaultValue)) {
                $this.ValueType = [string]
            }
            elseif ( [int]::TryParse($pDefaultValue, [ref]$v)) {
                $this.ValueType = [int]
                $pDefaultValue = $v
            }
            elseif ( [double]::TryParse($pDefaultValue, [ref]$v)) {
                $this.ValueType = [double]
                $pDefaultValue = $v
            }
            elseif ( $pDefaultValue -eq '[]' ) {
                $this.ValueType = [array]
                $pDefaultValue = @()
            }
            elseif ( $pDefaultValue -eq 'true' -or $pDefaultValue -eq 'false' ) {
                $this.ValueType = [bool]
                $pDefaultValue = [bool]::Parse($pDefaultValue)
            }
            else {
                $this.ValueType = [string]
            }
            $this.DefaultValue = $pDefaultValue
        }
        else {
            throw "Could not convert $text into a parameter"
        }
    }
    [string]ToString() {
        # this is a bool, we convert it to a switch parameter
        if ( $this.ValueType -eq [bool] ) {
            $pName = $this.Name
            if ( $this.DefaultValue ) {
                $pName = "No${pName}"
            }
            $pString = '[Parameter(Mandatory=${0})][switch]${{{1}}}' -f $this.IsMandatory,$pName
        }
        elseif ( $this.ValueType -eq [array] -and ! $this.DefaultValue ) {
                $pString = '[Parameter(Mandatory=${0})][{1}]${{{2}}} = @()' -f $this.IsMandatory,$this.ValueType,$this.Name
        }
        elseif ( $this.ValueType -eq [string] -and $this.DefaultValue ) {
                $pString = '[Parameter(Mandatory=${0})][{1}]${{{2}}} = "{3}"' -f $this.IsMandatory,$this.ValueType,$this.Name,$this.DefaultValue
            
        }
        elseif ( $this.DefaultValue ) {
                $pString = '[Parameter(Mandatory=${0})][{1}]${{{2}}} = {3}' -f $this.IsMandatory,$this.ValueType,$this.Name,$this.DefaultValue
        }
        else {
            $pString = '[Parameter(Mandatory=${0})][{1}]${{{2}}}' -f $this.IsMandatory,$this.ValueType,$this.Name
        }
        return $pString
    }
}

# With Kubectl, there are 3 levels of help documentation
# level 1 (General) is what you see when you type 
# kubectl --help
# this provides categorizations of commands, which leads to
# level 2 (Group)
# this may provide more finer grained categorizations (or not)
# but may lead to 
# level 3 (Command)
# this contains the help for the specific fully qualified command
# the help may contain a number of different tokens, some are the same throughout
# (options, examples)
# some are available only for that level of help
# we have to start at the general level and search for group topics, each
# group topic may be an end point, or a group topic, we should be able to determine
# based on the tokens.


# progress
$el = tput el
$cp = $host.ui.rawui.cursorposition
$x = $cp.x
$y = $cp.y
function Show-Prog
{
    param ( [string]$message )
    # write-host "${message}"
    Write-Log $message
    write-host -no "`e[${y};${x}H${el}Parsing data from: '${message}'"
}

# a log function
$LOGFILE = "/tmp/kubewrapper.log"
function Write-Log
{
    [CmdletBinding()]
    param ( [Parameter(position=0,mandatory)][string]$message, [switch]$initialize )
    # just put a couple of newlines at the beginning to ease finding the start
    if ( $initialize ) { "`n`n" | out-file -append $LOGFILE }
    "$(get-date) : $message" | out-file -append $LOGFILE
}

Write-Log "====== START RUN $(get-date) ======" -init

# invoke kubectl and log it
function Invoke-Kubectl {
    [CmdletBinding()]
    param ( [Parameter(ValueFromRemainingArguments,Position=0,Mandatory=$true)][string[]]$command )
    $p = "kubectl $($command -join ' ')"
    show-prog -message "$p"
    kubectl $command
}

function Get-Options {
    $text = Invoke-Kubectl "options" | ?{$_ -match " --"}
    $text.Foreach({[ParameterInfo]::new($_, $false)})
}

function Parse-Command
{
    #[CmdletBinding()]
    #param ( [Parameter(Mandatory=$true,Position=0)][string[]]$text, [Parameter(Mandatory,Position=1)][string[]]$pattern )
    # param ( $text, $pattern )
    param ( [array]$text, [array]$pattern, [switch]$Simple )
    $patternRegex = $pattern -join "|"
    $results = [System.Collections.ArrayList]::new()
    for ( $i = 0; $i -lt $text.Count; $i++ ) {
        if ( $text[$i] -match $patternRegex ) {
            $i++
            while ( $text[$i].Trim() -ne "" ) {
               if ( $Simple ) {
                   $null = $results.Add([CommandBase]::new($text[$i]))
               }
               else
               {
                   $null = $results.Add([Command]::new($text[$i]))
               }
               $i++
               if ( $i -gt $text.count ) { break }
            }
        }
    }
    $results
}

function Parse-Usage
{
    #[CmdletBinding()]
    #param ( [Parameter(Mandatory=$true,Position=0)][string[]]$text, [Parameter(Mandatory,Position=1)][string[]]$pattern )
    param ( $text, $pattern )
    # param ( [array]$text, [array]$pattern )
    $patternRegex = $pattern -join "|"
    $results = [System.Collections.ArrayList]::new()
    for ( $i = 0; $i -lt $text.Count; $i++ ) {
        if ( $text[$i] -match $patternRegex ) {
            $i++
            while ( ($text[$i] -as [string]).Trim() -ne "" ) {
               $null = $results.Add($text[$i].Trim())
               $i++
               if ( $i -gt $text.count ) { break }
            }
        }
    }
    return $results
}

function Parse-GeneralHelp
{
    # first generate the output
    $text = kubectl --help  # Invoke-Kubectl "--help"
    $usage = Parse-Usage -text $text -pattern $UsageTopicTokens
    write-verbose -verbose $usage
    $subcommands = Parse-Command -text $text -pattern $CommandTopicTokens -Simple
    $r = Get-Options
    $ci = [commandinfo]::new()
    $ci.Usage = $usage
    $ex = [ExampleInfo]::GetExamples($text)
    $ci.Examples = $ex
    $ci.Options = $r
    return $ci
}

function Get-CommandOptions {
    param ( [string[]]$helpContent )
    for($i = 0; $i -lt $helpContent.Count; $i++) {
        if ( $helpContent[$i] -match "^Options:" ) {
            $i++
            do {
                [parameterinfo]::new($helpContent[$i], $false)
            } while ( $helpContent[++$i] -ne "" )
        }
    }
}


function Parse-CommandHelp {
    param ( [string[]]$command )
    $kArgs = @()
    $kArgs += $command
    $kArgs += "--help"
    $text = kubectl $kArgs
    $usage = Parse-Usage -text $text -pattern $UsageTopicTokens
    $r = Get-CommandOptions $text
    # $e = Parse-Examples $text
    $e = [ExampleInfo]::GetExamples($text)

    [pscustomobject]@{
        Subcommands = $subcommands
        Usage = $usage
        Examples = $e
        Options = $r
    }
}

function Parse-Examples {
    param ( [string[]]$text )
    for($i = 0; $i -lt $text.count; $i++ ) {
        if ( $text[$i] -match "Examples:") {
            $i++
            $exampleText = @()
            while ( $text[$i] -ne "" ) {
                $exampleText += $text[$i++]
            }
            # [exampleinfo]::new($exampleText)
        }
    }

}

function parse-helppage
{
    param ( $text )
    $parameters = Parse-Options $text
    $examples = Parse-Examples $text
    $subcommands = Parse-Command $text ${GeneralTopicTokens}
    $usage = Parse-Usage $text
}
