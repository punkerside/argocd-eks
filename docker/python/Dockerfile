ARG IMG
FROM ${IMG} AS build
RUN apk add --no-cache python3 python3-dev py3-pip
RUN pip install flask flask_restful redis -t /app
COPY app/python/app.py /app/app.py

ARG IMG
FROM ${IMG}
RUN apk add --no-cache python3
COPY --from=build /app /app
CMD [ "python", "app.py" ]