#!/bin/bash
set -e

# TokenPay 配置初始化脚本
# 在容器启动时根据环境变量生成 appsettings.json

TOKENPAY_DIR="/opt/tokenpay"
CONFIG_FILE="${TOKENPAY_DIR}/appsettings.json"

# 默认值
API_TOKEN="${TOKENPAY_API_TOKEN:-$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 32)}"
TRON_ADDRESS="${TOKENPAY_TRON_ADDRESS:-}"
EVM_ADDRESS="${TOKENPAY_EVM_ADDRESS:-}"
TRONGRID_KEY="${TOKENPAY_TRONGRID_KEY:-}"
WEBSITE_URL="${TOKENPAY_WEBSITE_URL:-http://localhost:5000}"
TG_ADMIN_ID="${TOKENPAY_TG_ADMIN_ID:-0}"
TG_BOT_TOKEN="${TOKENPAY_TG_BOT_TOKEN:-}"
BASE_CURRENCY="${TOKENPAY_BASE_CURRENCY:-CNY}"

# 如果没有配置文件或强制重新生成
if [ ! -f "$CONFIG_FILE" ] || [ "${TOKENPAY_FORCE_CONFIG:-false}" = "true" ]; then
    echo ">>> Generating TokenPay configuration..."

    cat > "$CONFIG_FILE" << EOF
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
    "DB": "Data Source=TokenPay.db;"
  },
  "TRON-PRO-API-KEY": "${TRONGRID_KEY}",
  "BaseCurrency": "${BASE_CURRENCY}",
  "Rate": {
    "USDT": 0,
    "TRX": 0,
    "ETH": 0,
    "USDC": 0
  },
  "ExpireTime": 1800,
  "UseDynamicAddress": false,
  "Address": {
    "TRON": ["${TRON_ADDRESS}"],
    "EVM": ["${EVM_ADDRESS}"]
  },
  "OnlyConfirmed": false,
  "NotifyTimeOut": 3,
  "ApiToken": "${API_TOKEN}",
  "WebSiteUrl": "${WEBSITE_URL}",
  "Collection": {
    "Enable": false,
    "UseEnergy": true,
    "ForceCheckAllAddress": false,
    "RetainUSDT": true,
    "CheckTime": 1,
    "MinUSDT": 0.1,
    "NeedEnergy": 65000,
    "EnergyPrice": 210,
    "Address": "${TRON_ADDRESS}"
  },
  "Telegram": {
    "AdminUserId": ${TG_ADMIN_ID},
    "BotToken": "${TG_BOT_TOKEN}"
  },
  "RateMove": {
    "TRX_CNY": 0,
    "USDT_CNY": 0
  },
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

# 导出 API_TOKEN 供其他脚本使用
echo "$API_TOKEN" > "${TOKENPAY_DIR}/.api_token"
chmod 600 "${TOKENPAY_DIR}/.api_token"

echo ">>> TokenPay init completed."
