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

# 复制 TokenPay
COPY tokenpay/ /opt/tokenpay/
RUN chmod +x /opt/tokenpay/TokenPay

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
COPY docker/supervisor/tokenpay.conf /opt/docker/etc/supervisor.d/tokenpay.conf

# 复制启动脚本（按执行顺序命名）
COPY docker/scripts/init-db.sh /opt/docker/provision/entrypoint.d/10-init-db.sh
COPY docker/scripts/init-data.sh /opt/docker/provision/entrypoint.d/20-init-data.sh
COPY docker/scripts/init-dujiaoka-db.sh /opt/docker/provision/entrypoint.d/30-init-dujiaoka-db.sh
COPY docker/scripts/init-tokenpay-pays-simple.sh /opt/docker/provision/entrypoint.d/40-init-tokenpay-pays.sh
RUN chmod +x /opt/docker/provision/entrypoint.d/*.sh

# 数据目录
VOLUME ["/var/lib/mysql", "/opt/tokenpay"]

ENV WEB_DOCUMENT_ROOT=/app/public

# ============================================
# 默认环境变量（ClawCloud 可覆盖）
# ============================================

# 数据目录
ENV DATA_DIR=/data

# 独角数卡配置
ENV DB_DATABASE=dujiaoka
ENV DB_USERNAME=dujiaoka
ENV DB_PASSWORD=dujiaoka
ENV APP_NAME=独角数卡
ENV APP_DEBUG=false
ENV ADMIN_LANGUAGE=zh_CN
ENV ADMIN_PATH=admin
ENV ADMIN_HTTPS=false

# TokenPay 配置
ENV TOKENPAY_BASE_CURRENCY=CNY