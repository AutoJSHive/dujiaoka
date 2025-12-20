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

if [ ! -f "$DUJIAOKA_ENV" ]; then
    echo ">>> Generating dujiaoka .env..."

    # 生成 APP_KEY
    APP_KEY=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 32)

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

# 创建符号链接
ln -sf "${DATA_DIR}/dujiaoka/.env" /app/.env
ln -sf "${DATA_DIR}/dujiaoka/uploads" /app/public/uploads

# install.lock 处理
if [ -f "${DATA_DIR}/dujiaoka/install.lock" ]; then
    ln -sf "${DATA_DIR}/dujiaoka/install.lock" /app/install.lock
fi

# ============================================
# TokenPay 配置
# ============================================
TOKENPAY_CONFIG="${DATA_DIR}/tokenpay/appsettings.json"
TOKENPAY_DIR="/opt/tokenpay"

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
