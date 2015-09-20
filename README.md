# x3arth

Bring the latest stunning and sexy earth and sun satellite images on your desktop

# Copyright

Copyright (C) 2015 Luc Deschenaux <luc.dechenaux@freesurf.ch>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

Additional Terms:

  You are required to preserve legal notices and author attributions in
  that material or in the Appropriate Legal Notices displayed by works
  containing it.


# Images

The images are obtained via the NASA-Goddard Space Flight Center
Those images are in the public domain.
Permission is granted to use, duplicate, modify and redistribute images.
Please give credit to the NOAA-NASA GOES Project for the satellite images.

# Documentation

```
## NAME
  x3arth - download, crop, colorize and set satellite images as wallpaper

## SYNOPSIS
  usage: x3arth [options] [<remote_path>]

## OPTIONS
  Command line options:

  -h|--help

  -r|--reload                 Reload same image.

  -p|--previous               Load previous raw image,
                              OR (when used with --reload)
                              reload previous wallpaper.

  -r|--random                 Load random raw image,
                              OR (when used with -p and -r)
                              reload random previous wallpapaer

  -x|--offsetx [+|-]<offset>  Specify absolute or relative horizontal offset

  -y|--ofsety [+|-]<offset>   Specify absolute or relative vertical offset

  -n|--nochange               Lock offsets

  -c|--change                 Randomize offsets


## MORE OPTIONS
  Other options:

  -s|--sample <gradient>      Specify gradient image for sample colorize

  -d|--destdir <directory>    Change the destination directory

  -u|--url <url>              Change the default url

## EXAMPLES

  - Download the next raw image, crop it at random offsets, colorize it,
    and set it as wallpaper:

        x3arth

  - Reload the same raw image, crop it at random offsets, colorize it,
    and set it as wallpaper:

        x3arth --reload

  - Reload a random local raw image, crop it at the same offsets,
    and lock offsets for subsequent calls:

        x3arth --reload --random --nochange

  - Reload a random local raw image, crop it at random offsets.
    and unlock offsets for subsequent calls:

        x3arth --reload --random --change

  - Reload image and move top-left corner 500 pixels to the right
    and 500 pixels to the top:

        x3arth --reload --offsetx +500 --offsety -500

  - Reload the previous wallpaper

        x3arth --reload --previous

  - Reload a random previous wallpaper:

        x3arth --reload --previous --random

```
