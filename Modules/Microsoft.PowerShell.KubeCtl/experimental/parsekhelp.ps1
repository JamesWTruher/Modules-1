# using module ./KubectlHelpParser.psm1
import-module -force ./KubectlHelpParser.psm1
#$r = Get-Options
#$r.Foreach({[ParameterInfo]::new($_, $false)})
$r = Parse-GeneralHelp
$r
# $c = Parse-CommandHelp plugin,list
$c2 = Parse-CommandHelp version


# $null -eq $c
$null -eq $c2
