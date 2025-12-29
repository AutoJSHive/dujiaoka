# ClawCloud 部署指南

## 部署配置

### 1. 基础设置
- **镜像**: `ghcr.io/your-username/dujiaoka:latest`
- **端口**: `80`
- **数据挂载**: `/data`

### 2. 生产环境变量清单

将以下变量一次性填入平台的环境变量表单（平台只有一组变量）：

```
# ===== 必填项 =====
DATA_DIR=/data
APP_URL=https://your-domain.com          # ← 改成你的真实域名

# ===== 可选修改（有默认值）=====
APP_NAME=独角数卡
APP_DEBUG=false
ADMIN_LANGUAGE=zh_CN
ADMIN_PATH=admin                          # ← 建议改成随机路径，如 admin_xyz123
ADMIN_HTTPS=false                         # ← 如果用 HTTPS 改为 true

# 数据库配置（建议修改密码）
DB_DATABASE=dujiaoka
DB_USERNAME=dujiaoka
DB_PASSWORD=dujiaoka                      # ← 建议改成强密码
DB_HOST=localhost                         # ← 避免 127.0.0.1 被 MariaDB 拒绝
DB_PORT=3306

# ===== TokenPay 配置（如不使用可全部留空）=====
TOKENPAY_API_TOKEN=                       # ← 留空，系统自动生成
TOKENPAY_WEBSITE_URL=https://your-domain.com  # ← 改成你的真实域名
TOKENPAY_BASE_CURRENCY=CNY

# 钱包地址（使用 TokenPay 时必填）
TOKENPAY_TRON_ADDRESS=                    # ← 你的 TRON 收款地址
TOKENPAY_EVM_ADDRESS=                     # ← 你的 EVM 收款地址（ETH/BSC等）
TOKENPAY_TRONGRID_KEY=                    # ← TronGrid API Key（trongrid.io 申请）

# Telegram 通知（可选）
TOKENPAY_TG_ADMIN_ID=0
TOKENPAY_TG_BOT_TOKEN=
```

### 变量说明

| 变量 | 是否必填 | 说明 |
|------|----------|------|
| `APP_URL` | ✅ 必填 | 你的商店访问地址 |
| `TOKENPAY_API_TOKEN` | ❌ 留空 | 系统自动生成，写入 `/data/tokenpay/.api_token` |
| `TOKENPAY_*_ADDRESS` | ⚠️ 按需 | 使用 TokenPay 收款时才需要填写真实钱包地址 |
| `TOKENPAY_TRONGRID_KEY` | ⚠️ 按需 | 使用 TRON 收款时需要，去 [trongrid.io](https://www.trongrid.io/) 免费申请 |
| `DB_PASSWORD` | 🔒 建议修改 | 默认密码不安全，建议改成强密码 |

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