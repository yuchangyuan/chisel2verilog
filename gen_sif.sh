#!/bin/sh
VER=0.4

nix build
podman load -i result
rm result

podman save localhost/chisel:v$VER -o tmp.tar.gz
podman image rm localhost/chisel:v$VER

apptainer pull chisel2verilog_5-${VER}.sif docker-archive:tmp.tar.gz
rm tmp.tar.gz
