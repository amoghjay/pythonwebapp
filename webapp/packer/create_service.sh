#!/bin/bash

#create csye6225 service file 
output_file=/tmp/csye6225.service
cat<<EOF >"$output_file"
[Unit]
Description=CSYE 6225 App
ConditionPathExists= /opt/csye6225/webapp
After=network.target


[Service]
Type=simple
User=csye6225
Group=csye6225
WorkingDirectory=/opt/csye6225/webapp
Environment="PATH=/opt/csye6225/webapp/venv/bin"
ExecStart=/opt/csye6225/webapp/venv/bin/python3 /opt/csye6225/webapp/run.py
Restart=always
RestartSec=5
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=csye6225

[Install]
WantedBy=multi-user.target
EOF

chmod +x $output_file
# cat $output_file
sudo mv /tmp/csye6225.service /etc/systemd/system/csye6225.service