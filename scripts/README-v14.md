v14 confirmado no rig: o automatico via `miner start` depende do caminho `miner-run custom 3` e exige `miner_ver`, `miner_fork` e `miner_config_gen` dentro do `h-config.sh`.

Instalador recomendado:

```bash
sudo -i
wget -qO /tmp/install-keryx-v14.sh https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/scripts/install-v14-flat-raw.sh
bash /tmp/install-keryx-v14.sh
miner start
```

O instalador baixa os arquivos texto atuais direto do repositório para `/hive/miners/custom`, que é o caminho usado pelo HiveOS quando o miner é `custom`.
