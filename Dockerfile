# MakeCode for micro:bit (pxt-microbit) local server
FROM node:20-bookworm

ARG PXT_MICROBIT_REF=master
ENV DEBIAN_FRONTEND=noninteractive \
    PXT_NODOCKER=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates python3 build-essential \
    && rm -rf /var/lib/apt/lists/*

# PXT command line, plus a static file server for the packaged editor
RUN npm install -g pxt http-server@14.1.1

WORKDIR /app
RUN git clone --depth 1 --branch ${PXT_MICROBIT_REF} https://github.com/microsoft/pxt-microbit.git .

RUN npm install

# Bundle GitHub extensions from extensions.txt so they work offline
COPY extensions.txt bundle-extensions.js /opt/pxt-ext/
RUN node /opt/pxt-ext/bundle-extensions.js /opt/pxt-ext/extensions.txt /app

# Build the target once at image build time so `pxt serve` starts fast
RUN pxt buildtarget

# Package the editor as a static site in built/packaged. The packaged build
# also pre-compiles native (C++) images for each bundled extension into
# built/hexcache and copies them into the site, so any browser on the network
# can download hex files without a cloud build.
RUN pxt staticpkg

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/docker-entrypoint.sh \
    && chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 3232 3233 3443
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["static"]
