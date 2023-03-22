ARG IMG
FROM ${IMG}

RUN apk add --no-cache go

COPY app/music/run run
ENTRYPOINT [ "./run" ]