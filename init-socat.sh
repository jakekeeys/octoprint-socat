#!/bin/sh

set -e
socat pty,wait-slave,link=/socat/ttyACM0 tcp:${PRINTER_HOST},forever,interval=10,fork &
exec docker-entrypoint.sh
