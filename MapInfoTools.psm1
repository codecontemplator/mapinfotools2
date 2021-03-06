Set-StrictMode -Version 2.0

$settings = @{ ENABLE_GDAL = $true }

function Get-ImageProperties($fileName)
{
    if (!(Test-Path Variable:\ImageSizeCommand))
    {
        # try initializing gdal
        if ($settings["ENABLE_GDAL"])
        {        
            Import-Module $PSScriptRoot\GDAL
        }
        
        if (Test-Path Function:\Get-ImagePropertiesUsingGDAL)
        {
            $script:ImageSizeCommand = Get-Command Get-ImagePropertiesUsingGDAL
            Write-Verbose "Get-ImagePropertiesUsingGDAL command was found and will be used to determine image properties."
        }
        else
        {
            Add-Type -AssemblyName "System.Drawing"    
            $script:ImageSizeCommand = 
                {
                    param([string]$fileName)
                    $img = new-object System.Drawing.Bitmap -ArgumentList $fileName 
                    $imgprop = New-Object PSObject -Property @{ Width = $img.Width; Height = $img.Height }
                    if ($img.Palette)
                    {
                        $imgprop | Add-Member NoteProperty ColorTable $img.Palette.Entries
                    }
                    
                    $img.Dispose()
                    $imgprop                
                }
            Write-Verbose ".NET Bitmap class will be used to determine image properties."
        }        
    }
    
    & $script:ImageSizeCommand $fileName
}

function Get-RelativePath 
{
    <#
    .SYNOPSIS
      Get a path to a file (or folder) relative to another folder
    .DESCRIPTION
      Converts the FilePath to a relative path rooted in the specified Folder
    .PARAMETER Folder
      The folder to build a relative path from
    .PARAMETER FilePath
      The File (or folder) to build a relative path TO
    .PARAMETER Resolve
      If true, the file and folder paths must exist
	.LINK
	  http://poshcode.org/1751
    .Example
      Get-RelativePath ~\Documents\WindowsPowerShell\Logs\ ~\Documents\WindowsPowershell\Modules\Logger\log4net.xslt
     
      ..\Modules\Logger\log4net.xslt
     
      Returns a path to log4net.xslt relative to the Logs folder
    #>

    [CmdletBinding()]
    param
	(
       [Parameter(Mandatory=$true, Position=0)]
       [string]$Folder,
       [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true)]
       [Alias("FullName")]
       [string]$FilePath,
       [switch]$Resolve
    )
	
    process 
	{
       Write-Verbose "Resolving paths relative to '$Folder'"
       $from = $Folder = split-path $Folder -NoQualifier -Resolve:$Resolve
       $to = $filePath = split-path $filePath -NoQualifier -Resolve:$Resolve
     
       while($from -and $to -and ($from -ne $to)) 
	   {
          if($from.Length -gt $to.Length) 
		  {
             $from = split-path $from
          } 
		  else 
		  {
             $to = split-path $to
          }
       }
     
       $filepath = $filepath -replace "^"+[regex]::Escape($to)+"\\"
       $from = $Folder
       while($from -and $to -and $from -gt $to ) 
	   {
          $from = split-path $from
          $filepath = join-path ".." $filepath
       }
	   
       Write-Output $filepath
    }
}

function Get-RegionDefinition
{	
	process
	{
	    # get content of tab file
	    $tabFileName = $_
	    $tabContent = Get-Content $tabFileName
	    
	    # get control points from tab file            
        $decimalNumberRegEx = "[+-]?(?:\d+\.?\d*|\d*\.?\d+)"        
	    $controlPoints = $tabContent | % { 
	        if ($_ -match "\(($decimalNumberRegEx),($decimalNumberRegEx)\) \(($decimalNumberRegEx),($decimalNumberRegEx)\) Label") { 
	            new-object psobject -property @{ GeoX=[double]$matches[1]; GeoY=[double]$matches[2]; ImgX=[double]$matches[3]; ImgY=[double]$matches[4] };
	        } 
	    }              

	    # calculate transormation coefficients, geo = img * s + m
	    $controlPointsX = $controlPoints | sort -property ImgX -unique
	    $controlPointsY = $controlPoints | sort -property ImgY -unique
	                
	    $sx = ($controlPointsX[0].GeoX - $controlPointsX[1].GeoX)  / ($controlPointsX[0].ImgX - $controlPointsX[1].ImgX) 
	    $sy = ($controlPointsY[0].GeoY - $controlPointsY[1].GeoY)  / ($controlPointsY[0].ImgY - $controlPointsY[1].ImgY) 
	    $mx = ($controlPointsX[0].GeoX - $controlPointsX[0].ImgX * $sx)
	    $my = ($controlPointsY[0].GeoY - $controlPointsY[0].ImgY * $sy)

	    # get bounds of embedded image file
	    $imageFile = $tabContent | % { if ($_ -match "File `"([^`"]+)`"") { $matches[1] } }
	    $imageFile = join-path (split-path $tabFileName) $imageFile 
	    $img = Get-ImageProperties $imageFile 
	    $xmin = $mx
	    $ymax = $my
	    $xmax = ($img.Width-1) * $sx + $mx
	    $ymin = ($img.Height-1) * $sy + $my
	    
	    # return text block defining rectangle
@"
Region 1
  5
$xmin $ymin
$xmin $ymax
$xmax $ymax
$xmax $ymin
$xmin $ymin
 Pen (1,2,0)
 Brush (2,16777215,16777215)        
"@    
	}
}

function New-SeamlessTable
{
	<# 
	.SYNOPSIS
	    This script creates a seamless table for the input .TAB file(s).
	.DESCRIPTION
	    This script creates a seamless table for the input .TAB file(s). Seamless tables
	    are special mapinfo .TAB files that acts as an index for the contained files.
	.LINK 
	    This script leans on tab2tab.exe from http://mitab.maptools.org/
	    This script was written using information from http://www.mail-archive.com/mapinfo-l@lists.directionsmag.com/msg28998.html
	    This script is included in http://mapinfotools.codeplex.com/ 
	.EXAMPLE      
	    DIR *.tab | New-SeamlessTable -Target seamless.tab
	    This code snippet will produce a seamless table for all the .TFW files in the current directory.
	.PARAMETER target 
	    The name of the seamless table (.TAB file).
	.PARAMETER nocleanup
	    If specified the intermediate .MIF file (and ofcourse .MID file) that are used to produce final
	    seamless .TAB file will not be deleted.
	#>

	param
	(
	    [string[]]$files = @(),
	    [string]$target = "out.tab",
	    [switch]$nocleanup
	)

	begin
	{
	    $tab2tab = join-path $PSScriptRoot "tab2tab.exe"	    	    
	}

	process
	{
	    $files += $_
	}

	end
	{
	    # check preconditions
	    if ($files.Count -eq 0)    
	    {
	        Write-Warning "No input files"
	        return
	    }
	    
	    # init
	    $tf = [System.IO.FileInfo]$target
	    $coordsys = (Get-Content $files[0]) | ? { $_ -match "CoordSys Earth Projection" }  
	    $layername = split-path -leaf $tf.BaseName 
	    $targetRootDir = split-path $tf | resolve-path
	    
	    # create mid file
	    $mid = join-path $targetRootDir ($tf.BaseName + ".mid")    
	    $files | % { $fn = Get-RelativePath $targetRootDir $_; "`"$fn`",`"$layername`"" } | out-file -encoding ascii $mid
	    
	    # create mif file
	    $mif = join-path $targetRootDir ($tf.BaseName + ".mif")
@"
Version 450
Charset "WindowsLatin1"
Delimiter ","
$coordsys
Columns 2
   Table Char(100)
   Description Char(25)
Data

"@ | out-file -encoding ascii $mif       
	    $files | Get-RegionDefinition | out-file -encoding ascii -append $mif 
	    
	    # convert mif/mid to tab
	    & $tab2tab $mif $target
	    
	    # append meta data to tab file
@"
ReadOnly
begin_metadata
"\IsSeamless" = "TRUE"
"\IsReadOnly" = "FALSE"
end_metadata
"@ | out-file -encoding ascii -append $target
	           
	    # cleanup
	    if (!$nocleanup)
	    {
	        del $mif
	        del $mid
	    }
	}
}

function Convert-WorldFile2Tab
{
    <# 
    .SYNOPSIS
        This script creates mapinfo .TAB georefering file(s) for the input world file file(s).
    .DESCRIPTION
        This script uses information from the world file along with the corresponding image
        file to create a mapinfo .TAB file that makes it possible to consume the raster
        data using mapinfo products.
    .LINK 
        This script was written using information from http://free-zg.t-com.hr/gorantt/geo/tfw2tab.htm
        This script is included in http://mapinfotools.codeplex.com/
        Information about raster styles can be found here http://community.mapinfo.com/forums/thread.jspa?threadID=6404
    .EXAMPLE      
        DIR *.TFW | Convert-WorldFile2Tab
        This code snippet will produce .TAB files for all the .TFW files in the current directory.
    .PARAMETER coordsys 
        Definition of coordinate system (mapinfo style). 
        Sample: "CoordSys Earth Projection 8, 1000, `"m`", 15, 0, 1, 5500000, 0"
    .PARAMETER rasterstyle
        This is a dictionary from raster style index to value.
        Sample: @{ 4=1; 5=0 }
        RasterStyle 1 brightness_value
        RasterStyle 2 contrast_value  
        RasterStyle 3 grayscale_value
        RasterStyle 4 use_transparent_value           
        RasterStyle 5 transparent_index_value
        RasterStyle 6 grid_value
        RasterStyle 7 transparent_color_value (BBGGRR)
    #>

    param([string]$coordsys = $(throw "Coordinate system expected."), $rasterstyle = $null)

    begin
    {
        function Get-ImageFileExtensionFromWorldFile($worldFile)
        {
            switch ($worldFile.Extension)
            {
                ".tfw" { ".tif" }
                ".bpw" { ".bmp" }
                ".pgw" { ".png" }
                ".jpw" { ".jpg" }
                default { throw "Unknown world file $worldFile" }
            }
        }
    }
    
    process
    {   
        # ref: http://free-zg.t-com.hr/gorantt/geo/tfw2tab.htm
        
        # get input
        $worldFile = $_
        
        # figure out filenames
        $wf  = $worldFile.FullName 
        $base = $worldFile.FullName.SubString(0, $worldFile.FullName.Length - $worldFile.Extension.Length) 
        $tab = $base + ".tab"
        $imf = $base + (Get-ImageFileExtensionFromWorldFile $worldFile)
        
        # parse coefficients from the world file 
        $wfContent = Get-Content $wf
        $dx = [double]$wfContent[0];
        $dy = [double]$wfContent[3];
        $xr = [double]$wfContent[4];
        $yr = [double]$wfContent[5];
        
        # get image
        $img = Get-ImageProperties $imf 
        $imgw = $img.Width - 1
        $imgh = $img.Height - 1
        
        # calculate control points for .tab file
        $x0 = $xr - $dx * 0.5
        $y0 = $yr - $dy * 0.5
        $x1 = $x0 + $dx * $imgw
        $y1 = $y0
        $x2 = $x0
        $y2 = $y0 + $dy * $imgh
            
        # create tab file content
        $imfShortName = ([System.IO.FileInfo]$imf).Name
        $text = @"
!table
!version 300
!charset WindowsLatin2
 
Definition Table
  File "$imfShortName"
  Type "RASTER"
  ($x0,$y0) (0,0) Label "Pkt 1",
  ($x1,$y1) ($imgw,0) Label "Pkt 2",
  ($x2,$y2) (0,$imgh) Label "Pkt 3"
  $coordsys
  Units "m"

"@    
        
        # create tab file and set content
        $f = new-item -path $tab -type file -force -value $text    
        
        # append raster styles
        if ($rasterstyle)
        {
            $rasterstyle.keys | sort | % {
                $val = $rasterstyle[$_]
                add-content $f "RasterStyle $_ $val" 
            }
        }
    }
}

Export-ModuleMember Convert-WorldFile2Tab
Export-ModuleMember New-SeamlessTable
