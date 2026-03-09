# Repository Guidelines

## First Read / 快速接手
- 默认把本仓库视为 **MonoGS（Gaussian Splatting SLAM）主仓库**，主入口是 `slam.py`。
- 优先使用 **中文** 沟通、注释和补充文档。
- 如无特殊说明，优先使用 **TMUX + Docker + NVIDIA Container Toolkit** 运行实验；宿主机直接运行仅作为对照或应急方案。
- 当前仓库已经提供 Docker 相关文件：`Dockerfile`、`docker-compose.yml`、`docker/entrypoint.sh`、`docs/Docker_运行指南.md`。
- 当前仓库没有独立 `tests/` 目录；改动后至少做一次最小冒烟验证。

## Project Structure & Module Organization
- `slam.py` 是主入口，负责读取配置、启动前端/后端进程、GUI 与评估流程。
- `utils/` 存放 SLAM 主要逻辑：`slam_frontend.py` 负责跟踪与关键帧，`slam_backend.py` 负责建图与高斯优化，`dataset.py` 负责数据集解析。
- `gaussian_splatting/` 是 3D Gaussian Splatting 相关模型、渲染与工具代码；`gui/` 是实时可视化界面。
- `configs/mono`、`configs/rgbd`、`configs/stereo`、`configs/live` 按传感器类型组织 YAML 配置。
- `submodules/` 包含本项目依赖的 CUDA/C++ 子模块，尤其是 `simple-knn` 和 `diff-gaussian-rasterization`。
- `scripts/` 提供数据下载脚本；`docs/`、`media/` 为论文和素材；`results/` 用于运行输出。

## Preferred Runtime: Docker

### Host prerequisites
- 宿主机应已安装并验证：
  - `docker`
  - `docker compose`
  - `nvidia-container-toolkit`
- 宿主机应满足以下验证：
  - `docker run --rm hello-world`
  - `docker run --rm --gpus all nvidia/cuda:11.8.0-runtime-ubuntu22.04 nvidia-smi`
- 如果当前 shell 里 `docker` 仍提示 `permission denied while trying to connect to the docker API`，通常是 `docker` 用户组尚未在当前 shell 生效；优先尝试 `newgrp docker` 或重新登录 shell / tmux 会话。

### Repo Docker files
- `Dockerfile`：基于 `nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04` 构建镜像，镜像名通过 Compose 生成为 `monogs:cu118`。
- `docker-compose.yml`：
  - `monogs`：无头运行 / 评估 / 调试
  - `monogs-gui`：X11 GUI 运行
- `docker/entrypoint.sh`：容器启动时自动激活 `conda` 环境并切到 `/workspace/MonoGS`。
- `Dockerfile` 已在靠后层固化 `xvfb` / `xauth`，用于在容器内跑带 GUI 逻辑的 Quick Demo，而不依赖宿主机 X11 透传。
- 详细说明见 `docs/Docker_运行指南.md`。

### Docker workflow
- 首次或依赖更新后：
  - `git submodule update --init --recursive`
  - `docker compose build monogs`
- 进入容器调试：
  - `export MONOGS_UID=$(id -u)`
  - `export MONOGS_GID=$(id -g)`
  - `docker compose run --rm monogs bash`
- Docker 内 Quick Demo（优先用于验证 GUI 路径是否正常）：
  - `docker compose run --rm monogs bash -lc "cd /workspace/MonoGS && xvfb-run -a python slam.py --config configs/mono/tum/fr3_office.yaml"`
- 常用无头评估：
  - `docker compose run --rm monogs python slam.py --config configs/mono/tum/fr3_office.yaml --eval`
  - `docker compose run --rm monogs python slam.py --config configs/rgbd/tum/fr3_office.yaml --eval`
- GUI 模式（宿主机 X11 透传，仅在需要真实窗口交互时使用，疑似不可用）：
  - `docker compose run --rm -e DISPLAY=$DISPLAY monogs-gui python slam.py --config configs/mono/tum/fr3_office.yaml`

### Docker implementation notes
- `Dockerfile` 已刻意把以下步骤拆层，以保护缓存、减少重下大包：
  - conda 环境创建
  - `pip` / 构建工具
  - `PyTorch cu118`
  - 普通 Python 依赖
  - 本地 CUDA 子模块编译
- 后续若需修 Docker 构建问题，**尽量不要修改 `PyTorch` 安装之前的层**，否则会导致 `torch==2.0.1+cu118` 重新下载。
- 本地 CUDA 子模块当前在 Docker 内通过 `python setup.py install` 安装，而不是直接 `pip install -r requirements.txt` 完成，原因是：
  - `simple-knn` / `diff-gaussian-rasterization` 的 `setup.py` 直接依赖已安装的 `torch`
  - 新版 `pip` / `PEP 517` 隔离构建容易导致构建期看不到 `torch`
- 若 Docker Hub 拉取元数据超时，可优先重试；若持续缓慢，再考虑为 Docker daemon 或当前 shell 单独配置代理。
- 当前验证经验：本项目“纯无 GUI”路径未必总是最稳；首次验证环境时，优先用 `xvfb-run` 走 `slam.py` 官方入口，不要先写自定义 Python 包装脚本绕过主入口。

## Build, Test, and Development Commands
- `git submodule update --init --recursive`：初始化依赖子模块，首次克隆后必跑。
- `docker compose build monogs`：构建推荐运行镜像。
- `docker compose run --rm monogs bash`：进入容器调试环境。
- `docker compose run --rm monogs bash -lc "cd /workspace/MonoGS && xvfb-run -a python slam.py --config configs/mono/tum/fr3_office.yaml"`：运行 Docker 内 Quick Demo。
- `docker compose run --rm monogs python slam.py --config configs/mono/tum/fr3_office.yaml --eval`：运行单目无头评估示例。
- `docker compose run --rm monogs python slam.py --config configs/rgbd/tum/fr3_office.yaml --eval`：运行 RGB-D 无头评估示例。
- `python slam.py --config configs/mono/tum/fr3_office.yaml`：宿主机直跑单目示例，仅在 Docker 不可用或做对照时使用。
- `ruff check .` / `ruff format .`：静态检查与格式化。

## Data, Paths, and Outputs
- 配置文件中的数据路径默认写成仓库内相对路径，例如 `datasets/tum/...`。
- Docker 工作流下，宿主机 `datasets/` 挂载到容器 `/workspace/MonoGS/datasets`，`results/` 挂载到 `/workspace/MonoGS/results`。
- 当前 `configs/mono/tum/fr3_office.yaml` 对应的 `datasets/tum/rgbd_dataset_freiburg3_long_office_household/rgb` 本地共有 `2585` 帧；盯 Demo 进度时不要猜总帧数，先数数据集再判断进度。
- 新增实验时，优先复用现有 `configs/*/base_config.yaml` 体系，不要复制整份配置。
- 不要提交数据集、模型权重、`results/` 产物或本机路径。

## Coding Style & Naming Conventions
- Python 使用 4 空格缩进，遵循 `pyproject.toml` 中的 Ruff 配置，行宽 88。
- 变量与函数使用 `snake_case`，类名使用 `PascalCase`，配置键延续现有 YAML 风格（如 `Results`、`Dataset`、`Training`）。
- 修改时尽量保持补丁聚焦；优先复用现有工具函数，不要平行复制逻辑。
- 对已有 CUDA / C++ 子模块，优先做最小必要修改；若改接口，要明确说明兼容性影响。

## Testing Guidelines
- 当前没有完整单元测试框架，提交前至少做一次针对性验证。
- 推荐优先级：
  1. `python slam.py --help`
  2. 对应配置的 `--eval` 无头冒烟
  3. 必要时再跑 GUI 或更长序列
- 涉及配置或数据加载改动时，优先验证对应数据集入口。
- 涉及格式或 Python 语法改动时，运行 `ruff check .`。
- 若改动 Docker 相关文件，至少验证：
  - `docker compose build monogs`
  - `docker compose run --rm monogs python -c "import torch; print(torch.cuda.is_available())"`
  - `docker compose run --rm monogs bash -lc "cd /workspace/MonoGS && xvfb-run -a python slam.py --config configs/mono/tum/fr3_office.yaml"`

## Commit & Pull Request Guidelines
- 提交信息保持简短、聚焦、动词开头，遵循现有历史风格，例如：`remove noisy logs`、`fix realsense depth config`。
- Pull Request 需要说明：修改目的、影响范围、复现/验证命令、是否影响配置、Docker 工作流或结果目录。
- 若改动 GUI、渲染效果或评估输出，附上截图、关键日志或指标摘要；若改动子模块接口，明确说明兼容性影响。

## Security & Configuration Tips
- 不要提交数据集、模型权重、`results/` 产物、代理配置或宿主机私有路径。
- 若需要代理，仅在当前 shell / 当前构建会话中临时设置，不要把代理地址写死进仓库文件。
- 新增配置时优先基于现有 `base_config.yaml` 继承，避免复制整份配置造成漂移。
