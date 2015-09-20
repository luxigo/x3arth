GIMP_VERSION=$(shell ./gimp-version.sh)

all: histogram_check

install:
	install -D sample.bmp ${HOME}/.x3arth/sample.bmp
	install -D samplecolorize.scm ${HOME}/.gimp-${GIMP_VERSION}/scripts/samplecolorize.scm
	install -D x3arth ${HOME}/bin
	install -D histogram_check ${HOME}/bin

histogram_check: histogram_check.cpp Makefile
	g++ histogram_check.cpp -o histogram_check -ltiff -Wall -g
