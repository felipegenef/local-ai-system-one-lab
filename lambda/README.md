# lambda/ — Laya inside an AWS Lambda (memory × latency experiment)

> Original plan: `../LAMBDA-LAYA.md` (route A). This folder holds the code that **runs** the experiment.

## What is here

```
lambda/
├── docker/Dockerfile   # python:3.12-slim + laya[serve] + checkpoint baked + Lambda Web Adapter
├── cdk/                # plain-JS CDK app (no TypeScript): DockerImageFunction + Function URL
│   ├── app.js          # memory via --context memory=NNNN (default 10240; models via --context models=...)
│   └── stack.js
└── bench.sh            # measures cold (1st call) and warm (3×) against the Function URL
```

## Why these choices (honest)

- **Not Alpine, not scratch**: torch publishes no musl/Alpine wheels — the *real* minimum for the Laya engine is `python:3.12-slim` (slim Debian). The truly tiny container path is `laya[onnx]` with no torch (route B in the plan).
- **No Node proxy**: the Lambda Web Adapter **already is** the official HTTP↔Lambda proxy; `laya-serve` listens on port 8000 and the adapter bridges it. (If someone ever wants Express in front, that is one more `CMD` line.)
- **Checkpoint baked at build time** (`snapshot_download` during `docker build`): the Lambda cold start cannot afford a download. Current laya uses **one repo with subfolders** — we bake everything except the `typed-decisions/` specialist and pin `LAYA_MODELS=english,multilingual`.
- **Memory = CPU** on Lambda (1 vCPU ≈ 1.77 GB): the matrix tests whether 5 GB is enough or whether 10 GB wins.

## Measured results (Oct 17, 2026, us-east-1, x86)

| Configuration | Cold (1st call) | Warm | Status |
|---|---|---|---|
| 3 GB (english) | ❌ **Runtime.OutOfMemory** | ❌ | does not run — real working set ≈ 5.5 GB |
| 5 GB (EN+PT) | 252 s | 0.58–0.62 s | ✅ runs (the plan's "5 GB is enough": on the edge) |
| **10 GB (EN+PT)** ⭐ | **97 s** | **0.52–0.53 s** | ✅ final configuration |

Honest notes:

- **Cold start = torch import (~20–40 s) + loading the two checkpoints (~1.5 GB) on the available vCPUs.** The load scales with CPU (6 vCPU ≈ 2.6× faster than 3 vCPU); the import barely does.
- **Answers identical to the local ones** (same weights): Laya's PT mistake (Zaffari → `health` 0.71) repeats on the cloud. The cloud does not fix quality — fine-tuning/calibration does.
- **Total experiment cost: ~US$ 0.12** (a cold is ≈ US$ 0.02 at 10 GB; warms are a fraction of a cent). Idle = $0.
- **For a live demo**: one warm-up call ~2 min before (≈ US$ 0.02) keeps the environment warm for hours.
- **SnapStart**: decision NO — the cache is ~US$ 20/month vs ~US$ 0.014 saved per cold (break-even ≈ 1,500 restores/month).
- **Sanitized for publishing on GitHub**: the committed files were grep-audited for account id / IAM user / ARNs / name — nothing personal is versioned (`rizzo-flow/`, `laya-cpu/`, `node_modules` and `.openchamber/` stay out via `.gitignore`). The stack was **destroyed** after the matrix (stack, log group and ECR images deleted → recurring cost zero).

## Running the experiment

```bash
# prerequisites: aws cli with credentials + docker running + node 20+
cd lambda/cdk && npm install
npx cdk bootstrap            # once per account/region
npx cdk deploy --context memory=10240   # first deploy: build image (~2-3 GB) + push to ECR (the slow step)
# the output prints the LayaUrl; then:
cd .. && ./bench.sh 'https://<id>.lambda-url.us-east-1.on.aws/'
```

Memory matrix (redeploys are fast — the image is already in ECR):

```bash
npx cdk deploy --context memory=3072 --context models=english   # floor test → OOM expected
npx cdk deploy --context memory=5120                            # on the edge
npx cdk deploy --context memory=10240                           # final config
```

## Debugging record (so nobody burns the same time)

1. `COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.8.4 /lambda-entrypoint.sh` → **not found**: that image ships `/lambda-adapter`; the v1.1.0 pattern is `COPY --from=...:1.1.0 /lambda-adapter /opt/extensions/lambda-adapter` (it carries its own RIC).
2. `Runtime.MalformedHandlerName` on the AWS python base image: its entrypoint parses CMD as `module.function` — switch to a **non-AWS base** and shell-form `CMD exec laya-serve`.
3. `Read-only file system: '/home/sbx_user1051'`: the Lambda runtime HOME is read-only → bake the HF cache into the image (`HF_HOME=/opt/hf`) and set `HF_HUB_OFFLINE=1` **at runtime**, turning it OFF only in the build step that fills the cache (chicken-and-egg).
4. `Subfolder 'multilingual' not found`: current laya ships **one repo with subfolders**; bake with `snapshot_download(..., ignore_patterns=['typed-decisions/*'])` and control preloading per deploy via `--context models=...` (no image rebuild needed).

## Teardown (so nothing keeps burning)

```bash
cd cdk && npx cdk destroy --force
aws logs delete-log-group --log-group-name "/aws/lambda/<FunctionName>"
aws ecr batch-delete-image --repository-name <asset-repo> --image-ids imageDigest=<digest>   # repeat for each digest
```
