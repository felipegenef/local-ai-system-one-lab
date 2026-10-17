# Laya engine inside an AWS Lambda — minimal viable image
# python-slim (Debian) is the REAL minimum: torch publishes no musl/Alpine wheels.
# (The truly-scratch path is laya[onnx] with no torch — see LAMBDA-LAYA.md, route B.)
# Non-AWS base: LWA v1.x ships the Runtime Interface Client, so CMD is a plain command.
FROM public.ecr.aws/docker/library/python:3.12-slim

# Lambda Web Adapter v1.1.0 as an extension (the official HTTP<->Lambda bridge, zero code of ours)
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:1.1.0 /lambda-adapter /opt/extensions/lambda-adapter

# HF cache under /opt (readable at runtime; the Lambda $HOME is read-only!)
ENV HF_HOME=/opt/hf \
    HF_HUB_OFFLINE=1 \
    TRANSFORMERS_OFFLINE=1

RUN pip install --no-cache-dir "laya[serve]"

# Bake the checkpoints at BUILD time (into /opt/hf) — offline OFF only here, since the cache does not exist yet.
# laya's current repo uses SUBFOLDERS (multilingual/, typed-decisions/); bake everything but the typed-decisions specialist.
RUN HF_HUB_OFFLINE=0 TRANSFORMERS_OFFLINE=0 python -c "from huggingface_hub import snapshot_download; snapshot_download('convaiinnovations/laya', ignore_patterns=['typed-decisions/*'])"

# LWA forwards to laya-serve on port 8000
ENV PORT=8000 \
    LAYA_HOST=0.0.0.0 \
    LAYA_MODELS=english,multilingual \
    READINESS_CHECK_PORT=8000 \
    AWS_LWA_READINESS_CHECK_PORT=8000

CMD exec laya-serve
