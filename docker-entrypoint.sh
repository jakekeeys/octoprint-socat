#!/bin/sh

socat pty,link=/socat/ttyACM0 tcp:${PRINTER_HOST} &
exec ${1}
