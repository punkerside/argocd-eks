ARG IMG
FROM ${IMG}
RUN apk add --no-cache python3
COPY app/python/ /app/
CMD [ "python", "app.py" ]