#!/bin/bash

print_help () {
    echo 'Update AXI slave from JSON file. Updates all files except top level AXI slave file, unless it is called with -a'
    echo 'Usage: $ ./update_axi_slave.sh [option]'
    echo 'Options: '
    echo '-a: Update all files, including top level AXI slave (changes to top level slave file is lost)'
    echo '-h: Print this message'
}


if [ $# -gt 1 ]; then
    echo 'Too many options'
    print_help
    exit
elif [ "$1" == "-h" ] && [ $# -eq 1 ]; then
    print_help
    exit
elif [ "$1" != "-a" ] && [ $# -eq 1 ]; then
    echo 'Unknown option'
    print_help
    exit
else
    if [[ -d "temp" ]]; then
        rm -rf temp
    fi

    uart ../json/canola.json -o temp

    if [ "$1" == "-a" ] && [ $# -eq 1 ]; then
        mv temp/canola_axi_slave/hdl/canola_axi_slave.vhd ../rtl/axi_slave/
    fi

    mv temp/canola_axi_slave/header/canola_axi_slave.py ../../software/py
    mv temp/canola_axi_slave/header/canola_axi_slave.h ../../software/cpp
    mv temp/canola_axi_slave/header/canola_axi_slave.hpp ../../software/cpp
    mv temp/canola_axi_slave/hdl/axi_pkg.vhd ../rtl/axi_slave/

    mv temp/canola_axi_slave/hdl/canola_axi_slave_axi_pif.vhd ../rtl/axi_slave/
    mv temp/canola_axi_slave/hdl/canola_axi_slave_pif_pkg.vhd ../rtl/axi_slave/
    mv temp/canola_axi_slave/docs/canola_axi_slave.tex ../../doc/
    rm -rf temp
fi
