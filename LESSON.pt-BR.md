# LESSON — System One: a IA que decide (não escreve)

> Material de estudo aberto (tutorial prático de System One). Setup: `RUNBOOK.pt-BR.md`; detalhes técnicos extra: `AGENTS.md`. Versão em inglês: `LESSON.md`.

**Como usar este tutorial:** cada passo tem 3 partes — **(1)** o conceito em poucas linhas, **(2)** o comando/JSON para colar, **(3)** o resultado esperado + o que reparar nele. Faça na ordem: leu o conceito → rodou → viu o resultado → reparou → próximo.

---

## 1. A ideia em uma frase

**System One model = IA de piloto automático.** Você pergunta "isso é urgente?" e ela responde "sim, 94%" — sem escrever texto, sem raciocínio longo, sem inventar frase.

**A analogia de Kahneman (quem batizou os nomes):** nosso cérebro tem dois modos. O **Sistema 1** é automático: você desvia do buraco na estrada antes de perceber que ele existe — rápido, barato, sem esforço consciente. O **Sistema 2** é o raciocínio lento: estacionar em vaga apertada, comparar duas propostas de financiamento... custa tempo e energia. Os LLMs do dia a dia são **Sistema 2**: escrevem resposta palavra por palavra. Um System One é **Sistema 1**: uma olhada rápida, uma resposta pronta com grau de certeza.

## 2. Como funciona (o encanamento)

Todo modelo System One segue o mesmo contrato:

```
                ┌────────────────────┐
   "state"      │                    │  respostas TIPADAS:
  (texto ou     │       MODELO       │  escolha + probabilidades + confiança
   JSON)  ────► │    (uma passada)   │
                │                    │
   "questions"─►│                    │  output_tokens: 0 (NENHUM texto gerado)
                └────────────────────┘
```

O truque da velocidade: cada pergunta vira **múltipla escolha** — cada candidato é uma letra (A, B, C...) — e o modelo **lê a probabilidade de cada letra direto nos bastidores da rede neural**, numa única passada. É como espiar o placar interno do modelo sem pedir para ele escrever "a opção B parece melhor porque...". Por isso é 40–200× mais rápido que um LLM respondendo em texto.

## 3. Os 4 tipos de pergunta (as variáveis do sistema)

| Tipo | É como perguntar... | O que devolve | Exemplo do dia a dia |
|---|---|---|---|
| `noul` (sim/não) | "Isto bloqueia clientes?" | P(sim), de 0 a 1 | "Cliente furioso?" → 0.85 |
| `choice` | "Qual opção descreve melhor?" | opção vencedora + prob. de cada + confiança | "e-mail SPAM/TRABALHO/PESSOAL?" |
| `score` | "Nota numa régua em ordem" | média ponderada da régua + confiança | "Urgência: [baixa, média, alta]" |
| `numeric`* | "Leia o número no dado" | valor ponderado + mediana + dispersão | termostato: 24 °C |

`*` `numeric` existe na API nativa do Rizzo Flow (`/v1/decisions`). Os 3 primeiros existem em todos, no contrato `/v1/systemone` (igualzinho à API paga do Jev).

Anatomia da requisição: **`state`** (o material a julgar) · **`questions`** (cada uma com `type`, `instructions` = a pergunta em texto natural, `criteria` = o cardápio de opções com descrições). As descrições do `criteria` são o que "norteia" o modelo — sem descrição, ele adivinha.

## 4. Confiança ≠ acerto (leia antes de experimentar)

Cada resposta vem com **confiança** — uma função matemática do *formato* das probabilidades, não uma promessa de acerto. O slogan da TypeSafe ("mais confiança ⇒ mais acerto") vale **medido nos dados deles**. No seu domínio há exceções — e o **Passo 7** mostra isso acontecendo diante de você.

---

## 5. Mão na massa — passo a passo

### Passo 1 — Instale o motor (escolha um)

**Opção A — com GPU (Rizzo Flow):**

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh    # ferramenta de gerência de Python
git clone https://github.com/Rizzo-AI-Academy/rizzo-flow.git && cd rizzo-flow
uv sync --locked
uv run rizzo download
```

Você deve ver: linhas de download com verificação sha256, terminando com o modelo em `models/` e o runtime em `runtimes/`.

**Opção B — qualquer computador, sem GPU (Laya em CPU):**

```bash
mkdir -p ../laya-cpu && cd ../laya-cpu
uv venv --python 3.12 && uv pip install laya
```

Você deve ver: pacotes instalados sem erro. Os pesos (~800 MB) baixam na primeira execução do Passo 7.

### Passo 2 — Suba o servidor (só a Opção A)

```bash
./start.sh
```

Você deve ver, entre outros: `Uvicorn running on http://127.0.0.1:8017`. Em outro terminal, confira:

```bash
curl http://127.0.0.1:8017/health
```

Esperado: `{"status":"ready", ...}` — pronto, o motor está quente.

### Passo 3 — Primeira decisão (playground)

Abra **http://127.0.0.1:8017/playground** → menu **Examples…** → **Support ticket** → botão **Run**.

Você deve ver: 3 respostas com barras de probabilidade — `department` (escolha entre times), `escalate` (P de urgência) e `frustration` (posição numa régua) — mais tempos e **`output_tokens: 0`**.

**Repare:** nenhuma palavra foi escrita pelo modelo; as barras são a resposta inteira. Mexa em 1 palavra do `state` (troque "refund" por "angry") e dê Run de novo — as barras mudam.

### Passo 4 — A mesma decisão pela API (copiar e colar)

```bash
curl http://127.0.0.1:8017/v1/systemone -H 'Content-Type: application/json' -d '{
  "state": "Help! My payouts have been failing for 3 days.",
  "model": "rizzo-latest",
  "questions": {
    "is_urgent": {"type": "noul", "instructions": "Does this convey urgency?"},
    "department": {"type": "choice", "instructions": "Which team should handle this?",
      "criteria": {"billing": "Payments, invoicing, refunds", "technical": "Bugs, outages", "sales": null}},
    "frustration": {"type": "score", "instructions": "How frustrated is the customer?",
      "criteria": ["Calm", "Frustrated", "Very angry"]}
  }
}'
```

Você deve ver (valores aproximados):

```json
{"answers": {
  "is_urgent":  {"type": "noul",  "noul": 0.94},
  "department": {"type": "choice", "choice": "billing",
                 "probabilities": {"billing": 0.99, "technical": 0.01, "sales": 0.00}, "confidence": 0.99},
  "frustration":{"type": "score", "score": 1.23,
                 "probabilities": {"0": 0.00, "1": 0.76, "2": 0.24}, "confidence": 0.64}
}, "usage": {"input_tokens": 291, "output_tokens": 0}}
```

**Repare:** o ticket mistura devolução + entrega atrasada + cobrança — e as probabilidades de `department` dizem isso ("billing" vence, mas não com 100% de chance): é por isso que a resposta traz distribuição, não só o rótulo. E `output_tokens: 0` de novo.

### Passo 5 — As opções dirigem a resposta

No playground, apague as **descrições** das opções do `department` (só as chaves: `billing`, `technical`, `sales`) e dê Run. Depois, adicione uma opção falsa `"vip": "cliente premium"` e dê Run de novo.

Você deve ver: sem descrições, a distribuição fica mais "cega" (menos estável); com a opção nova, as barras se redistribuem.

**Repare:** as descrições do `criteria` são o cardápio do modelo — elas carregam o significado. Prompt engineering aqui = escrever boas descrições de opção.

### Passo 6 — Números por âncoras

No playground, aba **JSON**, cole e rode:

```json
{
  "state": {"percent_value": 75, "unit": "%"},
  "questions": {
    "fill": {
      "type": "numeric", "unit": "percent",
      "instructions": "Read the reported fill percentage.",
      "anchors": [
        {"value": 0, "description": "Empty"},
        {"value": 50, "description": "Half"},
        {"value": 75, "description": "Three quarters"},
        {"value": 100, "description": "Completely full"}
      ]
    }
  }
}
```

Você deve ver: `value ≈ 75`, com a massa de probabilidade concentrada em "Three quarters" + campos de dispersão. Agora troque `"percent_value": 75` por `130` e rode de novo.

Você deve ver: o resultado vem como `__above_range__` (fora da régua), com `status` explícito.

**Repare:** o número não é "lido" — é a **média ponderada das âncoras**. E fora da régua o modelo **se recusa com status elegante** em vez de chutar.

### Passo 7 — Quando a confiança mente (Laya, CPU)

Na pasta `laya-cpu` (Opção B do Passo 1), crie `teste.py`:

```python
from laya import Router
router = Router(device='cpu')   # 1a execução baixa os pesos
q = {'churn': {'type': 'noul', 'instructions': 'Does the user threaten to cancel or leave?'}}
print("EN :", router.predict({'body': 'Please refund or we will cancel our plan.'}, q)['answers']['churn']['noul'])
print("PT :", router.predict({'body': 'Peço o reembolso hoje ou cancelarei nosso plano.'}, q)['answers']['churn']['noul'])
```

Rode com `OMP_NUM_THREADS=16 .venv/bin/python teste.py`. Você deve ver:

```
EN : 0.886
PT : 0.029
```

**Repare:** mesma pergunta, mesmo sentido — em inglês ele acerta; em português ele erra **com toda a confiança** (0,029 é quase "tenho certeza que NÃO"). É o momento-chave do tutorial: confiança só vale quando calibrada nos SEUS dados. (Antes de produção: teste nos seus textos, use o checkpoint certo, calibre ou faça fine-tune.)

### Passo 8 — Velocidade que se vê

Abra **http://127.0.0.1:8017/snake** (só Opção A). Cada movimento da cobrinha = **1 decisão do modelo**, com as probabilidades de cada direção legal na tela. Jogue uma rodada.

**Repare:** um LLM escrevendo "minha estratégia é..." gastaria segundos por movimento; aqui a decisão vem em milissegundos, sem gerar token. É o custo da automação caindo ordens de grandeza (a TypeSafe chama isso de paradoxo de Jevons: barateando a inteligência, a demanda explode).

### Passo 9 — Monte seu próprio benchmark

Pegue **5 textos seus** (mensagens, e-mails, notas) e um JSON como este — troque `state` e as `options` pelo seu caso:

```json
{
  "state": "<cole aqui o texto 1>",
  "options": {
    "<categoria_1>": "<descreva o que entra aqui>",
    "<categoria_2>": "<descreva o que entra aqui>",
    "_vazia": "nenhuma das opções se encaixa"
  }
}
```

Rode cada um pelo `curl` do Passo 4 (ou `./try-rizzo.sh`, `./try-laya.py` — scripts prontos no repositório) e anote: acertou? Em qual ficou com confiança baixa? Onde errou **confiante**?

**Repare:** comparar com o seu palpite humano é o que transforma "bonitinho" em confiável. Benchmark de terceiro é mapa; o seu domínio é o terreno.

---

## 6. Ficha de resumo (para levar no bolso)

- **O que é:** `state` (texto/JSON) + perguntas tipadas = respostas tipadas com probabilidades. Sem gerar texto ⇒ sem alucinar frase e sem JSON inválido (o type-safety é inerente ao design).
- **Quando usar:** automação rápida e em massa (triagem, roteamento, guardrails, extração de campo). **Não** use para escrever texto — isso é do LLM.
- **Variáveis-chave:** `state` · `questions{type, instructions, criteria}` · `noul = P(sim)` · `choice → probabilities + confidence` · `score → legend + média` · `numeric → anchors` (valores representativos, NÃO intervalos de confiança).
- **Armadilhas práticas:** opções mal descritas; pergunta sem contexto suficiente; idioma (testar em PT!); confiança crua precisa calibração.
- **O que você experimentou hoje:** Rizzo Flow 4B (GPU, Q8_0, API idêntica à do Jev) e Laya (CPU, multilíngue) — os dois open-weights.

## 7. Para onde ir depois

- O experimento em nuvem (um motor Laya dentro de uma AWS Lambda, com matriz de memória medida) está documentado em **`LAMBDA-LAYA.md`** e no **`lambda/README.md`** — inclui o que deu errado em cada tentativa, para você não perder o mesmo tempo.
- Os números medidos e as armadilhas de plataforma (Linux/Mac/Windows) estão em **`AGENTS.md`**.

Boa jornada! 🐍
