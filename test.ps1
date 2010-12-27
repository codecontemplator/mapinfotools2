# http://leftlobed.wordpress.com/2008/06/04/getting-the-current-script-directory-in-powershell/  

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
dir .\testdata\*.tab | & .\new-seamlesstable.ps1 -tab2tab ".\tab2tab.exe" -target .\seamless.tab

# test create seamless for oversiktskartan
dir .\Oversiktskartan\*.tab | & .\new-seamlesstable.ps1 -tab2tab ".\tab2tab.exe" -target .\Oversiktskartan\seamless.tab

# deinitialize
popd