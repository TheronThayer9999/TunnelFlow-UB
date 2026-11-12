%%bash
# Stop on the first error (except commands suffixed with || true)
set -e

echo "=================================================="
echo "1. Installing Bore (TCP tunnel tool)..."
echo "=================================================="
if command -v bore > /dev/null 2>&1; then
    echo "Bore is already installed: $(bore --version)"
else
    wget -q https://github.com/ekzhang/bore/releases/download/v0.6.0/bore-v0.6.0-x86_64-unknown-linux-musl.tar.gz
    tar -xzf bore-v0.6.0-x86_64-unknown-linux-musl.tar.gz
    mv bore /usr/local/bin/
    rm -f bore-v0.6.0-x86_64-unknown-linux-musl.tar.gz
    echo "Installed: $(bore --version)"
fi

echo "=================================================="
echo "2. Updating the system and installing dependencies..."
echo "=================================================="
apt-get update -qq
apt-get install -y -qq zstd curl ca-certificates > /dev/null

echo "=================================================="
echo "3. Installing Ollama..."
echo "=================================================="
if command -v ollama > /dev/null 2>&1; then
    echo "Ollama is already installed: $(ollama --version)"
else
    # install.sh often fails at the systemctl step (Colab has no systemd) -> do not abort
    curl -fsSL https://ollama.com/install.sh | sh || echo "WARN: install.sh reported an error (usually missing systemd); checking the binary next."
fi
if ! command -v ollama > /dev/null 2>&1; then
    echo "ERROR: could not install Ollama."
    exit 1
fi

echo "=================================================="
echo "4. Cleaning up old processes (if any)..."
echo "=================================================="
pkill -f "ollama serve" || true
pkill -f "bore local 11434 --to" || true   # only this port's tunnel
sleep 2

echo "=================================================="
echo "5. Starting Ollama in the background on 0.0.0.0:11434..."
echo "=================================================="
nohup env OLLAMA_HOST=0.0.0.0:11434 OLLAMA_ORIGINS="*" ollama serve > ollama.log 2>&1 &

# Wait for the API instead of a blind sleep (up to 60s)
OLLAMA_OK=0
for _ in $(seq 1 60); do
    if curl -sf "http://127.0.0.1:11434/api/tags" > /dev/null 2>&1; then
        OLLAMA_OK=1
        break
    fi
    sleep 1
done
if [ "$OLLAMA_OK" != "1" ]; then
    echo "ERROR: Ollama is not responding. Last log lines:"
    tail -n 30 ollama.log
    exit 1
fi
echo "Ollama is up at http://127.0.0.1:11434"

echo "=================================================="
echo "6. Opening the Bore tunnel and reading the public port..."
echo "=================================================="
rm -f bore.log
nohup bore local 11434 --to bore.pub > bore.log 2>&1 &
BORE_PID=$!

# OLD BUG: grep -o '[0-9]\{4,5\}' on the line
#   "2026-11-12T09:41:07.123Z  INFO bore_cli::client: listening at bore.pub:41234"
#   matched the YEAR "2026" first => printed http://bore.pub:2026 (wrong port)
# FIX: only take the digits that come right after "bore.pub:"
PORT=""
for _ in $(seq 1 30); do
    PORT=$(sed 's/\x1b\[[0-9;]*m//g' bore.log 2>/dev/null \
           | tr -d '\r' \
           | grep -oE 'bore\.pub:[0-9]{1,5}' \
           | sed 's/.*://' \
           | tail -n 1) || true
    if [ -n "$PORT" ]; then
        break
    fi
    sleep 1
done

echo "BORE TUNNEL INFO:"
echo "--------------------------------------------------"
if [ -n "$PORT" ]; then
    echo "$PORT" > bore.port
    echo "PUBLIC PORT ASSIGNED: $PORT"
    echo "API URL: http://bore.pub:$PORT"
    echo "Test:    curl http://bore.pub:$PORT/api/tags"
else
    echo "WARN: could not read the port yet. Raw bore log:"
    sed 's/\x1b\[[0-9;]*m//g' bore.log | tail -n 20
    echo "Wait 10s and read it again with:"
    echo "   grep -oE 'bore\.pub:[0-9]+' bore.log | sed 's/.*://' | tail -n 1"
    kill -0 "$BORE_PID" 2>/dev/null || echo "ERROR: the bore process already exited."
    exit 1
fi
echo "--------------------------------------------------"

echo "=================================================="
echo "7. Pulling models (optional, may take a few minutes)..."
echo "=================================================="
# Uncomment the model you want:
# ollama pull tranhuythang9999/deepseek-v4-pro-9b-heretic:probe
# ollama pull bge-m3
echo "No model pulled automatically. Run 'ollama pull <model>' when you need one."

echo "=================================================="
echo "SETUP COMPLETE"
echo "Read the port again anytime: grep -oE 'bore\.pub:[0-9]+' bore.log | sed 's/.*://' | tail -n 1"
echo "Stop everything:             pkill ollama; pkill bore"
echo "=================================================="
# Print the last log lines without ANSI colour codes
sed 's/\x1b\[[0-9;]*m//g' bore.log | tail -n 20
