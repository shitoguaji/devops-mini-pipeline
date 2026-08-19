# DevOps Mini Pipeline

一个用于学习和实践 DevOps 流程的极简 Python HTTP 应用，完整走通 CI/CD 全链路。

## 📖 项目简介

这是一个用 Python 内置 `http.server` 模块写的极简 Web 应用，只有一个接口：访问 `/` 时返回环境变量 `APP_MESSAGE` 的值（默认为 "Hello from DevOps Mini Pipeline"）。

**核心目的**：用这个极简应用串联起一套完整的 DevOps 工具链。

## 架构
GitHub Push → GitHub Actions → Docker Build → Push to Docker Hub → Kind 集群部署 → 自动验证


## 🛠️ 技术栈

| 工具 | 用途 |
|------|------|
| Python 3.13 | 应用开发语言 |
| Docker | 容器化打包 |
| GitHub Actions | CI/CD 流水线 |
| 阿里云 ACR | Docker 镜像仓库 |
| Kubernetes (Minikube) | 容器编排（后续集成） |

## 🚀 快速开始

### 1. 克隆项目
```bash
git clone https://github.com/shitoguaji/devops-mini-pipeline.git
cd devops-mini-pipeline
```

### 2. 本地运行（不带 Docker）
```bash
# 默认返回 "Hello from DevOps Mini Pipeline"
python server.py

# 自定义消息
export APP_MESSAGE="Hello DevOps"
python server.py
```
访问 `http://localhost:8000`

### 3. 用 Docker 运行
```bash
# 构建镜像
docker build -t devops-mini-pipeline:local .

# 运行容器
docker run -d -p 8000:8000 --name test -e APP_MESSAGE="Hello from Docker" devops-mini-pipeline:local

# 测试
curl http://localhost:8000
```

### 4. 从阿里云 ACR 拉取并运行
```bash
docker pull crpi-j2m2hn2j5pnrlqrp.cn-guangzhou.personal.cr.aliyuncs.com/shitoguaji-images/devops-mini-pipeline:latest

docker run -d -p 8000:8000 --name test \
-e APP_MESSAGE="Hello from ACR" \
ALIYUN_REGISTRY/ALIYUN_NAMESPACE/devops-mini-pipeline:latest
```

## 🧪 CI/CD 流水线

项目配置了 GitHub Actions，代码推送到 `main` 分支时自动触发：

```yaml
触发条件: push 到 main / pull_request 到 main
构建平台: linux/amd64, linux/arm64
镜像仓库: 阿里云 ACR
镜像标签: latest + commit SHA
```

### 查看流水线状态
访问：`https://github.com/shitoguaji/devops-mini-pipeline/actions`


## 📁 项目结构

```
devops-mini-pipeline/
├── .github/
│   └── workflows/
│       └── ci.yml              # GitHub Actions：构建镜像 → 推 Docker Hub → Kind 部署验证
├── k8s/                        # Kubernetes 清单目录
│   ├── deployment.yaml         # Deployment + 三探针（liveness/readiness/startup）
│   └── service.yaml            # NodePort Service
├── kind-config.yaml            # Kind 集群配置（端口映射 30080）
├── server.py                   # 极简 HTTP 服务（Python 标准库）
├── Dockerfile                  # 多阶段构建（builder → distroless runtime）
├── .dockerignore               # 排除 .git / __pycache__ / .env 等
└── README.md                   # 项目说明 + 踩坑记录 + 故障排查
```


# ⚠️ 踩坑记录（重要！）

## 🕳️ 坑 1：`/usr/bin/python3: no such file or directory`

**现象**：容器启动时报错 `exec: "/usr/bin/python3": stat /usr/bin/python3: no such file or directory`

**原因**：不同基础镜像中 Python 的安装路径不一样。
- `python:3.13-slim` 中 Python 在 `/usr/local/bin/python3`
- `distroless/python3` 中 Python 在 `/usr/bin/python3`

**解决方案**：改用 `python3` 让系统自动查找。

```dockerfile
# ❌ 错误写法
ENTRYPOINT ["/usr/bin/python3", "/app/server.py"]

# ✅ 正确写法
ENTRYPOINT ["python3", "/app/server.py"]
```

---

## 🕳️ 坑 2：Git push 报 `Connection reset by peer`

**现象**：`git push` 时报错 `fatal: unable to access ... Recv failure: Connection reset by peer`

**原因**：服务器网络无法稳定访问 GitHub。

**解决方案**：改用 SSH 协议替代 HTTPS。

```bash
# 1. 在服务器生成 SSH 密钥
ssh-keygen -t ed25519 -C "your_email@example.com"
cat ~/.ssh/id_ed25519.pub  # 复制公钥

# 2. 添加到 GitHub：Settings → SSH and GPG keys → New SSH Key

# 3. 修改远程仓库地址
git remote set-url origin git@github.com:shitoguaji/devops-mini-pipeline.git

# 4. 推送
git push -u origin main
```

---

## 🕳️ 坑 3：GitHub Actions 报 `unknown manifest class`

**现象**：镜像构建成功，推送时报错：
```
denied: unknown manifest class for application/vnd.oci.empty.v1+json
```

**原因**：阿里云 ACR 不支持 OCI attestation manifest（`provenance` 和 `sbom` 生成的额外 manifest）。

**解决方案**：在 `docker/build-push-action` 中禁用 provenance 和 sbom。

```yaml
- name: Build and push
uses: docker/build-push-action@v7
with:
# ... 其他配置
provenance: false
sbom: false
```

---

## 🕳️ 坑 4：VS Code Remote-SSH 连不上服务器

**现象**：VS Code 远程连接报错 `Permission denied (publickey,password).`

**原因**：
1. VS Code 默认使用密钥认证，没配置密钥就连接失败
2. `remote.SSH.path` 指向了不存在的 SSH 客户端

**解决方案**：

**方案一：强制走密码登录**
```bash
# 在 VS Code 命令板中输入
ssh -o PreferredAuthentications=password 用户名@IP
```

**方案二：修改 VS Code 设置**
```json
{
"remote.SSH.path": "C:\\WINDOWS\\System32\\OpenSSH\\ssh.exe",
"remote.SSH.showLoginTerminal": true
}
```

**方案三：配置 SSH 密钥（一劳永逸）**
```bash
# 在本地生成密钥并复制到服务器
ssh-keygen -t rsa
type C:\Users\你的用户名\.ssh\id_rsa.pub | ssh 用户名@IP "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

---

# 📚 学习资源

- [Docker 官方文档](https://docs.docker.com/)
- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [阿里云 ACR 文档](https://help.aliyun.com/zh/acr/)
- [VS Code Remote-SSH 文档](https://code.visualstudio.com/docs/remote/ssh)