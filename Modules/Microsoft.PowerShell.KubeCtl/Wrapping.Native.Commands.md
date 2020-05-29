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

However, PowerShell does not have cmdlets for all aspects of administration on all platforms. 
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

* The expression of behavior can be made more "native" to the new environment
* Performance issues can be addressed
* New code means that new technologies can be used advantageously

#### Issues with Reimplementations

The biggest issue with reimplementation is probably the amount of work that is needed to achieve behavior expressed in the original.
This is especially the case if the reimplementor is not intimately familiar with the workings of the tool.
Another issue with reimplementation is that you need to continue to track changes in the original code.
This can be a challenge as depending on the activity and updates in the tool, wholescale changes can occur which then need to be reimplemented,
or the reimplementation will be out of date.
Worse, if the the command is the client side of a client/server app, changes in the server may negatively effect the reimplementation.

TODO:  Jim, is it worth pointing out here that reimplementation is a short sighted view of the world - there will be updates to the original command functionality, sometimes very frequently.  My experience is that as a maintainer, my cost is rasied so high to maintain, that its not worth the initial time to develop the reimplenetation.  I guess this applies to wrapping teh command as well.

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
In the kubernetes example above, if I needed to query the REST endpoint to see what types of resources were available, that means more calls back and forth from the service.

TODO - I use to have (at the tip of my tongue) an example of swagger cmdlets that showed the developers view -- this came up years ago for a while....  If you happen to know of a today example -- maybe it would be great to reference -- but i will see if I can find soemthing as well.

### Native Application Wrapping

Because it is possible to call native applications easily from within PowerShell it is possible to write a script which provides a more PowerShell-like experience.
It can provide parameter handling such as prompting for mandatory parameters and tab-completion for parameter values.
It can take the application output and use the text output into objects so it can take advantage of all the post processing tools such as `Sort-Object`, `Where-Object`, etc.
This approach has some advantages:

* We are using an interface

TODO: Jim, in the above list, would it be also good to mention somethig like : It can update itself when the originating native command updates.

One of my first experiences with this was a very simple processes of getting information about pdf files with the tool `pdfinfo.exe`.
I needed to retrieve information from a very large set of set of PDF files (1000s).
I wrapped both the parameters and the output to have it behave much like a regular cmdlet.
Of course, I could have just used the native app, but I wanted a command I could pipe files to it and filter the results:

```powershell
$a = get-childitem -rec -filt *.pdf | Get-PdfInfo | Where-Object { $_.subject -like "sibelius" }
$sa | ft file,title,subject,pagesize

File           Title                        Subject            Pagesize
----           -----                        -------            --------
SIB08.pdf      Sibelius - Finlandia, Op. 26 Trumpet            720x936 pts
SIB08.pdf      Sibelius - Finlandia, Op. 26 Viola              720x936 pts
...
SIB08.pdf      Sibelius - Finlandia, Op. 26 Cello              720x936 pts
SIB08.pdf      Sibelius - Finlandia, Op. 26 Bassoon            720x936 pts
```

The point of all this was that I wanted a native PowerShell experience rather than the experience provided by the standalone application.

#### Issues with application wrapping

The issues are roughly the same as above, there is a certain amount of programming that is needed to call the application.
There is more programming needed to convert the text output to objects so they can participate in the PowerShell pipelines.
A significant difference is that unlike the REST approach, I don't have extra work determining _how_ to invoke the app, I can just invoke it.
Further, it seems a more natural use of the tool; I'm familiar with the workings of the tool, I'm just parsing the output into objects.
It's important to note that if the tool were to emit json or xml, a lot less effort would be needed to create the objects that I want.

## Is there a better way

It may be possible to create a framework which inspects the output of the help of utility and _automatically_ create the code which uses

## possibilities in wrapping

The aspect which makes this possible is that some commands have regular, consistent help which describes how the application can be used.
If this is the case, then we can iteratively call the help, parse it,
and automatically construct much of the infrastructure needed to allow these native applications to be encorporated into the PowerShell environment.

## Is this framework something you will continue to build commands with?

Jim, just adding some thought notes.  Always available to discuss with you and help out.

Our focus is on providing the community with an extensable framework to build powershell-style cmdlets from common commands.  While we may supply some commands (kubectl, docker), our hope is that the community will adopt the framework and build commands as needed. 
  - Is an extensable framework for building commands needed? Why?
  - If so, what commands should be considered in the near term? Why those commands? How often do you use/script them?
