import uuid
import redis

from flask import Flask, redirect, url_for, request

app = Flask(__name__)

@app.route('/movie', methods=['GET'])
def home():
    return {"api":"movie","version":"v0.0.2"}

@app.route('/movie/api', methods=['GET'])
def get():
    r = redis.StrictRedis(host='redis', port=6379, decode_responses=True)
    response = r.keys('*')
    return response

@app.route('/movie/api', methods=['POST'])
def post():
    r = redis.StrictRedis(host='redis', port=6379, decode_responses=True)
    name = request.args.get('name', type = str)
    r.set(name, "id")
    return 'agregando pelicula: ' + name

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)