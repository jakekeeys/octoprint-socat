FROM octoprint/octoprint

USER root
RUN apt-get install -y socat htop

COPY docker-entrypoint.sh /usr/local/bin/
