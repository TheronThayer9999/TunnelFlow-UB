%%bash
# Set the root password here (change "MySecurePass123" to your own password)
ROOT_PASSWORD="MySecurePass123"

echo "=================================================="
echo "1. Installing the SSH server..."
echo "=================================================="
apt-get update -qq && apt-get install -y -qq openssh-server > /dev/null 2>&1
echo "openssh-server installed."

echo "=================================================="
echo "2. Setting the root password (non-interactive)..."
echo "=================================================="
echo "root:${ROOT_PASSWORD}" | chpasswd
echo "Root password set."

echo "=================================================="
echo "3. Configuring SSH to allow remote login..."
echo "=================================================="
# Required directories for sshd inside a container/Colab environment
mkdir -p /run/sshd

# Comment out the leading # (if any) and set the value to yes
sed -i 's/#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Host keys are mandatory in a container/Colab environment
ssh-keygen -A > /dev/null 2>&1

echo "Verify the settings:"
grep -E "PermitRootLogin|PasswordAuthentication" /etc/ssh/sshd_config

echo "=================================================="
echo "4. Starting the SSH server..."
echo "=================================================="
# Stop old processes
pkill sshd || true
sleep 1

# Start the daemon directly
/usr/sbin/sshd

echo "=================================================="
echo "5. Checking which port sshd listens on..."
echo "=================================================="
ss -tlnp | grep sshd || echo "WARN: sshd is not listening yet, check the log."

echo "=================================================="
echo "6. Opening a Bore tunnel for port 22..."
echo "=================================================="
pkill -f "bore local 22 --to" 2>/dev/null || true   # only the old SSH tunnel
rm -f bore_ssh.log
nohup bore local 22 --to bore.pub > bore_ssh.log 2>&1 &

SSH_PORT=""
for _ in $(seq 1 30); do
    SSH_PORT=$(sed 's/\x1b\[[0-9;]*m//g' bore_ssh.log 2>/dev/null \
               | tr -d '\r' \
               | grep -oE 'bore\.pub:[0-9]{1,5}' \
               | sed 's/.*://' \
               | tail -n 1) || true
    if [ -n "$SSH_PORT" ]; then
        break
    fi
    sleep 1
done

if [ -n "$SSH_PORT" ]; then
    echo "SSH PUBLIC PORT: $SSH_PORT"
    echo "Connect with: ssh -p ${SSH_PORT} root@bore.pub"
    echo "Password:     ${ROOT_PASSWORD}"
else
    echo "WARN: could not read the SSH port yet. Raw log (wait a few seconds):"
    sed 's/\x1b\[[0-9;]*m//g' bore_ssh.log | tail -n 20
fi
echo "=================================================="
