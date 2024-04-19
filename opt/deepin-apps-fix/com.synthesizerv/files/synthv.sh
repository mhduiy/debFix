#!/bin/bash
#/bin/sh
if [ ! -d $HOME/Synthv2 ]
then
    cd $HOME
    mkdir Synthv2
    cp -r /opt/apps/com.synthesizerv/files/files.7z $HOME/Synthv2
    cd $HOME/Synthv2
    7z x files.7z
    rm files.7z
    mkdir settings
    mkdir databases
else
    cd /opt/apps/com.synthesizerv/files
    a=`cat versions`
    cd $HOME/Synthv2
    b=0
    if [ ! -e $HOME/Synthv2/versions ]
    then
        b=0
    else
        b=`cat versions`
    fi
    if [ $a -gt $b ]
    then
        ls . | grep -v settings | grep -v databases | xargs rm -rf 
        cp -r /opt/apps/com.synthesizerv/files/files.7z $HOME/Synthv2
        cp /opt/apps/com.synthesizerv/files/versions $HOME/Synthv2/
        7z x files.7z
        rm files.7z
    fi 
fi
$HOME/Synthv2/synthv-studio $1
