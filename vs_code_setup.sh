#!/bin/bash

# Step 1: Update system packages
# This step ensures that all packages on your server are up-to-date. 
# It's essential to keep the system secure and compatible with new software.
echo ""
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install necessary dependencies
# These tools are required for downloading, extracting, and generating certificates.
echo ""
echo "Installing necessary dependencies..."
sudo apt install -y unzip curl wget git openssl

# Step 2: Create the /var/app directory
# This directory will store the VS Code Server files for consistency and organization.
echo ""
echo "Creating /var/app directory for storing VS Code Server files..."
sudo mkdir -p /var/app

# Step 3: Download the latest code-server release
# Fetches the latest version of VS Code Server from its official GitHub repository.
echo ""
echo "Downloading the latest version of VS Code Server..."
latest_version=$(curl -s https://api.github.com/repos/coder/code-server/releases/latest | grep "browser_download_url.*linux-amd64.tar.gz" | cut -d '"' -f 4)
wget -O code-server-latest-linux-amd64.tar.gz $latest_version

# Extract the downloaded tar.gz file and move it to /var/app
# This installs VS Code Server in a consistent location for easy management.
echo ""
echo "Extracting and installing VS Code Server into /var/app..."
tar -xvzf code-server-latest-linux-amd64.tar.gz
sudo mv code-server-*-linux-amd64 /var/app/code-server
sudo ln -s /var/app/code-server/bin/code-server /usr/local/bin/code-server

# Clean up the downloaded tar.gz file to save space
# Once the server is installed, the archive is no longer needed.
echo ""
echo "Cleaning up temporary installation files..."
rm -rf code-server-latest-linux-amd64.tar.gz

# Verify the installation of code-server
# Ensures the installation was successful by checking the version.
echo ""
echo "Verifying the VS Code Server installation..."
code-server --version

# Step 4: Generate self-signed SSL certificates
# Self-signed certificates encrypt traffic, though they are not trusted by browsers.
echo ""
echo "Generating self-signed SSL certificates for secure access..."
mkdir -p ~/.config/code-server
openssl req -newkey rsa:2048 -nodes -keyout ~/.config/code-server/selfsigned.key -x509 -days 365 -out ~/.config/code-server/selfsigned.crt -subj "/C=US/ST=State/L=City/O=Organization/OU=Unit/CN=localhost"

# Step 5: Create a configuration file for VS Code Server
# The configuration specifies the server's behavior, including the SSL certificate and password.
echo ""
echo "Creating a configuration file for VS Code Server..."
cat > ~/.config/code-server/config.yaml << EOF
bind-addr: 0.0.0.0:443
auth: password
password: changeme!
cert: ~/.config/code-server/selfsigned.crt
cert-key: ~/.config/code-server/selfsigned.key
EOF

# Step 6: Create a script to start VS Code Server automatically
# This script starts the server and ensures it's running.
echo ""
echo "Creating a script to manage the VS Code Server startup..."
cat > ~/startup.sh << 'EOF'
#!/bin/bash

# Check if VS Code Server is already running
if ps -ef | grep -v grep | grep code-server > /dev/null
then
    echo "VS Code Server is already running."
else
    echo "Starting VS Code Server on port 443..."
    sudo code-server --bind-addr 0.0.0.0:443 --cert ~/.config/code-server/selfsigned.crt --cert-key ~/.config/code-server/selfsigned.key /home/ubuntu > ~/code-server.log 2>&1 &
    echo "VS Code Server started on port 443."
fi
EOF

# Make the startup.sh script executable
# Allows the script to be run directly from the terminal.
echo ""
echo "Making the startup script executable..."
chmod +x ~/startup.sh

# Step 7: Automatically run the startup script when the user logs in
# Adds the script to .bashrc so it runs automatically at login.
echo ""
echo "Adding the startup script to .bashrc for automatic execution..."
if ! grep -Fxq "~/startup.sh" /home/ubuntu/.bashrc; then
    echo "~/startup.sh" >> /home/ubuntu/.bashrc
fi

# Run the startup script to start the VS Code Server immediately
echo ""
echo "Starting the VS Code Server..."
~/startup.sh

# Step 8: Retrieve the system's private and public IP addresses
# Displays the IP addresses for reference and use in accessing the server.
echo ""
echo "Retrieving the private and public IP addresses of the system..."
PRIVATE_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com/)

# Export the IP addresses as environment variables
# Saves the IP addresses for use in future sessions.
echo ""
echo "Exporting the private and public IP addresses as environment variables..."
echo "export HOST_PRIVATE_IP=$PRIVATE_IP" >> ~/.bashrc
echo "export HOST_PUBLIC_IP=$PUBLIC_IP" >> ~/.bashrc

# Source .bashrc to apply the changes immediately
source ~/.bashrc

# Display the IP addresses for reference
echo ""
echo "Private IP Address: $HOST_PRIVATE_IP"
echo "Public IP Address: $HOST_PUBLIC_IP"

# Step 9: Check if the default password is still in use
# Prompts the user to change the default password for better security.
echo ""
echo "Checking if the password is still set to the default..."
if grep -q "password: changeme!" ~/.config/code-server/config.yaml; then
    echo ""
    echo "WARNING: The password is still set to 'changeme!'."
    echo "Please update the password in the following file:"
    echo "~/.config/code-server/config.yaml"
    echo "Restart the VS Code Server after making changes."
fi

# Step 10: Optimize system limits for file watching
# Increases the number of files the system can monitor, improving editor performance.
echo ""
echo "Increasing the number of file watchers for better performance..."
sudo bash -c 'echo "fs.inotify.max_user_watches=524288" > /etc/sysctl.d/99-sysctl.conf'

echo ""
echo "Applying the updated file watcher configuration..."
sudo sysctl -p /etc/sysctl.d/99-sysctl.conf

# Verify the configuration change
echo ""
echo "Verifying the file watcher configuration..."
CURRENT_VALUE=$(sysctl fs.inotify.max_user_watches | awk '{print $3}')
if [ "$CURRENT_VALUE" -eq 524288 ]; then
    echo "File watcher limit successfully updated to $CURRENT_VALUE."
else
    echo "Failed to update file watcher limit. Current value is $CURRENT_VALUE."
fi

# Final Step: Provide the user with the access link for VS Code Server
# Outputs the final access URL and reminds the user about the password.
echo ""
echo "Setup completed successfully."
echo "You can manually start the server using: ~/startup.sh"
if [ -z "$HOST_PUBLIC_IP" ]; then
    echo "Public IP not found. Ensure the instance has a public IP assigned."
else
    echo "Access your VS Code Server at: https://$HOST_PUBLIC_IP"
fi
echo "Note: The default password is 'changeme!' and should be changed for better security."
