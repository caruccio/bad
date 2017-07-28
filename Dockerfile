FROM alpine:3.6

ENV PATH=/bad/bin:$PATH \
    HOME=/bad

RUN apk upgrade --no-cache && \
    apk add --no-cache \
    'ansible<2.4' \
    bash \
    curl \
    docker \
    docker-py \
    openssl \
    python2 && \
    curl -s -L https://bootstrap.pypa.io/get-pip.py | python -u && \
    pip install boto3 paramiko

COPY bin/install-deps.sh /bad/bin/

RUN /bad/bin/install-deps.sh

COPY . /bad

VOLUME ["/var/run/docker.sock", "/bad/.docker/", "/src/", "/ssh-private-key"]

ENTRYPOINT ["/bad/bin/container-entrypoint"]
