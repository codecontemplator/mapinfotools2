function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

pushd $(Get-ScriptDirectory)
dir .\testdata\*.tfw | & .\tfw2tab.ps1 -coordsys "CoordSys Earth Projection 8, 112, `"m`", 15.8082777778, 0, 1, 1500000, 0"
popd