class Readiness {
    [int]$Count
    [int]$Ready
    [string]ToString() {
        return ("{0}/{1}" -f $this.count, $this.ready)
    }
    Readiness([string]$r) {
        $this.Count,$this.Ready = $r.Split("/")
    }
    Readiness([int]$c, [int]$r) {
        $this.count = $c
        $this.Ready = $r
    }
}

class Deployment
{

    hidden [pscustomobject]$OriginalObject
    [string]$Namespace
    [string]$Name
    [Readiness]$Readiness
    [int]$Updated
    [int]$Available
    [DateTime]$StartDate
    Deployment ( [pscustomobject]$o ) {
        $this.OriginalObject = $o
        $this.Namespace =  $o.metadata.namespace
        $this.Name = $o.metadata.name
        $this.Readiness = [Readiness]::new($o.status.replicas,$o.status.readyreplicas)
        $this.Updated = $o.status.updatedReplicas
        $this.Available = $o.status.availableReplicas
        $this.StartDate = $o.metadata.creationTimestamp
    }
}

function Get-KubeDeployment 
{
    param ( $name = ".*" )
    $items = Invoke-KubeCtl -verb get -resource deployment
    $items.ForEach({[deployment]::new($_)}).Where({$_.name -match "$name"})
}

$proxyFunctions = @{
    "get:deployment" = {
        [CmdletBinding()]
        param ($name = ".*")
        $items = Invoke-KubeCtl -verb get -resource deployment
        $items.ForEach({[deployment]::new($_)}).Where({$_.name -match "$name"})
        }
    
    "get:pods" = {
        [CmdletBinding()]
        param ( $name = ".*" )
        $items = Invoke-KubeCtl -verb get -resource pod
        $items.foreach({[Pod]::new($_)}).Where({$_.Name -match $name})
        }
}

# NAMESPACE     NAME                                      READY   STATUS      RESTARTS   AGE     IP           NODE            NOMINATED NODE   READINESS GATES
# kube-system   helm-install-traefik-z4j9n                0/1     Completed   1          2d18h   10.42.0.3    jwtraspbian04   <none>           <none>

class Pod {
    [string]$NameSpace
    [string]$Name
    [Readiness]$Ready
    [string]$Status
    [int]$Restarts
    [DateTime]$StartDate
    [URI]$Ip
    [string]$NodeName
    [string]$NominatedNode
    [string]$ReadinessGates
    hidden [pscustomobject]$OriginalObject
    Pod ([pscustomobject]$o ) {
        $this.OriginalObject = $o
        $this.Namespace = $o.metadata.namespace
        $this.name = $o.metadata.name
        $this.StartDate = $o.metadata.creationTimestamp
        $this.NodeName = $o.spec.nodeName
        $this.Ip = $o.status.podip
        $this.Restarts = ($o.status.containerStatuses.restartcount|measure-object -sum ).sum
        [int]$totalCount = $o.Status.containerStatuses.Count
        [int]$readyCount = $o.status.ContainerStatuses.State.running.Count
        $this.Ready = [Readiness]::new($totalCount, $readyCount)
        $this.Status = $o.status.phase
    }

}

function Get-KubePod2
{
    param ( $name = ".*" )
    $items = (kubectl get pods --all-namespaces -o json | ConvertFrom-Json).Items
    $items.foreach({[Pod]::new($_)}).Where({$_.Name -match $name})
}

class KubeResource {
    [string]$Name
    [string[]]$Shortnames
    [string]$ApiGroup
    [bool]$Namespaced
    [string]$Kind
    [string[]]$Verbs
    KubeResource([int[]]$offsets, $string)
    {
        $this.name = $string.substring($offsets[0],($offsets[1]-1)).Trim()
        $this.Shortnames = $string.substring($offsets[1],($offsets[2]-$offsets[1])).Replace(" ","").Split(",")
        $this.ApiGroup = $string.substring($offsets[2],($offsets[3]-$offsets[2])).Trim()
        $this.Namespaced = [bool]::Parse($string.substring($offsets[3],($offsets[4]-$offsets[3])).Trim())
        $this.Kind = $string.substring($offsets[4],($offsets[5]-$offsets[4])).Trim()
        $this.Verbs = $string.substring($offsets[5]).Replace("[","").Replace("]","").Split(" ")
    }
    [string]ToString()
    {
        return $this.Name
    }
}


$KUBERESOURCES = $null
if ( $global:DEFAULTSESSION ) {
    $DEFAULTSESSION = $global:DEFAULTSESSION
}
else {
    $DEFAULTSESSION = $null
}

if ( $global:DefaultRequireSudo ) {
    $DefaultRequireSudo = $global:DefaultRequireSudo
}
else {
    $DefaultRequireSudo = $false
}

function Set-DefaultPSSession
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ( [System.Management.Automation.Runspaces.PSSession]$Session )
    if ( $PSCmdlet.ShouldProcess("session")) {
        $script:DEFAULTSESSION = $Session
    }
}

function Get-DefaultPSSession
{
    [CmdletBinding()]
    param ()
    return $script:DEFAULTSESSION
}

function Get-KubeRequireSudo
{
    [CmdletBinding()]
    param ()
    return $script:DefaultRequireSudo
}

function Set-KubeRequireSudo
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param ( [bool]$RequireSudo )
    if ( $PSCmdlet.ShouldProcess("require sudo")) {
        $script:DefaultRequireSudo = $RequireSudo
    }
}

function Get-KubeResource
{
    [CmdletBinding()]
    param ( [string]$name = ".*" )
    # $res = kubectl api-resources -o wide
    if ( ! $script:KUBERESOURCES ) {
        write-debug "running!"
        $res = Invoke-KubeCtl -verb "" -resource "api-resources"  -noJson -arguments @("-o","wide") -noAllNamespace
        $FIELDS = "NAME","SHORTNAMES","APIGROUP","NAMESPACED","KIND","VERBS"
        $offsets = $FIELDS.ForEach({$res[0].IndexOf($_)})
        $script:KUBERESOURCES = $res[1..($res.count-1)].Foreach({[KubeResource]::new($offsets,$_)}).Where({$_.name -match $name})
    }
    return $script:KUBERESOURCES
}

function Initialize-ProxyFunction
{
    $r = Get-KubeResource
    export-modulemember -Function 'Get-KubeResource', 'Initialize-ProxyFunction', 'Get-DefaultPSSession', 'Set-DefaultPSSession', 'Get-KubeRequireSudo', 'Set-KubeRequireSudo'
    $getters = $r.where({ $_.verbs -contains "get" })
    $getters.foreach({
        $resource = $_.Name
        $proxyKey = "get:{0}" -f $resource
        $implementation = $proxyFunctions[$proxyKey]
        $functionName = "Get-Kube${resource}"
        if ( $implementation ) {
            [scriptblock]::Create("function global:${functionName} {
                    $implementation
                }").Invoke()
        }
        else {
            [scriptBlock]::Create("function global:$functionName {
                    [CmdletBinding()]
                    param ()
                    Invoke-KubeCtl -Verb get -resource $resource }").Invoke()
        }
        Export-ModuleMember -Function $functionName
    })

    <#
    [scriptblock]::Create('function global:get-kubepod { 
        param ( $name = ".*" )
        $items = Invoke-KubeCtl -verb get -resource pod
        $items.foreach({[Pod]::new($_)}).Where({$_.Name -match $name})
    } ').Invoke()
    Export-ModuleMember -Function get-kubepod
    #>
    # write-verbose -verbose "export?"
}

function Invoke-KubeCtl
{
    param ( 
        [switch]$requireSudo,
        [System.Management.Automation.Runspaces.PSSession]$session = $script:DEFAULTSESSION,
        [string]$verb,
        [string]$resource,
        [switch]$noJson,
        [switch]$noAllNamespace,
        [string[]]$arguments
        )

    [string[]]$action = @()
    if ( $requireSudo -or $script:DefaultRequireSudo) {
        $action += "sudo kubectl"
    }
    else {
        $action += "kubectl"
    }

    $action += $verb
    $action += $resource
    if ( ! $noAllNamespace ) {
        $action += "--all-namespaces"
    }
    if ( ! $noJson ) {
        $action += "-o","json"
    }
    $action += $arguments
    # create the script block to execute
    [scriptblock]$action = [scriptblock]::create($action)

    Write-Debug -Message ("SESSION IS NULL: {0}" -f $null -eq $script:DEFAULTSESSION)
    if ( $session ) {
        $result = invoke-command -session $session -scriptblock $action
    }
    else {
        $result = & $action
    }

    if ( ! $noJson ) {
        $convertedResult = $result | ConvertFrom-Json
        $convertedResult.Items
    }
    else {
        return $result
    }
}

Initialize-ProxyFunction
