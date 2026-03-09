# MonoGS Docker 运行指南

这份文档是写给**第一次接触 Docker、但想把 MonoGS 稳定跑起来**的人看的。

目标不是只给你一串命令，而是让你知道：

- 为什么要这么配
- 每一步在解决什么问题
- 成功后应该看到什么现象
- 出问题时优先查哪里

本文采用的工作方式是：**宿主机负责代码编辑和日常终端，Docker 容器负责运行 MonoGS 环境**。

这也是当前仓库最推荐的使用方式。

---

## 1. 先理解：为什么这里要用 Docker？

MonoGS 不是一个纯 Python 小项目，它会碰到这些典型问题：

- 依赖里有 `PyTorch + CUDA`
- 还要编译本地 CUDA / C++ 扩展
- 不同项目之间可能需要不同版本的 Python、PyTorch、CUDA 组合
- 一旦环境装乱了，后续排查会很痛苦

把它放进 Docker 后，你会得到这些好处：

- **环境隔离**：MonoGS 依赖不会污染宿主机
- **更可复现**：同一个镜像在别的机器上也更容易复用
- **更容易恢复**：容器坏了可以删，代码和数据不会丢
- **更适合长期维护**：后续你交给 Codex 做开发、实验、记录时，环境更稳定

一句话理解：

> 宿主机保留“工作台”，Docker 提供“实验室”。

---

## 2. 先理解几个概念

如果你是第一次用 Docker，下面这 4 个词最重要：

### 2.1 镜像（image）

镜像可以理解成：

- 一个“已经装好依赖的系统模板”
- 或者“可重复使用的运行环境快照”

在本项目里，最终会构建出一个镜像：

- `monogs:cu118`

以后你再运行容器时，本质上都是从它启动。

### 2.2 容器（container）

容器就是镜像启动后的运行实例。

可以把它理解成：

- 镜像是“类模板”
- 容器是“运行起来的实例”

你执行：

```bash
docker compose run --rm monogs bash
```

其实就是：

- 用 `monogs:cu118` 镜像
- 启动一个临时容器
- 进入里面的 shell

### 2.3 挂载（mount / volume）

挂载的作用是：

- 把宿主机目录映射到容器里

在本项目里，最关键的挂载是：

- 仓库根目录 → `/workspace/MonoGS`
- `datasets/` → `/workspace/MonoGS/datasets`
- `results/` → `/workspace/MonoGS/results`

这意味着：

- 你在宿主机改代码，容器里立刻能看到
- 你在容器里跑实验，结果会写回宿主机 `results/`

### 2.4 Docker Compose

如果只用 `docker run`，很多参数会很长。

`docker compose` 的作用是：

- 用一个 YAML 文件统一描述容器怎么启动
- 省去你每次手打一大串参数

本仓库里用的是：

- `docker-compose.yml`

---

## 3. 本文假设的机器环境

当前仓库的 Docker 方案默认面向下面这种机器：

- 宿主机是 Linux
- 宿主机已经装好 NVIDIA 驱动
- 你希望让 Docker 里的容器也能使用 GPU
- 你的目标 CUDA 运行环境是 `11.8`

你这台机器在实际配置中已经验证过：

- Docker 正常
- `nvidia-container-toolkit` 正常
- `docker run --gpus all ... nvidia-smi` 正常

如果以后换机器，也请按本文第 4 节重新检查一次。

---

## 4. 宿主机准备：先把“底座”装对

这一节解决的是：

> 容器到底能不能启动？能不能访问 GPU？

如果这一步没打稳，后面构建 MonoGS 时会一直卡。

### 4.1 检查 Docker 是否安装成功

先在宿主机运行：

```bash
docker --version
docker compose version
```

如果能看到版本号，说明 Docker 和 Compose 插件已经装好。

### 4.2 检查宿主机是否能看到 GPU

```bash
nvidia-smi
```

如果能看到显卡型号、显存、驱动版本，说明宿主机的 NVIDIA 驱动正常。

### 4.3 检查 Docker 容器是否能看到 GPU

这是最关键的一步：

```bash
docker run --rm --gpus all nvidia/cuda:11.8.0-runtime-ubuntu22.04 nvidia-smi
```

如果这条命令能在容器里打印出显卡信息，说明：

- Docker 没问题
- `nvidia-container-toolkit` 没问题
- 容器 GPU 通路没问题

如果这一步不通，不要继续构建 MonoGS，先把宿主机问题解决。

### 4.4 如果 `docker` 提示权限不足怎么办？

常见报错：

```bash
permission denied while trying to connect to the docker API at unix:///var/run/docker.sock
```

这通常不是 Docker 坏了，而是：

- 你的当前 shell / tmux 会话还没继承 `docker` 用户组权限

优先尝试：

```bash
newgrp docker
```

或者：

- 重新开一个终端
- 重新登录 shell
- 重新开一个新的 `tmux` 会话

经验上，**旧的 tmux 会话最容易保留旧权限状态**。

---

## 5. 本仓库里和 Docker 有关的文件都做什么？

你不一定需要记住所有细节，但要知道每个文件负责什么。

### 5.1 `Dockerfile`

它负责定义镜像怎么构建，核心事情包括：

- 以 `nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04` 为基础镜像
- 安装系统依赖
- 安装 Miniconda
- 创建 `monogs` conda 环境
- 安装 `PyTorch cu118`
- 安装项目普通 Python 依赖
- 编译本地 CUDA 子模块

### 5.2 `docker-compose.yml`

它负责定义“怎么启动容器”，主要有两个服务：

- `monogs`：无头运行，适合评估、调试、批量实验
- `monogs-gui`：GUI 运行，适合看实时界面

### 5.3 `docker/entrypoint.sh`

它负责容器启动后的初始化动作：

- 自动激活 `conda` 环境
- 自动进入 `/workspace/MonoGS`

这也是为什么你进入容器后，通常不需要手动再 `conda activate monogs`。

### 5.4 `.dockerignore`

它负责告诉 Docker：

- 构建镜像时，哪些文件不要打包进构建上下文

这样可以避免：

- 把 `datasets/`、`results/`、`.git/` 这些大目录也打进去
- 导致构建慢、镜像大、缓存脏

---

## 6. 第一次构建前，先初始化仓库

在仓库根目录执行：

```bash
git submodule update --init --recursive
mkdir -p datasets results
```

这一步的意义：

- `submodules/` 里有本项目依赖的 CUDA / C++ 扩展源码
- `datasets/` 和 `results/` 是后面挂载进容器的常用目录

如果你漏了 `git submodule update --init --recursive`，后续构建时很容易失败。

---

## 7. 先理解本项目的 Docker 构建策略

这部分是为了让你在以后出问题时，知道为什么我们这样设计。

当前 `Dockerfile` 的构建顺序不是随便写的，而是故意拆层：

1. 安装系统依赖
2. 安装 Miniconda
3. 创建 conda 环境
4. 安装 `pip` / 构建工具
5. 安装 `PyTorch cu118`
6. 安装普通 Python 依赖
7. 编译本地 CUDA 子模块

这样拆的好处是：

- 体积最大的 `PyTorch` 层可以单独缓存
- 如果后面只是子模块编译失败，不需要每次都重下 `torch`
- 调整 Docker 构建逻辑时，更容易定位问题

这也是我们这次实际踩坑后总结出来的经验。

---

## 8. 正式构建镜像

在仓库根目录执行：

```bash
docker compose build monogs
```

### 8.1 第一次构建为什么会很久？

第一次通常会比较久，因为它要完成：

- 拉取 `CUDA 11.8 + cuDNN + devel` 基础镜像
- 安装系统依赖
- 安装 Miniconda
- 安装 `torch==2.0.1+cu118`
- 安装 Open3D 等普通 Python 依赖
- 编译 `simple-knn` 和 `diff-gaussian-rasterization`

其中最耗时的通常是：

- 基础镜像下载
- `torch` wheel 下载
- 本地 CUDA 扩展编译

### 8.2 构建成功后你应该看到什么？

大致会看到：

```bash
✔ Image monogs:cu118 Built
```

这表示本地镜像已经准备好。

### 8.3 构建失败时先看什么？

优先检查下面三类问题：

1. **宿主机前提没满足**
   - Docker 没装好
   - GPU 容器不通
   - 当前 shell 没有 docker 权限

2. **网络问题**
   - 拉 Docker Hub 元数据超时
   - 下载 `torch` / `pip` 依赖超时

3. **本地 CUDA 子模块编译问题**
   - 常见于 `simple-knn` / `diff-gaussian-rasterization`
   - 一般和 `torch`、构建工具、pip 构建模式有关

### 8.4 构建失败后要不要直接 `--no-cache`？

不建议上来就用：

```bash
docker compose build --no-cache monogs
```

因为这样会让所有缓存失效，重新下载大镜像和 `torch` 会很慢。

更好的顺序是：

1. 先看失败发生在哪一层
2. 只修那一层之后再重建
3. 只有缓存明显脏掉了，才考虑 `--no-cache`

---

## 9. 启动容器前，先设置 UID / GID

为了避免容器生成的文件在宿主机上归 `root`，建议每次新开 shell 之后先执行：

```bash
export MONOGS_UID=$(id -u)
export MONOGS_GID=$(id -g)
```

这一步的作用是：

- 让容器尽量以和宿主机当前用户一致的身份运行
- 这样 `results/` 下的输出文件权限更正常

如果你不设置，Compose 会退回默认值，通常也能跑，但不如显式设置稳妥。

---

## 10. 第一次进入容器看看环境

### 10.1 打开交互式 shell

```bash
docker compose run --rm monogs bash
```

进入后，建议先运行：

```bash
pwd
python --version
python slam.py --help
```

你应该看到：

- 当前目录是 `/workspace/MonoGS`
- `python` 能正常用
- `slam.py --help` 能显示命令行参数

如果这一步都不通，不要急着跑完整实验，先把基础环境问题解决。

### 10.2 在容器里检查 PyTorch 和 GPU

还可以进一步验证：

```bash
python -c "import torch; print(torch.__version__); print(torch.cuda.is_available())"
```

如果输出里：

- 版本类似 `2.0.1+cu118`
- `True`

就说明容器内的 CUDA / PyTorch 通路已经正常。

---

## 11. 容器里的目录是怎么映射的？

默认挂载关系如下：

- 宿主机仓库根目录 → `/workspace/MonoGS`
- 宿主机 `datasets/` → `/workspace/MonoGS/datasets`
- 宿主机 `results/` → `/workspace/MonoGS/results`

这意味着配置文件里像下面这样的相对路径可以直接工作：

```yaml
Dataset:
  dataset_path: "datasets/tum/rgbd_dataset_freiburg3_long_office_household"
```

这也是为什么我们建议：

- 数据集尽量统一放在仓库 `datasets/`
- 输出统一写到 `results/`

因为这样宿主机和容器内路径天然一致，最不容易出错。

---

## 12. 第一次跑实验，先用无头模式

如果你第一次只想验证环境能跑通，**优先用无头模式**，不要一上来折腾 GUI。

### 12.1 单目 TUM 示例

```bash
docker compose run --rm monogs \
  python slam.py --config configs/mono/tum/fr3_office.yaml --eval
```

### 12.2 RGB-D TUM 示例

```bash
docker compose run --rm monogs \
  python slam.py --config configs/rgbd/tum/fr3_office.yaml --eval
```

### 12.3 Replica 示例

```bash
docker compose run --rm monogs \
  python slam.py --config configs/rgbd/replica/office0.yaml --eval
```

### 12.4 为什么建议先用 `--eval`？

因为它会：

- 关闭 GUI
- 更适合服务器 / 无头环境
- 更容易判断是不是纯环境问题
- 自动保留评估输出

第一次验证环境时，`--eval` 是最稳妥的入口。

---

## 13. 如果你想看 GUI，怎么做？

等无头模式跑通后，再去碰 GUI。

### 13.1 宿主机开放 X11 访问

```bash
xhost +local:root
```

运行完 GUI 后建议恢复：

```bash
xhost -local:root
```

### 13.2 启动 GUI 容器

```bash
docker compose run --rm \
  -e DISPLAY=$DISPLAY \
  monogs-gui \
  python slam.py --config configs/mono/tum/fr3_office.yaml
```

如果你要跑 RGB-D GUI：

```bash
docker compose run --rm \
  -e DISPLAY=$DISPLAY \
  monogs-gui \
  python slam.py --config configs/rgbd/tum/fr3_office.yaml
```

### 13.3 GUI 容易踩哪些坑？

优先排查：

- `DISPLAY` 是否存在
- `xhost +local:root` 是否执行过
- 你是不是 X11 会话
- 宿主机有没有远程桌面或图形占用影响

如果 GUI 不显示，不要立刻怀疑项目代码，先回到无头模式确认环境本身能跑通。

---

## 14. 数据集怎么放？怎么下载？

### 14.1 推荐放法

推荐统一放在仓库根目录的：

- `datasets/`

因为当前配置和 Compose 挂载都是围绕这个约定设计的。

### 14.2 在容器里下载数据集

你可以直接在容器中执行脚本：

```bash
docker compose run --rm monogs bash scripts/download_tum.sh
docker compose run --rm monogs bash scripts/download_replica.sh
docker compose run --rm monogs bash scripts/download_euroc.sh
```

下载完成后，数据仍然会保存在宿主机仓库下的 `datasets/` 目录里。

---

## 15. 你以后最常用的几个命令

### 15.1 构建镜像

```bash
docker compose build monogs
```

### 15.2 进入容器调试

```bash
docker compose run --rm monogs bash
```

### 15.3 跑一次无头评估

```bash
docker compose run --rm monogs \
  python slam.py --config configs/mono/tum/fr3_office.yaml --eval
```

### 15.4 检查容器 GPU

```bash
docker compose run --rm monogs \
  python -c "import torch; print(torch.cuda.is_available())"
```

你后面真正常用的，其实就是这几条。

---

## 16. 常见问题与排查顺序

### 16.1 `permission denied while trying to connect to the docker API`

优先怀疑：

- 当前 shell / tmux 没继承 `docker` 组权限

先试：

```bash
newgrp docker
```

不行就：

- 新开 shell
- 新开 `tmux`
- 重新登录

### 16.2 `docker run --gpus all ...` 不通

优先怀疑：

- `nvidia-container-toolkit` 没装好
- Docker runtime 没配置好

这个问题必须先解决，MonoGS 才值得继续往下跑。

### 16.3 Docker Hub 拉取超时

优先策略：

- 先重试一遍
- 如果仍慢，再考虑代理

如果你本机已经开了 Clash TUN，很多时候已经够用。

如果还不够，可以临时只给当前 shell 设置：

```bash
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
```

注意：

- 尽量不要把代理写死进仓库文件
- 代理配置更适合作为当前 shell 的临时环境变量

### 16.4 Docker 构建里 CUDA 子模块失败

这个仓库里最常见的构建难点就是：

- `simple-knn`
- `diff-gaussian-rasterization`

如果失败，不要第一时间怀疑“是不是 CUDA 根本坏了”，更常见的原因是：

- `torch` 安装顺序不合适
- pip 构建隔离导致构建期看不到 `torch`
- 构建工具版本与老式 `setup.py` 不兼容

### 16.5 构建失败后又开始重装 `PyTorch`

这是 Docker 分层缓存导致的正常现象。

经验原则：

> 尽量不要修改 `PyTorch` 安装之前的层。

否则后面的大包就会重新下载。

---

## 17. 推荐的学习路径

如果你以后想自己越来越熟悉这套工作流，建议按这个顺序练习：

1. 先确保宿主机 Docker + GPU 通路正常
2. 成功构建一次 `monogs:cu118`
3. 成功进入容器并运行 `python slam.py --help`
4. 成功跑一次 `--eval`
5. 再尝试 GUI
6. 最后再做配置修改和实验批量化

这样你会更容易分清：

- 哪些是宿主机问题
- 哪些是 Docker 问题
- 哪些是 MonoGS 本身的实验问题

---

## 18. 一套你可以直接照抄的最小流程

如果你现在只想“照着跑起来”，最短路径如下：

```bash
git submodule update --init --recursive
mkdir -p datasets results
export MONOGS_UID=$(id -u)
export MONOGS_GID=$(id -g)
docker compose build monogs
docker compose run --rm monogs python slam.py --help
docker compose run --rm monogs python -c "import torch; print(torch.cuda.is_available())"
docker compose run --rm monogs python slam.py --config configs/mono/tum/fr3_office.yaml --eval
```

如果这套流程能跑通，说明你的 Docker 化 MonoGS 环境已经基本建立完成。

---

## 19. 最后一句建议

第一次学 Docker 时，最容易犯的错误是：

- 一出错就不停重装
- 把宿主机问题、Docker 问题、项目问题混在一起看

更稳的做法是：

- 先验证宿主机 Docker
- 再验证 GPU 容器
- 再验证镜像构建
- 再验证 `python` / `torch` / `slam.py --help`
- 最后才跑真正实验

按这条顺序排查，效率会高很多。
