
ARG ALPINE=3.8
FROM alpine:${ALPINE} AS fetcher
RUN apk add  --no-cache \
        ca-certificates \
        coreutils \
        wget
ARG DOCKER_TAG=0.49.2
RUN wget https://github.com/gohugoio/hugo/releases/download/v${DOCKER_TAG}/hugo_extended_${DOCKER_TAG}_Linux-64bit.tar.gz \
    && wget https://github.com/gohugoio/hugo/releases/download/v${DOCKER_TAG}/hugo_extended_${DOCKER_TAG}_checksums.txt \
    && sha256sum --ignore-missing -c hugo_extended_${DOCKER_TAG}_checksums.txt \
    && tar -zxvf hugo_extended_${DOCKER_TAG}_Linux-64bit.tar.gz

FROM alpine:${ALPINE}
RUN apk add --no-cache \
        libc6-compat \
        libstdc++ \
        py3-pygments \
        py3-docutils && \
    ln -s /usr/bin/rst2html5-3 /usr/bin/rst2html
COPY --from=fetcher /hugo /usr/bin/hugo
COPY . /site
WORKDIR /site
VOLUME  /site
EXPOSE  1313
ENTRYPOINT ["/usr/bin/hugo"]
CMD ["server", "--bind=0.0.0.0"]