# Problems of functionality coverage when using PowerShell

PowerShell provides a number of benefits to it's users

* consistent parameter naming for similar uses
* a single parameter parser so errors about mis-parameter use are consistent across all commands
* output consisting of objects (no text parsing)
* common way to get assistance
* <Jason can you fill in more details here?>

Some of these are not unique to PowerShell.
Of course, the tools on UNIX also provide some of these behaviors.
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

In the above example, the work of the script is broken into 2 sections.

* a section which gets the data from the REST endpoint
* a section which converts the json data into an object which has the specific properties I want to see

There are a few shortcuts in the first section:

* I'm not providing for parameter to retrieve different resources
* I'm not using any authentication
* I'm using what I already know with regard to the actual `url` to retrieve data

The second section which alters the data to a form I need by converting the json to a view I'm more comfortable with.
With regard to the output, I made a decision to handle the presentation of elapsed time in a way that most cmdlets do.

This approach casts the problem in the light of the developer again.
Much like re-implementation, there is a certain amount of code that is required just to _get_ the data,
and with this example I'm showing the absolute simplest case since I'm not doing any authentication and I _know what the endpoint to which I'm connecting.
The part that is familiar is the second part of the script which creates an object which I can use with our other filters.
This can be done in many different ways, I could have written this code using `Select-Object` as follows:

```powershell
$data.Items | Select-Object -Property @{ N = "Name"; E = {$_.metadata.Name}},
     @{ N = "Ready"; E = { "{0}/{1}" -f ($_.item.status.conditions|Where-Object {$_.Ready -eq "True"}).Count, $_.status.containerstatuses.count}},
     @{ N = "Status"; E = { @($_.status.containerstatuses.state.terminated.reason)[-1]}},
     @{ N = "Restarts"; E = { $_.status.containerstatuses.restartcount}},
     @{ N = "Age"; E = { [DateTime]::now.touniversaltime() - [datetime]($_.status.conditions.lastTransitionTime[-1])}}
```

Regardless of how it's written, I believe that the second section is well understood by most PowerShell scripters,
but the first section is less known and needs knowledge about the service and how to authenticate.

*However*, I think the biggest issue with this approach is that for anything complicated (or anything more complicated than simple "gets") is that the REST APIs are developer constructs _made for developers_.
This means that if you want to use these REST APIs, you need to put on a developer hat and produce a solution which has a different set of problems.
This is what the developer did initially; He took the available APIs (REST or otherwise) and built up the administrative experience in the application,
sheltering the admin from the programming problems.
In the kubernetes example above, if I needed to query the REST endpoint to see what types of resources were available, that means more calls back and forth from the service.

_Jason - I don't have anything here_
TODO - I use to have (at the tip of my tongue) an example of swagger cmdlets that showed the developers view -- this came up years ago for a while....  If you happen to know of a today example -- maybe it would be great to reference -- but i will see if I can find soemthing as well.

### Native Application Wrapping

Because it is possible to call native applications easily from within PowerShell it is possible to write a script which provides a more PowerShell-like experience.
It can provide parameter handling such as prompting for mandatory parameters and tab-completion for parameter values.
It can take the application output and use the text output into objects so it can take advantage of all the post processing tools such as `Sort-Object`, `Where-Object`, etc.

if we look at the above example, the script can be greatly simplified and written as follows

```powershell
$data = kubectl get pods -o json | ConvertFrom-Json
$data.Items | Select-Object -Property @{ N = "Name"; E = {$_.metadata.Name}},
     @{ N = "Ready";    E = { "{0}/{1}" -f ($_.item.status.conditions|Where-Object {$_.Ready -eq "True"}).Count, $_.status.containerstatuses.count}},
     @{ N = "Status";   E = { @($_.status.containerstatuses.state.terminated.reason)[-1]}},
     @{ N = "Restarts"; E = { $_.status.containerstatuses.restartcount}},
     @{ N = "Age";      E = { [DateTime]::now.touniversaltime() - [datetime]($_.status.conditions.lastTransitionTime[-1])}}
```

When applicatons have a choice of output types, it is easy to use PowerShell tools to convert (in this case) json to an object,
and then we have the same code for presenting the data the way we want it.

This approach has some advantages:

* We avoid the entire problem of how to authenticate to access the data
  * We are protected from changes in the service and API endpoint
* Small changes in the tool can be easily managed by simple changes to the script
* If the application is supports uniform cross-platform execution, the wrapper can be easy run on whatever platform is needed

_Jason - not sure what more I should add here_
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
There is some programming needed to convert the text output to objects so they can participate in the PowerShell pipelines.
A significant difference is that unlike the REST approach, I don't have extra work determining _how_ to invoke the app, I can just invoke it.
Further, it seems a more natural use of the tool; I'm familiar with the workings of the tool, I'm just parsing the output into objects.
It's important to note that if the tool emits `json`, `xml`, or other structured data, a lot less effort would be needed to create the objects that I want.

## Is there a better way

It may be possible to create a framework which inspects the help of the application and _automatically_ create the code which calls the underlying application.
This framework can also handle the output mapping to an object more suitable for the PowerShell environment.

## possibilities in wrapping

The aspect which makes this possible is that some commands have regular, consistent help which describes how the application can be used.
If this is the case, then we can iteratively call the help, parse it,
and automatically construct much of the infrastructure needed to allow these native applications to be encorporated into the PowerShell environment.

### First Experiment - Module Microsoft.PowerShell.Kubectl

I created a wrapper for to take the output of `kubectl api-resources` and create functions for each returned resource.
This way, instead of running `kubectl get pod`, I could run `Get-KubectlPod` (a much more _PowerShell_ like experience).
I also wanted to have the function return objects which I could then use the other PowerShell tools (where-object, foreach-object, etc).
To do this, I needed a way to map the output (json) from the `kubectl` tool to PowerShell objects.
I decided that a reasonable approach for this was to use a more declarative to map the property in the json to a PowerShell class member.

There were some problems that I wanted to solve with this first experiment

* wrap `kubectl api-resources` in a function
  * automatically create object output from `kubectl api-resources`
* Auto-generate functions for each resource which could be retrieved (only resource get for now)
  * only support `name` as a parameter
* Auto-generate the conversion of output to objects to look similar to the usual `kubectl` output

When it came to wrapping `kubectl api-resources` I took the static approach rather than auto generation.
First, because it was my first attempt so I was still finding my feet.
Second, because this is one of the `kubectl` commands which does not emit jason,
so I took the path of parsing the output of `kubectl api-resources -o wide`.
My concern is that I wasn't sure whether the table changes width based on the screen width.
I calculated column positions based on the fields I knew to be present and then sent the line with the offsets off to be parsed.
You can see the code in the function `get-kuberesource` and the constructor for the PowerShell class `KubeResource`.
My plan was that these resources would drive the auto-generation of the Kubernetes resource functions.

Now that I have the resources retrieved, I can auto-generate specific resource function for calling the `kubectl get <resource>`.
At the time, I wanted some flexibility in the creation of these proxy functions,
so I provided a way to include a specific implementation, if desired (see the `$proxyFunctions` hashtable).
I'm not sure that's needed now, but we'll get to that later.
The problem is that while the resource data can be returned as json, that json has absolutely no relation to the way the
data is represented in the `kubectl get pod` table.
I want to return the data as objects, I created classes for a couple resources by hand, but thought there might be a better way.

I determined that when you get data from kubernetes, the table (both normal and wide) output _is created on the server_.
This means the mapping of the properties of the json object to the table columns is defined in the server code.
It is possible to provide data as custom columns, but you need to provide the value for the column with a json path expression,
so it's not possible to automatically generate those tables.
I thought it might be possible to provide a configuration file which could be read to automatically generate a PowerShell class
which would include the name of the column and the expression to get the value for the object.
This would allow a user to retrieve the json object and construct their custom object without touching the programming logic
of the module but a configuration file.
I created the `ResourceConfiguration.json` file to encapsulate all the resources that I had access to and provide a way where
the object members can be customized where desired.

here's an example:

```json
  {
    "TypeName": "namespaces",
    "Fields": [
      {
        "PropertyName": "NAME",
        "PropertyReference": "$o.metadata.NAME"
      },
      {
        "PropertyName": "STATUS",
        "PropertyReference": "$o.status.phase"
      },
      {
        "PropertyName": "AGE",
        "PropertyReference": "$o.metadata.creationTimeStamp"
      }
    ]
  },
```

This json is converted into a PowerShell class whose constructor takes the json object and assigns the values to the members,
according to the `PropertyReference`.
The module automatically attaches the original json to a hidden member `originalObject` so if you want to inspect
all the data that's available, you can.
The module also automatically generates a proxy function so you can get the data:

```powershell
function Get-KubeNamespace
{
  [CmdletBinding()]
  param ()
  (Invoke-KubeCtl -Verb get -resource namespaces).Foreach({[namespaces]::new($_)})
}
```

This function is then exported so it's available in the module.
When used, it behaves very close to the original:

```powershell
PS> Get-KubeNamespace

Name                 Status Age
----                 ------ ---
default              Active 5/6/2020 6:13:07 PM
default-mem-example  Active 5/14/2020 8:14:45 PM
docker               Active 5/6/2020 6:14:25 PM
kube-node-lease      Active 5/6/2020 6:13:05 PM
kube-public          Active 5/6/2020 6:13:05 PM
kube-system          Active 5/6/2020 6:13:05 PM
kubernetes-dashboard Active 5/18/2020 8:44:01 PM
openfaas             Active 5/6/2020 6:51:22 PM
openfaas-fn          Active 5/6/2020 6:51:22 PM

PS> kubectl get namespaces --all-namespaces

NAME                   STATUS   AGE
default                Active   26d
default-mem-example    Active   18d
docker                 Active   26d
kube-node-lease        Active   26d
kube-public            Active   26d
kube-system            Active   26d
kubernetes-dashboard   Active   14d
openfaas               Active   26d
openfaas-fn            Active   26d
```

but importantly, I can use the output with `where-object` and `foreach-object` or change the format to list, etc.

```powershell
PS> Get-KubeNamespace |? name -match "faas"

Name        Status Age
----        ------ ---
openfaas    Active 5/6/2020 6:51:22 PM
openfaas-fn Active 5/6/2020 6:51:22 PM
```

### Second Experiment - Module KubectlHelpParser

I wanted to see if I could read any help content from `kubectl` which would enable me to auto-generate a complete
proxy to the `kubectl` command which included general parameters, command specific parameters, and help.
It turns out that `kubectl` help is regular enough where this is quite possible.

When retrieving help, kubectl may provide subcommands which also has structured help.
I created a recursive parser which allowed me to retrieve all of the help for all of the available kubectl commands.
This means that if an additional command is provided in the future, and the help for that command follows the
existing pattern for help, this parser will be able to generate a command for it.

```powershell
PS> kubectl --help
kubectl controls the Kubernetes cluster manager.

 Find more information at: https://kubernetes.io/docs/reference/kubectl/overview/

Basic Commands (Beginner):
  create         Create a resource from a file or from stdin.
  expose         Take a replication controller, service, deployment or pod and expose it as a new Kubernetes Service
  run            Run a particular image on the cluster
  set            Set specific features on objects

Basic Commands (Intermediate):
  explain        Documentation of resources
  get            Display one or many resources
. . .

kubectl set --help

PS> kubectl set --help

Configure application resources

 These commands help you make changes to existing application resources.

Available Commands:
  env            Update environment variables on a pod template
  . . .
  subject        Update User, Group or ServiceAccount in a RoleBinding/ClusterRoleBinding

Usage:
  kubectl set SUBCOMMAND [options]

PS> kubectl set env --help 

Update environment variables on a pod template.

 List environment variable definitions in one or more pods, pod templates. Add, update, or remove container environment
variable definitions in one or more pod templates (within replication controllers or deployment configurations). View or
modify the environment variable definitions on all containers in the specified pods or pod templates, or just those that
match a wildcard.

 If "--env -" is passed, environment variables can be read from STDIN using the standard env syntax.

 Possible resources include (case insensitive):

  pod (po), replicationcontroller (rc), deployment (deploy), daemonset (ds), job, replicaset (rs)

Examples:
  # Update deployment 'registry' with a new environment variable
  kubectl set env deployment/registry STORAGE_DIR=/local
  . . .
  # Set some of the local shell environment into a deployment config on the server
  env | grep RAILS_ | kubectl set env -e - deployment/registry

Options:
      --all=false: If true, select all resources in the namespace of the specified resource types
      --allow-missing-template-keys=true: If true, ignore any errors in templates when a field or map key is missing in
the template. Only applies to golang and jsonpath output formats.
  . . .
      --template='': Template string or path to template file to use when -o=go-template, -o=go-template-file. The
template format is golang templates [http://golang.org/pkg/text/template/#pkg-overview].

Usage:
  kubectl set env RESOURCE/NAME KEY_1=VAL_1 ... KEY_N=VAL_N [options]

Use "kubectl options" for a list of global command-line options (applies to all commands).
```

The main function of the module will recursively collect the help for all of the commands, and construct an
object representation which I hope can then be used to generate the proxy functions.
This is still very much a work in progress, but it is definitely showing promise.
Here's an example of what it can already do.

```powershell
PS> import-module ./khp2.psm1
 PS> import-module ./KHP2.psm1 -force

[Modules-1|kubectl↑0↓0•0+2?5] PS> $res = get-kubecommands           

VERBOSE: kubectl --help
VERBOSE: kubectl  create --help
. . .
VERBOSE: kubectl  set --help
VERBOSE: kubectl  set env --help
VERBOSE: kubectl  set image --help
VERBOSE: kubectl  set resources --help
VERBOSE: kubectl  set selector --help
. . .
VERBOSE: kubectl  plugin --help
VERBOSE: kubectl  plugin list --help
VERBOSE: kubectl  version --help

PS> $res.subcommands[3].subcommands[0]

Command             : set env
CommandElements     : {, set, env}
Description         : Update environment variables on a pod template.
                      
                       List environment variable definitions in one or more pods, pod templates. Add, update, or remove container environment variable definitions in one or more pod templates (within replication controllers or deployment configurations). View or modify the environment variable definitions 
                      on all containers in the specified pods or pod templates, or just those that match a wildcard.
                      
                       If "--env -" is passed, environment variables can be read from STDIN using the standard env syntax.
                      
                       Possible resources include (case insensitive):
                      
                        pod (po), replicationcontroller (rc), deployment (deploy), daemonset (ds), job, replicaset (rs)
Usage               : kubectl set env RESOURCE/NAME KEY_1=VAL_1 ... KEY_N=VAL_N [options]
SubCommands         : {}
Parameters          : {[Parameter(Mandatory=$False)][switch]${All}, [Parameter(Mandatory=$False)][switch]${NoAllowMissingTemplateKeys}, [Parameter(Mandatory=$False)][System.String]${Containers} = "*", [Parameter(Mandatory=$False)][switch]${WhatIf}…}
MandatoryParameters : {}
Examples            : {kubectl set env deployment/registry STORAGE_DIR=/local, kubectl set env deployment/sample-build --list, kubectl set env pods --all --list, kubectl set env deployment/sample-build STORAGE_DIR=/data -o yaml…}

PS> $res.subcommands[3].subcommands[0].usage   
Usage                                                               supportsFlags hasOptions
-----                                                               ------------- ----------
kubectl set env RESOURCE/NAME KEY_1=VAL_1 ... KEY_N=VAL_N [options]         False       True

PS> $res.subcommands[3].subcommands[0].examples
Description                                                   Command
-----------                                                   -------
Update deployment 'registry' with a new environment variable  kubectl set env deployment/registry STORAGE_DIR=/local
. . .

PS> $res.subcommands[3].subcommands[0].parameters.Foreach({$_.tostring()})

[Parameter(Mandatory=$False)][switch]${All}
[Parameter(Mandatory=$False)][switch]${NoAllowMissingTemplateKeys}
[Parameter(Mandatory=$False)][System.String]${Containers} = "*"
[Parameter(Mandatory=$False)][switch]${WhatIf}
. . .
[Parameter(Mandatory=$False)][System.String]${Selector}
[Parameter(Mandatory=$False)][System.String]${Template}

```

There are still a lot of open questions and details to work out here:

* how are mandatory parameters determined?
* how do we keep a map of used parameters?
* does parameter order matter?
* can resonable debugging be provided?
* do we have to "boil the ocean" to provide something useful?

## Call To Action

First, I'really interested if having a framework which can autogenerate functions which wrap a native executable is useful?
The obvious response might be "of course", but how much of a solution is really needed to provide value?

**Jason** can you think of additional things here in the call to action?

## Is this framework something you will continue to build commands with

Jim, just adding some thought notes.  Always available to discuss with you and help out.

Our focus is on providing the community with an extensable framework to build powershell-style cmdlets from common commands.  While we may supply some commands (kubectl, docker), our hope is that the community will adopt the framework and build commands as needed.

* Is an extensible framework for building commands needed? Why?
* If so, what commands should be considered in the near term? Why those commands? How often do you use/script them?
