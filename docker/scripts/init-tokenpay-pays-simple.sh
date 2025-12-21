#!/bin/bash
set -e

# TokenPay 支付方式初始化（简化版）
# 注意：此脚本在 entrypoint.d 中运行，supervisor 尚未启动
# 因此需要自己管理 MariaDB 生命周期

echo ">>> [TokenPay] Starting initialization check..."

DB_NAME="${DB_DATABASE:-dujiaoka}"
DATA_DIR="${DATA_DIR:-/data}"
LOCK_FILE="${DATA_DIR}/tokenpay/.pays_initialized"

# 清理函数：确保退出前关闭 MariaDB
cleanup_mariadb() {
    if [ "$MARIADB_STARTED_BY_US" = "true" ] && [ -n "$MARIADB_PID" ]; then
        echo ">>> [TokenPay] Stopping temporary MariaDB..."
        mysqladmin shutdown 2>/dev/null || true
        wait "$MARIADB_PID" 2>/dev/null || true
    fi
}
trap cleanup_mariadb EXIT

MARIADB_STARTED_BY_US=false
MARIADB_PID=""

# 如果已经初始化过，跳过
if [ -f "$LOCK_FILE" ]; then
    echo ">>> [TokenPay] Already initialized, skipping..."
    exit 0
fi

# 检查 MariaDB 是否已在运行（使用超时避免挂起）
echo ">>> [TokenPay] Checking MariaDB status..."
if ! timeout 3 mysqladmin ping &>/dev/null; then
    echo ">>> [TokenPay] Starting MariaDB temporarily..."
    /usr/sbin/mysqld --user=mysql &
    MARIADB_PID=$!
    MARIADB_STARTED_BY_US=true
fi

# 等待数据库就绪
echo ">>> [TokenPay] Waiting for database..."
for i in {1..30}; do
    if timeout 3 mysqladmin ping &>/dev/null; then
        echo ">>> [TokenPay] Database ready."
        break
    fi
    sleep 1
done

# 检查 pays 表是否存在
TABLE_EXISTS=$(mysql -u root -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}' AND table_name='pays';" 2>/dev/null || echo "0")

if [ "$TABLE_EXISTS" = "0" ]; then
    echo ">>> [TokenPay] Table 'pays' not found, dujiaoka not installed yet. Skipping."
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

echo ">>> [TokenPay] Adding payment methods..."

# 检查是否已存在
EXISTING=$(mysql -u root -N -e "SELECT COUNT(*) FROM ${DB_NAME}.pays WHERE pay_handleroute LIKE 'pay/tokenpay%';" 2>/dev/null || echo "0")

if [ "$EXISTING" != "0" ]; then
    echo ">>> [TokenPay] Updating existing payment methods..."
    mysql -u root -e "UPDATE ${DB_NAME}.pays SET merchant_key='${API_TOKEN}', merchant_pem='${TOKENPAY_URL}' WHERE pay_handleroute LIKE 'pay/tokenpay%';"
else
    echo ">>> [TokenPay] Inserting payment methods..."
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

echo ">>> [TokenPay] Payment methods initialized."
echo ">>> [TokenPay] Note: Payment methods are disabled by default. Enable them in admin panel."
