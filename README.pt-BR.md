# local-ai-system-one-lab — modelos System One (estilo Jev), open-weights, rodando local de graça

Laboratório para a classe **System One** — motores de IA que devolvem **decisões tipadas com probabilidades** (sim/não, escolha, escala, número) em uma única passada, sem gerar texto. O modelo fechado famoso dessa classe é o **Jev**, da TypeSafe; esta pasta roda e ensina os equivalentes **open-weights de graça**.

> 🇺🇸 This repository has an English sibling document: `README.md`. Both human materials exist in both languages (`RUNBOOK.pt-BR.md` PT + `RUNBOOK.md` EN; `LESSON.pt-BR.md` PT + `LESSON.md` EN).

## O que tem na caixa

| Arquivo | Papel |
|---|---|
| `CLAUDE.md` | instruções para agentes IA: modo tutor — um agente que abrir este repositório pode guiar uma pessoa passo a passo pela aula, na língua dela |
| `RUNBOOK.pt-BR.md` (PT) / `RUNBOOK.md` | runbook para humanos: instalar, rodar, playground, API — 3 comandos copiar-colar |
| `LESSON.pt-BR.md` (PT) / `LESSON.md` | material de aula: analogias, as 4 primitivas (noul/choice/score/numeric), 6 laboratórios práticos |
| `AGENTS.md` (EN) | dossiê técnico para agentes IA: números medidos, armadilhas, variações Linux/Mac/Windows, benchmarks |
| `start.sh` / `stop.sh` | liga/desliga o servidor local Rizzo Flow (playground em http://127.0.0.1:8017/playground) |
| `try-rizzo.sh` · `try-laya.py` | testa **uma** categorização por cada motor — mesmo contrato JSON de entrada e saída |
| `lambda/` | app CDK + Dockerfile que colocam o motor Laya dentro de uma AWS Lambda (executado e medido; resultados no README da pasta) |
| `LAMBDA-LAYA.md` (EN) | plano + resultados do experimento na nuvem (rota A; rotas B/C) |

## Quer um aprendizado mais interativo? Traga um agente de IA.

Abra o seu agente de IA preferido nesta pasta — **Claude Code, Codex, OpenCode, ou qualquer outro que leia `CLAUDE.md` / `AGENTS.md`**. Esses dois arquivos levam as instruções: o agente lê e entende este material e **te ensina, na sua língua materna**, passo a passo — os conceitos básicos de System One, os experimentos práticos da aula e respostas para cada pergunta que você fizer pelo caminho. Como as instruções são carregadas automaticamente quando o agente inicia nesta pasta, ele **se propõe a te ensinar sozinho**: você só diz em qual língua prefere e se quer o passo a passo guiado — e aí seguem a ordem da aula juntos, rodando os comandos e comentando os resultados que aparecem.

Prefere estudar sozinho? Leia `LESSON.pt-BR.md` (português) ou `LESSON.md` (inglês) — a aula é autocontida.

## Comece rápido (Linux + GPU AMD/NVIDIA; sem GPU → modo CPU no runbook)

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
git clone https://github.com/Rizzo-AI-Academy/rizzo-flow.git && cd rizzo-flow && uv sync --locked
uv run rizzo download        # ~5 GB, retomável, com sha256 conferido
uv run rizzo serve           # → http://127.0.0.1:8017/playground
```

Ou sem GPU (Laya em CPU): veja `RUNBOOK.pt-BR.md` → seção "Modo CPU: Laya".

## Destaques medidos (este laboratório)

- Rizzo Flow 4B (Q8_0, Vulkan, placa de 8 GB): **5,99 GiB de VRAM**, warm p50 0,21 s, acurácia smoke 0,95.
- Laya num CPU de 16 threads: **136 ms por requisição completa**; em lote 20×4 → 83 ms/requisição.
- Laya dentro de uma AWS Lambda (10 GB): cold **97 s** / warm **0,53 s**; API JSON idêntica à do Jev da TypeSafe.
- Achado honesto de qualidade: Laya zero-shot em **português** erra intentions discretas com confiança alta (churn 0,029 contra 0,886 em EN) — sempre benchmark nos SEUS dados.
