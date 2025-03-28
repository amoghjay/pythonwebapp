#!/bin/bash 

sudo systemctl daemon-reload
sudo systemctl enable csye6225
sudo systemctl start csye6225
sudo systemctl status csye6225