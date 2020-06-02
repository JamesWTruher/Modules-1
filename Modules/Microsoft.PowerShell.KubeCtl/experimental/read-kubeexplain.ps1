param ( $resourceType )

class Field {
    # the patterns which designate the different parts of the output
    # These will change based on the specific tool
    static [hashtable]$Tokens = @{
        NameType    = "^   [a-z]"
        Description = "^     "
        Url         = ".*More info: "
    }
    [string]$FieldName
    [string]$FieldType
    [string]$Description
    [Uri]$HelpUrl
    Field([string]$name, [string]$type, [string]$description ) {
        $this.FieldName = $name
        $this.FieldType = $type
        $this.Description = $description
        $this.HelpUrl = $description -replace [Field]::tokens.Url
    }
    static [char[]]$separators = " ","`t"
    static [Field[]]GetFields([string[]]$text) {
        $list = [System.Collections.Generic.List[Field]]::new()
        $fName = $fType = $dText = ""
        for ( $i = 0; $i -lt $text.count; $i++ ) {
            if ( $text[$i] -match [Field]::Tokens.NameType ) {
                $fName,$fType = $text[$i].Split([Field]::separators, [StringSplitOptions]::RemoveEmptyEntries)
            }
            elseif ( $text[$i] -match [Field]::Tokens.Description ) {
                $desc = @()
                while ( $t = ([string]($text[$i])) ) {
                    $desc += "$t".Trim()
                    $i++
                }
                $dText = $desc -join " "
                $list.Add([Field]::new($fName, $fType, $dText))
                $fName = $fType = $dText = ""
            }
        }
        return $list.ToArray()
    }
}

class ExplainText {
    # the patterns which designate the different parts of the output
    # These will change based on the specific tool
    static [hashtable]$tokens = @{
        KindToken        = "^KIND:"
        VersionToken     = "^VERSION:"
        DescriptionToken = "^DESCRIPTION:"
        FieldToken       = "^FIELDS:"
    }
    [string]$Kind
    [string]$Version
    [string]$Description
    [Field[]]$Fields
    ExplainText([string[]]$Text) {
        for($i = 0; $i -lt $text.count; $i++ ) {
            if ( $text[$i] -match [ExplainText]::tokens.KindToken ) {
                $v = $text[$i] -replace [ExplainText]::tokens.KindToken
                $this.Kind = "$v".Trim()
            }
            elseif ( $text[$i] -match [ExplainText]::tokens.VersionToken ) {
                $v = $text[$i] -replace [ExplainText]::tokens.VersionToken
                $this.Version = "$v".Trim()
            }
            elseif ( $text[$i] -match [ExplainText]::tokens.DescriptionToken ) {
                $i++
                $desc = @()
                while($text[$i]) {
                    $desc += $text[$i].Trim()
                    $i++
                }
                $this.Description = $desc -join " "
            }
            elseif ( $text[$i] -match [ExplainText]::tokens.FieldToken ) {
                $this.Fields = [Field]::GetFields($text[$i..($text.length)])
            }
        }
    }

}


$text = kubectl explain $resourceType 2>&1
[ExplainText]::new($text)

