GIMP_VERSION=$(shell ./gimp-version.sh)

all:

install:
	install -D sample.bmp ${HOME}/.x3arth/sample.bmp
	install -D samplecolorize.scm ${HOME}/.gimp-${GIMP_VERSION}/scripts/samplecolorize.scm
	install -D x3arth ${HOME}/bin
