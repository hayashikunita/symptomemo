import json, os, time, hmac, hashlib, base64, urllib.request, urllib.error, random

MAX_MESSAGES = int(os.environ.get('MAX_MESSAGES', '50'))
MAX_MESSAGE_CHARS = int(os.environ.get('MAX_MESSAGE_CHARS', '4000'))
DEFAULT_MAX_TOKENS = int(os.environ.get('DEFAULT_MAX_TOKENS', '400'))
MAX_PAYLOAD_BYTES = int(os.environ.get('MAX_PAYLOAD_BYTES', '200000'))

def _b64url_decode(s: str) -> bytes:
    pad = '=' * (-len(s) % 4)
    return base64.urlsafe_b64decode(s + pad)

def _verify_jwt(token: str, secret: str):
    try:
        header_b64, payload_b64, sig_b64 = token.split('.')
        header = json.loads(_b64url_decode(header_b64))
        if header.get('alg') != 'HS256':
            return None
        signing_input = f"{header_b64}.{payload_b64}".encode('ascii')
        expected = hmac.new(secret.encode('utf-8'), signing_input, hashlib.sha256).digest()
        if not hmac.compare_digest(expected, _b64url_decode(sig_b64)):
            return None
        payload = json.loads(_b64url_decode(payload_b64))
        now = int(time.time())
        if int(payload.get('exp', 0)) < now:
            return None
        # iatが未来過ぎる（時計ずれ > 120秒）場合は拒否
        if int(payload.get('iat', now)) - now > 120:
            return None
        return payload
    except Exception:
        return None

def _bad(status: int, code: str, msg: str, request_id: str | None = None):
    body = {"error": code, "message": msg}
    headers = {"content-type": "application/json"}
    # 呼び出し先識別のためのヘッダ（デバッグ用）
    if os.environ.get('SVC_NAME'):
        headers['x-svc-name'] = os.environ['SVC_NAME']
    if os.environ.get('SVC_STAGE'):
        headers['x-svc-stage'] = os.environ['SVC_STAGE']
    headers['x-func-name'] = os.environ.get('AWS_LAMBDA_FUNCTION_NAME', 'unknown')
    if request_id:
        body["requestId"] = request_id
        headers["x-request-id"] = request_id
    return {"statusCode": status, "headers": headers, "body": json.dumps(body)}

def _openai_request(api_key: str, payload: bytes, timeout: int = 20, max_retries: int = 3):
    url = 'https://api.openai.com/v1/chat/completions'
    headers = {
        'Authorization': f'Bearer {api_key}',
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
    attempt = 0
    while True:
        req = urllib.request.Request(url, data=payload, headers=headers, method='POST')
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.getcode(), r.read().decode('utf-8')
        except urllib.error.HTTPError as e:
            code = getattr(e, 'code', 0)
            body = None
            try:
                body = e.read().decode('utf-8')
            except Exception:
                body = json.dumps({"error": "upstream_http_error", "status": code})
            # 429/5xx はリトライ、それ以外は打ち切り
            if code in (429, 500, 502, 503, 504) and attempt < max_retries:
                delay = min(2 ** attempt * 0.4 + random.random() * 0.2, 5.0)
                time.sleep(delay)
                attempt += 1
                continue
            return code or 502, body
        except urllib.error.URLError as e:
            if attempt < max_retries:
                delay = min(2 ** attempt * 0.4 + random.random() * 0.2, 5.0)
                time.sleep(delay)
                attempt += 1
                continue
            return 502, json.dumps({"error": "upstream_error", "message": str(e)})

def chat(event, context):
    secret = os.environ.get('JWT_SECRET')
    if not secret:
        rid = getattr(context, 'aws_request_id', None)
        print(f"[aiChat] server_misconfigured: missing JWT_SECRET reqId={rid}")
        return _bad(500, "server_misconfigured", "missing JWT_SECRET", rid)

    headers = {k.lower(): v for k, v in (event.get('headers') or {}).items()}
    auth = headers.get('authorization')
    if not auth or not auth.startswith('Bearer '):
        rid = getattr(context, 'aws_request_id', None)
        print(f"[aiChat] not_authenticated: missing bearer token reqId={rid}")
        return _bad(401, "not_authenticated", "Missing bearer token", rid)
    payload_claims = _verify_jwt(auth.split(' ', 1)[1], secret)
    if not payload_claims:
        rid = getattr(context, 'aws_request_id', None)
        print(f"[aiChat] not_authenticated: invalid/expired token reqId={rid}")
        return _bad(401, "not_authenticated", "Invalid or expired token", rid)
    # スコープ確認（存在する場合）
    scopes = payload_claims.get('scope') or payload_claims.get('scopes') or []
    if isinstance(scopes, str):
        scopes = [scopes]
    if scopes and 'ai:chat' not in scopes:
        rid = getattr(context, 'aws_request_id', None)
        print(f"[aiChat] forbidden: missing ai:chat scope reqId={rid}")
        return _bad(403, "forbidden", "Missing ai:chat scope", rid)

    try:
        body = event.get('body') or '{}'
        if event.get('isBase64Encoded'):
            body = base64.b64decode(body).decode('utf-8')
        req = json.loads(body)
    except Exception:
        rid = getattr(context, 'aws_request_id', None)
        print(f"[aiChat] bad_request: invalid json reqId={rid}")
        return _bad(400, "bad_request", "Invalid JSON", rid)

    model = (req.get('model') or '').strip() or 'gpt-4o-mini'
    allowed = [m.strip() for m in (os.environ.get('ALLOWED_MODELS') or '').split(',') if m.strip()]
    # 大文字小文字の差で弾かないように正規化
    lowered_allowed = [m.lower() for m in allowed]
    if allowed and model.lower() not in lowered_allowed:
        rid = getattr(context, 'aws_request_id', None)
        print(f"[aiChat] model_not_allowed: '{model}' not in {allowed} reqId={rid}")
        return _bad(400, "model_not_allowed", f"Model '{model}' is not allowed", rid)

    api_key = os.environ.get('OPENAI_API_KEY')
    if not api_key:
        rid = getattr(context, 'aws_request_id', None)
        print(f"[aiChat] server_misconfigured: missing OPENAI_API_KEY reqId={rid}")
        return _bad(500, "server_misconfigured", "missing OPENAI_API_KEY", rid)

    # ここまでで ai:chat スコープを担保

    # メッセージの正規化と制限
    raw_messages = req.get('messages') or []
    if not isinstance(raw_messages, list):
        rid = getattr(context, 'aws_request_id', None)
        print(f"[aiChat] bad_request: messages not list reqId={rid}")
        return _bad(400, "bad_request", "messages must be an array", rid)
    allowed_roles = {"system", "user", "assistant"}
    messages = []
    for m in raw_messages[:MAX_MESSAGES]:
        if not isinstance(m, dict):
            continue
        role = str(m.get('role', '')).lower()
        content = str(m.get('content', ''))
        if role not in allowed_roles:
            continue
        if not content:
            continue
        if len(content) > MAX_MESSAGE_CHARS:
            content = content[:MAX_MESSAGE_CHARS]
        messages.append({"role": role, "content": content})
    if not messages:
        rid = getattr(context, 'aws_request_id', None)
        print(f"[aiChat] bad_request: empty messages after sanitation reqId={rid}")
        return _bad(400, "bad_request", "messages is required", rid)

    max_tokens = req.get('max_tokens', DEFAULT_MAX_TOKENS)
    try:
        max_tokens = int(max_tokens)
    except Exception:
        max_tokens = DEFAULT_MAX_TOKENS
    if max_tokens < 50:
        max_tokens = 50
    if max_tokens > 2000:
        max_tokens = 2000

    # temperature の正規化（0.0〜2.0）
    temperature = req.get('temperature', 0.2)
    try:
        temperature = float(temperature)
    except Exception:
        temperature = 0.2
    if temperature < 0:
        temperature = 0.0
    if temperature > 2:
        temperature = 2.0

    body_obj = {
        "model": model,
        "messages": messages,
        "temperature": temperature,
        "max_tokens": max_tokens
    }
    payload = json.dumps(body_obj).encode('utf-8')

    # 事前にペイロードサイズをチェック（任意の上限: 200KB）
    if len(payload) > MAX_PAYLOAD_BYTES:
        rid = getattr(context, 'aws_request_id', None)
        print(f"[aiChat] payload_too_large: size={len(payload)} limit={MAX_PAYLOAD_BYTES} reqId={rid}")
        return _bad(413, "payload_too_large", "Request body too large", rid)

    # 残り実行時間に合わせてタイムアウトを調整（最低3秒、最大20秒）
    try:
        remaining_ms = int(context.get_remaining_time_in_millis())
    except Exception:
        remaining_ms = 30_000
    per_req_timeout = max(3, min(20, (remaining_ms - 1500) // 1000))
    status, resp_body = _openai_request(api_key, payload, timeout=per_req_timeout, max_retries=3)
    rid = getattr(context, 'aws_request_id', None)
    headers = {"content-type": "application/json"}
    if rid:
        headers["x-request-id"] = rid
    return {"statusCode": status, "headers": headers, "body": resp_body}

# Serverlessのハンドラー指定が handlers/ai.chat の場合は不要だが、
# lambda_handler を使う設定の場合に備えてエイリアスを提供
lambda_handler = chat