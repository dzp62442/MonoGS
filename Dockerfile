FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    CONDA_DIR=/opt/conda \
    MONOGS_ENV_NAME=monogs \
    CUDA_HOME=/usr/local/cuda \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    TORCH_CUDA_ARCH_LIST="7.0;7.5;8.0;8.6;8.9"

SHELL ["/bin/bash", "-lc"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    ffmpeg \
    git \
    libegl1 \
    libgl1 \
    libglib2.0-0 \
    libglu1-mesa \
    libsm6 \
    libx11-6 \
    libxcursor1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libxinerama1 \
    libxrandr2 \
    libxrender1 \
    libxxf86vm1 \
    ninja-build \
    pkg-config \
    wget \
    && rm -rf /var/lib/apt/lists/*

RUN wget -qO /tmp/miniconda.sh \
    https://repo.anaconda.com/miniconda/Miniconda3-py310_24.11.1-0-Linux-x86_64.sh \
    && bash /tmp/miniconda.sh -b -p "${CONDA_DIR}" \
    && rm -f /tmp/miniconda.sh \
    && "${CONDA_DIR}/bin/conda" clean -afy

ENV PATH=${CONDA_DIR}/bin:${PATH}

WORKDIR /opt/monogs-build

COPY requirements.txt ./requirements.txt
COPY submodules/simple-knn ./submodules/simple-knn
COPY submodules/diff-gaussian-rasterization ./submodules/diff-gaussian-rasterization
COPY docker/entrypoint.sh /usr/local/bin/monogs-entrypoint

RUN chmod +x /usr/local/bin/monogs-entrypoint

RUN conda create -y -n "${MONOGS_ENV_NAME}" python=3.10 pip=22.3.1

RUN source "${CONDA_DIR}/etc/profile.d/conda.sh" \
    && conda activate "${MONOGS_ENV_NAME}" \
    && pip install --upgrade pip \
    && pip install wheel \
    && python -c "import pkg_resources; print(pkg_resources.__file__)"

RUN source "${CONDA_DIR}/etc/profile.d/conda.sh" \
    && conda activate "${MONOGS_ENV_NAME}" \
    && pip install \
        numpy==1.26.4 \
        torch==2.0.1 \
        torchvision==0.15.2 \
        torchaudio==2.0.2 \
        --index-url https://download.pytorch.org/whl/cu118

RUN grep -vE '^(submodules/simple-knn|submodules/diff-gaussian-rasterization)$' requirements.txt > /tmp/requirements.docker.txt \
    && source "${CONDA_DIR}/etc/profile.d/conda.sh" \
    && conda activate "${MONOGS_ENV_NAME}" \
    && pip install -r /tmp/requirements.docker.txt

RUN source "${CONDA_DIR}/etc/profile.d/conda.sh" \
    && conda activate "${MONOGS_ENV_NAME}" \
    && cd /opt/monogs-build/submodules/simple-knn \
    && python setup.py install \
    && cd /opt/monogs-build/submodules/diff-gaussian-rasterization \
    && python setup.py install \
    && conda clean -afy

RUN apt-get update && apt-get install -y --no-install-recommends \
    xauth \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace/MonoGS

ENTRYPOINT ["/usr/local/bin/monogs-entrypoint"]
CMD ["bash"]
