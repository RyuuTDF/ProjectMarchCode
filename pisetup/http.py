#!/usr/bin/python

# Simple HTTP server for retrieving recordings from the Raspberry Pi
from flask import Flask
from flask import render_template
import subprocess
import os

app = Flask(__name__)

# Index page: list the directory in a table
@app.route("/")
def home():
    flist = os.listdir("/home/pi/recordings/")
    flist.sort()
    return render_template("index.html", dowloadlist=flist)

# Download route: If a recording exists, return the output of the converter program
@app.route("/download/<file>")
def download(file):
    path = "/home/pi/recordings/" + file
    if os.path.exists(path):
        p = subprocess.Popen(['/opt/exo/convert', path], stdout=subprocess.PIPE,
            stderr=subprocess.PIPE)
        out, err = p.communicate()
        return out
    else:
        return "File not found!"

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=80)
