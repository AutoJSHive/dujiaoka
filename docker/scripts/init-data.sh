#!/bin/bash
set -e

# 主入口脚本 - 初始化所有服务配置
# ClawCloud 只需挂载 /data 目录 + 设置环境变量

DATA_DIR="${DATA_DIR:-/data}"

echo ">>> Initializing data directories..."

# 创建数据目录结构
mkdir -p "${DATA_DIR}/dujiaoka/uploads"
mkdir -p "${DATA_DIR}/mysql"
mkdir -p "${DATA_DIR}/tokenpay"

# 设置权限
chown -R mysql:mysql "${DATA_DIR}/mysql"
chmod -R 777 "${DATA_DIR}/dujiaoka"
chmod -R 755 "${DATA_DIR}/tokenpay"

# ============================================
# 独角数卡 .env 配置
# ============================================
DUJIAOKA_ENV="${DATA_DIR}/dujiaoka/.env"

_generate_app_key() {
    head -c 32 /dev/urandom | base64
}

_is_valid_app_key() {
    local key="$1"
    local b64
    local bytes

    if [[ ! "$key" =~ ^base64:[A-Za-z0-9+/=]+$ ]]; then
        return 1
    fi

    b64="${key#base64:}"
    bytes=$(printf '%s' "$b64" | base64 -d 2>/dev/null | wc -c || true)
    [ "$bytes" -eq 32 ]
}

_ensure_app_key() {
    local key_line
    local key_value
    local new_key

    if [ ! -f "$DUJIAOKA_ENV" ]; then
        return 0
    fi

    key_line=$(grep -E '^APP_KEY=' "$DUJIAOKA_ENV" || true)
    key_value="${key_line#APP_KEY=}"

    if _is_valid_app_key "$key_value"; then
        return 0
    fi

    new_key="base64:$(_generate_app_key)"
    if [ -n "$key_line" ]; then
        sed -i "s/^APP_KEY=.*/APP_KEY=${new_key}/" "$DUJIAOKA_ENV"
    else
        echo "APP_KEY=${new_key}" >> "$DUJIAOKA_ENV"
    fi

    echo ">>> [Dujiaoka] APP_KEY missing or invalid, regenerated."
}

if [ ! -f "$DUJIAOKA_ENV" ]; then
    echo ">>> Generating dujiaoka .env..."

    # 生成 APP_KEY (32 字节 base64 编码 = 44 字符)
    APP_KEY=$(head -c 32 /dev/urandom | base64)

    cat > "$DUJIAOKA_ENV" << EOF
APP_NAME=${APP_NAME:-独角数卡}
APP_ENV=production
APP_KEY=base64:${APP_KEY}
APP_DEBUG=${APP_DEBUG:-false}
APP_URL=${APP_URL:-http://localhost}

LOG_CHANNEL=stack

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=${DB_DATABASE:-dujiaoka}
DB_USERNAME=${DB_USERNAME:-dujiaoka}
DB_PASSWORD=${DB_PASSWORD:-dujiaoka}

BROADCAST_DRIVER=log
SESSION_DRIVER=file
SESSION_LIFETIME=120

CACHE_DRIVER=file
QUEUE_CONNECTION=sync

DUJIAO_ADMIN_LANGUAGE=${ADMIN_LANGUAGE:-zh_CN}
ADMIN_ROUTE_PREFIX=${ADMIN_PATH:-admin}
ADMIN_HTTPS=${ADMIN_HTTPS:-false}
EOF
    echo ">>> dujiaoka .env generated."
fi

_ensure_app_key

# 创建符号链接
ln -sf "${DATA_DIR}/dujiaoka/.env" /app/.env
ln -sf "${DATA_DIR}/dujiaoka/uploads" /app/public/uploads

# 确保 .env 文件可被 application 用户写入
if [ -f "/app/.env" ]; then
    chown application:application /app/.env
    chmod 666 /app/.env
fi

# 强制确保缓存和队列驱动使用文件系统（容器内无 Redis）
if [ -f "/app/.env" ]; then
    sed -i 's/^CACHE_DRIVER=.*/CACHE_DRIVER=file/' /app/.env
    sed -i 's/^QUEUE_CONNECTION=.*/QUEUE_CONNECTION=database/' /app/.env
    sed -i 's/^SESSION_DRIVER=.*/SESSION_DRIVER=file/' /app/.env
fi

# 确保 .env.example 存在且可读
if [ -f "/app/.env.example" ]; then
    chown root:root /app/.env.example
    chmod 644 /app/.env.example
fi

# install.lock 处理
if [ -f "${DATA_DIR}/dujiaoka/install.lock" ]; then
    ln -sf "${DATA_DIR}/dujiaoka/install.lock" /app/install.lock
else
    # 自动创建 install.lock，跳过安装向导
    echo "install ok" > "${DATA_DIR}/dujiaoka/install.lock"
    ln -sf "${DATA_DIR}/dujiaoka/install.lock" /app/install.lock
    echo ">>> [Dujiaoka] Created install.lock to skip installation wizard."
fi

# ============================================
# TokenPay 配置
# ============================================
TOKENPAY_CONFIG="${DATA_DIR}/tokenpay/appsettings.json"
TOKENPAY_DIR="/opt/tokenpay"
TOKENPAY_BIN="/opt/tokenpay-bin"

# 复制 TokenPay 可执行文件到挂载目录（首次启动时）
if [ ! -f "${TOKENPAY_DIR}/TokenPay" ] && [ -f "${TOKENPAY_BIN}/TokenPay" ]; then
    echo ">>> Copying TokenPay binary to data directory..."
    cp "${TOKENPAY_BIN}/TokenPay" "${TOKENPAY_DIR}/TokenPay"
    chmod +x "${TOKENPAY_DIR}/TokenPay"
fi

# API Token（两边共享）
API_TOKEN="${TOKENPAY_API_TOKEN:-$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 32)}"

if [ ! -f "$TOKENPAY_CONFIG" ]; then
    echo ">>> Generating TokenPay configuration..."

    cat > "$TOKENPAY_CONFIG" << EOF
{
  "Serilog": {
    "MinimumLevel": {
      "Default": "Information",
      "Override": {
        "Microsoft": "Warning",
        "Microsoft.Hosting.Lifetime": "Information"
      }
    }
  },
  "AllowedHosts": "*",
  "ConnectionStrings": {
    "DB": "Data Source=/data/tokenpay/TokenPay.db;"
  },
  "TRON-PRO-API-KEY": "${TOKENPAY_TRONGRID_KEY:-}",
  "BaseCurrency": "${TOKENPAY_BASE_CURRENCY:-CNY}",
  "Rate": {"USDT": 0, "TRX": 0, "ETH": 0, "USDC": 0},
  "ExpireTime": 1800,
  "UseDynamicAddress": false,
  "Address": {
    "TRON": ["${TOKENPAY_TRON_ADDRESS:-}"],
    "EVM": ["${TOKENPAY_EVM_ADDRESS:-}"]
  },
  "OnlyConfirmed": false,
  "NotifyTimeOut": 3,
  "ApiToken": "${API_TOKEN}",
  "WebSiteUrl": "${TOKENPAY_WEBSITE_URL:-http://localhost:5000}",
  "Collection": {
    "Enable": false,
    "UseEnergy": true,
    "ForceCheckAllAddress": false,
    "RetainUSDT": true,
    "CheckTime": 1,
    "MinUSDT": 0.1,
    "NeedEnergy": 65000,
    "EnergyPrice": 210,
    "Address": "${TOKENPAY_TRON_ADDRESS:-}"
  },
  "Telegram": {
    "AdminUserId": ${TOKENPAY_TG_ADMIN_ID:-0},
    "BotToken": "${TOKENPAY_TG_BOT_TOKEN:-}"
  },
  "RateMove": {"TRX_CNY": 0, "USDT_CNY": 0},
  "DynamicAddressConfig": {
    "AmountMove": false,
    "TRX": [0, 2],
    "USDT": [1, 2],
    "ETH": [0.1, 0.15]
  }
}
EOF
    echo ">>> TokenPay configuration generated."
fi

# 创建 TokenPay 数据目录符号链接
ln -sf "${DATA_DIR}/tokenpay/appsettings.json" "${TOKENPAY_DIR}/appsettings.json"
ln -sf "${DATA_DIR}/tokenpay/TokenPay.db" "${TOKENPAY_DIR}/TokenPay.db" 2>/dev/null || true

# 保存 API Token 供数据库初始化使用
echo "$API_TOKEN" > "${DATA_DIR}/tokenpay/.api_token"
chmod 600 "${DATA_DIR}/tokenpay/.api_token"

echo ">>> Data initialization completed."
