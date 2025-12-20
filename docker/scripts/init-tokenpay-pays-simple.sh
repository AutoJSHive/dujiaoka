#!/bin/bash
set -e

# TokenPay 支付方式初始化（简化版）

DB_NAME="${DB_DATABASE:-dujiaoka}"
DATA_DIR="${DATA_DIR:-/data}"
LOCK_FILE="${DATA_DIR}/tokenpay/.pays_initialized"

# 如果已经初始化过，跳过
if [ -f "$LOCK_FILE" ]; then
    echo ">>> TokenPay payment methods already initialized, skipping..."
    exit 0
fi

# 等待数据库就绪
echo ">>> Waiting for database..."
for i in {1..30}; do
    if mysqladmin ping &>/dev/null; then
        break
    fi
    sleep 1
done

# 检查 pays 表是否存在
TABLE_EXISTS=$(mysql -u root -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}' AND table_name='pays';" 2>/dev/null || echo "0")

if [ "$TABLE_EXISTS" = "0" ]; then
    echo ">>> Table 'pays' not found, dujiaoka not installed yet. Skipping TokenPay payment setup."
    exit 0
fi

# 读取 API Token
if [ -f "${DATA_DIR}/tokenpay/.api_token" ]; then
    API_TOKEN=$(cat "${DATA_DIR}/tokenpay/.api_token")
else
    API_TOKEN="${TOKENPAY_API_TOKEN:-666666}"
fi

# TokenPay 内部地址
TOKENPAY_URL="http://127.0.0.1:5000"

echo ">>> Adding TokenPay payment methods..."

# 检查是否已存在
EXISTING=$(mysql -u root -N -e "SELECT COUNT(*) FROM ${DB_NAME}.pays WHERE pay_handleroute LIKE 'pay/tokenpay%';" 2>/dev/null || echo "0")

if [ "$EXISTING" != "0" ]; then
    echo ">>> Updating existing TokenPay payment methods..."
    mysql -u root -e "UPDATE ${DB_NAME}.pays SET merchant_key='${API_TOKEN}', merchant_pem='${TOKENPAY_URL}' WHERE pay_handleroute LIKE 'pay/tokenpay%';"
else
    echo ">>> Inserting TokenPay payment methods..."
    mysql -u root "${DB_NAME}" << EOF
INSERT INTO pays (pay_name, pay_check, pay_method, pay_client, merchant_id, merchant_key, merchant_pem, pay_handleroute, is_open, created_at, updated_at, deleted_at) VALUES
('TRX', 'tokenpay-trx', 1, 3, 'TRX', '${API_TOKEN}', '${TOKENPAY_URL}', 'pay/tokenpay', 0, now(), now(), NULL),
('USDT-TRC20', 'tokenpay-usdt-trc', 1, 3, 'USDT_TRC20', '${API_TOKEN}', '${TOKENPAY_URL}', 'pay/tokenpay', 0, now(), now(), NULL),
('ETH', 'tokenpay-eth', 1, 3, 'EVM_ETH_ETH', '${API_TOKEN}', '${TOKENPAY_URL}', 'pay/tokenpay', 0, now(), now(), NULL),
('USDT-ERC20', 'tokenpay-usdt-erc', 1, 3, 'EVM_ETH_USDT_ERC20', '${API_TOKEN}', '${TOKENPAY_URL}', 'pay/tokenpay', 0, now(), now(), NULL),
('BNB', 'tokenpay-bsc-bnb', 1, 3, 'EVM_BSC_BNB', '${API_TOKEN}', '${TOKENPAY_URL}', 'pay/tokenpay', 0, now(), now(), NULL),
('USDT-BSC', 'tokenpay-usdt-bsc', 1, 3, 'EVM_BSC_USDT_BEP20', '${API_TOKEN}', '${TOKENPAY_URL}', 'pay/tokenpay', 0, now(), now(), NULL);
EOF
fi

# 标记已初始化
touch "$LOCK_FILE"

echo ">>> TokenPay payment methods initialized."
echo ">>> Note: Payment methods are disabled by default. Enable them in admin panel."