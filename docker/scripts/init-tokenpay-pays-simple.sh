#!/bin/bash
# 注意：此脚本被 source 执行，不能用 exit，必须用 return
# 也不能用 trap EXIT，会影响父 shell

# TokenPay 支付方式初始化（简化版）
# 注意：此脚本在 entrypoint.d 中运行，supervisor 尚未启动
# 因此需要自己管理 MariaDB 生命周期

echo ">>> [TokenPay] Starting initialization check..."

_TOKENPAY_DB_NAME="${DB_DATABASE:-dujiaoka}"
_TOKENPAY_DATA_DIR="${DATA_DIR:-/data}"
_TOKENPAY_LOCK_FILE="${_TOKENPAY_DATA_DIR}/tokenpay/.pays_initialized"
_TOKENPAY_MARIADB_STARTED_BY_US=false
_TOKENPAY_MARIADB_PID=""

# 清理函数：确保关闭 MariaDB（手动调用）
_tokenpay_cleanup_mariadb() {
    if [ "$_TOKENPAY_MARIADB_STARTED_BY_US" = "true" ] && [ -n "$_TOKENPAY_MARIADB_PID" ]; then
        echo ">>> [TokenPay] Stopping temporary MariaDB..."
        mysqladmin shutdown 2>/dev/null || true
        wait "$_TOKENPAY_MARIADB_PID" 2>/dev/null || true
    fi
}

# 如果已经初始化过，跳过
if [ -f "$_TOKENPAY_LOCK_FILE" ]; then
    echo ">>> [TokenPay] Already initialized, skipping..."
    return 0 2>/dev/null || true
fi

# 检查 MariaDB 是否已在运行（使用超时避免挂起）
echo ">>> [TokenPay] Checking MariaDB status..."
if ! timeout 3 mysqladmin ping &>/dev/null; then
    echo ">>> [TokenPay] Starting MariaDB temporarily..."
    /usr/sbin/mysqld --user=mysql &
    _TOKENPAY_MARIADB_PID=$!
    _TOKENPAY_MARIADB_STARTED_BY_US=true
fi

# 等待数据库就绪
echo ">>> [TokenPay] Waiting for database..."
for _i in {1..30}; do
    if timeout 3 mysqladmin ping &>/dev/null; then
        echo ">>> [TokenPay] Database ready."
        break
    fi
    sleep 1
done

# 检查 pays 表是否存在
_TOKENPAY_TABLE_EXISTS=$(mysql -u root -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${_TOKENPAY_DB_NAME}' AND table_name='pays';" 2>/dev/null || echo "0")

if [ "$_TOKENPAY_TABLE_EXISTS" = "0" ]; then
    echo ">>> [TokenPay] Table 'pays' not found, dujiaoka not installed yet. Skipping."
    _tokenpay_cleanup_mariadb
    return 0 2>/dev/null || true
fi

# 读取 API Token
if [ -f "${_TOKENPAY_DATA_DIR}/tokenpay/.api_token" ]; then
    _TOKENPAY_API_TOKEN=$(cat "${_TOKENPAY_DATA_DIR}/tokenpay/.api_token")
else
    _TOKENPAY_API_TOKEN="${TOKENPAY_API_TOKEN:-666666}"
fi

# TokenPay 内部地址
_TOKENPAY_URL="http://127.0.0.1:5000"

echo ">>> [TokenPay] Adding payment methods..."

# 检查是否已存在
_TOKENPAY_EXISTING=$(mysql -u root -N -e "SELECT COUNT(*) FROM ${_TOKENPAY_DB_NAME}.pays WHERE pay_handleroute LIKE 'pay/tokenpay%';" 2>/dev/null || echo "0")

if [ "$_TOKENPAY_EXISTING" != "0" ]; then
    echo ">>> [TokenPay] Updating existing payment methods..."
    mysql -u root -e "UPDATE ${_TOKENPAY_DB_NAME}.pays SET merchant_key='${_TOKENPAY_API_TOKEN}', merchant_pem='${_TOKENPAY_URL}' WHERE pay_handleroute LIKE 'pay/tokenpay%';"
else
    echo ">>> [TokenPay] Inserting payment methods..."
    mysql -u root "${_TOKENPAY_DB_NAME}" << EOF
INSERT INTO pays (pay_name, pay_check, pay_method, pay_client, merchant_id, merchant_key, merchant_pem, pay_handleroute, is_open, created_at, updated_at, deleted_at) VALUES
('TRX', 'tokenpay-trx', 1, 3, 'TRX', '${_TOKENPAY_API_TOKEN}', '${_TOKENPAY_URL}', 'pay/tokenpay', 0, now(), now(), NULL),
('USDT-TRC20', 'tokenpay-usdt-trc', 1, 3, 'USDT_TRC20', '${_TOKENPAY_API_TOKEN}', '${_TOKENPAY_URL}', 'pay/tokenpay', 0, now(), now(), NULL),
('ETH', 'tokenpay-eth', 1, 3, 'EVM_ETH_ETH', '${_TOKENPAY_API_TOKEN}', '${_TOKENPAY_URL}', 'pay/tokenpay', 0, now(), now(), NULL),
('USDT-ERC20', 'tokenpay-usdt-erc', 1, 3, 'EVM_ETH_USDT_ERC20', '${_TOKENPAY_API_TOKEN}', '${_TOKENPAY_URL}', 'pay/tokenpay', 0, now(), now(), NULL),
('BNB', 'tokenpay-bsc-bnb', 1, 3, 'EVM_BSC_BNB', '${_TOKENPAY_API_TOKEN}', '${_TOKENPAY_URL}', 'pay/tokenpay', 0, now(), now(), NULL),
('USDT-BSC', 'tokenpay-usdt-bsc', 1, 3, 'EVM_BSC_USDT_BEP20', '${_TOKENPAY_API_TOKEN}', '${_TOKENPAY_URL}', 'pay/tokenpay', 0, now(), now(), NULL);
EOF
fi

# 标记已初始化
touch "$_TOKENPAY_LOCK_FILE"

echo ">>> [TokenPay] Payment methods initialized."
echo ">>> [TokenPay] Note: Payment methods are disabled by default. Enable them in admin panel."

# 清理
_tokenpay_cleanup_mariadb
