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

function Get-ClassDefinition ( [psobject]$configuration, [ref]$className )
{
    $outputType = $configuration.TypeName
    $className.Value = $outputType
    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine('class ' + $outputType + " {")
    $null = $sb.AppendLine('# fields')
    $null = $configuration.Fields.Foreach({$sb.AppendLine('    [object]$' + $textinfo.ToTitleCase($_.PropertyName.ToLower().Replace(" ","").Replace("-","")))})
    $null = $sb.AppendLine('    hidden [psobject]$originalObject')
    $null = $sb.AppendLine('# originalObject member')
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine('# constructor')
    $null = $sb.AppendLine("    $outputType ([pscustomobject]`$o) {")
    $null = $sb.AppendLine('    if ( $env:DebugAutoConstructor -eq $true ) {')
    $null = $sb.AppendLine('        wait-debugger')
    $null = $sb.AppendLine('    }')
    $null = $configuration.Fields.Foreach({$sb.AppendLine('        $this.' +  $textinfo.ToTitleCase($_.PropertyName.ToLower().Replace(" ","").Replace("-","")) + ' = ' + $_.PropertyReference)})
    $null = $sb.AppendLine('        $this.originalObject = $o')
    $null = $sb.AppendLine('    }')
    $null = $sb.AppendLine('}')
    return $sb.ToString()
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