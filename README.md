# 🚀 VS Code Server Setup on Ubuntu EC2 🎉

Welcome to the **"VS Code in the Cloud"** repository! 🌩️ Tired of running out of resources on your local machine? Want to show off your cool coding skills by hosting your own web-based VS Code server? You've come to the right place! 🎯

This script automates the process of setting up **VS Code Server** on an **Ubuntu EC2 instance** and even includes self-signed SSL for that sweet, sweet "secure" green lock. 🛡️🔒

---

## 📜 What Does This Script Do?

This bash script will:
1. Update your system packages because nobody likes outdated software. 🚑
2. Install all the cool tools you need (like `curl`, `wget`, and `git`). 🛠️
3. Download and install the **latest** version of VS Code Server directly from the official GitHub repo. 🖥️
4. Generate **self-signed SSL certificates** because let's face it, we're secure like that. 🧙‍♂️✨
5. Configure your server with a password (`changeme!` – yes, you should change it). 🤫
6. Automatically start VS Code Server for you every time you log in. 🏁
7. Set up **private and public IPs** as environment variables because we're organized like that. 🗂️
8. Adjust system limits so you can watch all the files you want without breaking a sweat. 👀
9. Provide you with the access link to your web-based VS Code, complete with a ~totally~ professional warning about self-signed certificates. 🌐

---

## 🛠️ Setup Instructions

### 1. Clone This Repository, and run the setup file steps
```bash
git clone https://github.com/andrewbrimusu/ec2_scripts.git
cd ec2_scripts
chmod +x vs_code_setup.sh
./vs_code_setup.sh

