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

There a many benefits in a complete rewrite of a command

#### Issues with Reimplementations

### API wrapping

#### Issues with API wrapping

### Native Application Wrapping

#### Issues with application wrapping

## Is there a better way?

## possibilities in wrapping
