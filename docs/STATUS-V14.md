# Status v14

A correção confirmada no rig foi aplicada nos scripts principais do projeto.

O ponto crítico é o `h-config.sh`: ele agora define `miner_ver`, `miner_fork` e `miner_config_gen`, que são chamadas pelo `miner-run custom 3` antes do `h-run.sh`.

Para instalar no rig sem depender de pacote tar durante teste:

```bash
sudo -i
wget -qO /tmp/install-keryx-v14.sh https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/scripts/install-v14-flat-raw.sh
bash /tmp/install-keryx-v14.sh
miner start
```
