ARG IMG
FROM ${IMG}
RUN apk add --no-cache go bash
COPY docker/golang/build/init.sh /opt/init.sh
CMD [ "/opt/init.sh" ]