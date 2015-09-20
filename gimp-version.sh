#!/bin/bash
if ! which gimp ; then
  echo "error: install gimp first !"
fi

version=($(gimp --version | awk '{print $NF}' | tr '.' ' '))
echo ${version[0]}.${version[1]}
  

