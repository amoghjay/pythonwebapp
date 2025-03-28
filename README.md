# Step by step imporvements worked and developed (From Bottom to Up)

# 6th Update: Logging and Metrics
##  Overview

The application is now enhanced with:

- Centralized structured logging using Python `logging` module
- Log forwarding to **Amazon CloudWatch Logs**
- Custom metrics pushed to **Amazon CloudWatch Metrics** via **StatsD**

---

## Logging Functionality

### Features:
- Logs are written to: `/var/log/webapp.log`
- Logs are forwarded to CloudWatch Log Group: `csye6225-webapp-logs`
- Each log entry includes:
  - Timestamp
  - Log level (INFO, ERROR, etc.)
  - Module and message
- All exceptions are logged with full stack traces

## Metrics Functionality

### Metrics Framework:
- Uses [`statsd`](https://pypi.org/project/statsd/) Python client
- CloudWatch Agent on EC2 instance listens on `localhost:8125`

### 📊 Custom Metrics Tracked:

| Metric Name                         | Type     | Description                                 |
|------------------------------------|----------|---------------------------------------------|
| `api.<endpoint>.count`             | counter  | # of times an API is called                 |
| `api.<endpoint>.latency`           | timing   | Duration (ms) of full API request           |
| `db.query.<operation>.time`        | timing   | DB query time in ms                         |
| `s3.<operation>.time`              | timing   | Time taken for S3 interaction (upload/delete) |


# 5th Update : Creating New v1/file Endpoint

## Overview
This repository contains the **FastAPI-based WebApp** with newly added **file management APIs** that integrate with **AWS S3 & PostgreSQL RDS**. Infrastructure automation is handled using **Terraform**.

---

## New Features & Updates

### 1. File Upload to AWS S3
- **Endpoint:** `POST /v1/upload`
- **Functionality:**
    - Accepts a file and uploads it to **AWS S3**.
    - Stores metadata (file name, size, upload date, etc.) in **PostgreSQL RDS**.
    - Returns the **file URL**.

### 2. Get File Metadata
- **Endpoint:** `GET /v1/file/{id}`
- **Functionality:**
    - Fetches file metadata from the database.
    - Does NOT return the actual file, only its S3 URL.
    - Rejects requests with a request body (returns 400 Bad Request).

### 3. Delete File from AWS S3 & Database
- **Endpoint:** `DELETE /v1/file/{id}`
- **Functionality:**
    - Deletes the file from S3 and removes metadata from the database.
    - Rejects requests with a request body (returns 400 Bad Request).


# Update 4: Creating Custom Images with Packer

## Overview 

This guide details the steps to create a custom image for deploying a web application using Packer, based on Ubuntu 24.04 LTS. The custom image includes all necessary dependencies and configurations for smooth deployment.

## Packer Configuration

### `packer/` Directory

Contains Packer configuration files needed to build the custom image.

### `fin-packer-test.pkr.hcl`

Defines the Packer configuration for the custom image. Key components include:

- **Required Plugins**: Specifies GCP and AWS plugins.
- **Variables**: Defines variables like project ID, PostgreSQL password, source image, zone, machine type, and SSH username.
- **Source Block**: Configures AWS EBS and GCP source details such as project ID, source image, zone, instance name, disk size, disk type, SSH username, machine type, tags, and network.
- **Build Block**: Details build steps, including provisioning files and executing shell commands to set up the environment, install dependencies, and configure the web application.
- **Provisioners**: Uses provisioners like file to copy files and shell to run commands for environment setup and web application configuration.

## GitHub Actions Workflow

### `.github/workflows/` Directory

Contains GitHub Actions workflow files for validating the Packer template and building the custom image.

### `PackerTestWorkflow.yml`

Validates the Packer template format and configuration before building the image. Tasks include:

- Installing Packer.
- Checking the Packer template format with `packer fmt -check`.
- Validating the Packer template with `packer validate`.

### `PackerBuildWorkflow.yml`

Builds the custom image with Packer after merging changes into the main branch. Steps include:

- Installing dependencies and setting up the environment for Packer.
- Authenticating with GCP using service account credentials and AWS using AWS CLI.
- Running pytest for integration tests.
- Installing Packer.
- Validating the Packer template.
- Building the custom image with Packer.
- Creating an instance template from the custom image.

## Note

- Ensure necessary secrets and environment variables are configured in the GitHub repository settings for GCP and other services authentication.
- Verify network configurations and firewall rules in GCP and AWS to allow traffic to the web application port.
- Update secrets to enable GitHub Actions workflows to authenticate with GCP and AWS.

These configurations and workflows enable seamless creation and deployment of a custom image for your web application using Packer and GitHub Actions.


# Update 3: Adding Github Actions CI pipeline

## Key Features

### Automated Testing
- Runs `test_healthz.py` on every PR, checking:
    - HTTP status codes
    - Response headers
    - Error handling

### Merge Locking
- PRs can't merge until tests pass

### Security
- Prevents force-pushes and branch deletion

### Visibility
- Test results appear directly in PR checks

## Validation Steps
1. Create a test PR with failing tests
2. Verify GitHub Actions blocks merging
3. Fix tests and push changes
4. Confirm merge unlocks after successful run


# Update 2: Automating Application Setup with Shell Script and Integration Testing

This update contains a bash script for automating the deployment of a Python FastAPI application on Ubuntu 24.04 LTS.
### Features

- System package updates
- PostgreSQL installation and database setup
- Application user and group creation
- Python environment setup with virtual environment
- Automatic dependency installation
- Application deployment 


### Script.sh
Prerequisites
- Ubuntu 24.04 LTS
- Sudo privileges
- Application zip file (amogh_jayasimha_002312557_02.zip) in /tmp/
- .env file in /tmp/ with database credentials

## Testing using Pytest

The testing module is designed to validate the functionality of the /healthz endpoint, 
ensuring it meets the specified requirements and handles various scenarios correctly

### Test Cases  
The test suite includes the following test cases:
- Successful Health Check: Verifies that a GET request to /healthz returns a 200 OK status code with no content and appropriate cache control headers.
- Request with Query Parameters: Checks that a GET request to /healthz with query parameters returns a 400 Bad Request status code.
- Method Not Allowed: Validates that non-GET requests to /healthz return a 405 Method Not Allowed status code.
- Database Failure Scenario: Simulates a database failure and verifies that the API returns a 503 Service Unavailable status code.

### Running the Tests
To run the tests:
Ensure you have pytest installed:
```bash
pip3 install pytest
```
- Navigate to the project root directory.
- Run the tests using:
```bash
pytest tests/test_healthz.py
```


# Started with : Building a Basic Healtz API with FASTApi, SQLAlchemy, and PostgreSQL

This project demonstrates the creation of a simple API to test the connection to a local database using FASTApi, SQLAlchemy, and PostgreSQL.

## Features

### Healthz Endpoint

The API includes a healthz endpoint designed to perform a database connection test. 

- To start the database server, use the Postgres desktop app.
- To verify the connection status, use the following curl request:

```bash
curl -vvvv http://localhost:8080/healthz
```

### GET /healthz

- Inserts a record in the health check table
- Returns:
- HTTP 200 OK if the record was inserted successfully
- HTTP 503 Service Unavailable if the insert command was unsuccessful
- The response code is HTTP 400 Bad Request if the request includes any payload
- HTTP 405 Method Not Allowed, for all other methods other than GET
- No response payload


### Middleware Blocking Other HTTP Methods

The healthz endpoint has been secured by middleware to allow only specific HTTP methods and Adds `Cache-Control: no-cache` header to the response
To test this middleware, you can use the following curl requests:

**PUT request:**

```bash
curl -vvvv -X PUT http://localhost:8080/healthz
```

**POST request:**

```bash
curl -vvvv -X POST http://localhost:8080/healthz
```

**DELETE request:**

```bash
curl -vvvv -X DELETE http://localhost:8080/healthz
```

**PATCH request:**

```bash
curl -vvvv -X PATCH http://localhost:8080/healthz
```

## Installation and Setup

1. Clone the repository
2. Create a virtual environment:
python -m venv venv
source venv/bin/activate # On Windows use venv\Scripts\activate
text
3. Install dependencies:
pip install -r requirements.txt
4. Set up your PostgreSQL database and update the `.env` file with your database URL
5. Run the application: python3 run.py
