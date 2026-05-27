#!/bin/bash

# 1. 权限检查
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[31m❌ 错误: 请以 root 用户运行此脚本！\033[0m"
  exit 1
fi

CONFIG_FILE="/usr/local/etc/xray/config.json"
KEY_FILE="/usr/local/etc/xray/public.key"
PORT=443 
SNI="images.apple.com"

# 动态获取服务器公网 IP
get_ip() {
    SERVER_IP=$(curl -s ifconfig.me)
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(curl -s api.ipify.org)
    fi
}

# 检查 Xray 执行文件路径
get_xray_bin() {
    XRAY_BIN=$(which xray)
    if [ -z "$XRAY_BIN" ]; then
        XRAY_BIN="/usr/local/bin/xray"
    fi
}

# ==================== 功能1：安装/一键部署 ====================
install_reality() {
    echo "=================================================="
    echo "        vless_REALITY 最终完美适配版一键部署        "
    echo "=================================================="
    
    get_ip
    
    echo "① 正在安装系统基础依赖..."
    apt-get update -y && apt-get install -y curl jq qrencode

    get_xray_bin
    if [ ! -f "$XRAY_BIN" ]; then
        echo "未检测到 Xray 内核，正在通过官方脚本安装..."
        bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
    fi

    echo "② 正在动态生成 REALITY 核心安全参数..."
    UUID=$($XRAY_BIN uuid)

    TMP_KEY_FILE="/tmp/xray_keys.tmp"
    $XRAY_BIN x25519 > $TMP_KEY_FILE

    PRIVATE_KEY=$(sed -n 's/.*PrivateKey://p' $TMP_KEY_FILE | tr -d '[:space:]')
    PUBLIC_KEY=$(sed -n 's/.*PublicKey)://p' $TMP_KEY_FILE | tr -d '[:space:]')
    rm -f $TMP_KEY_FILE

    SHORT_ID="0123456789abcdef"

    if [ -z "$PUBLIC_KEY" ] || [ -z "$PRIVATE_KEY" ]; then
        echo -e "\033[31m❌ 错误: 提取 Xray 密钥对失败，请检查 Xray 是否正常工作！\033[0m"
        exit 1
    fi

    echo "③ 正在生成完美版 config.json 配置文件..."
    mkdir -p /usr/local/etc/xray
    
    # 核心修复：安装时把动态生成的公钥死死写入本地文件
    echo "$PUBLIC_KEY" > $KEY_FILE

    cat <<EOF > $CONFIG_FILE
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": $PORT,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$UUID"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "dest": "$SNI:443",
                    "xver": 0,
                    "serverNames": [
                        "$SNI"
                    ],
                    "privateKey": "$PRIVATE_KEY",
                    "shortIds": [
                        "$SHORT_ID"
                    ]
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
EOF

    echo "④ 正在尝试放行系统本地防火墙端口..."
    if command -v ufw >/dev/null 2>&1; then
        ufw allow $PORT/tcp >/dev/null 2>&1
        ufw reload >/dev/null 2>&1
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --zone=public --add-port=$PORT/tcp --permanent >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
    fi

    echo "⑤ 正在重启并固化 Xray 系统服务..."
    systemctl daemon-reload
    systemctl restart xray
    systemctl enable xray

    echo -e "\033[32m✔ 部署成功！\033[0m"
    view_config
}

# ==================== 功能2：查看当前配置与链接 ====================
view_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "\033[31m❌ 错误: 未检测到配置文件，请先执行安装！\033[0m"
        return
    fi

    get_ip
    UUID=$(jq -r '.inbounds[0].settings.clients[0].id' $CONFIG_FILE)
    SHORT_ID=$(jq -r '.inbounds[0].streamSettings.realitySettings.shortIds[0]' $CONFIG_FILE)
    
    # 动态读取当初固化的真实公钥
    if [ -f "$KEY_FILE" ]; then
        REAL_PBK=$(cat $KEY_FILE | tr -d '[:space:]')
    else
        REAL_PBK="未在本地找到保存的公钥，请重新执行一键部署生成"
    fi

    # 彻底修复点：这里全部对齐使用真实动态提取的 REAL_PBK 变量！
    SHARE_LINK="vless://$UUID@$SERVER_IP:$PORT?encryption=none&security=reality&sni=$SNI&fp=chrome&pbk=$REAL_PBK&sid=$SHORT_ID#REALITY_vless"

    echo "=================================================="
    echo -e "\033[35m               当前 vless_REALITY 配置信息          \033[0m"
    echo "=================================================="
    echo -e "用户 UUID:   \033[36m$UUID\033[0m"
    echo -e "目标 SNI:    \033[36m$SNI\033[0m"
    echo -e "端口 (Port): \033[36m$PORT\033[0m"
    echo -e "公钥 (pbk):  \033[32m$REAL_PBK\033[0m"
    echo -e "Short ID:    \033[36m$SHORT_ID\033[0m"
    echo "=================================================="
    echo -e "\033[33m您的专属通用分享链接:\033[0m"
    echo -e "\033[32m$SHARE_LINK\033[0m"
    echo "=================================================="
    echo "二维码："
    qrencode -t ansiutf8 "$SHARE_LINK"
}

# ==================== 功能3：更新 Xray 内核 ====================
update_xray() {
    echo "正在检查并更新 Xray 内核..."
    bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
    systemctl restart xray
    echo -e "\033[32m✔ Xray 内核更新/重启完成！\033[0m"
    systemctl status xray --no-pager
}

# ==================== 功能4：完全卸载 ====================
uninstall_reality() {
    read -p "⚠️ 确定要完全卸载 Xray 及其所有配置文件吗？(y/n): " choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        echo "正在停止 Xray 服务..."
        systemctl stop xray >/dev/null 2>&1
        systemctl disable xray >/dev/null 2>&1
        
        echo "正在清理服务脚本与二进制文件..."
        bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh) --remove
        
        echo "正在删除配置文件目录..."
        rm -rf /usr/local/etc/xray
        rm -f /etc/systemd/system/xray.service
        systemctl daemon-reload
        
        echo -e "\033[32m✔ vless_REALITY 已成功从本服务器完全卸载！\033[0m"
    else
        echo "已取消卸载。"
    fi
}

# ==================== 菜单主循环 ====================
clear
echo "=================================================="
echo -e "\033[36m       欢迎使用 VLESS_REALITY 专业管理面板        \033[0m"
echo "=================================================="
echo " 1. 一键安装 / 重新部署"
echo " 2. 查看当前配置 (含分享链接与二维码)"
echo " 3. 更新 Xray 内核"
echo " 4. 完全卸载 Xray"
echo " 0. 退出脚本"
echo "=================================================="
read -p "请输入数字选择功能: " num

case "$num" in
    1)
        install_reality
        ;;
    2)
        view_config
        ;;
    3)
        update_xray
        ;;
    4)
        uninstall_reality
        ;;
    0)
        exit 0
        ;;
    *)
        echo -e "\033[31m输入错误，请输入正确数字！\033[0m"
        ;;
esac
