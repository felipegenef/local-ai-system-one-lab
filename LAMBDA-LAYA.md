# LAMBDA-LAYA — plan: a System One engine inside an AWS Lambda

> **STATUS: EXECUTED (Oct 17, 2026) and cleaned up** — route A deployed, measured, and torn down (stack/log group/ECR images removed; recurring cost zero). The original plan text follows, with the measured results baked in.

## Goal

One Lambda with a **Laya engine inside** serving typed decisions over HTTP — the smallest possible "System One as a Service", ~US$ 0–2/month for study usage.

## What the research confirmed (Oct 2026)

- **Lambda Web Functions** (announced Oct 2026) = the "new web Lambda": your code **listens on a port like a plain HTTP server** (Express, FastAPI, Hono), no adapter, built-in Function URL, pay-per-active-CPU. Made exactly for "AI inference endpoints".
- Web Function quotas: **2 fixed vCPUs per environment**, 512 MB package (unzipped), 512 MB `/tmp`.
- **Classic** Lambda with container: image up to **10 GB**, memory up to **10,240 MB** (≈ 6 vCPU), 15 min timeout. **Lambda Web Adapter** (LWA) runs any HTTP app inside it.
- Laya: English checkpoint **~808 MB (fp32)**; `laya[onnx]` exists (ONNX Runtime) → int8 estimate **~200 MB** (needs measuring).

## The 3 routes

| Route | How | Pro | Con | Verdict |
|---|---|---|---|---|
| **A. Classic Lambda + container + LWA** ⭐ executed | DockerImageFunction (CDK) running `laya-serve`; checkpoint **baked into the image** (fits the 10 GB); 10 GB memory ≈ 6 vCPU | simple CDK; no size surprises; same API as local | **cold start 97 s at 10 GB** (torch import + 1.5 GB checkpoint load) | **recommended for the experiment** — done |
| B. Lambda **Web Function** + `laya[onnx]` | the new primitive, minimal code | active-CPU pricing (cheap for sporadic use); no adapter | 512 MB package (torch doesn't fit; needs the ONNX int8 path); 2 vCPU → ~200–500 ms/decision | experimental: measure the ONNX weight first |
| C. Fargate/EC2 always-on | 0.5 vCPU resident | no cold start; always warm | ~US$ 5–12/month | if you want "always up" |
| Bonus | **SnapStart for Python** | would kill route A's cold start (snapshot of the loaded state) | rejected on cost: cache ~US$ 20/month (5 GB, always published) vs ~US$ 0.014 saved per cold; break-even ≈ 1,500 restores/month | not used |

## Route A as built (CDK Node @ `lambda/`)

```
lambda/
├── cdk/                # plain-JS CDK app: DockerImageFunction + FunctionUrl
│   ├── app.js          # memory via --context memory=NNNN; LAYA_MODELS via --context models=...
│   └── stack.js
├── docker/Dockerfile   # python:3.12-slim + laya[serve] + LWA 1.1.0 + checkpoint baked at build
├── bench.sh            # measures cold (1st call) + warm (3×) against the Function URL
└── README.md           # runbook + measured results
```

```ts
// cdk/stack.js (essence)
const fn = new lambda.DockerImageFunction(this, 'LayaFn', {
  code: lambda.DockerImageCode.fromImageAsset('../docker'),
  memorySize: 10240,
  timeout: cdk.Duration.minutes(5),
});
fn.addFunctionUrl({ authType: lambda.FunctionUrlAuthType.NONE }); // study only; swap for IAM/auth in production
```

```dockerfile
# docker/Dockerfile (essence) — LWA v1.x ships the RIC, so the base can be non-AWS
FROM public.ecr.aws/docker/library/python:3.12-slim
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:1.1.0 /lambda-adapter /opt/extensions/lambda-adapter
ENV HF_HOME=/opt/hf HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1
RUN pip install --no-cache-dir "laya[serve]"
RUN HF_HUB_OFFLINE=0 TRANSFORMERS_OFFLINE=0 python -c "from huggingface_hub import snapshot_download; snapshot_download('convaiinnovations/laya', ignore_patterns=['typed-decisions/*'])"
ENV PORT=8000 LAYA_HOST=0.0.0.0 LAYA_MODELS=english,multilingual
CMD exec laya-serve
```

Deploy: `cdk bootstrap` (once) → `cdk deploy --context memory=10240` → bench against the printed Function URL.

## Measured results (Oct 17, 2026, us-east-1, x86)

| Config | Cold (1st call) | Warm |
|---|---|---|
| 3 GB (english) | ❌ **Runtime.OutOfMemory** | ❌ |
| 5 GB (EN+PT) | 252 s | 0.58–0.62 s |
| **10 GB (EN+PT)** ⭐ | **97 s** | **0.52–0.53 s** |

- **RAM working set: 5.5 GB** (read from CloudWatch) — that is the true floor; 5 GB runs at the edge.
- Cold = torch import (~20–40 s) + load of the two checkpoints (~1.5 GB); the load scales with vCPU, the import barely does.
- **Answers identical to local** (same weights): the PT mistake (Zaffari → `saude` 0.71) repeats on the cloud. Cloud changes latency, not quality — fine-tuning/calibration does.
- **Total experiment cost: ~US$ 0.12.** Idle = $0. Deploy/runbook details in `lambda/README.md`.

## Route A debugging record (so nobody burns the same time)

1. `COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.8.4 /lambda-entrypoint.sh` → **not found**: the image ships `/lambda-adapter`; v1.1.0 pattern is `/opt/extensions/lambda-adapter` and it carries its own RIC.
2. `Runtime.MalformedHandlerName` on the AWS python base: the base image's entrypoint parses CMD as `module.function` — switch to a **non-AWS base** (LWA 1.x ships the RIC) and `CMD exec laya-serve`.
3. `Read-only file system: '/home/sbx_user1051'`: the runtime's HOME is read-only → **HF_HOME must point into the image** (`/opt/hf`), and turn `HF_HUB_OFFLINE=1` on at runtime — but OFFLINE **off during the build step** that fills the cache (chicken-and-egg).
4. `Subfolder 'multilingual' not found`: current laya uses **one repo with subfolders**; bake with `snapshot_download(..., ignore_patterns=['typed-decisions/*'])` and pin `LAYA_MODELS=english,multilingual`.

## When NOT to use Lambda (honesty)

- **Always-on and < 100 ms**: Fargate/EC2 or a cheap VPS — a 97 s cold start kills interactive UX.
- A growing model (Rizzo 4B, Kev): the Lambda becomes only the *proxy*; the engine lives on EC2/GPU or on TypeSafe's service.
