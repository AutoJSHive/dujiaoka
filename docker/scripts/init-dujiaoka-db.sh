#!/bin/bash
set -e

# 独角数卡数据库初始化（简化版）
# 注意：此脚本在 entrypoint.d 中运行，supervisor 尚未启动
# 因此需要自己管理 MariaDB 生命周期

DB_NAME="${DB_DATABASE:-dujiaoka}"
DB_USER="${DB_USERNAME:-dujiaoka}"
DB_PASS="${DB_PASSWORD:-dujiaoka}"
DATA_DIR="${DATA_DIR:-/data}"

LOCK_FILE="${DATA_DIR}/mysql/.dujiaoka_initialized"

# 如果已经初始化过，跳过
if [ -f "$LOCK_FILE" ]; then
    echo ">>> dujiaoka database already initialized, skipping..."
    exit 0
fi

# 检查 MariaDB 是否已在运行
MARIADB_STARTED_BY_US=false
if ! mysqladmin ping &>/dev/null; then
    echo ">>> Starting MariaDB temporarily for dujiaoka initialization..."
    /usr/sbin/mariadbd --user=mysql &
    MARIADB_PID=$!
    MARIADB_STARTED_BY_US=true
fi

# 等待数据库就绪
echo ">>> Waiting for database..."
for i in {1..30}; do
    if mysqladmin ping &>/dev/null; then
        break
    fi
    sleep 1
done

# 检查数据库是否存在
DB_EXISTS=$(mysql -u root -N -e "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='${DB_NAME}';" 2>/dev/null || echo "0")

if [ "$DB_EXISTS" = "0" ]; then
    echo ">>> Creating dujiaoka database..."
    mysql -u root <<-EOSQL
        CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
        CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
        GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
        GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1';
        FLUSH PRIVILEGES;
EOSQL
fi

# 如果是我们启动的 MariaDB，则关闭它（supervisor 稍后会正式启动）
if [ "$MARIADB_STARTED_BY_US" = "true" ]; then
    echo ">>> Stopping temporary MariaDB..."
    mysqladmin shutdown || true
    wait "$MARIADB_PID" 2>/dev/null || true
fi

# 标记已初始化
touch "$LOCK_FILE"

echo ">>> dujiaoka database initialized."