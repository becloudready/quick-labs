#!/bin/bash
yum install python-pip -y;
pip install flask;
python ~/aws-python/flaskApp/app.py &;