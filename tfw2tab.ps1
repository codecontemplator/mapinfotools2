# sample usage: dir *.tfw | & c:\scripts\tfw2tab.ps1

param($coordsys = "CoordSys Earth Projection 8, 1000, `"m`", 15, 0, 1, 5500000, 0")

begin
{
    add-type -assemblyname "System.Drawing"    

    function get-transparent-color-index($img)
    {
        if ($img.Palette)
        {
            $img.Palette | % { $i = 0 } { $i = $i + 1; if ($_.A -lt 255) { $i-1 } }            
        }        
    }
}

process
{   
    # ref: http://free-zg.t-com.hr/gorantt/geo/tfw2tab.htm
    
    # get input
    $tfwFile = $_
    
    # figure out filenames
    $tfw = $tfwFile.FullName 
    $tab = $tfwFile.FullName.SubString(0, $tfwFile.FullName.Length - $tfwFile.Extension.Length) + ".tab"
    $tif = $tfwFile.FullName.SubString(0, $tfwFile.FullName.Length - $tfwFile.Extension.Length) + ".tif"
    
    # parse coefficients from .tfw file 
    $tfw = Get-Content $tfw
    $dx = [double]$tfw[0];
    $dy = [double]$tfw[3];
    $xr = [double]$tfw[4];
    $yr = [double]$tfw[5];
    
    # get image
    $img = new-object System.Drawing.Bitmap -ArgumentList $tif 
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
    $tifShortName = ([System.IO.FileInfo]$tif).Name
    $text = @"
!table
!version 300
!charset WindowsLatin2
 
Definition Table
  File "$tifShortName"
  Type "RASTER"
  ($x0,$y0) (0,0) Label "Pkt 1",
  ($x1,$y1) ($imgw,0) Label "Pkt 2",
  ($x2,$y2) (0,$imgh) Label "Pkt 3"
  $coordsys
  Units "m"
"@    
    
    # create tab file and set content
    $f = new-item -path $tab -type file -force -value $text    
    
    # append transparancy definition if available
    $ti = get-transparent-color-index $img
    if($ti)
    {
        # ref: http://community.mapinfo.com/forums/thread.jspa?threadID=6404
        add-content $f "RasterStyle 4 1"
        add-content $f "RasterStyle 5 $ti"
    }
}
