#!/bin/sh
#\
(kill -0 `cat ~/.x3arth/x3arth.pid`) 1> /dev/null 2> /dev/null && exit 0
#\
echo $$ > ~/.x3arth/x3arth.pid
#\
export PATH=/usr/X11R6/bin:/usr/bin:/usr/local/bin:$PATH
# the next line restarts using tclsh \
exec tclsh "$0" "$@"

 #
 # x3arth - display the latest earth/sun satellite images on your desktop
 #
 # Copyright (c) 1999-2015 Luc Deschenaux <luc@miprosoft.com>
 #
 # This program is free software: you can redistribute it and/or modify
 # it under the terms of the GNU Affero General Public License as published by
 # the Free Software Foundation, either version 3 of the License, or
 # (at your option) any later version.
 #
 # This program is distributed in the hope that it will be useful,
 # but WITHOUT ANY WARRANTY; without even the implied warranty of
 # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 # GNU Affero General Public License for more details.
 #
 # You should have received a copy of the GNU Affero General Public License
 # along with this program.  If not, see <http://www.gnu.org/licenses/>.
 #
 # Additional Terms:
 #
 #      You are required to preserve legal notices and author attributions in
 #      that material or in the Appropriate Legal Notices displayed by works
 #      containing it.
 #


#set _Trace_fd [open "${prefs_dir}/tcltrace.tmp" w]

# fconfigure $_Trace_fd -buffering line

#                puts $::_Trace_fd "$name >> $cmd"
#rename proc _proc
#_proc proc {name arglist body} {
#    uplevel 1 [list _proc $name $arglist $body]
#        uplevel 1 [list trace add execution $name enterstep [list ::proc_start $name]]
#      }
#      _proc proc_start {name command op} {
#          puts "$name >> $command"
#        }
# you must install tcllib for ftp support
set NASA {http://www.gfd-dennou.org/arch/dcsatel/nasa-Weather}
set NASA {http://rsd.gsfc.nasa.gov/goesg/earth/Weather}
set NASA {ftp://weather.cs.ucl.ac.uk/Weather}
set NASA {ftp://cyclone.msfc.nasa.gov/Weather}
set NASA {http://rsd.gsfc.nasa.gov/goesg/earth/Weather}
set NASA {ftp://rsd.gsfc.nasa.gov/pub/Weather}
set NASA {ftp://geo.msfc.nasa.gov/Weather}
set NASA {http://goes.gsfc.nasa.gov/goeseast/fulldisk/fullres/vis/}
set NASA {http://goes.gsfc.nasa.gov/goeswest/fulldisk/fullres/vis/}
set NASA {http://goes.gsfc.nasa.gov}
# default path/ 
set path goeswest/fulldisk/fullres/vis/
set pathl [lrange [split $path /] 0 [expr [llength [split $path /]]-2]]
set bgimagetype png
set chgbgmethod dconf
set prefs_dir $env(HOME)/.x3arth

set usage {x3arth [<satellite>] [<type>] [<channel>] [<resolution>]  [ [-c [<file>] | -b] | 
[[-new] [-hash] [-url <url>] [-all] [-h] [-r] [-from <substr>] [-to <substr>]]

<satellite>    : default: goeswest
<type>         : default: fulldisk
<channel>      : default: fullres
<resolution>   : default: vis
-c             : load current image from disk
-c <file>      : copy current bitmap to <file>
-b             : display previous image
-new           : dont change background when no new image is found
-hash          : no progress bar
-url <url>     : root url (ftp or http)
-all           : all the files between -from and -to
-h             : help
-r             : random image from disk
-from <substr> : inclusive inferior limit eg: 030912
-to <substr>   : inclusive superior limit eg: 030914
 
image directory = <url>/<satellite>/<type>/<channel>/<resolution>/

- GMS-5 cloud imagery is originally obtained via GMS of JMA.

- GOES images are originally obtained via the NASA-Goddard Space Flight Center
  data from NOAA GOES

- Those images are public domain, You can freely use them for educational and
  non-commercial purposes but please check their website and make sure to
  include the required credits when redistributing them.

- For a list of mirror sites of the University of Hawaii data
  see http://goes.gsfc.nasa.gov/text/goesds.html
  or  http://www.ghcc.msfc.nasa.gov/GOES/satlinks.html

- Please setup a shared directory if you plan to use x3arth on a local network

- Send cookies and Thanks to all the people making it possible !

- Maybe you do have enough upstream, disk space, stability, interest,
  resources or cookie addiction to gratefully mirror their archive or
  contribute with some stunning images ? 

}

set hash 0
set gotit {}

array set pbar {
    0 {[                    ]}
    1 {[>                   ]}
    2 {[->                  ]}
    3 {[-->                 ]}
    4 {[--->                ]}
    5 {[---->               ]}
    6 {[----->              ]}
    7 {[------>             ]}
    8 {[------->            ]}
    9 {[-------->           ]}
    10 {[--------->          ]}
    11 {[---------->         ]}
    12 {[----------->        ]}
    13 {[------------>       ]}
    14 {[------------->      ]}
    15 {[-------------->     ]}
    16 {[--------------->    ]}
    17 {[---------------->   ]}
    18 {[----------------->  ]}
    19 {[------------------> ]}
    20 {[------------------->]}
}

proc http_copy {url file bar} {
  if {[catch {set token [http::geturl $url -validate 1]} err]} {
    puts stderr \n***\ $url:\ $err\n
    return {}
  }
  upvar #0 $token state
  set size $state(totalsize)
  if {([file exists $file]) && ([file size $file]==$size)} {
    puts stderr "Already here: $file"
    return {}
  }
                                                                              
  if {[catch {set token [http::geturl $url -channel [set out [open $file w]] -progress [list http_progress $bar [clock seconds]]]} err]} {
    puts stderr \n***\ $url:\ $err\n
    return {}
  }
  catch {close $out}
  puts stderr {}
  upvar #0 $token state
  foreach {name value} $state(meta) {
    if {[regexp -nocase ^location$ $name]} {
      return [http_copy [string trim $value] $file $bar]
    }
  }
  return $token
}

proc http_progress {bar time token total current} {
  if {!$bar} {return}
  progress $total 0 $time $current
}

proc latest {u first} {
  global prots 
  if {(![regexp -nocase {^([^:]+)://} $u {} prot]) || ([lsearch $prots [string tolower $prot]]<0)} {
    puts stderr invalid\ url:\ $u
    return {}
  }
  return [[string tolower $prot]_latest $u $first]
}

proc http_latest {u first} {
  global token0 token path page prevfile updaTIME prefs_dir
  if {![info exists page]} {
    if {([file exists ${prefs_dir}/${path}index.html] && ([expr [clock seconds]-[file mtime ${prefs_dir}/${path}index.html]]>$updaTIME)) || (![file exists ${prefs_dir}/${path}index.html])} { 
      puts stderr "Getting file list"
      set token0 [http_copy $u ${prefs_dir}/temp.html 0]
      if {$token0=={}} {
        puts stderr "Cant reach website."
        set token previous
        return {} 
      }
      upvar #0 $token0 state
      if {[expr [lindex $state(http) 1]/100]!=2} {
        puts stderr {Cannot get file list.}
        set token previous
        return {}
      }
      file mkdir ${prefs_dir}/$path
      file copy -force -- ${prefs_dir}/temp.html ${prefs_dir}/${path}index.html
    }
    set f [open ${prefs_dir}/${path}index.html r]
    set page [read $f]
    close $f
  }
  if {$first} {
    set i 0
    while {1} {
      if {![regexp -start $i -indices -nocase {<A HREF="([0-9]{10}.{6}\.tif)">([0-9]{10}.{6}\.tif)</A>} $page {} i0 i1]} {
        puts stderr {end of directory list}
        set token previous
        return {}
      }
      set i [lindex $i0 1]
      set f0 [string range $page [lindex $i0 0] $i]
      puts stdout $f0
      if {[discard $f0]} {
        continue
      }
      if {![info exists prevfile($f0)] && ![file exists ${prefs_dir}/$path/$f0]} {
        return $u$f0
      }
    }
  } else {
#    puts stdout $page
    regexp -all -nocase {<A HREF="([0-9]{10}.{6}\.tif)">([0-9]{10}.{6}\.tif)</A>} $page {} f0 f1
  }
  
  if {[info exists prevfile($f0)]} {
    set token notnew
    return {}
  }

  if {[discard $f0]} {
    set token previous
    return {}
  }
  return $u$f0 
}

proc ftp_latest {u first} {
  global token path ftpsock names prevfile updaTIME prefs_dir
  
  if {![info exists names]} {
    if {([file exists ${prefs_dir}/${path}ftpindex.txt]) && ([expr [clock seconds]-[file mtime ${prefs_dir}/${path}ftpindex.txt]]<$updaTIME)} {
      set f [open ${prefs_dir}/${path}ftpindex.txt r]
      set names [read $f]
      close $f
    } else {
      if {[ftpcd $u]} {
        set token previous
        return {}
      }
      puts stderr "Getting file list"
      set names [::ftp::NList $ftpsock]
      if {$names=={}} {
        puts stderr {Cannot get file list.}
        set token previous
        return {} 
      }
      set f [open ${prefs_dir}/${path}ftpindex.txt w]
      puts -nonewline $f $names
      close $f
    }
  }
  
  file mkdir ${prefs_dir}/$path
  set f0 {}
  foreach fn $names {
    if {[regexp -- {^[0-8][0-9]+\.[^\.]{3}$} $fn f1]} {
      set f0 $f1
      if {($first) && (![discard $f0]) && (![info exists prevfile($f0)]) && (![file exists ${prefs_dir}/${path}/$f0])} {
        break
      }
    }
  }
  if {[info exists prevfile($f0)] || [file exists ${prefs_dir}/${path}/$f0]} {
    set token notnew
    return {}
  }
  if {[discard $f0]} {
    set token previous
    return {}
  }
  
  if {[ftpcd $u]} {
    set token previous
    return {}
  }

  return $u$f0 
}

proc discard {fname} {
  global sat chn from to
  if {[regexp {^([0-9]{6})([0-9]{4})(.*)} $fname {} dat tim suf]} {
    set dat [string trimleft $dat 0]
    set tim [string trimleft $tim 0]
    if {[info exists from]} {
      set l [string length $from]
      if {[string compare [string range $fname 0 [expr $l-1]] $from]<0} {
        return 1
      }
    }
    if {[info exists to]} {
      set l [string length $to]
      if {[string compare [string range $fname 0 [expr $l-1]] $to]>0} {
        return 1
      }
    }
    if {$chn=={vis}} {
      switch -- $sat {
        {GOES-8} {
          if {($tim>=100) && ($tim<=730)} {
            puts stderr discarded:$fname
            return 1
          }
        }
        {GOES-10} {
          if {($tim>=600) && ($tim<=1230)} {
            puts stderr discarded:$fname
            return 1
          }
        }
      }
    }
  }
  return 0
}

proc ftpconnect {u} {
  global ftpsock server user pass errorInfo
  regexp -nocase -- {ftp://(([^:@\ ]+)(:([^@\ ]+))?@)?([^/:\ ]+)(:([0-9]+))?} $u {} {} user {} pass server {} port
  if {$port=={}} {
    set port 21
  }
  if {$user=={}} {
    set user anonymous
  }
  if {$pass=={}} {
    set pass anonymous@ftp.org
  }
  catch {::ftp::Close $ftpsock}
  set i 0
  puts stdout "Connecting to $server"
#  puts stdout "::ftp::Open $server $user $pass -port $port -progress progress"
  while {[set ftpsock [::ftp::Open $server $user $pass -port $port -progress ftprogress]]==-1} {
    incr i
    if {$i==3} {
      puts stderr "Could not connect to $server\n\n$errorInfo"
      return 1
    }
  }
  puts stdout Connected
  return 0
}

proc ftprogress {current} {
  global size lsize ttime
  if {!$size} {
    return
  }
  progress $size $lsize $ttime $current
}

proc ftpcd {u} {
  global ftpsock errorInfo server ftpwd
  
  regexp -nocase -- {ftp://(([^:@\ ]+)(:([^@\ ]+))?@)?([^/:\ ]+)(:([0-9]+))?(/.*)} $u {} {} user {} pass server {} port dir
  
  puts stderr cd:$dir
  if {![info exists ftpsock]} {
    if {[ftpconnect $u]} {
      return 1
    }
    if {([catch {set ret [::ftp::Cd $ftpsock $dir]}]) || (!$ret)} {
      puts stderr "Could not change directory to $dir\n"
      return 1
    }
    set ftpwd $dir
    return 0
  }
  
  set i 0
  if {$ftpwd==$dir} {
    return 0
  }
  while {([catch {set ret [::ftp::Cd $ftpsock $dir]}]) || (!$ret)} {
    incr i
    if {$i==2} {
      puts stderr "Could not change directory to $dir\n"
      return 1
    }
    if {$i==1} {
      if {[ftpconnect $u]} {
        return 1
      }
    }
  }
  set ftpwd $dir
  return 0
}

proc progress {size lsize ttime bytes} {
  global pbar hash
  if {$hash} {
    puts -nonewline stderr \#
  } else {
    set pr [expr (0.0+$bytes+$lsize)*100/$size]
    if {$pr<0} {set pr 0}
    set px [expr int($pr/5)]
    set dt [expr [clock seconds]-$ttime+1]
    set speed [expr $bytes/$dt]
    if {$speed} {
      set eta \ [clock format [expr int(($size-$bytes-$lsize)/$speed)] -format %H:%M:%S -gmt 1]\ left
    } else {
      set eta {}
    }
    puts -nonewline stderr [format %-81s \x0d[format %4d [expr int($pr)]]%\ $pbar($px)\ [expr ($bytes+$lsize)/1024]k\ of\ [expr $size/1024]k\ at\ [expr int($speed/102.4)/10.0]\kb/s$eta]
  }
}

proc getlatest {} {
  global token NASA path f2disp ftpsock url2c lsize size ttime all gotit prevfile sat prefs_dir
  set token {}
  http::config -useragent x3arth
  set url2c [latest $NASA/$path $all]
  set fname [file tail $url2c]
  
  if {[info exists prevfile($fname)]} {
   set token notnew
   return
  }
  if {$fname!={}} {
    puts stderr $url2c
    set lname ${prefs_dir}/$path$fname
    set ext [file extension $url2c]
      regexp -- {[^:]+} $url2c prot
      set prot [string tolower $prot]
      switch $prot {
        http {
          catch {set token [http_copy $url2c $lname 1]}
          if {$token!=""} { 
            upvar #0 $token state
            if {([expr [lindex $state(http) 1]/100]==2) && ((![info exists size]) || ([file size $lname]>=$size))} {
              cd ${prefs_dir}/$path
              catch {exec rm ${prefs_dir}/$path$previous$ext}
              catch {exec mv ${prefs_dir}/${path}latest$ext ${prefs_dir}/${path}previous$ext}
              catch {exec ln -s $fname ${prefs_dir}/${path}latest$ext}
              set prevfile($fname) 1
              exec echo $fname >> ${prefs_dir}/${path}.prevfiles
              lappend gotit ${prefs_dir}/$path$fname
              set f2disp $lname
              set token {}
            } else {puts stderr "Cant get the latest image." ; set token previous}
          } else {
            set token previous
          }
        }
        ftp {
          set err {}
          if {([catch {set size [::ftp::FileSize $ftpsock $fname]} err]) || ($size=={})} {
            puts stderr "Could not download $fname\n\n$err"
            set token previous
          } else {
            if {[catch {set lsize [file size $lname]}]} {
              set lsize 0
              set op Get
            } else {
              set op Reget
              if {$lsize>=$size} {
                puts stderr "File already here: $fname" 
                set token previous
                set prevfile($fname) 1
                exec echo $fname >> ${prefs_dir}/${path}.prevfiles
                return
              }
            }
            puts stdout "Getting file: $path$fname"
            set ttime [clock seconds]
            if {([catch {::ftp::$op $ftpsock $fname $lname} err]) || ([file size $lname]<$size)} {
              puts stderr "\nCould not download $fname\n\n$err"
              set token previous
            } else {
              puts stderr {}
              catch {exec rm ${prefs_dir}/$path$previous$ext}
              catch {exec mv ${prefs_dir}/${path}latest$ext ${prefs_dir}/${path}previous$ext}
              catch {exec ln -s $fname ${prefs_dir}/${path}latest$ext}
              set prevfile($fname) 1
              exec echo $fname >> ${prefs_dir}/${path}.prevfiles
              lappend gotit ${prefs_dir}/$path$fname
              set f2disp $lname
              set token {}
            }
          }
        }
      }
  } else {set token notnew}
}

proc display {f2disp} {
  global bgimagetype prefs_dir
  #set sw [winfo screenwidth .]
  #set sh [winfo screenheight .]
  set cropped_image [file join [file dirname $f2disp] background.$bgimagetype]
  set desktop_res [split [exec xdpyinfo | grep dimens | awk {{print $2}}] {x}]
  set sw [lindex $desktop_res 0] 
  set sh [lindex $desktop_res 1]
  set desc [exec identify $f2disp]
  if {[regexp -- {([0-9]+)x([0-9]+)} $desc {} iw ih]} {

    while {1} {
      set ox [expr int(($iw-$sw)*rand())]
      set oy [expr int(($ih-$sh)*rand())]
      if {$ox<0} {
        set ox 0
      }
      if {$oy<0} {
        set oy 0
      }
  #    puts stderr "convert -crop ${sw}x${sh}+$ox+$oy \\\n$f2disp $cropped_image"
      if [catch {exec convert -crop ${sw}x${sh}+$ox+$oy $f2disp $cropped_image >> ${prefs_dir}/x3arth.log} err] {
        puts stderr $err
      }

      if {[file size $cropped_image] < 1048576 } continue;

      set image_colorized [file rootname $cropped_image].new.$bgimagetype
      sample_colorize ${prefs_dir}/sample.bmp $cropped_image [file rootname $cropped_image].new.$bgimagetype
      if [catch {exec mv $image_colorized $cropped_image} err] {
        puts stderr $err
        exit 1
      }
      break
    }
    set f2disp $cropped_image
  }
  exec mv $f2disp [file rootname $f2disp].[pid].$bgimagetype
  set f2disp [file rootname $f2disp].[pid].$bgimagetype
  xsetroot $f2disp
}

proc xsetroot {f2disp} {
  global xpid chgbgmethod prefs_dir

  switch -- $chgbgmethod {
    {gconftool2} {
      exec gconftool-2 --type string --set /desktop/gnome/background/picture_options spanned
      exec gconftool-2 --type string --set /desktop/gnome/background/picture_filename "" 
      exec gconftool-2 --type string --set /desktop/gnome/background/picture_filename $f2disp
    }
    {dconf} {
#      puts stdout dconf
      exec echo dconf write /org/gnome/desktop/background/picture-uri \"\'file://$f2disp\'\" > ${prefs_dir}/x3arth.sh
      exec echo dconf write /org/gnome/desktop/background/picture-options \"\'spanned\'\"  >> ${prefs_dir}/x3arth.sh
      if [catch { exec ${prefs_dir}/x3arth.sh } err ] {
        puts stderr $err
        exit 1
      }
    }
    {gsettings} {
      exec echo gsettings set org.gnome.desktop.background picture-uri \"\'file://$f2disp\'\" > ${prefs_dir}/x3arth.sh
      exec echo gsettings set org.gnome.desktop.background picture-options \"\'spanned\'\" >> ${prefs_dir}/x3arth.sh
      if [catch { exec ${prefs_dir}/x3arth.sh } err ] {
        puts stderr $err
        exit 1
      }
    }
  }

#  exec echo gconftool-2 --type string --set /desktop/gnome/background/picture_options centered >> ${prefs_dir}/x3arth.sh
#  exec echo gconftool-2 --type string --set /desktop/gnome/background/picture_filename $f2disp >> ${prefs_dir}/x3arth.sh
#  exec echo xsetroot -solid black >> ${prefs_dir}/x3arth.sh
 # puts stderr [set c "wmsetbg $f2disp && exit 0"]
#  exec echo $c >> ${prefs_dir}/x3arth.sh
# what would we do without xv ? :)
#  puts stderr "xv $f2disp -quit -iconic -rmode 5 -viewonly"
#  exec echo xv $f2disp -quit -iconic -rmode 5 -viewonly >> ${prefs_dir}/x3arth.sh
#  exec chmod +x ${prefs_dir}/x3arth.sh
#  if {[info exists xpid]} {
#    while {![catch {exec kill -0 $xpid}]} {
#      after 150
#    }
#  }
#  set xpid [exec ${prefs_dir}/x3arth.sh &]

}

proc loadprevfile {path} {
  global prevfile prefs_dir
  array unset prevfile
  array set prevfile {}
  file mkdir ${prefs_dir}/${path}
  exec touch ${prefs_dir}/${path}.prevfiles
  set f [open ${prefs_dir}/${path}.prevfiles r]
  set prevfilelist [read -nonewline $f]
  close $f
  regsub -all -- {([^\n]+)(\n)?} $prevfilelist {set prevfile(\1) 1\2} prevfilelist
  eval $prevfilelist
}


proc sample_colorize {sample image outfile} {
  global prefs_dir

  exec cp $sample [file dirname $image]
  cd [file dirname $image]
  set sample [file tail $sample]
  set image [file tail $image]
  set outfile [file tail $outfile]
  
  if [catch {exec echo gimp -i -b \'(sample-colorize \"$sample\" \"$image\" \"$outfile\")\' > ${prefs_dir}/x3arth.sh} err] {
    puts stderr $err
    exit 1
  }
  exec chmod +x ${prefs_dir}/x3arth.sh
#  puts stdout [exec cat ${prefs_dir}/x3arth.sh]
  if [catch {exec ${prefs_dir}/x3arth.sh} err] {
    puts stderr $err
    exit 1
  }
}


##############################################################################

package require http
set prots {http}

if {[lsearch $argv {-h}]>=0} {
  puts stderr $usage 
  exit 0
}

if {[catch {package require ftp}]} {
  puts stderr {*** You must install tcllib to enable ftp support.\n(http://sourceforge.net/projects/tcllib)}
} else {
  lappend prots ftp
  set ::ftp::DEBUG 0
  set ::ftp::VERBOSE 0
}

if {$argc} {
  set dir [lindex $argv 0]
  if {($dir!={}) && ([string index $dir 0]!={-})} {
    set path {}
    set i 0
    while {($dir!={}) && ([string index $dir 0]!={-})} {
      set pathl [lreplace $pathl $i $i $dir]
      set argv [lreplace $argv 0 0]
      incr argc -1
      incr i
      if {$i==5} {
        puts stderr {Too many levels}
        puts stderr $usage
        exit 1
      }
      set dir [lindex $argv 0]
    }
    set path [lindex $pathl 0]/
    set i 0
    while {[incr i]<[llength $pathl]} {
      set path $path[lindex $pathl $i]/
    }
  }
  #puts stderr path=$path
}

regexp {([^/]+)/([^/]+)/([^/]+)/([^/]+)/} $path {} sat typ chn res

loadprevfile $path
set f2disp [glob -nocomplain ${prefs_dir}/${path}latest.???]
  
if {[set p [lsearch $argv -b]]>=0} {
  if {[file exists ${prefs_dir}/${path}previous[file extension $f2disp]]} {
    display ${prefs_dir}/${path}previous[file extension $f2disp]
    exit 0
  }
  set argv [lreplace $argv $p $p]
  incr argc -1
  if {$argc} {
    puts stderr $usage
    exit 1
  }
  exit 0
}

if {[set p [lsearch $argv -s]]>=0} {
  set argv [lreplace $argv $p $p]
  incr argc -1
  if {$argc} {
    if {$argc>1} {
      puts stderr $usage
      exit 1
    }
    if {[catch {exec cp ${prefs_dir}/${path}background.$bgimagetype [lindex $argv 0]} err]} {
      puts stderr $err
      exit 1
    }
  } else {
    file mkdir ${prefs_dir}/${path}saved/
    if {[catch {exec cp ${prefs_dir}/${path}background.$bgimagetype ${prefs_dir}/${path}saved/[clock format [clock seconds] -format %Y%m%d%H%M%S].$bgimagetype} err]} {
      puts stderr $err
      exit 1
    }
  }
  exit 0
}
if {[set p [lsearch $argv -c]]>=0} {
  set argv [lreplace $argv $p $p]
  incr argc -1
  if {$argc} {
    if {$argc>1} {
      puts stderr $usage
      exit 1
    }
    if {[file exists ${prefs_dir}/${path}background.$bgimagetype]} {
      if {[catch {exec cp ${prefs_dir}/${path}background.$bgimagetype [lindex $argv 0]} err]} {
        puts stderr $err
        exit 1
      }
    }
    exit 0
  } else {
    if {[file exists ${prefs_dir}/${path}latest[file extension $f2disp]]} {
      display ${prefs_dir}/${path}latest[file extension $f2disp]
      exit 0
    } else {
      puts stdout {nothing to display}
      exit 1
    }
  }
}

set p [lsearch $argv -from]
if {$p>=0} {
  incr argc -1
  if {$p==$argc} {
    puts stderr $usage
    exit 1
  }
  set argv [lreplace $argv $p $p]
  set from [lindex $argv $p]
  set argv [lreplace $argv $p $p]
  incr argc -1
}

set p [lsearch $argv -to]
if {$p>=0} {
  incr argc -1
  if {$p==$argc} {
    puts stderr $usage
    exit 1
  }
  set argv [lreplace $argv $p $p]
  set to [lindex $argv $p]
  set argv [lreplace $argv $p $p]
  incr argc -1
}

set p [lsearch $argv -r]
if {$p>=0} {
  set filelist [array names prevfile]
  while 1 {
    set l [llength $filelist]
    if {!$l} {
      puts stderr "nothing to display"
      exit 0
    }
    set n [expr int(rand()*$l)]
    set ft [lindex $filelist $n]
    set fn ${prefs_dir}/$path$ft
    if {(![discard $ft]) && ([file exists $fn])} {
      display $fn
      exit 0
    }
    set filelist [lreplace $filelist $n $n]
  }
}

set p [lsearch $argv -new]
if {$p>=0} {
  set onlynew 1
  set argv [lreplace $argv $p $p]
  incr argc -1
}

set p [lsearch $argv -hash]
if {$p>=0} {
  set hash 1
  set argv [lreplace $argv $p $p]
  incr argc -1
}

set p [lsearch $argv -all]
if {$p>=0} {
  set all 1
  set argv [lreplace $argv $p $p]
  incr argc -1
} else {
  set all 0
}

set p [lsearch $argv -url]
if {$p>=0} {
  incr argc -1
  if {$p==$argc} {
    puts stderr $usage
    exit 1
  }
  set argv [lreplace $argv $p $p]
  set NASA [string trimright [lindex $argv $p] /]
  set argv [lreplace $argv $p $p]
  incr argc -1
}

set p [lsearch $argv -url]
if {$p>=0} {
  incr argc -1
  if {$p==$argc} {
    puts stderr $usage
    exit 1
  }
  set argv [lreplace $argv $p $p]
  set NASA [string trimright [lindex $argv $p] /]
  set argv [lreplace $argv $p $p]
  incr argc -1
}

if {$argc} {
  puts stderr $usage
  exit 1
}

set updaTIME 1800
set NASA [string trimright $NASA /]

if {$argc<2} {
  getlatest
  if {$all} {
#    display $f2disp
    while {$token=={}} {
      getlatest
      puts stdout f2disp=$f2disp
#      display $f2disp
    }
  }
  if {[llength $gotit]} {
    set token {}
  }
}
catch {::ftp::Close $ftpsock}

if {[file exists $f2disp]} {
  if {($token=={previous}) || (($token=={notnew}) && (![info exists onlynew]))} {
    puts stdout "Loading previous image..."
  }
  if {($token!={notnew}) || (![info exists onlynew])} {
    display $f2disp
  }
  puts stdout "Thanks to the NASA and University of Hawaii."   
  if {$sat=={GMS-5}} {
    puts stdout {The cloud imagery was originally obtained via GMS of JMA.}
  } elseif {[regexp -nocase ^GOES $sat]} {
    puts stdout "The image was originally obtained via the NASA-Goddard Space Flight Center, data from NOAA GOES"
  }
}

#puts stdout "token:{$token}"

if {[regexp -nocase {http://[^/]+} $NASA home]} {
  catch {set f [open ${prefs_dir}/x3arth.url r]}
  if {(![file exists ${prefs_dir}/x3arth.url]) || ([read $f]!=$home)} {
     catch {close $f}
    if {[catch {exec xdg-open $home &}]} {
        puts stderr "Please visit $home"
    }
    if {(![file exists ${prefs_dir}/x3arth.url])} {
      puts stdout "x3arth (C) 1999-2015 Luc Deschenaux <luc@miprosoft.ch>"
    }
    set f [open ${prefs_dir}/x3arth.url w]
    puts -nonewline $f $home
  }
  close $f
}

