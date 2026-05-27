cat << 'EOF' > README.md
# VLESS REALITY 一键管理脚本 (终极全功能版)

这是一个基于官方 XTLS/REALITY 方案的极简一键部署与管理脚本。针对特定内核版本的文本标签输出进行了专项鲁棒性适配，移除了不兼容的流控字段，支持查看配置、动态密钥提取、升级内核及完全卸载。

## 🚀 一键安装与管理命令

在你的云服务器（VPS）上，以 `root` 用户执行以下命令即可一键运行面板：

```bash
bash <(curl -sL https://raw.githubusercontent.com/fang12100/xray_manger.sh/refs/heads/main/xray_manger.sh)
