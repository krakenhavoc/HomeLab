# ReazonSpeech k2 v2 (Japanese, int8) for wkjp's reading answers; see server.py.
# Built on the VM by wkjp-sync (docker compose up --build).
FROM python:3.12-slim

RUN pip install --no-cache-dir sherpa-onnx==2.0.1 av==19.0.2 numpy==2.5.4 huggingface_hub==2.4.0

# int8 files only (~160 MB), pinned to a revision
ARG MODEL_REPO=reazon-research/reazonspeech-k2-v2
ARG MODEL_REV=291488c8151be24d7da4bf7af26e533fad96e407
RUN python -c "from huggingface_hub import hf_hub_download as d; \
[d('${MODEL_REPO}', f, revision='${MODEL_REV}', local_dir='/models') for f in \
('encoder-epoch-99-avg-1.int8.onnx', 'decoder-epoch-99-avg-1.int8.onnx', 'joiner-epoch-99-avg-1.int8.onnx', 'tokens.txt')]" \
    && rm -rf /models/.cache /root/.cache

COPY server.py /app/server.py
USER nobody
EXPOSE 8000
HEALTHCHECK --interval=60s --timeout=5s CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=4)"
CMD ["python", "/app/server.py"]
