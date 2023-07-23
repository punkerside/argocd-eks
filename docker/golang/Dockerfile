ARG IMG
FROM ${IMG} AS build
RUN apk add --no-cache go
ADD app/golang/ /app
RUN go get go.mongodb.org/mongo-driver/bson && \
  go get go.mongodb.org/mongo-driver/mongo && \
  go get go.mongodb.org/mongo-driver/mongo/options && \
  go get go.mongodb.org/mongo-driver/bson && \
  go build

ARG IMG
FROM ${IMG}
RUN apk add --no-cache go
COPY --from=build /app/run ./
CMD [ "./run" ]