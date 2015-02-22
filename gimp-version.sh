#!/bin/bash
version=($(gimp --version | awk '{print $NF}' | tr '.' ' '))
echo ${version[0]}.${version[1]}
  

