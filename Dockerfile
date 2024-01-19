FROM ghcr.io/aserto-dev/topaz:model-v2.2

RUN apk add --no-cache bash

WORKDIR /app
COPY ./entrypoint.sh /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
