# logger_util.py
import os
import logging
import sys
from pathlib import Path

# Define log file location
# LOF_DIR = "/var/log"
# LOG_FILE = "/var/log/webapp.log"
# if not os.path.exists(LOF_DIR):
#     os.makedirs(LOF_DIR, exist_ok=True)
# # Ensure log directory exists
# Path(LOG_FILE).parent.mkdir(parents=True, exist_ok=True)
hostname = os.uname().nodename
if os.getenv('GITHUB_ACTIONS') == 'true' or hostname.endswith('.local'):
    LOG_FILE = 'webapp_local.log'
else:
    LOG_FILE = '/var/log/webapp.log'


# Create and configure logger
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(name)s - %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stdout)
    ]
)


# Reusable logger for other modules
def get_logger(name: str):
    return logging.getLogger(name)