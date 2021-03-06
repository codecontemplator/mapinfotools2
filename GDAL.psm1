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

function Get-ImagePropertiesUsingGDAL($fileName)
{    
    $dataset = [OSGeo.GDAL.Gdal]::Open( $fileName, [OSGeo.GDAL.Access]::GA_ReadOnly );
    if ($dataset)
    {
        # create result object
        $result = New-Object PSObject 
        
        # add image dimensions
        $result | Add-Member NoteProperty Width $dataset.RasterXSize
        $result | Add-Member NoteProperty Height $dataset.RasterYSize

        # add color table if available
        $band = $dataset.GetRasterBand(1);
        $colorTableGdal = $band.GetColorTable();
        if ($colorTableGdal -and $colorTableGdal.GetPaletteInterpretation() -eq [OSGeo.GDAL.PaletteInterp]::GPI_RGB)
        {
            $numColors = $colorTableGdal.GetCount()-1
            $colorTable = 0..$numColors | % {
                $e = $colorTableGdal.GetColorEntry($_)
                New-Object PSObject -Property @{ R=$e.C1; G=$e.C2; B=$e.C3; A=$e.C4 }
            }
            
            $result | Add-Member NoteProperty ColorTable $colorTable
        }

        # cleanup and return result        
        $dataset.Dispose()
        return $result
    }
}

try
{
    InitializeFwTools
    Export-ModuleMember Get-ImagePropertiesUsingGDAL
}
catch
{
}
