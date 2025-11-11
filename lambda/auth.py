import json
import os
import time
import hmac
import hashlib
import base64
from datetime import datetime, timedelta, timezone
import urllib.request
import urllib.error


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode('ascii')


def _sign(header: dict, payload: dict, secret: str) -> str:
    header_b64 = _b64url(json.dumps(header, separators=(',', ':'), ensure_ascii=False).encode('utf-8'))
    payload_b64 = _b64url(json.dumps(payload, separators=(',', ':'), ensure_ascii=False).encode('utf-8'))
    signing_input = f"{header_b64}.{payload_b64}".encode('ascii')
    sig = hmac.new(secret.encode('utf-8'), signing_input, hashlib.sha256).digest()
    return f"{header_b64}.{payload_b64}.{_b64url(sig)}"


def refresh(event, context):
    now = int(time.time())
    exp = now + 15 * 60  # 15分
    # 入力ボディ（originalTransactionId 任意）
    body = {}
    try:
        raw = event.get('body') or '{}'
        if event.get('isBase64Encoded'):
            raw = base64.b64decode(raw).decode('utf-8')
        body = json.loads(raw)
    except Exception:
        body = {}
    header = {"alg": "HS256", "typ": "JWT"}
    # デフォルトではスコープなし（非プレミアム）。
    # 環境変数 BYPASS_PREMIUM が真なら常に ai:chat を付与（暫定運用用）。
    scopes: list[str] = []
    bypass = str(os.environ.get('BYPASS_PREMIUM', '')).lower() in ("1", "true", "yes", "on")
    if bypass:
        scopes = ["ai:chat"]
        rid = getattr(context, 'aws_request_id', None)
        print(f"[authRefresh] premium_bypass_enabled: granting ai:chat to all reqId={rid}")
    else:
        original_tx = body.get('originalTransactionId')
        if original_tx and _verify_premium_with_apple(original_tx):
            scopes = ["ai:chat"]
    payload = {
        "iat": now,
        "exp": exp,
        "scope": scopes,
        "sub": "anonymous"
    }

    secret = os.environ.get('JWT_SECRET')
    if not secret:
        rid = getattr(context, 'aws_request_id', None)
        print(f"[authRefresh] server_misconfigured: missing JWT_SECRET reqId={rid}")
        return {
            "statusCode": 500,
            "headers": {"content-type": "application/json"},
            "body": json.dumps({"error": "server_misconfigured", "requestId": rid})
        }

    token = _sign(header, payload, secret)
    rid = getattr(context, 'aws_request_id', None)
    headers = {"content-type": "application/json"}
    # 呼び出し先識別のためのヘッダ（デバッグ用）
    if os.environ.get('SVC_NAME'):
        headers['x-svc-name'] = os.environ['SVC_NAME']
    if os.environ.get('SVC_STAGE'):
        headers['x-svc-stage'] = os.environ['SVC_STAGE']
    headers['x-func-name'] = os.environ.get('AWS_LAMBDA_FUNCTION_NAME', 'unknown')
    if rid:
        headers["x-request-id"] = rid
    return {
        "statusCode": 200,
        "headers": headers,
        "body": json.dumps({"token": token, "expiresAt": exp, "requestId": rid})
    }

# Serverlessのハンドラー指定が handlers/auth.refresh の場合は不要だが、
# lambda_handler を使う設定の場合に備えてエイリアスを提供
lambda_handler = refresh


def _verify_premium_with_apple(original_transaction_id: str) -> bool:
    """App Store Server API を使ってサブスク権利を検証。
    環境変数が未設定の場合やエラー時は False を返す。
    判定は Subscription Status の status 値が "有効/猶予/請求再試行" 等のとき True。
    """
    issuer = os.environ.get('APPSTORE_ISSUER_ID')
    key_id = os.environ.get('APPSTORE_KEY_ID')
    priv_b64 = os.environ.get('APPSTORE_PRIVATE_KEY_B64')
    env = (os.environ.get('APPSTORE_ENV') or 'Production').lower()
    if not issuer or not key_id or not priv_b64:
        return False
    try:
        private_key_pem = base64.b64decode(priv_b64).decode('utf-8')
        token = _asc_jwt(issuer, key_id, private_key_pem)
        base_url = 'https://api.storekit.itunes.apple.com' if env.startswith('prod') else 'https://api.storekit-sandbox.itunes.apple.com'
        url = f"{base_url}/inApps/v1/subscriptions/{original_transaction_id}"
        req = urllib.request.Request(url, headers={'Authorization': f'Bearer {token}', 'Accept': 'application/json'}, method='GET')
        with urllib.request.urlopen(req, timeout=6) as r:
            if r.getcode() != 200:
                return False
            data = json.loads(r.read().decode('utf-8'))
        # 簡易判定: いずれかのサブスク状態グループで lastTransactions の status がアクティブ系なら True
        # Appleの定義: 1=ACTIVE, 2=EXPIRED, 3=IN_GRACE_PERIOD, 4=IN_BILLING_RETRY, 5=REVOKED
        active_like = {1, 3, 4}
        for grp in data.get('data', []):
            for lt in grp.get('lastTransactions', []):
                if int(lt.get('status', 0)) in active_like:
                    return True
        return False
    except Exception:
        return False


def _asc_jwt(issuer: str, key_id: str, private_key_pem: str) -> str:
    # 外部依存（PyJWT）が無い場合は検証不可
    try:
        import jwt  # type: ignore
    except Exception:
        raise RuntimeError('PyJWT not available')
    now = datetime.now(tz=timezone.utc)
    payload = {
        'iss': issuer,
        'iat': int(now.timestamp()),
        'exp': int((now + timedelta(minutes=5)).timestamp()),
        'aud': 'appstoreconnect-v1'
    }
    headers = {'kid': key_id, 'alg': 'ES256', 'typ': 'JWT'}
    return jwt.encode(payload, private_key_pem, algorithm='ES256', headers=headers)