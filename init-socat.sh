#!/bin/sh

set -e
socat pty,wait-slave,link=/socat/ttyACM0 tcp:${PRINTER_HOST} &
exec docker-entrypoint.sh
