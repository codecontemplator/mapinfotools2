# sample usage: dir *.tab | & c:\scripts\create-seamless-tab.ps1 -target seamless.tab

# ref: mitab (tab2tab.exe) - http://mitab.maptools.org/
# ref: http://www.mail-archive.com/mapinfo-l@lists.directionsmag.com/msg28998.html

param(
    $tab2tab = "tab2tab.exe",
    $files = @(),
    $target = "out.tab",
    [switch]$nocleanup
)

begin
{
    . .\external.ps1
    
    add-type -assemblyname "System.Drawing"    

    function get-region-definition()
    {
        process
        {
            # get content of tab file
            $tabFileName = $_
            $tabContent = Get-Content $tabFileName
            
            # get control points from tab file            
            $controlPoints = $tabContent | % { 
                if ($_ -match "\((\d+),(\d+)\) \((\d+),(\d+)\) Label") { 
                    new-object psobject -property @{ GeoX=[double]$matches[1]; GeoY=[double]$matches[2]; ImgX=[double]$matches[3]; ImgY=[double]$matches[4] };
                } 
            }              

            # calculate transormation coefficients, geo = img * s + m
            $controlPointsX = $controlPoints | sort -property ImgX -unique
            $controlPointsY = $controlPoints | sort -property ImgY -unique
                        
            $sx = ($controlPointsX[0].GeoX - $controlPointsX[1].GeoX)  / ($controlPointsX[0].ImgX - $controlPointsX[1].ImgX) 
            $sy = -($controlPointsY[0].GeoY - $controlPointsY[1].GeoY)  / ($controlPointsY[0].ImgY - $controlPointsY[1].ImgY) 
            $mx = ($controlPointsX[0].GeoX - $controlPointsX[0].ImgX * $sx)
            $my = ($controlPointsY[0].GeoY - $controlPointsY[0].ImgY * $sy)

            # get bounds of embedded tif file
            $tifFile = $tabContent | % { if ($_ -match "File `"([^`"]+)`"") { $matches[1] } }
            $tifFile = join-path (split-path $tabFileName) $tifFile 
            $tifImg = new-object System.Drawing.Bitmap -ArgumentList $tifFile 
            $xmin = $mx
            $ymin = $my
            $xmax = $tifImg.Width * $sx + $mx
            $ymax = $tifImg.Height * $sy + $my
            
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
    $files | get-region-definition | out-file -encoding ascii -append $mif 
    
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
