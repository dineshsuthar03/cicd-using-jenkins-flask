#!/bin/bash

# Step 1: Navigate to Jenkins workspace
cd $WORKSPACE

# Define the path to your PEM file (private key) for SSH access
PEM_FILE="/home/ubuntu/workspace/staging-server.pem"

# Define the destination path on the remote server
REMOTE_SERVER="user@ip"
REMOTE_PATH="/home/ubuntu/workspace/cicd-jenkins-flask-app"

# Step 2: Copy the Flask app to the server using SCP with PEM file
echo "Starting to copy Flask app to the remote server..."
scp -i $PEM_FILE -r $WORKSPACE/* $REMOTE_SERVER:$REMOTE_PATH

if [ $? -eq 0 ]; then
    echo "Flask app copied successfully to the remote server."
else
    echo "Failed to copy Flask app to the remote server."
    exit 1
fi

# Step 3: SSH into the remote server and perform necessary tasks
echo "Connecting to the remote server to deploy the Flask app..."

ssh -i $PEM_FILE $REMOTE_SERVER << EOF
    # Navigate to the Flask app directory
    cd $REMOTE_PATH

    # Step 4: Set up the environment (e.g., activate virtual environment)
    if [ -d "venv" ]; then
        echo "Activating the existing virtual environment..."
        source venv/bin/activate
    else
        echo "Virtual environment not found, creating a new one..."
        python3 -m venv venv
        source venv/bin/activate
        echo "Installing dependencies..."
        pip install -r requirements.txt
    fi

    # Step 5: Restart the Flask app (e.g., using gunicorn or any other method)
    echo "Starting the Flask app with gunicorn..."
    nohup gunicorn -w 4 -b 0.0.0.0:5002 app:app > flask_app.log 2>&1 &

    # Check if the Flask app is running
    FLASK_PID=\$(pgrep -f 'gunicorn')
    if ps -p \$FLASK_PID > /dev/null; then
        echo "Flask app started successfully with PID: \$FLASK_PID"
    else
        echo "Flask app failed to start"
        exit 1
    fi

    # Optional: Run a health check using curl
    echo "Checking if Flask app is responding..."
    if curl --silent --fail http://localhost:5002; then
        echo "Flask app is live and responding."
    else
        echo "Flask app is not responding on port 5002"
        exit 1
    fi
EOF

# Step 6: Final status
echo "Deployment to the remote server completed."
