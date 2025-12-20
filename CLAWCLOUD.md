# ClawCloud 部署指南

## 部署配置

### 1. 基础设置
- **镜像**: `ghcr.io/your-username/dujiaoka:latest`
- **端口**: `80`
- **数据挂载**: `/data`

### 2. 环境变量（必需）

#### 独角数卡基础配置
```
APP_URL=https://your-domain.com
ADMIN_PATH=admin        # 后台路径，建议修改
DB_PASSWORD=your_password    # 数据库密码，建议修改
```

#### TokenPay 支付配置（冷钱包）
```
TOKENPAY_TRON_ADDRESS=TYourTronAddressHere      # TRC20收款地址
TOKENPAY_EVM_ADDRESS=0xYourEvmAddressHere        # ERC20收款地址
TOKENPAY_TRONGRID_KEY=your-trongrid-api-key      # TronGrid API Key
TOKENPAY_WEBSITE_URL=https://your-domain.com     # 外网访问地址
```

### 3. 可选配置
```
# 基础货币（默认 CNY）
TOKENPAY_BASE_CURRENCY=USD

# Telegram 通知
TOKENPAY_TG_ADMIN_ID=12345678
TOKENPAY_TG_BOT_TOKEN=bot_token_here
```

## 启动后操作

1. **访问前端**: `https://your-domain.com`
2. **访问后台**: `https://your-domain.com/admin`
3. **完成安装**: 首次访问会进入安装向导
4. **启用支付**: 后台 → 配置 → 支付配置 → 启用 TokenPay 支付方式

## 目录结构

启动后会在 `/data` 目录下自动创建：
```
/data/
├── dujiaoka/
│   ├── .env          # 独角数卡配置
│   ├── uploads/      # 上传文件
│   └── install.lock  # 安装锁
├── mysql/            # MariaDB 数据文件
└── tokenpay/
    ├── appsettings.json  # TokenPay 配置
    ├── TokenPay.db       # SQLite 数据
    └── .api_token        # API 密钥
```

## 注意事项

- 所有配置通过环境变量自动生成，无需手动创建文件
- TokenPay 支付方式默认禁用，需在后台手动启用
- 建议修改默认的 `ADMIN_PATH` 和 `DB_PASSWORD`