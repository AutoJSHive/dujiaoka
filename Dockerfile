FROM webdevops/php-nginx:7.4

# 安装 MariaDB
RUN apt-get update && apt-get install -y --no-install-recommends \
    mariadb-server \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/mysqld \
    && chown mysql:mysql /run/mysqld

# 复制 MariaDB 轻量化配置
COPY docker/mariadb/my.cnf /etc/mysql/mariadb.conf.d/99-lightweight.cnf

# 复制应用代码
COPY . /app
WORKDIR /app

# 安装 PHP 依赖
RUN composer install --ignore-platform-reqs --no-dev --optimize-autoloader

# 设置权限
RUN chmod -R 755 /app && \
    chmod -R 777 /app/storage /app/bootstrap/cache

# 复制 supervisor 配置
COPY docker/supervisor/mariadb.conf /opt/docker/etc/supervisor.d/mariadb.conf

# 复制启动脚本
COPY docker/scripts/init-db.sh /opt/docker/provision/entrypoint.d/99-init-db.sh
RUN chmod +x /opt/docker/provision/entrypoint.d/99-init-db.sh

# 数据目录
VOLUME ["/var/lib/mysql"]

ENV WEB_DOCUMENT_ROOT=/app/public
