#!/bin/bash

# Exit immediately on error and enable error tracing
set -eo pipefail

# Configuration variables
APP_DIR="/opt/csye6225"
ZIP_FILE="/tmp/amogh_jayasimha_002312557_02.zip "
PY_DIR="/opt/csye6225/amogh_jayasimha_002312557_02/webapp"
# Error handling function
handle_error() {
    echo "ERROR: Operation failed at line $1 - $2"
    exit 1
}

trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

# Function definitions
update_system() {
    echo "Updating system packages..."
    sudo apt update -y
    sudo apt upgrade -y
}

install_postgresql() {
    echo "Installing PostgreSQL..."
    sudo apt install -y postgresql postgresql-contrib
}

setup_database() {
    echo "Configuring database..."
    source .env || { echo "Missing .env file"; exit 1; }

    if [ "$DB_USER" = "postgres" ]; then
      sudo -u postgres psql -c "ALTER ROLE postgres WITH PASSWORD '$DB_PASSWORD';"
    else
      sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
    fi
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME WITH OWNER $DB_USER;"
}



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
    sudo mkdir -p $APP_DIR
    # Check if unzip is installed, if not, install it
    if ! command -v unzip &> /dev/null; then
        echo "unzip is not installed. Installing now..."
        sudo apt install -y unzip
    fi
    sudo unzip -q $ZIP_FILE -d $APP_DIR
    sudo chown -R csye6225:csye6225 $APP_DIR
    sudo chmod -R 755 $APP_DIR
    #copy .env to py dir
    echo "Copying env to application working directory"
    cp /tmp/.env $PY_DIR
    # Change working directory
    echo "Changing working directory to application working directory"
    cd $PY_DIR || { echo "Failed to change directory"; exit 1; }
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
    install_postgresql
    setup_database
    setup_app_user
    setup_app_directory
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
