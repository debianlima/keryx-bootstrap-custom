# Funcoes do backend externo OPoI - Keryx v1.1

Este documento explica as funcoes/blocos criados no patch de backend externo OPoI, o funcionamento e os parametros envolvidos.

> Observacao: este repositorio e de bootstrap/assets. O fonte Rust completo do Keryx patchado fica no pacote de fonte customizado. Este documento registra o desenho funcional validado para continuidade por humano ou outra IA.

## Objetivo do patch

Permitir que o Keryx Miner declare capacidades OPoI ao pool, mas encaminhe a inferencia para um backend externo OpenAI-compatible.

No setup validado:

```text
Keryx Miner
  -> recebe desafio OPoI para model_id interno
  -> verifica se model_id esta mapeado para backend externo
  -> envia prompt para Ollama /v1/chat/completions
  -> recebe resposta
  -> conclui desafio OPoI
  -> retoma PoW nas GPUs reais
```

## Flags CLI adicionadas

### `--external-inference-url <URL>`

Endpoint HTTP OpenAI-compatible usado para inferencia.

Valor validado:

```text
http://127.0.0.1:11434/v1/chat/completions
```

Uso:

```bash
--external-inference-url http://127.0.0.1:11434/v1/chat/completions
```

Comportamento:

- Se ausente, o Keryx tenta usar o fluxo local original.
- Se presente, os modelos declarados em `--external-inference-model` podem ser servidos externamente.

### `--external-inference-model <MODEL>`

Declara que um modelo interno do Keryx sera servido pelo backend externo.

Formatos aceitos:

```text
internal_model
internal_model=api_model
```

Exemplos:

```bash
--external-inference-model deepseek-r1-32b
--external-inference-model deepseek-r1-32b=keryx32b
--external-inference-model tinyllama=keryx32b
```

Significado:

| Formato | Interno Keryx | Modelo enviado ao backend externo |
| --- | --- | --- |
| `deepseek-r1-32b` | `deepseek-r1-32b` | `deepseek-r1-32b` |
| `deepseek-r1-32b=keryx32b` | `deepseek-r1-32b` | `keryx32b` |
| `tinyllama=keryx32b` | `tinyllama` | `keryx32b` |

Configuracao validada:

```bash
--external-inference-model tinyllama=keryx32b \
--external-inference-model deepseek-r1-8b=keryx32b \
--external-inference-model deepseek-r1-32b=keryx32b
```

### `--external-inference-api-key <KEY>`

Chave opcional para backend externo.

Comportamento esperado:

```text
Se informado, adiciona Authorization: Bearer <KEY> na requisicao HTTP.
Se nao informado, chama endpoint sem Authorization.
```

No setup validado com Ollama local, nao foi necessario.

### `--external-inference-timeout-sec <SECONDS>`

Timeout das chamadas HTTP externas.

Valor validado para 32B/32k:

```text
900
```

Uso:

```bash
--external-inference-timeout-sec 900
```

Motivo:

- DeepSeek-R1-32B com contexto 32768 pode demorar durante OPoI.
- Timeout curto pode causar falha no desafio.

## Estruturas conceituais

### `ExternalInferenceConfig`

Estrutura conceitual que agrupa a configuracao externa.

Campos:

| Campo | Tipo conceitual | Descricao |
| --- | --- | --- |
| `url` | string/Url | Endpoint `/v1/chat/completions`. |
| `api_key` | Option<String> | Bearer token opcional. |
| `timeout_sec` | u64 | Timeout HTTP em segundos. |
| `models` | Map<String, ExternalModelMapping> | Mapa de modelo interno para modelo externo. |

### `ExternalModelMapping`

Representa uma regra de roteamento.

Campos:

| Campo | Exemplo | Descricao |
| --- | --- | --- |
| `internal_model` | `deepseek-r1-32b` | Nome usado pelo Keryx/pool. |
| `api_model` | `keryx32b` | Nome enviado ao backend externo. |

Exemplo:

```text
internal_model = deepseek-r1-32b
api_model      = keryx32b
```

## Funcoes/blocos criados ou alterados

## 1. Parser de modelos externos

Nome conceitual:

```rust
parse_external_inference_model_arg(arg: &str) -> ExternalModelMapping
```

Entrada:

```text
arg = "tinyllama=keryx32b"
arg = "deepseek-r1-8b=keryx32b"
arg = "deepseek-r1-32b=keryx32b"
```

Saida:

```text
ExternalModelMapping {
  internal_model: "tinyllama",
  api_model: "keryx32b"
}
```

Regras:

```text
Se arg contem "=":
  esquerda = modelo interno Keryx
  direita  = modelo real no backend externo

Se arg nao contem "=":
  modelo interno = arg
  modelo real    = arg
```

Motivo:

Permitir que o Keryx declare uma capacidade interna, mas use outro modelo no backend externo.

Exemplo validado:

```text
Pool pede: tinyllama
Keryx loga: via 'tinyllama'
Backend recebe: model = keryx32b
```

## 2. Verificacao se um modelo e externo

Nome conceitual:

```rust
is_external_model(model_id: &str, cfg: &ExternalInferenceConfig) -> bool
```

Entrada:

| Parametro | Exemplo | Descricao |
| --- | --- | --- |
| `model_id` | `deepseek-r1-32b` | Modelo interno solicitado pelo Keryx/pool. |
| `cfg` | config externa | Contem os mapeamentos passados por CLI. |

Saida:

```text
true  se model_id esta em --external-inference-model
false se deve seguir fluxo local original
```

Uso no fluxo:

```text
Se true:
  nao baixa/carrega modelo local
  chama backend externo
Se false:
  fluxo local original
```

Logs esperados quando true:

```text
SlmEngine: 'deepseek-r1-32b' served by external backend — skipping local model prefetch.
```

## 3. Skip de prefetch local

Nome conceitual:

```rust
prefetch_model_if_needed(model_id, cfg)
```

Alteracao aplicada:

```text
Antes:
  sempre tentava garantir arquivos locais do modelo.

Depois:
  se model_id esta mapeado para backend externo:
    registra log
    pula prefetch/download local
  senao:
    executa prefetch original
```

Parametros:

| Parametro | Descricao |
| --- | --- |
| `model_id` | Modelo interno do Keryx. |
| `cfg` | Config com URL e mapeamentos externos. |

Logs validados:

```text
Prefetching model files before mining starts…
SlmEngine: 'tinyllama' served by external backend — skipping local model prefetch.
SlmEngine: 'deepseek-r1-8b' served by external backend — skipping local model prefetch.
SlmEngine: 'deepseek-r1-32b' served by external backend — skipping local model prefetch.
Model files ready — starting mining.
```

## 4. Probe do backend externo

Nome conceitual:

```rust
probe_external_inference(cfg: &ExternalInferenceConfig, selected_models: &[ModelId]) -> Result<()>
```

Objetivo:

Antes de declarar capacidades virtuais ao pool, verificar se o backend externo responde para cada modelo mapeado.

Entrada:

| Parametro | Exemplo | Descricao |
| --- | --- | --- |
| `cfg.url` | `http://127.0.0.1:11434/v1/chat/completions` | Endpoint OpenAI-compatible. |
| `selected_models` | `tinyllama`, `deepseek-r1-8b`, `deepseek-r1-32b` | Modelos internos selecionados pelo modo atual. |
| `mapping.api_model` | `keryx32b` | Modelo real no Ollama. |

Fluxo:

```text
para cada modelo selecionado:
  se modelo esta em external map:
    envia health-check para o backend
    espera resposta valida
  se algum falhar:
    nao declara capacidades virtuais
    retorna erro
se todos ok:
  habilita virtual capabilities
```

Logs esperados:

```text
External OPoI: probing model 'tinyllama' via http://127.0.0.1:11434/v1/chat/completions
External OPoI: model 'tinyllama' ready (... chars)
External OPoI: probing model 'deepseek-r1-8b' via http://127.0.0.1:11434/v1/chat/completions
External OPoI: model 'deepseek-r1-8b' ready (... chars)
External OPoI: probing model 'deepseek-r1-32b' via http://127.0.0.1:11434/v1/chat/completions
External OPoI: model 'deepseek-r1-32b' ready (... chars)
External OPoI backend verified — virtual capabilities enabled.
```

Parametro ajustado:

```text
max_tokens do probe foi aumentado de 16 para 128
```

Motivo:

Modelos DeepSeek-R1/Ollama podem gastar tokens em `reasoning` antes de preencher `content`. Um probe muito curto retornava `content` vazio.

## 5. Requisicao HTTP externa

Nome conceitual:

```rust
external_chat_request(
    cfg: &ExternalInferenceConfig,
    mapping: &ExternalModelMapping,
    prompt: &str,
    max_tokens: usize,
) -> Result<String>
```

Parametros:

| Parametro | Exemplo | Descricao |
| --- | --- | --- |
| `cfg.url` | `http://127.0.0.1:11434/v1/chat/completions` | URL do backend. |
| `cfg.api_key` | vazio ou token | Se presente, vira `Authorization: Bearer`. |
| `cfg.timeout_sec` | `900` | Timeout HTTP. |
| `mapping.internal_model` | `deepseek-r1-32b` | Modelo interno usado em logs e decisao Keryx. |
| `mapping.api_model` | `keryx32b` | Modelo enviado no JSON para Ollama. |
| `prompt` | desafio OPoI | Prompt recebido do fluxo OPoI. |
| `max_tokens` | depende do desafio/probe | Limite de tokens da resposta. |

Corpo JSON enviado:

```json
{
  "model": "keryx32b",
  "messages": [
    {
      "role": "system",
      "content": "..."
    },
    {
      "role": "user",
      "content": "<prompt OPoI>"
    }
  ],
  "stream": false,
  "max_tokens": 900
}
```

Observacao: o valor exato de `max_tokens` no corpo e controlado pelo fluxo do Keryx/probe. `--external-inference-timeout-sec` controla timeout de rede, nao tamanho da resposta.

Headers:

```text
Content-Type: application/json
Authorization: Bearer <api_key>    # somente se api_key foi informado
```

Resposta aceita pela v1.1:

```text
choices[0].message.content
choices[0].text
choices[0].message.reasoning
```

Prioridade:

```text
1. content nao vazio
2. text nao vazio
3. reasoning nao vazio
```

Risco conhecido:

```text
content e o campo padrao de resposta final.
reasoning foi aceito como fallback de compatibilidade com Ollama/DeepSeek-R1.
Para v1.2, e recomendavel aceitar reasoning no probe, mas tentar forcar content na resposta real.
```

## 6. Execucao de inferencia OPoI

Nome conceitual:

```rust
run_slm_inference(model_id: &str, prompt: &str, max_tokens: usize) -> Result<String>
```

Alteracao aplicada:

```text
Antes:
  model_id sempre era resolvido para motor local/modelos locais.

Depois:
  se model_id esta em external map:
    chama external_chat_request
  senao:
    usa motor local original
```

Parametros:

| Parametro | Exemplo | Descricao |
| --- | --- | --- |
| `model_id` | `tinyllama`, `deepseek-r1-8b`, `deepseek-r1-32b` | Modelo solicitado pelo pool/Keryx. |
| `prompt` | desafio OPoI | Entrada do desafio. |
| `max_tokens` | limite interno | Limite de resposta. |

Logs de sucesso:

```text
External OPoI: inference complete via 'tinyllama'
External OPoI: inference complete via 'deepseek-r1-8b'
External OPoI: inference complete via 'deepseek-r1-32b'
```

Importante:

O texto depois de `via` e o **modelo interno solicitado**, nao o nome real do modelo no Ollama.

Com mapeamento atual:

```text
via 'tinyllama'      -> backend model keryx32b
via 'deepseek-r1-8b' -> backend model keryx32b
via 'deepseek-r1-32b'-> backend model keryx32b
```

## 7. Declaracao de capacidades virtuais

Nome conceitual:

```rust
enable_virtual_capabilities_if_external_probe_ok()
```

Objetivo:

Declarar ao pool bridge que o minerador possui os modelos selecionados, mesmo quando a inferencia sera servida externamente.

Condição:

```text
probe externo precisa passar para todos os modelos selecionados e mapeados.
```

Log de sucesso:

```text
External OPoI backend verified — virtual capabilities enabled.
OPoI: declaring 3 model(s) to pool bridge
```

No `--high`, os 3 modelos selecionados sao:

```text
tinyllama
deepseek-r1-8b
deepseek-r1-32b
```

## Fluxo completo validado

```text
1. Usuario inicia minerador com --high e mapeamentos externos.
2. CLI carrega external-inference-url, timeout, api_key opcional e modelos.
3. Keryx seleciona TinyLlama + 8B + 32B.
4. Keryx faz probe externo dos tres model_ids internos.
5. Cada probe chama o Ollama usando api_model=keryx32b.
6. Probe passa.
7. Keryx habilita capacidades virtuais.
8. Keryx pula prefetch local dos modelos mapeados.
9. Keryx carrega plugins CUDA/OpenCL reais.
10. Keryx declara 3 modelos ao pool bridge.
11. Pool envia OPoI para um model_id.
12. Keryx pausa PoW globalmente.
13. Keryx chama external_chat_request.
14. Ollama responde.
15. Keryx conclui OPoI.
16. PoW retoma.
17. Shares continuam aceitas.
```

## Teste completo de ponta a ponta

```bash
cd /hive/miners/custom

RUST_BACKTRACE=1 ./keryx-miner.bin \
  -s stratum+tcp://krx.baikalmine.com:9020 \
  --mining-address keryx:qzppqqpg3f4yrp93g9fx0t65akrtzqpfaxrdjlyljjp59gdxh549u5s9pnesa.ESPOSA \
  --high \
  --external-inference-url http://127.0.0.1:11434/v1/chat/completions \
  --external-inference-model tinyllama=keryx32b \
  --external-inference-model deepseek-r1-8b=keryx32b \
  --external-inference-model deepseek-r1-32b=keryx32b \
  --external-inference-timeout-sec 900 \
  2>&1 | tee /var/log/miner/keryx-v11-high-all-to-32b-ctx32k.log
```

Validar:

```bash
grep -iE "External OPoI|virtual capabilities|skipping local model|Plugins found|OPoI: declaring|inference complete|challenge: done|Share accepted|error|panic" \
  /var/log/miner/keryx-v11-high-all-to-32b-ctx32k.log | tail -200
```

Resultado esperado:

```text
External OPoI backend verified — virtual capabilities enabled.
SlmEngine: 'tinyllama' served by external backend — skipping local model prefetch.
SlmEngine: 'deepseek-r1-8b' served by external backend — skipping local model prefetch.
SlmEngine: 'deepseek-r1-32b' served by external backend — skipping local model prefetch.
Plugins found 3 workers
OPoI: declaring 3 model(s) to pool bridge
External OPoI: inference complete via 'deepseek-r1-32b'
OPoI challenge: done ... — PoW resumes on next notify
Share accepted
```

## Comandos para depurar parametros

### Confirmar flags no binario

```bash
/hive/miners/custom/keryx-miner.bin --help | grep external-inference
```

### Confirmar Ollama e modelo

```bash
ollama ps
curl -s http://127.0.0.1:11434/api/version
```

### Testar o modelo diretamente no backend

```bash
curl -sS --max-time 900 \
  http://127.0.0.1:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "keryx32b",
    "messages": [
      {"role": "user", "content": "Responda em uma frase curta: pronto para OPoI Keryx"}
    ],
    "stream": false,
    "max_tokens": 128
  }'
```

## Proximos ajustes recomendados v1.2

```text
1. Logar internal_model e api_model na mesma linha:
   External OPoI: inference complete internal='tinyllama' api_model='keryx32b'

2. Separar fallback de reasoning:
   - probe pode aceitar reasoning
   - resposta real deve priorizar/forcar content

3. Adicionar flags opcionais:
   --external-inference-allow-reasoning-fallback
   --external-inference-system-prompt
   --external-inference-max-tokens

4. Expor metricas:
   - tempo de inferencia externa
   - tamanho da resposta
   - modelo interno solicitado
   - modelo externo chamado
```
