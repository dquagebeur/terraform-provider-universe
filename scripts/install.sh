#!/usr/bin/env bash
set -euo pipefail
. $(dirname $0)/init.sh

BINARY="$SCRIPTS_DIR"/../terraform-provider-universe
BASE_PLUGINS_DIR="$HOME/.terraform.d/plugins/"

mkdir -p "$BASE_PLUGINS_DIR/"
cp -v "$BINARY" "$BASE_PLUGINS_DIR/"
cp -v "$BINARY" "$BASE_PLUGINS_DIR/"terraform-provider-linux

## Terraform >= v0.13 layout
PROVIDER_NAME=universe
PROVIDER_VERSION=0.0.3
PROVIDER_REGISTRY='github.com'
PROVIDER_ORGANIZATION='birchb1024'
PROVIDER_SOURCE_ADDRESS="${PROVIDER_ORGANIZATION}/${PROVIDER_NAME}"

PLUGINS_DIR="${BASE_PLUGINS_DIR}${PROVIDER_REGISTRY}/${PROVIDER_SOURCE_ADDRESS}/${PROVIDER_VERSION}/${OS}_${PROC}"
mkdir -p "$PLUGINS_DIR"
cp -v "$BINARY" "$PLUGINS_DIR/"

## Terraform >= v0.13 layout
PROVIDER_NAME=linux
PROVIDER_SOURCE_ADDRESS="${PROVIDER_ORGANIZATION}/${PROVIDER_NAME}"

PLUGINS_DIR="${BASE_PLUGINS_DIR}${PROVIDER_REGISTRY}/${PROVIDER_SOURCE_ADDRESS}/${PROVIDER_VERSION}/${OS}_${PROC}"
mkdir -p "$PLUGINS_DIR"
cp -v "$BINARY" "$PLUGINS_DIR/"terraform-provider-"${PROVIDER_NAME}"
