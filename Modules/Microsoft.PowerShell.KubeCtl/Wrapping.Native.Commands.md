# Problems of functionality coverage when using PowerShell

PowerShell provides a number of benefits to it's users

* consistent parameter naming for similar uses
* a single parameter parser so errors about mis-parameter use are consistent across all commands
* output consisting of objects (no text parsing)
* common way to get assistance
* ...
* ...

Some of these are not unique to PowerShell.
Of course, the tools on UNIX also address some of these behaviors.
Specifically, UNIX systems have man pages and the _mostly_ ubiquitous `--help` for getting assistance directly from the command.

However, PowerShell does not have cmdlets for all aspects of administration on all platforms it is now available.
There are a number of very excellent and needed tools which target the scenarios for administration and management very well.
Some of these tools have existed for many years and have grown in functionality and complexity including their own 'mini-language'.
Examples of these include:

* Package managers such as `apt`, `yum`, `brew`
* The Microsoft Windows utilities `net`, `netsh`
* Source control applications such as `git`
* The utility for Docker management `docker`
* The utility for Kubernetes management `kubectl`

## Solution Options

To achieve coverage for tools that participate fully in the PowerShell ecosystem, only a few options exist:

* You can re-implement the tool in managed code or script
* You can call web based apis. SWAGGER provides a very easy way to do this
* You can wrap the native application in a powershell script 

### Reimplementation

There a many benefits in a complete rewrite of a command:

* The expression of behavior can be made more "native"
* ...

#### Issues with Reimplementations

The biggest issue with reimplementation is probably the amount of work that is needed to achieve behavior expressed in the original.
This is especially the case if the reimplementor is not intimately familiar with the workings of the tool.

### API wrapping

Many native apps use a REST endpoint to retrieve data.
These can be used to interact with the data end point, retrieve data from it and then present it to the user.
For example, the following shows how you could present the data about kubernetes pods by interacting with the REST end point and display the data.
In comparison is the output from the native command.

```powershell
kubectl get pods; get-pods.ps1|ft

NAME                     READY   STATUS      RESTARTS   AGE
hello-1589924940-rv2v2   0/1     Completed   0          3m5s
hello-1589925000-gs5n7   0/1     Completed   0          2m5s
hello-1589925060-j4bjc   0/1     Completed   0          65s
hello-1589925120-jvxtd   0/1     Completed   0          4s

Name                   Ready Status    Restarts Age
----                   ----- ------    -------- ---
hello-1589925000-gs5n7 0/1   Completed        0 00:02:05.2602110
hello-1589925060-j4bjc 0/1   Completed        0 00:01:05.2607090
hello-1589925120-jvxtd 0/1   Completed        0 00:00:04.2612030
```

#### Issues with API wrapping

The most impactful issues with this approach are about authentication and complexity.
The script which produced the output can be used to illustrate some of the problems with this approach

```powershell

# retrieve data from REST endpoint
$baseUrl = "http://127.0.0.1:8001"
$urlPathBase = "api/v1/namespaces/default"
$urlResourceName = "pods"
$url = "${baseUrl}/${urlPathBase}/${urlResourceName}"
$data = (invoke-webrequest ${url}).Content | ConvertFrom-Json

# manipulate data for output
foreach ( $item in $data.Items ) {
    $replicaCount = $item.status.containerstatuses.count
    $replicaReadyCount = ($item.status.conditions | Where-Object {$_.Ready -eq "True"}).Count
    $Age = [datetime]::now.touniversaltime() - ([datetime]$item.status.conditions.lastTransitionTime[-1])
    [pscustomobject]@{
        Name     = $item.metadata.name
        Ready    = "{0}/{1}" -f $replicaReadyCount, $replicaCount
        Status   = @($item.status.containerstatuses.state.terminated.reason)[-1]
        Restarts = $item.status.containerstatuses.restartcount
        Age      = $age
        }
}
```

In the above example, there's 2 sections. First the section which gets the data from the REST endpoint and the second which changes the data into a usable form.
There a couple of shortcuts in the first section:

* I'm not using any authentication
* I'm using what I already know with regard to the actual `url` to retrieve data

The second section which alters the data to a form I need by converting the json to a view I'm more comfortable with.
With regard to the output, I'm not handling the presentation of elapsed time the same way that the native tool does.

This approach casts the problem in the light of the developer again.
Much like re-implementation, there is a certain amount of code that is required just to _get_ the data,
and with this example I'm showing the absolute simplest case since I'm not doing any authentication and I _know what the endpoint to which I'm connecting.

I believe that the second section is well understood by PowerShell scripters, but the first section is less well known.

*However*, I think the biggest issue with this approach is that for anything complicated (or anything more complicated than simple "gets") is that the REST APIs are developer constructs _made for developers_.
This means that if you want to use these REST APIs, you need to put on a developer hat and produce a solution with a different set of problems.
This is what the developer did initially; He took the available APIs (REST or otherwise) and built up the administrative experience in the application,
sheltering the admin from the programming problems.
In the kubernetes example above, if I needed to query the REST enddpoint to see what types of resources were available, that means more calls back and forth from the service.


### Native Application Wrapping

#### Issues with application wrapping

## Is there a better way

It may be possible to create a framework which inspects the output of the help of utility and _automatically_ create the code which uses

## possibilities in wrapping

## Is this framework something you will continue to build commands with?

Jim, just adding some thought notes.  Always available to discuss with you and help out.

Our focus is on providing the community with an extensable framework to build powershell-style cmdlets from common commands.  While we may supply some commands (kubectl, docker), our hope is that the community will adopt the framework and build commands as needed. 
  - Is an extensable framework for building commands needed? Why?
  - If so, what commands should be considered in the near term? Why those commands? How often do you use/script them?
