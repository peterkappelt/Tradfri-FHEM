#!/bin/sh
cd ./src

cp /opt/fhem/FHEM/*Tradfri* ./FHEM
ls -al ./FHEM
perl ./build-controls-file.pl

echo "Done."
