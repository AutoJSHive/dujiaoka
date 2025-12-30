#!/bin/bash
# 注意：此脚本被 source 执行，不能用 exit，必须用 return
# 也不能用 trap EXIT，会影响父 shell

# 独角数卡数据库初始化（简化版）
# 注意：此脚本在 entrypoint.d 中运行，supervisor 尚未启动
# 因此需要自己管理 MariaDB 生命周期

echo ">>> [Dujiaoka] Starting database initialization check..."

_DUJIAOKA_DB_NAME="${DB_DATABASE:-dujiaoka}"
_DUJIAOKA_DB_USER="${DB_USERNAME:-dujiaoka}"
_DUJIAOKA_DB_PASS="${DB_PASSWORD:-dujiaoka}"
_DUJIAOKA_DATA_DIR="${DATA_DIR:-/data}"
_DUJIAOKA_LOCK_FILE="${_DUJIAOKA_DATA_DIR}/mysql/.dujiaoka_initialized"
_DUJIAOKA_MARIADB_STARTED_BY_US=false
_DUJIAOKA_MARIADB_PID=""

# 清理函数：确保关闭 MariaDB（手动调用）
_dujiaoka_cleanup_mariadb() {
    if [ "$_DUJIAOKA_MARIADB_STARTED_BY_US" = "true" ] && [ -n "$_DUJIAOKA_MARIADB_PID" ]; then
        echo ">>> [Dujiaoka] Stopping temporary MariaDB..."
        mysqladmin shutdown 2>/dev/null || true
        wait "$_DUJIAOKA_MARIADB_PID" 2>/dev/null || true
    fi
}

# 如果已经初始化过，跳过
if [ -f "$_DUJIAOKA_LOCK_FILE" ]; then
    echo ">>> [Dujiaoka] Database already initialized, skipping..."
    return 0 2>/dev/null || true
fi

# 检查 MariaDB 是否已在运行（使用超时避免挂起）
echo ">>> [Dujiaoka] Checking MariaDB status..."
if ! timeout 3 mysqladmin ping &>/dev/null; then
    echo ">>> [Dujiaoka] Starting MariaDB temporarily..."
    /usr/sbin/mysqld --user=mysql &
    _DUJIAOKA_MARIADB_PID=$!
    _DUJIAOKA_MARIADB_STARTED_BY_US=true
fi

# 等待数据库就绪
echo ">>> [Dujiaoka] Waiting for database..."
for _i in {1..30}; do
    if timeout 3 mysqladmin ping &>/dev/null; then
        echo ">>> [Dujiaoka] Database ready."
        break
    fi
    sleep 1
done

# 检查数据库是否存在
_DUJIAOKA_DB_EXISTS=$(mysql -u root -N -e "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='${_DUJIAOKA_DB_NAME}';" 2>/dev/null || echo "0")

if [ "$_DUJIAOKA_DB_EXISTS" = "0" ]; then
    echo ">>> [Dujiaoka] Creating database..."
    mysql -u root <<-EOSQL
        CREATE DATABASE IF NOT EXISTS \`${_DUJIAOKA_DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
EOSQL
    echo ">>> [Dujiaoka] Database created."
else
    echo ">>> [Dujiaoka] Database already exists."
fi

# 幂等授权：每次启动都确保权限存在
# 同步用户名与密码，避免环境变量与数据库用户不一致
echo ">>> [Dujiaoka] Ensuring database grants..."
mysql -u root <<-EOSQL
    CREATE USER IF NOT EXISTS '${_DUJIAOKA_DB_USER}'@'localhost' IDENTIFIED BY '${_DUJIAOKA_DB_PASS}';
    CREATE USER IF NOT EXISTS '${_DUJIAOKA_DB_USER}'@'127.0.0.1' IDENTIFIED BY '${_DUJIAOKA_DB_PASS}';
    ALTER USER '${_DUJIAOKA_DB_USER}'@'localhost' IDENTIFIED BY '${_DUJIAOKA_DB_PASS}';
    ALTER USER '${_DUJIAOKA_DB_USER}'@'127.0.0.1' IDENTIFIED BY '${_DUJIAOKA_DB_PASS}';
    GRANT ALL PRIVILEGES ON \`${_DUJIAOKA_DB_NAME}\`.* TO '${_DUJIAOKA_DB_USER}'@'localhost';
    GRANT ALL PRIVILEGES ON \`${_DUJIAOKA_DB_NAME}\`.* TO '${_DUJIAOKA_DB_USER}'@'127.0.0.1';
    FLUSH PRIVILEGES;
EOSQL
echo ">>> [Dujiaoka] Database grants ensured."

# 检查是否已导入数据表 (检查 admin_users 表是否存在)
_DUJIAOKA_TABLE_EXISTS=$(mysql -u root -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${_DUJIAOKA_DB_NAME}' AND table_name='admin_users';" 2>/dev/null || echo "0")

if [ "$_DUJIAOKA_TABLE_EXISTS" = "0" ]; then
    echo ">>> [Dujiaoka] Importing initial data..."
    if [ -f "/app/database/sql/install.sql" ]; then
        mysql -u root "${_DUJIAOKA_DB_NAME}" < "/app/database/sql/install.sql"
        echo ">>> [Dujiaoka] Initial data imported."
    else
        echo ">>> [Dujiaoka] ERROR: install.sql not found!"
    fi

    # 确保 jobs 表存在（database queue 驱动必须）
    echo ">>> [Dujiaoka] Creating jobs table for queue..."
    mysql -u root "${_DUJIAOKA_DB_NAME}" <<-EOSQL
        CREATE TABLE IF NOT EXISTS \`jobs\` (
            \`id\` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
            \`queue\` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
            \`payload\` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
            \`attempts\` tinyint(3) unsigned NOT NULL,
            \`reserved_at\` int(10) unsigned DEFAULT NULL,
            \`available_at\` int(10) unsigned NOT NULL,
            \`created_at\` int(10) unsigned NOT NULL,
            PRIMARY KEY (\`id\`),
            KEY \`jobs_queue_index\` (\`queue\`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
EOSQL
    echo ">>> [Dujiaoka] Jobs table ensured."
else
    echo ">>> [Dujiaoka] Tables already exist, skipping import."
fi

# 标记已初始化
touch "$_DUJIAOKA_LOCK_FILE"

echo ">>> [Dujiaoka] Database initialization completed."

# 清理
_dujiaoka_cleanup_mariadb
