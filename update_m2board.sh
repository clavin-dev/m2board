#!/bin/bash

# M2Board 升级脚本
# 用法: 在 v2board 安装目录下执行 bash update_m2board.sh
# 功能: 从原版 v2board 升级到 m2board (包含 ShadowFlow 协议支持)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  M2Board 升级工具 - ShadowFlow Protocol   ${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# 检查是否在 v2board 目录
if [ ! -f "artisan" ] || [ ! -d "app" ]; then
    echo -e "${RED}错误: 请在 v2board 安装目录下运行此脚本${NC}"
    echo -e "${YELLOW}用法: cd /www/wwwroot/你的v2board目录 && bash update_m2board.sh${NC}"
    exit 1
fi

# 检查 git
if ! command -v git &> /dev/null; then
    echo -e "${RED}错误: Git 未安装，请先安装 git${NC}"
    exit 1
fi

echo -e "${YELLOW}[1/5] 备份当前配置...${NC}"
BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -f .env "$BACKUP_DIR/.env" 2>/dev/null
cp -f config/v2board.php "$BACKUP_DIR/v2board.php" 2>/dev/null
echo -e "${GREEN}  ✓ 配置已备份到 $BACKUP_DIR/${NC}"

echo ""
echo -e "${YELLOW}[2/5] 添加 M2Board 源...${NC}"
if git remote | grep -q "m2board"; then
    git remote set-url m2board https://github.com/clavin-dev/m2board.git
    echo -e "${GREEN}  ✓ 已更新 m2board 远程源${NC}"
else
    git remote add m2board https://github.com/clavin-dev/m2board.git
    echo -e "${GREEN}  ✓ 已添加 m2board 远程源${NC}"
fi

echo ""
echo -e "${YELLOW}[3/5] 拉取 M2Board 代码...${NC}"
git config --global --add safe.directory $(pwd)
git fetch m2board
git reset --hard m2board/main
echo -e "${GREEN}  ✓ 代码已更新到 M2Board 最新版${NC}"

echo ""
echo -e "${YELLOW}[4/5] 更新 PHP 依赖...${NC}"
rm -rf composer.lock composer.phar
wget -q https://github.com/composer/composer/releases/latest/download/composer.phar -O composer.phar
php composer.phar update -vvv

echo ""
echo -e "${YELLOW}[5/5] 执行数据库迁移 + 重启服务...${NC}"
# php artisan v2board:update 会自动:
# 1. 读取 database/update.sql 里所有 SQL (包括 ShadowFlow 的 ALTER TABLE)
# 2. 逐条执行，字段已存在会自动跳过
# 3. 重启 horizon 队列
php artisan v2board:update

# PHP 8+ Webman 处理
php_main_version=$(php -r 'echo PHP_MAJOR_VERSION;' 2>/dev/null)
if [ -n "$php_main_version" ] && [ "$php_main_version" -ge 8 ] 2>/dev/null; then
    php composer.phar require joanhey/adapterman 2>/dev/null
    if [ -f "cli-php.ini" ]; then
        if ! php -m 2>/dev/null | grep -q "pcntl"; then
            sed -i '/extension=redis.so/a extension=pcntl.so' cli-php.ini 2>/dev/null
        fi
        php -c cli-php.ini webman.php stop 2>/dev/null
        echo -e "${YELLOW}  Webman 已停止${NC}"
    fi
fi

# 宝塔权限
if [ -f "/etc/init.d/bt" ]; then
    chown -R www $(pwd)
    echo -e "${GREEN}  ✓ 宝塔权限已设置${NC}"
fi

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${GREEN}  ✓ M2Board 升级完成!${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "  新增协议: ${GREEN}ShadowFlow${NC}"
echo -e "  管理面板: 节点管理 → V2node → 新建节点 → 节点协议 → ShadowFlow"
echo ""
echo -e "  ${YELLOW}如果使用 Webman，请手动重启:${NC}"
echo -e "  php -c cli-php.ini webman.php start -d"
echo ""
