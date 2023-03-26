ARG IMG
FROM ${IMG}

RUN apk add --no-cache go

COPY app/golang/run run
ENTRYPOINT [ "./run" ]