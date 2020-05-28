
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

$LOGFILE = "/tmp/kubewrapper.log"
function Write-Log ( [Parameter(position=0,mandatory)][string]$message, [switch]$initialize ) {
    # just put a couple of newlines at the beginning to ease finding the start
    if ( $initialize ) { "`n`n" | out-file -append $LOGFILE }
    "$(get-date) : $message" | out-file -append $LOGFILE
}

Write-Log "====== START RUN $(get-date) ======" -init

$USAGE_STRING = "^Usage:"

function Invoke-Kubectl {
    param ( [Parameter(ValueFromRemainingArguments,Position=0,Mandatory=$true)][string[]]$command )
    $p = "kubectl $($command -join ' ')"
    show-prog -message $p
    kubectl $command
}

function Get-CommandAndHelp
{
    param ([string]$text)
    $command,$help = "$text".Trim().Split(" ",2, [System.StringSplitOptions]::RemoveEmptyEntries)
    @{ Command = $command; Help = $help }
}

function Get-Usage
{
    param ( [string[]]$helpText )
    $result = ""
    for($i = 0; $i -lt $helpText.Count; $i++ ) {
        if ( $helpText[$i] -match "${USAGE_STRING}" ) {
            $i++
            do {
                $result += $helpText[$i]
            } until ( $helpText[$i++].Trim() -eq "" -or $i -ge $helpText.Count)
        }
        elseif ( $helpText[$i] -match "AvailableCommands") {
        }
    }
    return $result
}

function Get-SubTopics
{
    param ( $command )
    $text = Invoke-KubeCtl $command --help
    for ( $i = 0; $i -lt $text.Count; $i++) {
        if ( $text[$i] -match "Available Commands:") {
            $i++
            do {
                Get-CommandAndHelp $text[$i++]
            } until ( $text[$i].Trim() -eq "")
            break;
        }
    }
}

$o = Invoke-Kubectl --help 
$availableTopics = "Basic Commands (Beginner):", "Basic Commands (Intermediate):", "Deploy Commands:", "Cluster Management Commands:",
    "Troubleshooting and Debugging Commands:", "Advanced Commands:", "Settings Commands:", "Other Commands:"
$topics = @()

for( $i = 0; $i -lt $o.count ; $i++ ) {
    if ( $availableTopics -contains $o[$i]) {
        $i++
        while ( $o[$i] -ne "" ) {
            $topics += Get-CommandAndHelp ($o[$i++])
        }
    }
}

write-log -init "Main collection done"

foreach ( $topic in $topics ) {
    $ctext = Invoke-KubeCtl $topic.Command --help
    $usage = Get-Usage $ctext
    $topic['Usage'] = "${usage}".Trim()
    $subtopics = Get-SubTopics -command $topic.Command
    $topic['Subtopics'] = $subtopics
    $subTopicUsage = @()
    foreach ( $subtopic in $subtopics ) {
        $stext = Invoke-KubeCtl $topic.Command $subtopic.Command --help
        $subTopicUsage += Get-Usage $stext
    }
    $topic['SubTopicUsage'] = $subTopicUsage
}
$topics.ForEach({[pscustomobject]$_})
