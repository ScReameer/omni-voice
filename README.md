# Qwen3-Omni на Runpod

Минимальный запуск [Qwen3-Omni-30B-A3B-Instruct](https://huggingface.co/Qwen/Qwen3-Omni-30B-A3B-Instruct) через [официальный образ vLLM-Omni v0.32.0](https://docs.vllm.ai/projects/vllm-omni/en/v0.32.0/getting_started/installation/gpu/). Сервер vLLM-Omni сразу предоставляет OpenAI-совместимый HTTP API. Своего API-кода и Docker Compose здесь нет.

## Развёртывание из GitHub

1. Отправьте репозиторий на GitHub и подключите его в Runpod: **Settings → Connections → GitHub**.
2. В **Serverless → New Endpoint → GitHub** выберите репозиторий, ветку и `Dockerfile` в корне.
3. Тип endpoint: **Load Balancer**. Для Queue нужен отдельный handler, которого здесь нет.
4. Выберите **2 × H100 80 GB в одном worker**. [Штатный профиль модели](https://github.com/vllm-project/vllm-omni/blob/v0.32.0/vllm_omni/deploy/qwen3_omni_moe.yaml) размещает Thinker на GPU 0, Talker и Code2Wav на GPU 1. Этот вариант проверен авторами vLLM-Omni на двух H100.
5. В поле **Model** укажите `Qwen/Qwen3-Omni-30B-A3B-Instruct` для [кэширования модели Runpod](https://docs.runpod.io/serverless/endpoints/model-caching). Размер репозитория модели около **70,5 ГБ**. Не включайте веса в Docker-образ. `HF_TOKEN` добавьте только при необходимости доступа к Hugging Face.
6. Откройте **8000/http**. В настройках endpoint задайте `PORT=8000` и `PORT_HEALTH=8000`. Путь проверки здоровья оставьте стандартным (`/ping`), а команду запуска контейнера — из Dockerfile.
7. Запустите endpoint и дождитесь готовности worker. Первая загрузка образа и модели может занять несколько минут.

Runpod [собирает Dockerfile из GitHub](https://docs.runpod.io/serverless/workers/github-integration). Веса Runpod размещает в `/runpod-volume/huggingface-cache`; `HF_HOME` в образе указывает на этот кэш. [Проверка здоровья Load Balancer](https://docs.runpod.io/serverless/load-balancing/overview) обращается к штатному [vLLM `/ping`](https://github.com/vllm-project/vllm/blob/v0.32.0/vllm/entrypoints/serve/sagemaker/api_router.py) на порту 8000.

## Проверка API

Подставьте ID endpoint и API-ключ Runpod. Ключ не сохраняйте в репозитории.

```bash
export RUNPOD_API_KEY='...'
export BASE_URL='https://ENDPOINT_ID.api.runpod.ai'

curl -fsS "$BASE_URL/ping" -H "Authorization: Bearer $RUNPOD_API_KEY"
curl -fsS "$BASE_URL/v1/models" -H "Authorization: Bearer $RUNPOD_API_KEY"
```

Текстовый ответ:

```bash
curl -fsS "$BASE_URL/v1/chat/completions" \
  -H "Authorization: Bearer $RUNPOD_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "Qwen/Qwen3-Omni-30B-A3B-Instruct",
    "messages": [{"role": "user", "content": "Ответь одним предложением: что ты умеешь?"}],
    "modalities": ["text"],
    "max_tokens": 128
  }'
```

Распознавание и понимание речи из короткого WAV по URL:

```bash
curl -fsS "$BASE_URL/v1/chat/completions" \
  -H "Authorization: Bearer $RUNPOD_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "Qwen/Qwen3-Omni-30B-A3B-Instruct",
    "messages": [{"role": "user", "content": [
      {"type": "audio_url", "audio_url": {"url": "https://qianwen-res.oss-cn-beijing.aliyuncs.com/Qwen3-Omni/demo/cough.wav"}},
      {"type": "text", "text": "What do you hear?"}
    ]}],
    "modalities": ["text"]
  }'
```

Генерация речи (локально нужны `jq` и `base64`):

```bash
curl -fsS "$BASE_URL/v1/chat/completions" \
  -H "Authorization: Bearer $RUNPOD_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "Qwen/Qwen3-Omni-30B-A3B-Instruct",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "modalities": ["text", "audio"]
  }' | jq -r '.choices[1].message.audio.data' | base64 -d > output.wav
```

Примеры для [изображений, видео и потокового вывода](https://github.com/vllm-project/vllm-omni/blob/v0.32.0/examples/online_serving/qwen3_omni/README.md) есть у vLLM-Omni. У Runpod Load Balancer [лимит 30 МБ на запрос или ответ и 5,5 минуты на обработку](https://docs.runpod.io/serverless/load-balancing/overview), поэтому первые медиафайлы лучше брать короткие.

## Локальная машина

Здесь установлена **RTX 3080 Ti с 12 ГБ VRAM**. Полная модель BF16 локально не поместится: [Qwen указывает минимум 78,85 ГБ](https://huggingface.co/Qwen/Qwen3-Omni-30B-A3B-Instruct) даже для 15-секундного видео при запуске через Transformers, а профиль vLLM-Omni проверен на двух H100 80 GB. Локальная сборка Docker может проверить рецепт образа, но запуск этого полноразмерного профиля на данной видеокарте невозможен.
