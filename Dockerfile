# MakeCode for micro:bit (pxt-microbit) local server
FROM node:20-bookworm

ARG PXT_MICROBIT_REF=master
ENV DEBIAN_FRONTEND=noninteractive \
    PXT_NODOCKER=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates python3 build-essential \
    && rm -rf /var/lib/apt/lists/*

# PXT command line
RUN npm install -g pxt

WORKDIR /app
RUN git clone --depth 1 --branch ${PXT_MICROBIT_REF} https://github.com/microsoft/pxt-microbit.git .

RUN npm install

# Bundle GitHub extensions from extensions.txt so they work offline
COPY extensions.txt bundle-extensions.js /opt/pxt-ext/
RUN node /opt/pxt-ext/bundle-extensions.js /opt/pxt-ext/extensions.txt /app

# Build the target once at image build time so `pxt serve` starts fast
RUN pxt buildtarget

# Pre-compile native (C++) images for each bundled extension into
# built/hexcache, so adding one extension needs no cloud build later.
# staticpkg runs the packaged target build; its static site output is not needed.
ARG PXT_OFFLINE_HEX=1
RUN if [ "$PXT_OFFLINE_HEX" = "1" ]; then pxt staticpkg && rm -rf built/packaged; fi

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/docker-entrypoint.sh \
    && chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 3232 3233
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["serve"]
