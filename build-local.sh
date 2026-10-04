#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$SCRIPT_DIR"
ZMK_WS="/home/ld50/zmk-workspace"
ARTIFACTS_DIR="${WORKSPACE_DIR}/build/artifacts"
USER_UID=$(id -u)
USER_GID=$(id -g)

mkdir -p "${ARTIFACTS_DIR}"

echo "========================================="
echo "Building ZMK firmware for Cannonball LL (Clean Port)"
echo "Config:    ${WORKSPACE_DIR}"
echo "Workspace: ${ZMK_WS}"
echo "Output:    ${ARTIFACTS_DIR}"
echo "========================================="

docker run --rm \
    -v "${WORKSPACE_DIR}:/workspace/zmk-config" \
    -v "${ZMK_WS}:/workspace/zmk-workspace" \
    -w /workspace/zmk-workspace \
    -e ZEPHYR_BASE=/workspace/zmk-workspace/zephyr \
    -e CMAKE_PREFIX_PATH=/workspace/zmk-workspace/zephyr/share/zephyr-package/cmake \
    zmkfirmware/zmk-build-arm:stable \
    bash -c '
set -e

git config --global --add safe.directory "*"

echo "==> Building firmware for Cannonball LL on seeeduino_xiao_ble..."
west build -p always -s /workspace/zmk-workspace/zmk/app -d /workspace/zmk-config/build/cannonball_ll -b seeeduino_xiao_ble -S studio-rpc-usb-uart -- \
    -DSHIELD="Cannonball_LL" \
    -DBOARD_ROOT=/workspace/zmk-config \
    -DZMK_CONFIG=/workspace/zmk-config/config \
    -DZMK_EXTRA_MODULES="/workspace/zmk-config;/workspace/zmk-workspace/zmk-pmw3610-driver;/workspace/zmk-workspace/prospector-zmk-module;/workspace/zmk-workspace/zmk-behavior-sensor-attr-cycle" \
    -DZEPHYR_BASE=/workspace/zmk-workspace/zephyr

mkdir -p /workspace/zmk-config/build/artifacts

if [ -f "/workspace/zmk-config/build/cannonball_ll/zephyr/zmk.uf2" ]; then
    cp /workspace/zmk-config/build/cannonball_ll/zephyr/zmk.uf2 /workspace/zmk-config/build/artifacts/cannonball_ll.uf2
    echo "==> SUCCESS! Firmware created: build/artifacts/cannonball_ll.uf2"
fi

chown -R '"${USER_UID}:${USER_GID}"' /workspace/zmk-config/build 2>/dev/null || true
'

echo "========================================="
echo "Build completed successfully!"
ls -lh "${ARTIFACTS_DIR}"
echo "========================================="
