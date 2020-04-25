#!/bin/sh

socat pty,wait-slave,link=/dev/ttyACM0,perm-late=0770,group-late=octoprint tcp:${PRINTER_HOST} &
su - octoprint -c "PATH='/opt/venv/bin:/opt/ffmpeg:/opt/cura:$PATH' exec ${1}"
