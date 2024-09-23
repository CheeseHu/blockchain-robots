# Copyright 2020-2023 Tiryoh<tiryoh@gmail.com>
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# 
# This Dockerfile is based on https://github.com/AtsushiSaito/docker-ubuntu-sweb
# which is released under the Apache-2.0 license.

FROM ubuntu:jammy-20240808

ARG TARGETPLATFORM
LABEL maintainer="Tiryoh<tiryoh@gmail.com>"

SHELL ["/bin/bash", "-c"]

# Upgrade OS
RUN apt-get update -q && \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
    apt-get autoclean && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

# Install Ubuntu Mate desktop
RUN apt-get update -q && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        ubuntu-mate-desktop && \
    apt-get autoclean && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

# Add Package
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        tigervnc-standalone-server tigervnc-common \
        supervisor wget curl gosu git sudo python3-pip tini \
        build-essential vim sudo lsb-release locales \
        bash-completion tzdata terminator \
        dos2unix && \
    apt-get autoclean && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

# noVNC and Websockify
RUN git clone https://github.com/AtsushiSaito/noVNC.git -b add_clipboard_support /usr/lib/novnc
RUN pip install git+https://github.com/novnc/websockify.git@v0.10.0
RUN ln -s /usr/lib/novnc/vnc.html /usr/lib/novnc/index.html

# Set remote resize function enabled by default
RUN sed -i "s/UI.initSetting('resize', 'off');/UI.initSetting('resize', 'remote');/g" /usr/lib/novnc/app/ui.js

# Disable auto update and crash report
RUN sed -i 's/Prompt=.*/Prompt=never/' /etc/update-manager/release-upgrades
RUN sed -i 's/enabled=1/enabled=0/g' /etc/default/apport

# Install Firefox
RUN DEBIAN_FRONTEND=noninteractive add-apt-repository ppa:mozillateam/ppa -y && \
    echo 'Package: *' > /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin: release o=LP-PPA-mozillateam' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/mozilla-firefox && \
    apt-get update -q && \
    apt-get install -y \
    firefox && \
    apt-get autoclean && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

# # Install VSCodium
# RUN wget https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
#     -O /usr/share/keyrings/vscodium-archive-keyring.asc && \
#     echo 'deb [ signed-by=/usr/share/keyrings/vscodium-archive-keyring.asc ] https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/debs vscodium main' \
#     | tee /etc/apt/sources.list.d/vscodium.list && \
#     apt-get update -q && \
#     apt-get install -y codium && \
#     apt-get autoclean && \
#     apt-get autoremove && \
#     rm -rf /var/lib/apt/lists/*

# Install Visual Studio Code
RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg && \
    install -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/ && \
    sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list' && \
    apt-get update && \
    apt-get install -y code && \
    apt-get clean && \
    rm -f packages.microsoft.gpg

# Install ROS
ENV ROS_DISTRO humble
# desktop or ros-base
ARG INSTALL_PACKAGE=desktop

RUN apt-get update -q && \
    apt-get install -y curl gnupg2 lsb-release && \
    curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null && \
    apt-get update -q && \
    apt-get install -y ros-${ROS_DISTRO}-${INSTALL_PACKAGE} \
    python3-argcomplete \
    python3-colcon-common-extensions \
    python3-rosdep python3-vcstool && \
    rosdep init && \
    rm -rf /var/lib/apt/lists/*

RUN rosdep update

# Install simulation package only on amd64
# Not ready for arm64 for now (July 28th, 2020)
# https://github.com/Tiryoh/docker-ros2-desktop-vnc/pull/56#issuecomment-1196359860
RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
    apt-get update -q && \
    apt-get install -y \
    ros-${ROS_DISTRO}-gazebo-ros-pkgs \
    ros-${ROS_DISTRO}-ros-ign && \
    rm -rf /var/lib/apt/lists/*; \
    fi
# Package By Huynh=========================================================
# Install Gazebo
RUN apt-get update && \
    apt-get install -y ros-humble-gazebo-* \
    ros-${ROS_DISTRO}-ros-gz && \
    rm -rf /var/lib/apt/lists/*

# Install Cartographer
RUN apt-get update && \
    apt-get install -y ros-humble-cartographer \
    ros-humble-cartographer-ros && \
    rm -rf /var/lib/apt/lists/*

# Install Navigation2
RUN apt-get update && \
    apt-get install -y ros-humble-navigation2 \
    ros-humble-nav2-bringup \
    ros-humble-dynamixel-sdk \
    ros-humble-turtlebot3-msgs \ 
    ros-humble-turtlebot3 && \
    rm -rf /var/lib/apt/lists/*

# Install Python packages using pip
RUN apt-get update && \
    apt-get install -y python3-pip && \
    pip3 install --no-cache-dir redis && \
    rm -rf /var/lib/apt/lists/*

# Install Redis server
RUN apt update && \
    apt install -y redis-server && \
    rm -rf /var/lib/apt/lists/*

# Install curl
RUN apt-get update && apt-get install -y curl

# Run the curl command to install Aiken
RUN curl --proto '=https' --tlsv1.2 -LsSf https://install.aiken-lang.org | sh

# Run the curl command to install Deno
RUN curl -fsSL https://deno.land/install.sh | sh

# Update package lists and install nano
RUN apt-get update && apt-get install -y nano

# Run the autocompletion command for Aiken
# RUN aiken completion bash --install

# Install new OpenSSL
RUN wget http://nz2.archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.23_amd64.deb && \
    dpkg -i libssl1.1_1.1.1f-1ubuntu2.23_amd64.deb

# Install Node
RUN wget https://nodejs.org/dist/v20.17.0/node-v20.17.0-linux-x64.tar.xz
RUN tar -xf node-v20.17.0-linux-x64.tar.xz
RUN mv node-v20.17.0-linux-x64 /usr/local
# ==========================================================================
# Enable apt-get completion after running `apt-get update` in the container
RUN rm /etc/apt/apt.conf.d/docker-clean

COPY ./entrypoint.sh /
RUN dos2unix /entrypoint.sh
ENTRYPOINT [ "/bin/bash", "-c", "/entrypoint.sh" ]

ENV USER ubuntu
ENV PASSWD ubuntu

