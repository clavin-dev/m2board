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

# 从 .env 读取数据库配置 (兼容 Laravel .env 格式)
get_env_value() {
    local key="$1"
    grep -E "^${key}=" .env 2>/dev/null | head -1 | cut -d'=' -f2- | tr -d '\r' | tr -d '"' | tr -d "'"
}

echo -e "${YELLOW}[1/6] 备份当前配置...${NC}"
BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -f .env "$BACKUP_DIR/.env" 2>/dev/null
cp -f config/v2board.php "$BACKUP_DIR/v2board.php" 2>/dev/null
echo -e "${GREEN}  ✓ 配置已备份到 $BACKUP_DIR/${NC}"

echo ""
echo -e "${YELLOW}[2/6] 添加 M2Board 源...${NC}"
# 检查是否已有 m2board remote
if git remote | grep -q "m2board"; then
    git remote set-url m2board https://github.com/clavin-dev/m2board.git
    echo -e "${GREEN}  ✓ 已更新 m2board 远程源${NC}"
else
    git remote add m2board https://github.com/clavin-dev/m2board.git
    echo -e "${GREEN}  ✓ 已添加 m2board 远程源${NC}"
fi

echo ""
echo -e "${YELLOW}[3/6] 拉取 M2Board 代码...${NC}"
git config --global --add safe.directory $(pwd)
git fetch m2board
git reset --hard m2board/main
echo -e "${GREEN}  ✓ 代码已更新到 M2Board 最新版${NC}"

echo ""
echo -e "${YELLOW}[4/6] 更新 PHP 依赖...${NC}"
rm -rf composer.lock composer.phar
wget -q https://github.com/composer/composer/releases/latest/download/composer.phar -O composer.phar
php composer.phar update -vvv

echo ""
echo -e "${YELLOW}[5/6] 执行数据库迁移 (ShadowFlow 字段)...${NC}"

DB_HOST=$(get_env_value "DB_HOST")
DB_PORT=$(get_env_value "DB_PORT")
DB_DATABASE=$(get_env_value "DB_DATABASE")
DB_USERNAME=$(get_env_value "DB_USERNAME")
DB_PASSWORD=$(get_env_value "DB_PASSWORD")

# 设置默认值
DB_HOST=${DB_HOST:-127.0.0.1}
DB_PORT=${DB_PORT:-3306}
DB_DATABASE=${DB_DATABASE:-v2board}
DB_USERNAME=${DB_USERNAME:-root}
DB_PASSWORD=${DB_PASSWORD:-}

# 检查 mysql 命令是否可用
if command -v mysql &> /dev/null; then
    # 检查是否已存在 camouflage 列
    HAS_COLUMN=$(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USERNAME" -p"$DB_PASSWORD" "$DB_DATABASE" -N -e \
        "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$DB_DATABASE' AND TABLE_NAME='v2_server_v2node' AND COLUMN_NAME='camouflage'" 2>/dev/null)

    if [ "$HAS_COLUMN" = "0" ]; then
        echo -e "  正在添加 ShadowFlow 字段..."
        mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USERNAME" -p"$DB_PASSWORD" "$DB_DATABASE" -e \
            "ALTER TABLE v2_server_v2node ADD COLUMN camouflage varchar(32) DEFAULT NULL COMMENT 'ShadowFlow伪装模式' AFTER padding_scheme;" 2>/dev/null
        mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USERNAME" -p"$DB_PASSWORD" "$DB_DATABASE" -e \
            "ALTER TABLE v2_server_v2node ADD COLUMN shaping_settings text DEFAULT NULL COMMENT 'ShadowFlow流量整形JSON' AFTER camouflage;" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}  ✓ ShadowFlow 数据库字段已添加${NC}"
        else
            echo -e "${YELLOW}  ⚠ 字段添加可能失败，请手动执行:${NC}"
            echo -e "  mysql -h$DB_HOST -u$DB_USERNAME -p $DB_DATABASE < database/migrations/add_shadowflow_to_v2node.sql"
        fi
    elif [ "$HAS_COLUMN" = "1" ]; then
        echo -e "${GREEN}  ✓ ShadowFlow 字段已存在，跳过迁移${NC}"
    else
        echo -e "${YELLOW}  ⚠ 无法检测字段状态，尝试直接添加...${NC}"
        mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USERNAME" -p"$DB_PASSWORD" "$DB_DATABASE" < database/migrations/add_shadowflow_to_v2node.sql 2>/dev/null
        echo -e "${GREEN}  ✓ 迁移已执行 (如字段已存在会自动跳过)${NC}"
    fi
else
    echo -e "${YELLOW}  ⚠ mysql 命令不可用，请手动执行:${NC}"
    echo -e "  mysql -u$DB_USERNAME -p $DB_DATABASE < database/migrations/add_shadowflow_to_v2node.sql"
fi

# 执行 v2board 自带迁移
php artisan v2board:update 2>/dev/null

echo ""
echo -e "${YELLOW}[6/6] 设置权限与服务...${NC}"

# 获取 PHP 主版本号 (兼容各种输出格式)
php_main_version=$(php -r 'echo PHP_MAJOR_VERSION;' 2>/dev/null)

if [ -n "$php_main_version" ] && [ "$php_main_version" -ge 8 ] 2>/dev/null; then
    php composer.phar require joanhey/adapterman 2>/dev/null
    if ! php -m 2>/dev/null | grep -q "pcntl"; then
        if [ -f "cli-php.ini" ]; then
            sed -i '/extension=redis.so/a extension=pcntl.so' cli-php.ini 2>/dev/null
        fi
    fi
    if [ -f "cli-php.ini" ]; then
        php -c cli-php.ini webman.php stop 2>/dev/null
        echo -e "${YELLOW}  Webman 已停止，请手动重启${NC}"
    fi
fi

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
