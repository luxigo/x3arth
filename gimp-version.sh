#!/bin/bash
if ! which gimp > /dev/null 2>&1 ; then
  echo "error: install gimp first !" >&2
  exit 1
fi

version=($(gimp --version | awk '{print $NF}' | tr '.' ' '))
echo ${version[0]}.${version[1]}
  

