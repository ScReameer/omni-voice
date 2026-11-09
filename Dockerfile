FROM vllm/vllm-omni:v0.32.0

# Runpod's cached Hugging Face models are mounted under this directory.
ENV HF_HOME=/runpod-volume/huggingface-cache \
    HF_HUB_CACHE=/runpod-volume/huggingface-cache/hub \
    PORT=8000 \
    PORT_HEALTH=8000

EXPOSE 8000

CMD ["bash", "-lc", "exec vllm serve Qwen/Qwen3-Omni-30B-A3B-Instruct --omni --host 0.0.0.0 --port \"${PORT}\""]
