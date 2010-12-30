Set-StrictMode -Version 2.0

# code copied from pscx to avoid dependecy
function Invoke-BatchFile
{
    param([string]$Path, [string]$Parameters)
    $tempFile = [IO.Path]::GetTempFileName()

    ## Store the output of cmd.exe.  We also ask cmd.exe to output
    ## the environment table after the batch file completes
    cmd.exe /c " `"$Path`" $Parameters && set > `"$tempFile`" "

    ## Go through the environment variables in the temp file.
    ## For each of them, set the variable in our local environment.
    Get-Content $tempFile | Foreach-Object {
        if ($_ -match "^(.*?)=(.*)$")
        {
            Set-Content "env:\$($matches[1])" $matches[2]
        }
    }

    Remove-Item $tempFile                       
}

function InitializeFwTools
{
    # get path to fwtools
    $fwtoolsPath = Dir $env:ProgramFiles\FWTools* | Select -first 1
    if (!$fwtoolsPath) {
        throw "Cannot find FWTools. Please make sure that the latest version of FWTools is installed."
    }
    
    # Initialize
    $setfw = Join-Path $fwtoolsPath "setfw.bat"
    Invoke-BatchFile $setfw
        
    # Load gdal c# wrappers
    $gdalcsharp = Join-Path $fwtoolsPath "csharp\gdal_csharp.dll"
    [System.Reflection.Assembly]::LoadFrom($gdalcsharp)
        
    # Register all drivers
    [OSGeo.GDAL.Gdal]::AllRegister()
}

function Get-ImageSizeGDAL($fileName)
{    
    $dataset = [OSGeo.GDAL.Gdal]::Open( $fileName, [OSGeo.GDAL.Access]::GA_ReadOnly );
    if ($dataset)
    {
        $result = New-Object PSObject 
        $result | Add-Member NoteProperty Width $dataset.RasterXSize
        $result | Add-Member NoteProperty Height $dataset.RasterYSize
        $dataset.Close()
        return $result
    }
}

try
{
    InitializeFwTools
    Export-ModuleMember Get-ImageSizeGDAL
}
catch
{
}
