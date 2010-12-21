function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

# initialize
pushd $(Get-ScriptDirectory)

# remove old data
del .\testdata\*.tab 
del seamless.*

# test tfw2tab
dir .\testdata\*.tfw | & .\tfw2tab.ps1 -coordsys "CoordSys Earth Projection 8, 112, `"m`", 15.8082777778, 0, 1, 1500000, 0"

# test create seamless
dir .\testdata\*.tab | & .\create-seamless-tab.ps1 -tab2tab ".\tab2tab.exe" -target .\seamless.tab

# deinitialize
popd