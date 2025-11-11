# 症状メモ（Symptom Notes）

シンプルに「毎日テキストで症状を記録」し、AI による健康アドバイスを受けられる iOS アプリです。見た目と使い心地にこだわり、ハプティクスや控えめなサウンド演出を入れています。

このリポジトリには Xcode でそのまま使える SwiftUI コード一式（SwiftDataベース）が入っています。Windows 上ではビルドできないため、後述の手順で Mac の Xcode に取り込んでください。

## スクリーンショット

<div align="center">
  <img src="screenshots/screenshot1.png" width="200" alt="メイン画面">
  <img src="screenshots/screenshot2.png" width="200" alt="メモ編集画面">
  <img src="screenshots/screenshot3.png" width="200" alt="AI アドバイス画面">
  <img src="screenshots/screenshot4.png" width="200" alt="設定画面">
  <img src="screenshots/screenshot5.png" width="200" alt="PDF 共有画面">
</div>

## デモ動画

<div align="center">
  <video width="300" controls>
    <source src="demo/demo.mp4" type="video/mp4">
    <a href="demo/demo.mp4">デモ動画を見る</a>
  </video>
</div>

*画像と動画は `screenshots/` および `demo/` フォルダに配置してください。*

## 主要機能

### 基本機能
- 毎日のメモ（1日1件を想定。既存があれば編集）
- 重症度スライダー（0-10）と服薬記録
- 美しいグラデーション背景とカードUI
- ハプティクス（成功/失敗/軽いタップ）
- 控えめなシステムサウンド（トック音）
- すべてローカル保存（SwiftData）

### AI 機能（プレミアム）
- OpenAI API（GPT-4o-mini など）による症状分析とアドバイス
- 単一エントリーまたは複数エントリーの一括分析
- カスタマイズ可能なトーン（丁寧/簡潔/医療者向け）
- 短文サマリー機能（箇条書き）
- モデル選択とシステムプロンプトのカスタマイズ
- API キーは AWS Lambda で安全に管理（クライアントに露出しない設計）

### プレミアム機能
- AI アドバイス機能（要 API キー）
- PDF エクスポート機能
- トライアル期間後はサブスクリプション購入が必要

### 設定
- ハプティクス/サウンド ON/OFF
- アクセントカラー選択
- OpenAI API キーの安全な保存（Keychain）
- AI モデルとプロンプトのカスタマイズ

## 対応環境
- iOS 17 以降（SwiftData を使用）
- Xcode 15 以降を推奨
- AWS Lambda（OpenAI API キー管理用）

## プロジェクト構造
```
symptomemo/
├── symptomemo/              # メインソースコード
│   ├── symptomemoApp.swift  # アプリエントリーポイント
│   ├── Models.swift         # データモデル（SwiftData）
│   ├── ContentView.swift    # メインリスト画面
│   ├── EditorView.swift     # メモ編集画面
│   ├── AIAdviceView.swift   # AI アドバイス画面
│   ├── AIService.swift      # OpenAI API 連携
│   ├── PurchaseManager.swift # サブスクリプション管理
│   ├── SettingsView.swift   # 設定画面
│   ├── PDFBuilder.swift     # PDF 生成機能
│   └── その他のユーティリティ
├── symptomemoTests/         # ユニットテスト
├── symptomemoUITests/       # UIテスト
└── backup/ios/              # 旧バージョンのバックアップ
```

## 取り込み手順（Mac + Xcode）

### 新規プロジェクトとして開く場合
1. このフォルダを Git でクローンまたは ZIP で取得し、Mac にコピーします。
2. Xcode で `symptomemo.xcodeproj` を開きます。
3. ターゲットが iOS 17+ になっていることを確認。
4. Signing & Capabilities でチーム（Apple ID）を選択。
5. ビルド＆実行（⌘+R）。

### 既存プロジェクトに統合する場合
1. Xcode で既存プロジェクトを開きます。
2. `symptomemo/` フォルダ内のファイルを Xcode ナビゲータにドラッグ&ドロップ（"Copy items if needed" にチェック）。
3. iOS 17+ ターゲットに設定。
4. ビルド＆実行（⌘+R）。

**補足**: 
- 初回は Signing & Capabilities のチーム選択が必要です。
- AI 機能を使用するには AWS Lambda の設定が必要です（後述）。
- プレミアム機能を有効にするには、App Store Connect でサブスクリプション製品を設定してください。

## AWS Lambda の設定（AI 機能用）

AI 機能では、OpenAI API キーをクライアントアプリに埋め込まず、AWS Lambda 経由で安全に管理します。

### Lambda 関数の作成手順
1. AWS コンソールで Lambda 関数を新規作成（Node.js または Python）
2. 環境変数に OpenAI API キーを設定
3. API Gateway をトリガーとして設定し、REST API エンドポイントを作成
4. Lambda 関数内で以下の処理を実装：
   - クライアントからのリクエストを受信
   - OpenAI API を呼び出し
   - レスポンスをクライアントに返却

### Lambda 関数の例（Node.js）
```javascript
const https = require('https');

exports.handler = async (event) => {
    const apiKey = process.env.OPENAI_API_KEY;
    const body = JSON.parse(event.body);
    
    const options = {
        hostname: 'api.openai.com',
        path: '/v1/chat/completions',
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${apiKey}`
        }
    };
    
    // OpenAI API 呼び出しロジック
    // ...
    
    return {
        statusCode: 200,
        body: JSON.stringify(response)
    };
};
```

### アプリ側の設定
1. `AIService.swift` の API エンドポイントを Lambda の API Gateway URL に変更
2. Authorization ヘッダーの代わりに Lambda 経由でリクエスト
3. 必要に応じて API Gateway で認証を設定（IAM、Cognito など）

### セキュリティのベストプラクティス
- Lambda 環境変数は AWS Systems Manager Parameter Store または Secrets Manager で管理
- API Gateway でレート制限を設定
- CORS 設定でアプリのドメインのみ許可
- CloudWatch Logs で監視とログ記録

## アプリの使い方

### 基本操作
- 右上の + ボタンで「今日のメモ」を作成/編集
- リストから日付をタップして過去メモを編集
- スライダーで重症度（0-10）を設定
- 服薬内容を記録可能
- 重要なメモにはスターマークを付けられます

### AI アドバイス機能（プレミアム）
1. AWS Lambda が設定済みであることを確認
2. メモ詳細画面またはメインリストから AI アドバイスを取得
3. 単一のメモまたは複数のメモを選択して分析可能
4. トーン（丁寧/簡潔/医療者向け）を選択可能
5. 短文サマリーまたは詳細アドバイスを選択

### 設定
- 左上の歯車アイコンから設定を開く
- ハプティクス・サウンドの ON/OFF 切替
- アクセントカラーの変更
- AI モデルとシステムプロンプトのカスタマイズ
- プレミアム機能の購入・復元

## デザインメモ
- メインカラーはベージュ基調（落ち着き・温かみ）
- カードは .ultraThinMaterial + 角丸 + やわらかい影で上質感
- 背景はベージュの柔らかいグラデーション（軽量）
- 文字はSF Proのダイナミックタイプに準拠、可読性優先

## 公開（App Store）までの流れ 概要

### 準備
1. Apple Developer Program 登録（有料：年間 $99）
2. アプリアイコン・スクショ・プライバシーポリシー準備
3. バージョン/ビルド番号設定

### App Store Connect での設定
1. アプリ情報の登録（名前、説明、カテゴリなど）
2. サブスクリプション製品の作成
   - プロダクト ID: `symptomemo.premium`（または任意の ID）
   - `PurchaseManager.swift` 内の `premiumProductId` を更新
3. スクリーンショットとプレビューのアップロード
   - `screenshots/` フォルダ内の画像を使用
   - `demo/` フォルダ内の動画をアプリプレビューとして使用
4. プライバシー情報の入力

### ビルドとアップロード
1. Xcode でアプリアーカイブ（Product > Archive）
2. Xcode Organizer から TestFlight へアップロード
3. App Store Connect で審査提出

### 注意事項
- AI 機能は AWS Lambda 経由で OpenAI API を使用します
- Lambda 関数と API Gateway の設定が必要です（詳細は「AWS Lambda の設定」セクション参照）
- プライバシーポリシーに OpenAI API の使用を明記してください
- Lambda の利用料金と OpenAI API の利用料金が発生します

## 次の拡張候補
- ✅ AI による症状分析（実装済み）
- ✅ PDF エクスポート機能（実装済み）
- ✅ プレミアム機能とサブスクリプション（実装済み）
- メモの検索・タグ機能
- カレンダービュー（月カレンダーから日付選択）
- グラフ表示（重症度の推移など）
- ウィジェット/ロック画面コンプリケーション
- iCloud 同期（CloudKit + SwiftData）
- 医師モード機能の強化
- AI による傾向分析とインサイト

## セキュリティとプライバシー
- すべてのデータはローカルに保存（SwiftData）
- OpenAI API キーは AWS Lambda の環境変数で管理（クライアントには露出しません）
- AI 分析は AWS Lambda → OpenAI API 経由で行われます
- アプリからユーザーの健康データを直接外部サーバーに送信することはありません
- Lambda 関数のログは AWS CloudWatch で管理されます

## 技術スタック
- **フレームワーク**: SwiftUI
- **データ永続化**: SwiftData（iOS 17+）
- **セキュア保存**: Keychain Services
- **課金**: StoreKit 2
- **AI バックエンド**: AWS Lambda + API Gateway
- **AI 連携**: OpenAI Chat Completions API
- **PDF 生成**: PDFKit

## テスト
```bash
# ユニットテストの実行
xcodebuild test -scheme symptomemo -destination 'platform=iOS Simulator,name=iPhone 15'

# または Xcode で ⌘+U
```

主要なテストファイル:
- `AIServiceTests.swift` - AI サービスのロジックテスト
- `PDFBuilderTests.swift` - PDF 生成のテスト
- `ModelsMigrationTests.swift` - データモデルのマイグレーションテスト

## ブランド化（アイコン/配色）提案メモ
- アイコンモチーフ: ハート×メモ帳、やわらかいトーン（温かみ）
- ベースカラー: ベージュ系（#C19A6B を基調、補助に #EED9C4 / #A67B5B）
- アクセントに穏やかなグリーンやコーラルを少量使用
- ライト/ダーク両対応でコントラストと可読性を優先

## ライセンス
このプロジェクトのライセンスについては [LICENSE](LICENSE) ファイルを参照してください。

## サポート
- バグ報告や機能要望は GitHub Issues へ
- プライバシーポリシーや利用規約については、App Store 掲載時に別途用意

---
**注意**: このアプリは医療診断を行うものではありません。症状が深刻な場合や緊急時は、必ず医療機関を受診してください。
