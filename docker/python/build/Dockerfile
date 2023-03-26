ARG IMG
FROM ${IMG}

RUN apk add --no-cache python3 python3-dev py3-pip
RUN pip install flask flask_restful redis

COPY app/movie/app.py app.py
CMD [ "python", "app.py" ]