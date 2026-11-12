
----------------------
ssh 
-----------------------



#!/bin/bash
echo "=================================================="
echo "1. Đang cài đặt SSH Server..."
echo "=================================================="
apt-get update -qq && apt-get install -y -qq openssh-server > /dev/null 2>&1
echo "✅ Đã cài đặt SSH."

echo "=================================================="
echo "2. Đặt mật khẩu cho user root"
echo "=================================================="
echo "⚠️  Hãy nhập mật khẩu mới 2 lần (ví dụ: MySecurePass123)"
passwd root

echo "=================================================="
echo "3. Cấu hình SSH cho phép đăng nhập từ xa..."
echo "=================================================="
# Lệnh sed tối ưu: tự động bỏ dấu # (nếu có) và set thành yes
sed -i 's/#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Tạo host keys (bắt buộc trong môi trường container/Colab)
ssh-keygen -A > /dev/null 2>&1

echo " Kiểm tra lại cấu hình:"
grep -E "PermitRootLogin|PasswordAuthentication" /etc/ssh/sshd_config

echo "=================================================="
echo "4. Khởi động SSH Server..."
echo "=================================================="
# Dắt các tiến trình cũ
pkill sshd || true
sleep 1

# Khởi động trực tiếp daemon
/usr/sbin/sshd

echo "=================================================="
echo "5. Kiểm tra cổng SSH đang lắng nghe..."
echo "=================================================="
ss -tlnp | grep sshd

echo "=================================================="
echo "🎉 HOÀN TẤT!"
echo "💡 Lưu ý: Colab thường chạy SSH trên cổng 2222."
echo "👉 Bước tiếp theo, hãy chạy lệnh Bore:"
echo "   bore local 2222 --to bore.pub"
echo "=================================================="
