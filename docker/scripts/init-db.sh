#!/bin/bash
set -e

DB_NAME="${DB_DATABASE:-dujiaoka}"
DB_USER="${DB_USERNAME:-dujiaoka}"
DB_PASS="${DB_PASSWORD:-dujiaoka}"

# 检查是否已初始化
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo ">>> Initializing MariaDB data directory..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql

    echo ">>> Starting MariaDB temporarily for setup..."
    /usr/sbin/mysqld --user=mysql &
    pid="$!"

    # 等待 MariaDB 启动
    for i in {1..30}; do
        if mysqladmin ping &>/dev/null; then
            break
        fi
        sleep 1
    done

    echo ">>> Creating database and user..."
    mysql -u root <<-EOSQL
        DELETE FROM mysql.user WHERE User='';
        DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
        DROP DATABASE IF EXISTS test;
        DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
        CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
        CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
        GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
        GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1';
        FLUSH PRIVILEGES;
EOSQL

    echo ">>> Stopping temporary MariaDB..."
    mysqladmin shutdown
    wait "$pid"

    echo ">>> MariaDB initialization completed."
fi

echo ">>> Database ready."
