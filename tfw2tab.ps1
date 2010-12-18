# sample usage: dir *.tfw | & c:\scripts\tfw2tab.ps1

param($coordsys = "CoordSys Earth Projection 8, 1000, `"m`", 15, 0, 1, 5500000, 0")

process
{   
    # ref: http://free-zg.t-com.hr/gorantt/geo/tfw2tab.htm
    
    # parse coefficients from .tfw file 
    $tfw = Get-Content $_       
    $dx = [double]$tfw[0];
    $dy = [double]$tfw[3];
    $x0 = [double]$tfw[4];
    $y0 = [double]$tfw[5];
    
    # calculate additional points for .tab file
    $x1 = $x0 + $dx
    $y1 = $y0
    $x2 = $x0
    $y2 = $y0 + $dy
    
    # figure out filenames for target
    $tab = $_.FullName.SubString(0, $_.Fullname.Length - $_.Extension.Length) + ".tab"
    $tif = $_.Name.SubString(0, $_.Name.Length - $_.Extension.Length) + ".tif"
    
    # create tab file content
    $text = @"
!table
!version 300
!charset WindowsLatin2
 
Definition Table
  File "$tif"
  Type "RASTER"
  ($x0,$y0) (0,0) Label "Pt 1",
  ($x1,$y1) (1,0) Label "Pt 2",
  ($x2,$y2) (0,1) Label "Pt 3"
  $coordsys
  Units "m"
"@    

    # create tab file and set content
    new-item -path $tab -type file -force -value $text    
}
