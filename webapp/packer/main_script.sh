#!/bin/bash

# Exit immediately on error and enable error tracing
set -eo pipefail

# Configuration variables
APP_DIR="/opt/csye6225"
ZIP_FILE="/tmp/webapp.zip "
PY_DIR="/opt/csye6225/webapp"
# Error handling function
handle_error() {
    echo "ERROR: Operation failed at line $1 - $2"
    exit 1
}

trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

# Function definitions
# Create .env file
echo "Creating .env file..."
cat > /tmp/.env << EOF
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
DATABASE_URL=${DATABASE_URL}
S3_BUCKET=${S3_BUCKET}
EOF



update_system() {
    echo "Updating system packages..."
    sudo apt clean -y
    sudo rm -rf /var/lib/apt/lists/*
    sudo apt update -y
    sudo apt upgrade -y
}

install_cloudwatch_agent() {
    echo "Installing and configuring Amazon CloudWatch Agent..."

    # Update packages and install CloudWatch Agent
    # Download the latest .deb installer
    wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb

    # Install the agent manually
    sudo dpkg -i amazon-cloudwatch-agent.deb

    # Create config directory
    sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc

    # Write CloudWatch Agent config
    cat <<EOF | sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/webapp.log",
                        "log_group_name": "csye6225-webapp-logs",
                        "log_stream_name": "{instance_id}",
                        "timestamp_format": "%Y-%m-%d %H:%M:%S"
                    }
                ]
            }
        }
    },
    "metrics": {
        "metrics_collected": {
            "statsd": {
                "service_address": ":8125"
            }
        }
    }
}
EOF

    # Start CloudWatch Agent with the config
    sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
        -a fetch-config \
        -m ec2 \
        -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
        -s

    # Enable the agent to start on boot
    sudo systemctl enable amazon-cloudwatch-agent

    echo "✅ CloudWatch Agent installed and configured successfully."
}

# install_postgresql() {
#     echo "Installing PostgreSQL..."
#     sudo apt update -y
#     sudo apt install -y postgresql postgresql-contrib
# }

# setup_database() {
#     echo "Configuring database..."
#     #source .env || { echo "Missing .env file"; exit 1; }
#     echo $DB_USER
#     if [ "$DB_USER" = "postgres" ]; then
#       sudo -u postgres psql -c "ALTER ROLE postgres WITH PASSWORD '$DB_PASSWORD';"
#     else
#       sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
#     fi
#     sudo -u postgres psql -c "CREATE DATABASE $DB_NAME WITH OWNER $DB_USER;"
# }



setup_app_user() {
    echo "Creating application user..."
    sudo groupadd csye6225 || true
    sudo useradd --system \
        --no-create-home \
        --shell /bin/false \
        -g csye6225 \
        csye6225 || true
}

setup_app_directory() {
    echo "Configuring application directory..."
    sudo mkdir -p $PY_DIR

    # Check if unzip is installed, if not, install it
    if ! command -v unzip &> /dev/null; then
        echo "unzip is not installed. Installing now..."
        sudo apt install -y unzip
    fi
    sudo unzip -q $ZIP_FILE -d $PY_DIR
    if [ $? -eq 0 ]; then
        echo "Unzip successful. Listing contents of $PY_DIR:"
        ls -la $PY_DIR
    else
        echo "ERROR: Unzip failed."
        exit 1
    fi
    # sudo chown -R csye6225:csye6225 $APP_DIR
    # sudo chmod -R 755 $APP_DIR
    #copy .env to py dir
    echo "Copying env to application working directory"
    sudo cp /tmp/.env $PY_DIR
    # Change working directory
    echo "Changing working directory to application working directory"
    cd $PY_DIR
}

log_file_permissions() {
    echo "Setting proper permissions for log files..."
    sudo touch /var/log/webapp.log
    sudo chown csye6225:csye6225 /var/log/webapp.log
    sudo chmod 644 /var/log/webapp.log
}

install_python_deps() {
    echo "Installing Python dependencies..."
    sudo apt install -y python3-pip python3-venv
}

set_permissions() {
  echo "Setting proper permissions for csye6225..."
  sudo chown -R csye6225:csye6225 $PY_DIR
  sudo chmod -R 755 $PY_DIR
}

setup_virtualenv() {
    echo "Configuring Python virtual environment with user csye6225 ..."
    cd $PY_DIR
    sudo -u csye6225 python3 -m venv venv
    sudo -u csye6225 /bin/bash -c "source venv/bin/activate && pip3 install --upgrade pip && pip3 install -r requirements.txt"
}

#Make sure to change the path of the this to the right path to activate the environment and run the application
#run_application(){
#  sudo -u csye6225 bash -c "source /opt/csye6225/amogh_jayasimha_002312557_02/webapp/venv/bin/activate && python3 run.py"
#}

# Main execution flow
main() {
    update_system
    install_cloudwatch_agent
    # install_postgresql
    # setup_database
    setup_app_user
    setup_app_directory
    log_file_permissions
    install_python_deps
    set_permissions
    setup_virtualenv

    echo "Application deployment completed successfully!"
    echo "Virtual environment activated at: $PY_DIR/venv"
#    echo "Starting up Application"

#    run_application

}

# Execute main function
main
