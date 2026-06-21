#!/usr/bin/env bash
set -euo pipefail
cd /hive/miners/custom
wget -qO /tmp/keryx-v14-flat.tar.gz.b64 https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/dist/keryx-bootstrap-custom-hiveos-v14-flat.tar.gz.b64
base64 -d /tmp/keryx-v14-flat.tar.gz.b64 > /tmp/keryx-v14-flat.tar.gz
gzip -t /tmp/keryx-v14-flat.tar.gz
tar -xzf /tmp/keryx-v14-flat.tar.gz -C /hive/miners/custom
chmod 755 /hive/miners/custom/h-run /hive/miners/custom/h-run.sh /hive/miners/custom/h-config.sh /hive/miners/custom/h-stats.sh /hive/miners/custom/keryx-bootstrap.sh /hive/miners/custom/keryx-miner
