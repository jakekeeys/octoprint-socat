FROM octoprint/octoprint

USER root
RUN apt-get install -y socat
COPY docker-entrypoint.sh /usr/local/bin/
RUN mkdir /socat
RUN chown octoprint:octoprint /socat

USER octoprint
ENV PATH="/opt/venv/bin:/opt/ffmpeg:/opt/cura:$PATH"