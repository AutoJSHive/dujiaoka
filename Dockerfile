FROM webdevops/php-nginx:7.4

# GitHub Token for private download
ARG GH_TOKEN

# 修复 Debian Buster EOL 源
RUN rm -f /etc/apt/sources.list.d/nginx.list && \
    echo "deb http://archive.debian.org/debian buster main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list

# 安装 MariaDB 和 jq
RUN apt-get update && apt-get install -y --no-install-recommends \
    mariadb-server \
    mariadb-client \
    jq \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/mysqld \
    && chown mysql:mysql /run/mysqld

# 复制 MariaDB 轻量化配置
COPY docker/mariadb/my.cnf /etc/mysql/mariadb.conf.d/99-lightweight.cnf

# 下载 TokenPay 私有 release
RUN set -e; \
    if [ -z "$GH_TOKEN" ]; then \
        echo "ERROR: GH_TOKEN is required to download TokenPay during build"; \
        exit 1; \
    fi; \
    ASSET_NAME="TokenPay-v1.0.4-linux-x64.zip"; \
    RELEASE_TAG="untagged-282fae86c85e3a0fd737"; \
    REPO="AutoJSHive/TokenPay"; \
    TEMP_DIR="/tmp/tokenpay"; \
    mkdir -p "$TEMP_DIR"; \
    echo "Fetching release info from GitHub API..."; \
    RELEASE_API_URL="https://api.github.com/repos/${REPO}/releases/tags/${RELEASE_TAG}"; \
    ASSET_URL=$(curl -sL \
        -H "Authorization: token $GH_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$RELEASE_API_URL" | jq -r ".assets[] | select(.name==\"$ASSET_NAME\") | .url"); \
    if [ -z "$ASSET_URL" ] || [ "$ASSET_URL" = "null" ]; then \
        echo "ERROR: Could not find asset $ASSET_NAME in release"; \
        exit 1; \
    fi; \
    echo "Downloading TokenPay from: $ASSET_URL"; \
    curl -L -f --retry 3 --retry-delay 5 \
        -H "Authorization: token $GH_TOKEN" \
        -H "Accept: application/octet-stream" \
        -o "$TEMP_DIR/tokenpay.zip" \
        "$ASSET_URL"; \
    echo "Download completed. Extracting..."; \
    cd "$TEMP_DIR" && \
    unzip -q tokenpay.zip && \
    mkdir -p /opt/tokenpay && \
    mv * /opt/tokenpay/ && \
    chmod +x /opt/tokenpay/TokenPay && \
    echo "TokenPay installed successfully." && \
    ls -la /opt/tokenpay/TokenPay && \
    rm -rf "$TEMP_DIR"

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