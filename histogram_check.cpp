/*
*    histogram_check - verify that at least n of the 4 image quarters have
*    more than m history bars.
*
*    This file is part of the x3arth project 
*
*    Copyright (C) 2015 Luc Deschenaux <luc.dechenaux@freesurf.ch>
*
*    This program is free software: you can redistribute it and/or modify
*    it under the terms of the GNU Affero General Public License as published by
*    the Free Software Foundation, either version 3 of the License, or
*    (at your option) any later version.
*
*    This program is distributed in the hope that it will be useful,
*    but WITHOUT ANY WARRANTY; without even the implied warranty of
*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*    GNU Affero General Public License for more details.
*
*    You should have received a copy of the GNU Affero General Public License
*    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*
* Additional Terms:                                                                                                  
*
*      You are required to preserve legal notices and author attributions in
*      that material or in the Appropriate Legal Notices displayed by works
*      containing it.
*
*/

#define cimg_use_tiff
#define cimg_display 0
#include <CImg.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <libgen.h>

using namespace cimg_library;

int main(int argc, char **argv) {

  if (argc<4) {
    fprintf(stderr,"\nUsage: %s <image_file> <threshold> <required>\n", basename(argv[0]));
    fprintf(stderr,"\nReturn an error when less than <required> quarters of the image\n");
    fprintf(stderr,"have less than <threshold> RGB histogram bars.\n\n");
    exit(1);
  }
  char *filename=argv[1];
  int threshold=atoi(argv[2]);
  int required=atoi(argv[3]);

  CImg<unsigned char> img(filename);

  const int width=img.width();
  const int height=img.height();
  const int spectrum=img.spectrum();
  const int depth=8;
  const int values=1<<depth;

  int64_t h[4][values]={{},{},{},{}};

  int x,y;
  int half_height=height>>1;
  int half_width=width>>1;

  // build histogram per image quarter 
  for (y=0; y<height; ++y) {
    int offset=(y/half_height)<<1;

    for (x=0; x<half_width; ++x) {
      for (int s=0; s<spectrum; ++s) {
        ++h[offset][img(x,y,0,s)];
      }
    }

    for (++offset; x<width; ++x) {
      for (int s=0; s<spectrum; ++s) {
        ++h[offset][img(x,y,0,s)];
      }
    }
  }

  // count histogram bars per image quarter
  int barCount[5]={};
  for(int c=0; c<values; ++c) {
    if (h[0][c]) ++barCount[0];
    if (h[1][c]) ++barCount[1];
    if (h[2][c]) ++barCount[2];
    if (h[3][c]) ++barCount[3];
  }

  // check how many quarters have a bar count above threshold
  int ok=4;
  for (int q=0; q<4; ++q) {
    if (barCount[q]<threshold) --ok;
  }

  printf("%s %d %d %d %d %s\n",filename,barCount[0],barCount[1],barCount[2],barCount[3],(ok?"ok":"bad"));

  // return null exit code if number of quarters with bar count above threshold meet requirements
  return ok < required;

}


