#!/bin/bash

# Step 1: Update system packages
echo ""
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install necessary dependencies
echo ""
echo "Installing dependencies..."
sudo apt install -y unzip curl wget git openssl

# Step 2: Create the /var/app directory (still needed for installation)
echo ""
echo "Creating /var/app directory..."
sudo mkdir -p /var/app

# Step 3: Download the latest code-server release
echo ""
echo "Downloading the latest code-server release..."
latest_version=$(curl -s https://api.github.com/repos/coder/code-server/releases/latest | grep "browser_download_url.*linux-amd64.tar.gz" | cut -d '"' -f 4)
wget -O code-server-latest-linux-amd64.tar.gz $latest_version

# Extract and move code-server to /var/app
echo ""
echo "Extracting and installing code-server to /var/app..."
tar -xvzf code-server-latest-linux-amd64.tar.gz
sudo mv code-server-*-linux-amd64 /var/app/code-server
sudo ln -s /var/app/code-server/bin/code-server /usr/local/bin/code-server

# Clean up downloaded files
echo ""
echo "Cleaning up installation files..."
rm -rf code-server-latest-linux-amd64.tar.gz

# Verify code-server installation
echo ""
echo "Verifying code-server installation..."
code-server --version

# Step 4: Generate self-signed SSL certificates
echo ""
echo "Generating self-signed SSL certificates..."
mkdir -p ~/.config/code-server
openssl req -newkey rsa:2048 -nodes -keyout ~/.config/code-server/selfsigned.key -x509 -days 365 -out ~/.config/code-server/selfsigned.crt -subj "/C=US/ST=State/L=City/O=Organization/OU=Unit/CN=localhost"

# Step 5: Update config.yaml to set the password
echo ""
echo "Updating config.yaml to set the password..."
cat > ~/.config/code-server/config.yaml << EOF
bind-addr: 0.0.0.0:8080
auth: password
password: changeme!
cert: ~/.config/code-server/selfsigned.crt
cert-key: ~/.config/code-server/selfsigned.key
EOF

# Step 6: Create startup.sh script
echo ""
echo "Creating startup.sh script..."
cat > ~/startup.sh << 'EOF'
#!/bin/bash

# Check if code-server is running using ps -ef | grep
if ps -ef | grep -v grep | grep code-server > /dev/null
then
    echo "VS Code Server is already running."
else
    echo "Starting VS Code Server..."
    code-server --bind-addr 0.0.0.0:8080 --cert ~/.config/code-server/selfsigned.crt --cert-key ~/.config/code-server/selfsigned.key /home/ubuntu > ~/code-server.log 2>&1 &
    echo "VS Code Server started."
fi
EOF

# Make the startup.sh script executable
echo ""
echo "Making the startup.sh script executable..."
chmod +x ~/startup.sh

# Step 7: Add a command to run startup.sh at the end of .bashrc
echo ""
echo "Adding startup script to .bashrc..."
if ! grep -Fxq "~/startup.sh" /home/ubuntu/.bashrc; then
    echo "~/startup.sh" >> /home/ubuntu/.bashrc
fi

# Run the startup.sh script
echo ""
echo "Running the startup script..."
~/startup.sh

# Step 8: Retrieve the Private and Public IP Addresses
echo ""
echo "Retrieving the IP addresses..."
PRIVATE_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com/)

# Export IP addresses as environment variables
echo ""
echo "Exporting IP addresses as environment variables..."
echo "export HOST_PRIVATE_IP=$PRIVATE_IP" >> ~/.bashrc
echo "export HOST_PUBLIC_IP=$PUBLIC_IP" >> ~/.bashrc

# Source .bashrc to apply the changes immediately
source ~/.bashrc

# Display the IP addresses
echo ""
echo "Private IP Address: $HOST_PRIVATE_IP"
echo "Public IP Address: $HOST_PUBLIC_IP"

# Step 9: Check if the password is still "changeme!" and display a warning if it is
echo ""
echo "Checking if the password is still the default..."
if grep -q "password: changeme!" ~/.config/code-server/config.yaml; then
    echo ""
    echo "WARNING: The password is still set to 'changeme!'."
    echo "It is recommended to change this password in the following file:"
    echo "~/.config/code-server/config.yaml"
    echo "Restart the code-server after changing the password for the changes to take effect."
fi

# Step 10: Update fs.inotify.max_user_watches value
echo ""
echo "Updating fs.inotify.max_user_watches value..."
sudo bash -c 'echo "fs.inotify.max_user_watches=524288" > /etc/sysctl.d/99-sysctl.conf'

echo ""
echo "Applying the new sysctl configuration..."
sudo sysctl -p /etc/sysctl.d/99-sysctl.conf

# Verify the change
echo ""
echo "Verifying the change..."
CURRENT_VALUE=$(sysctl fs.inotify.max_user_watches | awk '{print $3}')
if [ "$CURRENT_VALUE" -eq 524288 ]; then
    echo "The value of fs.inotify.max_user_watches has been successfully updated to $CURRENT_VALUE."
else
    echo "Failed to update fs.inotify.max_user_watches. Current value is $CURRENT_VALUE."
fi

# Display the access message with the Public IP
echo ""
echo "Setup completed successfully."
echo "You can run the startup script manually with: ~/startup.sh"
if [ -z "$HOST_PUBLIC_IP" ]; then
    echo "Public IP not found. Ensure the instance has a public IP assigned."
else
    echo "Access your VS Code Server at: https://$HOST_PUBLIC_IP:8080"
fi
echo "Note: The password is 'changeme!' and you may need to bypass a security warning for the self-signed certificate."
