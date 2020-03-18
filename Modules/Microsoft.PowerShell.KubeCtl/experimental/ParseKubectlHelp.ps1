$GeneralTopicTokens = @("Usage:","Commands.*:$")
$GroupTopicTokens   = @()
$CommandTopicTokens = @()

class Topic {
    [string]$Usage
    [string[]]$Options
    [string[]]$Examples
    [string]$Description
}

class Command {
    [string]$Command
    [string]$Description
    [ParameterInfo[]]$Parameters
    hidden [string]$originalText
    Command ([string]$text ) {
        $c,$d = "$text".Trim().Split("  ", 2, [System.StringSplitOptions]::RemoveEmptyEntries) | %{"$_".Trim()}
        $this.Command = $c
        $this.Description = $d
        $this.originalText = $text
    }
}

class GroupCommandInfo {
    [string]$Usage
    [Command[]]$Commands
}

# note that for PowerShell, we won't have parameter aliases
class ParameterInfo {
    [string]$Name
    [string]$Description
    [object]$DefaultValue
    [type]$ValueType
    [bool]$IsMandatory
    hidden [bool]$Parsed
    hidden [string]$originalText
    ParameterInfo ([string]$text, [bool]$isMandatory) {
        $this.originalText = $text
        if ( $text -match ".* --(?<option>.*): (?<Description>.*)" ) {
            $pname,$default = $matches['option'] -split "="
            $pDefaultValue = $default.Trim("'")
            $this.Name = "${pname}".Trim() -replace "-(.)",{($_ -replace "-").ToUpper()} -replace "^(.)",{"$_".ToUpper()}
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
            $pString = '[Parameter(Mandatory=${0})][switch]${1}' -f $this.IsMandatory,$pName
        }
        elseif ( $this.ValueType -eq [array] -and ! $this.DefaultValue ) {
                $pString = '[Parameter(Mandatory=${0})][{1}]${2} = @()' -f $this.IsMandatory,$this.ValueType,$this.Name
        }
        elseif ( $this.ValueType -eq [string] -and $this.DefaultValue ) {
                $pString = '[Parameter(Mandatory=${0})][{1}]${2} = "{3}"' -f $this.IsMandatory,$this.ValueType,$this.Name,$this.DefaultValue
            
        }
        elseif ( $this.DefaultValue ) {
                $pString = '[Parameter(Mandatory=${0})][{1}]${2} = {3}' -f $this.IsMandatory,$this.ValueType,$this.Name,$this.DefaultValue
        }
        else {
            $pString = '[Parameter(Mandatory=${0})][{1}]${2}' -f $this.IsMandatory,$this.ValueType,$this.Name
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
    show-prog -message $p
    kubectl $command
}

function Get-Options {
    $text = Invoke-Kubectl "options" | ?{$_ -match " --"}
    return $text
}

function Parse-GeneralHelp
{
    # first generate the output
    $text = Invoke-Kubectl "--help"
}


function parse-helppage
{
    param ( $text )
}

$r = Get-Options
$r.Foreach({[ParameterInfo]::new($_, $false)})
