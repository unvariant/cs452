#!/bin/sh

QEMU="./qemu/build/qemu-system-aarch64"

SERIAL=(
    -serial unix:/tmp/uart0.unix,server
    -serial none
    -serial none
    # -serial unix:/tmp/uart3.unix,server
)

DEBUG=(
    -s
)

"${QEMU}" \
    -nographic \
    -kernel ./build/iotest.img \
    -machine raspi4b -cpu cortex-a72 \
    "${SERIAL[@]}" \
    -d guest_errors \
    -dtb ./bcm2711-rpi-4-b.dtb \
    -D log.txt \
    "${DEBUG[@]}"