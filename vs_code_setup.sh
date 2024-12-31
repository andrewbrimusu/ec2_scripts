#!/bin/bash

# Step 1: Update system packages
echo ""
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install necessary dependencies
echo ""
echo "Installing necessary dependencies..."
sudo apt install -y unzip curl wget git openssl

# Step 2: Create the /var/app directory
echo ""
echo "Creating /var/app directory for storing VS Code Server files..."
sudo mkdir -p /var/app

# Step 3: Download the latest code-server release
echo ""
echo "Downloading the latest version of VS Code Server..."
latest_version=$(curl -s https://api.github.com/repos/coder/code-server/releases/latest | grep "browser_download_url.*linux-amd64.tar.gz" | cut -d '"' -f 4)
wget -O code-server-latest-linux-amd64.tar.gz $latest_version

# Extract the downloaded tar.gz file and move it to /var/app
echo ""
echo "Extracting and installing VS Code Server into /var/app..."
tar -xvzf code-server-latest-linux-amd64.tar.gz
sudo mv code-server-*-linux-amd64 /var/app/code-server
sudo ln -s /var/app/code-server/bin/code-server /usr/local/bin/code-server

# Clean up the downloaded tar.gz file to save space
echo ""
echo "Cleaning up temporary installation files..."
rm -rf code-server-latest-linux-amd64.tar.gz

# Verify the installation of code-server
echo ""
echo "Verifying the VS Code Server installation..."
code-server --version

# Step 4: Generate SSL certificates using DNS provider (e.g., Cloudflare)
echo ""
echo "Setting up SSL certificates for secure access..."
sudo apt install -y certbot python3-certbot-dns-cloudflare

# Cloudflare credentials file setup
echo ""
echo "Configuring Cloudflare credentials..."
CF_CREDENTIALS_PATH="/etc/cloudflare/cloudflare.ini"
sudo mkdir -p /etc/cloudflare
sudo bash -c "cat > $CF_CREDENTIALS_PATH" << EOF
dns_cloudflare_email = your-email@example.com
dns_cloudflare_api_key = your-cloudflare-api-key
EOF
sudo chmod 600 $CF_CREDENTIALS_PATH

# Request SSL certificate
echo ""
echo "Requesting SSL certificate using Cloudflare DNS..."
DOMAIN="your-domain.com"  # Replace with your actual domain
sudo certbot certonly --dns-cloudflare --dns-cloudflare-credentials $CF_CREDENTIALS_PATH -d $DOMAIN

# Step 5: Create a configuration file for VS Code Server
echo ""
echo "Creating a configuration file for VS Code Server..."
cat > ~/.config/code-server/config.yaml << EOF
bind-addr: 0.0.0.0:443
auth: password
password: changeme!
cert: /etc/letsencrypt/live/$DOMAIN/fullchain.pem
cert-key: /etc/letsencrypt/live/$DOMAIN/privkey.pem
EOF

# Step 6: Create a script to start VS Code Server automatically
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
    sudo code-server --bind-addr 0.0.0.0:443 --cert /etc/letsencrypt/live/$DOMAIN/fullchain.pem --cert-key /etc/letsencrypt/live/$DOMAIN/privkey.pem /home/ubuntu > ~/code-server.log 2>&1 &
    echo "VS Code Server started on port 443."
fi
EOF

# Make the startup.sh script executable
echo ""
echo "Making the startup script executable..."
chmod +x ~/startup.sh

# Step 7: Automatically run the startup script when the user logs in
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
echo ""
echo "Retrieving the private and public IP addresses of the system..."
PRIVATE_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com/)

# Export the IP addresses as environment variables
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
echo ""
echo "Setup completed successfully."
echo "You can manually start the server using: ~/startup.sh"
if [ -z "$HOST_PUBLIC_IP" ]; then
    echo "Public IP not found. Ensure the instance has a public IP assigned."
else
    echo "Access your VS Code Server at: https://$DOMAIN"
fi
echo "Note: The default password is 'changeme!' and should be changed for better security."
