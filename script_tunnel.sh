#!/bin/bash
# Đảm bảo script dừng lại nếu có lệnh nào bị lỗi (trừ các lệnh có || true)
set -e

echo "=================================================="
echo "1. Đang cài đặt Bore (Công cụ tạo Tunnel)..."
echo "=================================================="
wget -q https://github.com/ekzhang/bore/releases/download/v0.6.0/bore-v0.6.0-x86_64-unknown-linux-musl.tar.gz
tar -xzf bore-v0.6.0-x86_64-unknown-linux-musl.tar.gz
mv bore /usr/local/bin/
echo "✅ Đã cài đặt Bore: $(bore --version)"

echo "=================================================="
echo "2. Đang cập nhật hệ thống và cài dependencies..."
echo "=================================================="


apt-get update -y
apt-get install -y zstd curl

echo "=================================================="																																																																																													


echo "3. Đang cài đặt Ollama..."
echo "=================================================="
curl -fsSL https://ollama.com/install.sh | sh

echo "=================================================="
echo "4. Đang dọn dẹp tiến trình cũ (nếu có)..."
echo "=================================================="
pkill ollama || true
pkill bore || true
sleep 1

echo "=================================================="
echo "5. Đang cấu hình và chạy Ollama ngầm..."
echo "=================================================="
nohup env OLLAMA_HOST=0.0.0.0:11434 OLLAMA_ORIGINS="*" ollama serve > ollama.log 2>&1 &
sleep 2

if pgrep -x "ollama" > /dev/null; then
    echo "Ollama đang chạy ngầm thành công!"
else
    echo "LỖI: Ollama không khởi động được. Kiểm tra: cat ollama.log"
    exit 1
fi

echo "=================================================="
echo "6. Đang tạo Bore Tunnel và lấy thông tin Port..."
echo "=================================================="
# Chạy bore ngầm và ghi log
nohup bore local 11434 --to bore.pub > bore.log 2>&1 &
sleep 3 # Đợi 3 giây để bore server phản hồi và cấp port

# Trích xuất dòng chứa thông tin port từ log
BORE_LINE=$(grep "bore.pub" bore.log | head -n 1)
# Lọc lấy chỉ số port (chuỗi số có 4-5 chữ số)
PORT=$(echo "$BORE_LINE" | grep -o '[0-9]\{4,5\}' | head -n 1)

echo "🔗 THÔNG TIN BORE TUNNEL:"
echo "--------------------------------------------------"
if [ -n "$PORT" ]; then
    echo "ĐÃ CẤP PORT CÔNG KHAI: $PORT"
    echo "URL kết nối API: http://bore.pub:$PORT"
    echo "Ví dụ test: curl http://bore.pub:$PORT/api/tags"
else
    echo "Chưa bắt được port ngay lập tức. Nội dung log gốc:"
    cat bore.log
    echo "Hãy đợi 10 giây rồi chạy lại lệnh: grep 'bore.pub' bore.log"
fi
echo "--------------------------------------------------"

echo "=================================================="
echo "7. Đang tải 2 model (có thể mất vài phút)..."
echo "=================================================="
ollama pull bge-m3:latest || echo "⚠️ Cảnh báo: Tải bge-m3:latest chưa hoàn tất, hãy chạy lại thủ công."
ollama pull qwen3.5:latest
echo "=================================================="
echo " HOÀN TẤT THIẾT LẬP!"
echo " Để xem lại port bất cứ lúc nào: grep 'bore.pub' bore.log"
echo " Để dừng toàn bộ: pkill ollama && pkill bore"
cat bore.log
echo "=================================================="

