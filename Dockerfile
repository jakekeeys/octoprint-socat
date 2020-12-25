# Intermediate build container.
FROM python:3.7-alpine as build

ARG VERSION=1.5.2

RUN apk --no-cache add build-base
RUN apk --no-cache add linux-headers

RUN wget -qO- https://github.com/Octoprint/OctoPrint/archive/${VERSION}.tar.gz | tar xz
WORKDIR /OctoPrint-${VERSION}
RUN pip install -r requirements.txt
RUN python setup.py install

FROM python:3.7-alpine

COPY --from=build /usr/local/bin /usr/local/bin
COPY --from=build /usr/local/lib /usr/local/lib
COPY --from=build /OctoPrint-* /opt/octoprint

RUN apk --no-cache add build-base ffmpeg supervisor socat
RUN ln -s ~/.octoprint /data

VOLUME /data
WORKDIR /data

COPY supervisord.conf /etc/supervisor/supervisord.conf

ENV PIP_USER true
ENV PYTHONUSERBASE /data/plugins

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
