$TextInfo = [CultureInfo]::new("en-us",$false).TextInfo


function New-ClassConfigFile() {
$resources = get-kuberesource | Where-Object {$_.verbs -contains "get"}
$cmdletInfoAndOutput = $resources | ForEach-Object { $n = "get-kube{0}" -f $_.name; [pscustomobject]@{ Command = $n; Output = & $n}}
$objectHeaders = $cmdletInfoAndOutput | ForEach-Object {
    $rName = $_.Command -replace "get-kube"
    [pscustomobject]@{
        TypeName = $rName
        Fields = "$(kubectl get "$rName" --all-namespaces -o wide 2>&1|Select-Object -First 1)".split("  ",[stringsplitoptions]::removeEmptyEntries)|
            ForEach-Object { "$_".trim() } | # trim extra white space
            ForEach-Object {
                $propertyName = "$_" -replace " ",""
                if ( $propertyName -eq "Name" -or $propertyName -eq "Namespace" ) {
                    $propertyReference = '$_.metadata.' + $propertyName
                }
                else {
                    $propertyReference = '$_.<ReplaceWithProperty>'
                }
                [pscustomobject]@{ PropertyName = $propertyName; PropertyReference = $propertyReference }
            }
        }
    }

    $tmpConfigJson = [io.path]::GetTempFileName()
    remove-item $tmpConfigJson
    $tmpConfigJson = $tmpConfigJson -replace "tmp$","json"
    $objectHeaders | ConvertTo-Json -Depth 4 | Set-Content $tmpConfigJson
    return $tmpConfigJson
}

function Get-ClassDefinition ( [psobject]$configuration, [ref]$className ) {
    $outputType = $configuration.TypeName
    $className.Value = $outputType
    'class ' + $outputType + " {"
    '# fields'
    $configuration.Fields.Foreach({'    [object]$' + $textinfo.ToTitleCase($_.PropertyName.ToLower())})
    '# originalObject member'
    '    hidden [psobject]$originalObject'
    ""
    '# constructor'
    "    $outputType ([pscustomobject]`$o) {"
    '    if ( $env:DebugAutoConstructor -eq $true ) {'
    '        wait-debugger'
    '    }'
    $configuration.Fields.Foreach({'        $this.' +  $textinfo.ToTitleCase($_.PropertyName.ToLower()) + ' = ' + $_.PropertyReference})
    '        $this.originalObject = $o'
    '    }'
    '}'
}

$kClassConfigFile = New-ClassConfigFile
$kClassConfig = Get-Content $kClassConfigFile | convertfrom-json




foreach ( $toolType in $kClassConfig[0] ) {
    [ref]$className = ""
    $classdef = Get-ClassDefinition $toolType $className

    if ( ! ("$className" -as [type]) ) {
        Invoke-Expression -command ($classdef -join "`n")
    }

}

$data = get-content ./kubeoutput.json | ConvertFrom-Json

foreach ( $oo in $data[0].output ) {
    [componentstatuses]::new($oo)
}

function new-TableView([pscustomobject]$configuration, [switch]$standAlone) {
    if ( $standAlone ) {
    '<Configuration>'
    '  <ViewDefinitions>'
    }
    '    <View>'
    '     <Name>{0}Table</Name>' -f $configuration.TypeName
    '     <ViewSelectedBy>'
    '      <TypeName>{0}</TypeName>' -f $configuration.TypeName
    '     </ViewSelectedBy>'
    '     <TableControl>'
    '      <TableHeaders>'
    $configuration.Fields.Foreach({'         <TableColumnHeader><Label>{0}</Label></TableColumnHeader>' -f $textInfo.ToTitleCase($_.PropertyName.ToLower())})
    '      </TableHeaders>'
    '      <TableRowEntries>'
    '       <TableRowEntry>'
    '        <TableColumnItems>'
    $configuration.Fields.Foreach({'         <TableColumnItem><PropertyName>{0}</PropertyName></TableColumnItem>' -f $textInfo.ToTitleCase($_.PropertyName.ToLower())})
    '        </TableColumnItems>'
    '       </TableRowEntry>'
    '      </TableRowEntries>'
    '     </TableControl>'
    '    </View>'
    if ( $standAlone ) {
    '  </ViewDefinitions>'
    '</Configuration>'
    }
}