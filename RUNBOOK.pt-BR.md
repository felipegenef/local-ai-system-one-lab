# Jev e System One open-weights — Runbook

## Instalação (3 comandos)

> Serve para Linux de verdade com GPU AMD/Intel/NVIDIA (ideal) — testado numa **GPU de 8 GB**. Não tem GPU? Pule para "Modo CPU" no fim.

**1. Ferramentas + projeto**

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh   # instale o uv (se ainda não tem); feche o terminal depois
git clone https://github.com/Rizzo-AI-Academy/rizzo-flow.git && cd rizzo-flow
uv sync --locked
```

**2. Baixar modelo + motor** (~5 GB; se cair a conexão, rode de novo que continua de onde parou)

```bash
uv run rizzo download
```

**3. Ligar o servidor** (o modelo carrega em ~10 s)

```bash
uv run rizzo serve
```

---

## Rodar de novo ou desligar (outro dia)

Tudo já está baixado — não precisa reinstalar nem baixar nada. Na pasta `JEV` há dois atalhos prontos:

| O que você quer | Comando (na pasta `JEV`) |
|---|---|
| **Ligar** (sobe servidor + playground) | `./start.sh` |
| **Desligar** (libera a VRAM) | `./stop.sh` |
| Saber se está no ar | `curl http://127.0.0.1:8017/health` (voltar `"status":"ready"` = ok) |

Depois de `./start.sh`, espere ~15 s e abra **http://127.0.0.1:8017/playground**. Ctrl+C ou `./stop.sh` encerra e devolve a memória da GPU.

---

## Testando (rode nessa ordem)

1. **A GPU foi vista?** `uv run rizzo devices` → deve aparecer `Vulkan0` com o nome da sua placa.
2. **Interface gráfica** → abra **http://127.0.0.1:8017/playground**
   - Menu **Examples…** → **Support ticket** → botão **Run** → 3 respostas com barras de probabilidade.
   - Badge no topo: `Spark-X2.5-4B · q8_0 · gpu`.
3. **API por terminal** (cole em outro terminal, com o servidor ligado):

```bash
curl http://127.0.0.1:8017/v1/systemone -H 'Content-Type: application/json' -d '{
  "state": "Payouts failing for 3 days",
  "model": "rizzo-latest",
  "questions": {"u": {"type": "noul", "instructions": "Is this urgent?"}}
}'
```

✅ Tem que voltar um JSON com `"noul"` (~0.99) e `"output_tokens": 0`.

---

## Para brincar

- **Playground**: monte perguntas com cliques, mude o texto, aperte Run. ([/playground](http://127.0.0.1:8017/playground))
- **Snake da decisão**: cada movimento da cobrinha é uma decisão do modelo. ([/snake](http://127.0.0.1:8017/snake))
- **Docs da API** (swagger): [/docs](http://127.0.0.1:8017/docs)
- Aula guiada + exercícios: veja **LESSON.pt-BR.md** (na pasta de cima). O material explica os 3 tipos de pergunta e propor exercícios prontos para colar no playground.

## Servidor sempre ligado (opcional, servidor Linux)

```bash
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/rizzo.service <<'EOF'
[Unit]
Description=Rizzo Flow (System One)
After=network.target

[Service]
WorkingDirectory=%h/rizzo-flow
ExecStart=%h/.local/bin/uv run rizzo serve --host 0.0.0.0 --port 8017
Environment=RIZZO_API_KEY=TROQUE_ESTE_TOKEN
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now rizzo.service
sudo loginctl enable-linger $USER
```

- Testar: `curl -H 'Authorization: Bearer TROQUE_ESTE_TOKEN' http://SEU-IP:8017/health`
- Sem a variável `RIZZO_API_KEY`, a API fica aberta sem senha (ok para lab caseiro).
- Para acessar de outras máquinas: abrir a porta no firewall (`sudo ufw allow 8017/tcp`) ou colocar atrás de um proxy (Caddy: `caddy reverse-proxy --from example.com --to 127.0.0.1:8017`).

## Modo CPU (sem GPU nenhuma): Laya

```bash
mkdir -p ../laya-cpu && cd ../laya-cpu
uv venv --python 3.12 && uv pip install laya

> **O Laya não tem "de novo/desligar"**: ele é um programa que roda e termina — quando o script acaba, a memória da CPU é liberada sozinha. Rode de novo quantas vezes quiser. Quem tem liga/desliga é o **Rizzo** (`start.sh` / `stop.sh`).

OMP_NUM_THREADS=16 .venv/bin/python -c "
from laya import Router
router = Router(device='cpu')  # 1a execução baixa ~800 MB

state = {'body': 'Fui cobrado duas vezes. Reembolse hoje ou cancelo o plano.'}
questions = {
  'department': {'type': 'choice', 'instructions': 'Which department?',
                 'criteria': {'billing': 'invoices, payments', 'technical': 'bugs, outages', 'other': 'rest'}},
  'urgency':   {'type': 'score', 'instructions': 'How urgent?', 'criteria': ['not urgent', 'soon', 'blocking']},
  'churn':     {'type': 'noul', 'instructions': 'Does the user threaten to cancel or leave?'},
}
r = router.predict(state, questions)
print(r['answers']['department']['choice'], '|', r['answers']['urgency']['score'])
"
```

- Medido num CPU de 16 threads: **136 ms** por requisição completa — dá para usar interativo.
- **Atenção:** em português, o Laya zero-shot erra intenções discretas (diz "não vai cancelar" para quem ameaça cancelar). Teste sempre nos SEUS textos, em EN e PT. (Detalhes e números: LESSON.pt-BR.md.)

---

## Deu erro?

| Sintoma | O que fazer |
|---|---|
| `uv` não encontrado | feche e reabra o terminal |
| download parou | rode `uv run rizzo download` de novo (continua de onde parou) |
| `rizzo devices` não mostra a placa | instale o driver Vulkan: `sudo apt install mesa-vulkan-drivers` |
| porta 8017 ocupada | `uv run rizzo serve --port 8020` |
| SDK pede model estranho | use sempre `model="rizzo-latest"` |
| modelo lento/VRAM estourada | `uv run rizzo serve --quant q4_k_m` (2,6 GB) ou `--size 1.7b` (1,8 GB) |

Mais armadilhas técnicas e variações (Mac/Windows): ver **AGENTS.md**.
