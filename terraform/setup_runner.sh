#!/bin/bash

# Update system and install basic tools
sudo apt-get update
sudo apt-get install -y git curl wget build-essential unzip tar openssl automake autotools-dev bsdmainutils clang cmake firefox gcc jq libssl-dev libtool libzmq3-dev openssh-client pkg-config python3 mysql-client postgresql-client

# Install and configure Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
echo '{ "registry-mirrors": ["http://docker-cache.dcg.internal:5000"] }' | sudo tee /etc/docker/daemon.json
sudo systemctl enable containerd.service
sudo systemctl start docker
sudo usermod -aG docker $USER

# Install Node.js
curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Python and pip
sudo apt-get install -y python3 python3-pip

# Install Java
sudo apt-get install -y openjdk-11-jdk

# Install Rust and wasm toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env
rustup toolchain install stable
rustup target add wasm32-unknown-unknown --toolchain stable
cargo install -f wasm-bindgen-cli@0.2.86

# Configure swap file for better performance
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Install sccache for ARM64
curl -L -o sccache-v0.7.1-aarch64-unknown-linux-musl.tar.gz https://github.com/mozilla/sccache/releases/download/v0.7.1/sccache-v0.7.1-aarch64-unknown-linux-musl.tar.gz
tar -xzvf sccache-v0.7.1-aarch64-unknown-linux-musl.tar.gz
sudo mv sccache-v0.7.1-aarch64-unknown-linux-musl/sccache /usr/local/bin/sccache
rm -rf sccache-v0.7.1-aarch64-unknown-linux-musl*
sccache --version
sccache --show-stats

# Configure sccache
mkdir -p ~/.config/sccache
cat <<EOF > ~/.config/sccache/config
[cache.s3]
bucket = "multi-runner-cache-x1xibo9c"
region = "eu-west-1"
no_credentials = false
key_prefix = "sccache"
EOF
pkill sccache || true
sccache --start-server

# Install Brave browser for ARM64
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=arm64] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
sudo apt-get update
sudo apt-get install -y brave-browser
echo 'export CHROME_BIN=/usr/bin/brave-browser' >> $HOME/.bashrc
source $HOME/.bashrc
brave-browser --version

# Install protoc 25.2 for ARM64
PROTOC_ZIP=protoc-25.2-linux-aarch_64.zip
curl -OL https://github.com/protocolbuffers/protobuf/releases/download/v25.2/$PROTOC_ZIP
sudo unzip -o $PROTOC_ZIP -d /usr/local bin/protoc
sudo unzip -o $PROTOC_ZIP -d /usr/local 'include/*'
rm -f $PROTOC_ZIP
echo 'export PATH=/usr/local/bin:$PATH' >> $HOME/.bashrc
source $HOME/.bashrc
protoc --version

# Set up GitHub Actions Runner for ARM64
sudo -u ubuntu -i <<'EOF'
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-arm64-2.317.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.317.0/actions-runner-linux-arm64-2.317.0.tar.gz
tar xzf ./actions-runner-linux-arm64-2.317.0.tar.gz
./config.sh --url https://github.com/dashpay/platform --token ACLWCZ53SLVH3SLYLJ3ZZI3HFNXUU --labels "self-hosted,newplatform" --unattended --replace
EOF

# Create a service for the runner
sudo bash -c 'cat <<EOF > /etc/systemd/system/actions-runner.service
[Unit]
Description=GitHub Actions Runner
After=network.target

[Service]
ExecStart=/home/ubuntu/actions-runner/run.sh
User=ubuntu
WorkingDirectory=/home/ubuntu/actions-runner
StandardOutput=inherit
StandardError=inherit
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF'

# Reload the systemd daemon and start the runner service
sudo systemctl daemon-reload
sudo systemctl enable actions-runner.service
sudo systemctl start actions-runner.service

# AWS CLI configuration - We use a role for AWS access
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws configure set region us-west-2
aws s3 ls s3://multi-runner-cache-x1xibo9c --region eu-west-1

# Final setup verification
brave-browser --version
protoc --version
aws --version

echo "Setup complete!"
