# AgentCore Agent Template (JP)

[![CI](https://github.com/bolleta/agentcore-agent-template-jp/actions/workflows/ci.yml/badge.svg)](https://github.com/bolleta/agentcore-agent-template-jp/actions/workflows/ci.yml)

A deployable Terraform template for building agents on **Amazon Bedrock AgentCore**,
tuned for **ap-northeast-1 (Tokyo)** and Japanese-language workloads. Runtime, Memory,
Gateway (MCP), Identity and a Bedrock Knowledge Base come up with a single
`terraform apply`; `src/agent/agent_config.py` is the one file you edit to start a
new agent.

Amazon Bedrock AgentCore 上でエージェントを構築するための Terraform テンプレート。
東京リージョン・日本語ワークロード向けに調整済み。

---

## What I built

This project is derived from [aws-samples/sample-genai-strats](https://github.com/aws-samples/sample-genai-strats)
(MIT-0, © Amazon.com, Inc.), a collection of guided AWS workshops. I reworked two of
those workshops into templates that deploy as-is, and fixed the defects that surfaced
while doing it.

- **Turned a step-by-step workshop into a working template.** Upstream ships
  `terraform/workshop.tf` with every module commented out so learners uncomment them
  one at a time. I enabled and wired all five modules (`knowledge_base`, `memory`,
  `gateway`, `identity`, `runtime`) with an explicit dependency order, renamed the
  domain-specific resources and variables to generic ones
  (`tech_support_knowledgebase_id` → `knowledge_base_id`, etc.), and introduced a
  single `src/agent/agent_config.py` as the one file you edit to start a new agent.

- **Fixed three real defects.** (1) `agent.py` generated `session_id` at module scope,
  so every request shared one AgentCore Memory window — moved it inside the
  `@app.entrypoint` handler so each invocation gets its own. (2) `memory/memory.tf`
  hit a `ValidationException` because memory strategies were attached while the memory
  resource was still `UPDATING`; fixed with a `time_sleep` + `depends_on` guard.
  (3) The rename above left five `aws_cloudwatch_log_delivery_source` blocks in the
  observability files pointing at pre-rename resource names, so `terraform validate`
  failed on the knowledge-base, memory and gateway modules — found and fixed while
  setting up CI, and now covered by a regression test.

- **Tightened IAM.** Replaced the `bedrock:*` / `bedrock-agentcore:*` /
  `aws-marketplace:*` wildcards on the runtime execution role with a minimal explicit
  action list (`InvokeModel`, `Retrieve`, `GetMemory`, `PutMemoryEvent`,
  `SearchMemory`, `InvokeAgentRuntime`, plus CloudWatch/X-Ray).

- **Optimized for Japanese and the Tokyo region.** Default region `ap-northeast-1`,
  the `ap.` cross-region inference profile for Claude Sonnet 4.6,
  `cohere.embed-multilingual-v3` in place of `amazon.titan-embed-text-v2:0` for better
  Japanese retrieval (same 1024 dimensions, so the vector index is unchanged), chunk
  size reduced 200 → 150 tokens because Japanese text is denser per token, and a
  Japanese system prompt. Switching to another region is a documented two-line change.

- **Added consistency tests and CI.** `terraform validate` runs on both templates on
  every push. On top of that, a small pytest suite checks the couplings that span
  Python and HCL and fail only at deploy time: every referenced Terraform resource is
  declared in its module (the regression test for defect 3 above), the inference
  profile prefix matches the provider region, the embedding model in the IAM policy
  matches the one the knowledge base uses, the memory namespace prefix in
  `agent_config.py` matches the Terraform strategies, and no `bedrock:*` wildcard has
  crept back in.

- **Improved developer experience.** `.env.example` lets the agent run locally against
  only the services you have deployed (unset IDs disable that feature instead of
  crashing), `make status` prints every deployed resource ID, stale dependencies no
  longer accumulate in the runtime bundle, and the README carries architecture,
  request-flow and module-dependency diagrams.

- **A second template: `workshops/agentcore-gateway-deep-dive`.** Converted the
  upstream pizza-shop Gateway workshop into a generic MCP Gateway example — generic
  `tool_read` / `tool_write` Lambda tools, Cedar policies for scope-based tool
  authorization, Cognito M2M auth, Tokyo defaults and minimal IAM.

### Attribution

The upstream MIT-0 `LICENSE` and Amazon's copyright notice are retained verbatim; see
[`NOTICE`](NOTICE) for the derivation. The AgentCore workshop content and its original
Terraform layout are the work of the upstream authors; the changes above are mine.
AI coding assistance (Claude) was used throughout and is recorded in the commit
trailers. Development history before this repository lives in
[bolleta/sample-genai-strats](https://github.com/bolleta/sample-genai-strats), the
fork this work started in.

### Quick start

```bash
cd workshops/agentcore-building-ai-agents
make deploy            # terraform apply for all five modules
make invoke-agent      # call the deployed runtime

pip install -r ../../requirements-dev.txt
pytest ../../tests -q  # consistency checks, no AWS credentials needed
```

---

## アーキテクチャ

### 全体像

```
+----------------------------------------------------------------------+
|  Client  (curl / SDK / another agent)                                |
+----------------------------------------------------------------------+
       |  invoke_agent_runtime (HTTPS)
       v

+----------------------------------------------------------------------+
|  AgentCore Runtime  -- エージェント実行基盤                            |
|                                                                      |
|    agent.py                                                          |
|    +-- Strands Agent  (Claude Sonnet 4.6)                            |
|    +-- system_prompt.py      : エージェントの役割定義                  |
|    +-- tools/  (Python)      : ドメイン固有ロジック                    |
|    +-- memory_config.py  ---------> [AgentCore Memory]               |
|    +-- mcp_client.py     ---------> [AgentCore Gateway]              |
|    +-- identity_helper.py           (トークン自動取得)                 |
|                                                                      |
|    OTEL auto-instrumentation  (X-Ray + CloudWatch Logs)              |
+----------------------------------------------------------------------+
       |               |                    |
       v               v                    v

+--------------------+  +----------------------+  +----------------------+
|  AgentCore Memory  |  |  AgentCore Gateway   |  |  Bedrock Knowledge   |
|                    |  |  (MCP protocol)      |  |  Base                |
| - conversation     |  | - tool exposure      |  |                      |
|   recall           |  | - JWT auth           |  | - S3 documents       |
| - user preferences |  |                      |  | - S3 Vectors index   |
| - SEMANTIC         |  | +------------------+ |  | - Cohere Embed v3    |
| - USER_PREFERENCE  |  | |  Lambda tool     | |  |   (multilingual)     |
+--------------------+  | +------------------+ |  +----------------------+
                        |                      |
                        | +------------------+ |
                        | |  Cognito         | |
                        | |  (JWT issuer)    | |
                        | +------------------+ |
                        +----------------------+
                               |
                               v

                 +------------------------------------+
                 |  AgentCore Identity                |
                 |                                    |
                 |  - WorkloadIdentity                |
                 |  - OAuth2 CredentialProvider       |
                 |    (Gateway token auto-fetch)      |
                 +------------------------------------+
```

**日本語補足:**
- **AgentCore Runtime**: コンテナ不要。`agent.zip` を S3 に置くだけでデプロイ可能
- **AgentCore Memory**: 会話をまたいだ記憶の永続化（事実・ユーザー嗜好の2種類）
- **AgentCore Gateway**: Lambda ツールを MCP プロトコルで公開。Cognito JWT で認証
- **AgentCore Identity**: Runtime が Gateway を呼ぶ際の OAuth2 トークン取得を自動化
- **Bedrock Knowledge Base**: S3 ドキュメントをベクトル検索可能にする RAG 基盤

### コンポーネント一覧

| コンポーネント | AWSサービス | 役割 |
|---|---|---|
| **AgentCore Runtime** | Amazon Bedrock AgentCore | エージェントのホスティング基盤。コンテナ不要で Python コードを直接デプロイ |
| **Strands Agent** | Strands Agents SDK + Bedrock | ツール呼び出し・会話管理のオーケストレーター |
| **推論モデル** | Claude Sonnet 4.6 (`ap.*`) | 東京リージョン cross-region inference profile |
| **AgentCore Memory** | Amazon Bedrock AgentCore | 会話をまたいだ記憶の永続化。SEMANTIC（事実）と USER_PREFERENCE（嗜好）の2種類 |
| **AgentCore Gateway** | Amazon Bedrock AgentCore | Lambda ツールを MCP プロトコルで公開。JWT で認証 |
| **AgentCore Identity** | Amazon Bedrock AgentCore | Runtime が Gateway を呼ぶ際の OAuth2 トークン取得を自動化 |
| **Cognito User Pool** | Amazon Cognito | Gateway の JWT 発行元。client_credentials フロー (M2M) |
| **Knowledge Base** | Amazon Bedrock Knowledge Base | S3 ドキュメントをベクトル検索可能にする RAG 基盤 |
| **S3 Vectors** | Amazon S3 Vectors | ベクトルインデックスのストレージ（1024次元、cosine距離）|
| **Embedding モデル** | Cohere Embed Multilingual v3 | 日本語を含む100言語以上対応の embedding |
| **Lambda ツール** | AWS Lambda | Gateway 経由で公開される外部 API / DB アクセス用ツール |
| **CloudWatch + X-Ray** | Amazon CloudWatch, AWS X-Ray | 全コンポーネントの分散トレース・ログ収集 |

---

### リクエストフロー（詳細）

```
Client
    |
    | 1. invoke_agent_runtime(payload={"prompt": "..."})
    v
AgentCore Runtime  -->  agent.py: invoke()
    |
    | 2. session_id を新規生成（リクエストごと）
    v
Strands Agent
    |
    +-- 3a. Memory retrieval
    |         past conversations + user preferences
    |
    +-- 3b. Claude Sonnet 4.6
    |         input: system_prompt + user_prompt + memory context
    |         output: text or tool_use decision
    |
    |   [tool_use の場合]
    |
    +-- 4a. Python tool  (e.g. search_knowledge_base)
    |         --> Bedrock Knowledge Base
    |               Cohere embed query --> S3 Vectors search
    |
    +-- 4b. MCP Gateway tool  (e.g. example_tool)
    |         --> identity_helper: get token via WorkloadIdentity
    |         --> AgentCore Gateway (JWT auth)
    |         --> Lambda execution
    |
    | 5. stream final response chunks to Client
    v
Client
    |
    +-- 6. after response: Memory flush
              write facts + preferences for next session
```

---

### Terraform モジュール構成と依存関係

```
bootstrap.tf         # ランダムプレフィックス + project_name 生成
      │
      ├── module.knowledge_base   (独立)
      │     ├── S3 バケット (ドキュメント格納)
      │     ├── S3 Vectors インデックス
      │     └── Bedrock Knowledge Base
      │
      ├── module.memory           (独立)
      │     ├── AgentCore Memory
      │     ├── SEMANTIC strategy
      │     └── USER_PREFERENCE strategy
      │
      ├── module.gateway          (独立)
      │     ├── Cognito User Pool + M2M Client
      │     ├── AgentCore Gateway (MCP/JWT)
      │     └── Lambda ツール群
      │
      ├── module.identity         (gateway に依存)
      │     ├── WorkloadIdentity
      │     └── OAuth2 CredentialProvider ← Cognito の client_id/secret を注入
      │
      └── module.runtime          (全モジュールに依存)
            ├── S3 (agent.zip 格納)
            └── AgentCore Runtime
                  └── 環境変数で各モジュールの ID/URL を注入
```

---

## ファイル構成

```
workshops/agentcore-building-ai-agents/
├── src/agent/
│   ├── agent_config.py      # ★ 設定の起点 — ここを最初に編集
│   ├── agent.py             # エントリポイント・ツール登録
│   ├── system_prompt.py     # ★ エージェントの役割定義
│   ├── memory_config.py     # AgentCore Memory 接続 (インフラ)
│   ├── mcp_client.py        # AgentCore Gateway MCP 接続 (インフラ)
│   ├── identity_helper.py   # Cognito / WorkloadIdentity 認証 (インフラ)
│   └── tools/
│       ├── example_lookup.py    # ★ ツール例 — 置き換える
│       └── knowledge_base.py    # Knowledge Base RAG ツール (汎用)
├── src/lambdas/
│   └── example-tool/        # ★ Gateway 経由で呼ばれる Lambda ツール例
├── knowledge-base/
│   └── example-doc.txt      # ★ Knowledge Base に投入するドキュメント
├── .env.example             # ローカル開発用の環境変数サンプル
└── terraform/
    ├── bootstrap.tf          # ★ プロジェクト名はここで変更
    ├── workshop.tf           # 全モジュールの組み立て
    ├── memory/               # AgentCore Memory
    ├── knowledge_base/       # Bedrock Knowledge Base + S3 Vectors
    ├── gateway/              # AgentCore Gateway + Cognito + Lambda tools
    ├── identity/             # WorkloadIdentity + CredentialProvider
    └── runtime/              # AgentCore Runtime
```

---

## 新しいエージェントの作り方

### 1. プロジェクト名を変更

`terraform/bootstrap.tf`:
```hcl
project_name_short = "my-agent"   # ← 変更
```

### 2. エージェント設定を変更

`src/agent/agent_config.py`:
```python
AGENT_NAME              = "My Agent"
MODEL_ID                = "ap.anthropic.claude-sonnet-4-6"
MEMORY_NAMESPACE_PREFIX = "my-agent/user"   # terraform/memory/memory.tf と一致させる
```

### 3. システムプロンプトを書く

`src/agent/system_prompt.py` の `SYSTEM_PROMPT` を書き換える。

### 4. ツールを追加・差し替え

**Python ツール** (`src/agent/tools/`):  
`example_lookup.py` を参考に `@tool` デコレーターで関数を作り、`agent.py` の `tools` リストに追加する。

**Gateway ツール** (Lambda 経由で外部 API を叩く場合):  
1. `src/lambdas/example-tool/handler.py` を複製・編集  
2. `terraform/gateway/lambda.tf` にブロックを追加  
3. `terraform/gateway/gateway.tf` に `aws_bedrockagentcore_gateway_target` ブロックを追加  

### 5. Knowledge Base のドキュメントを差し替え

`knowledge-base/` の `example-doc.txt` を自分のドメインのドキュメントに置き換え、  
`terraform/knowledge_base/s3-kb-source.tf` の `kb_documents` リストを更新する。

### 6. Memory の namespace を合わせる

`terraform/memory/memory.tf` の `namespaces` を `agent_config.py` の `MEMORY_NAMESPACE_PREFIX` と一致させる。

### 7. デプロイ

```bash
cd workshops/agentcore-building-ai-agents
make build-agent-package   # agent.zip を作成
make deploy-infra          # Terraform apply (全モジュール)
make status                # デプロイ済みリソース ID を確認
make run-agent-locally     # ローカルで動作確認（Terraform デプロイ後）
make invoke-agent          # デプロイ済み Runtime を呼び出す
```

### ローカルでの部分動作確認（Terraform 不要）

```bash
cp .env.example .env
# .env を編集し、使いたいサービスの ID だけ埋める
# 未設定の変数はスキップされ、その機能がオフになる
# 例: MEMORY_ID, GATEWAY_URL を空欄にすると memory・MCP なしで動作
cd src/agent && uv run agent.py
```

---

## 日本語対応

| 設定 | 値 | 理由 |
|---|---|---|
| AWSリージョン | `ap-northeast-1` (東京) | デフォルト。`terraform/providers.tf` で変更可 |
| 推論モデル | `ap.anthropic.claude-sonnet-4-6` | 東京リージョンの cross-region inference profile |
| Embedding モデル | `cohere.embed-multilingual-v3` | 100言語以上対応、Titan v2より日本語精度が高い |
| チャンクサイズ | 150 tokens (overlap 20%) | 日本語は英語より文字密度が高いため小さめに設定 |
| システムプロンプト | 日本語ベース | ユーザーの言語に合わせて返答するよう指示済み |

### 他リージョンに変更する場合

`terraform/providers.tf`:
```hcl
provider "aws" {
  region = "us-east-1"
}
```

`src/agent/agent_config.py`:
```python
MODEL_ID = "us.anthropic.claude-sonnet-4-6"   # us-east-1 の場合は "us." プレフィックス
```

---

## ファイルの編集不要ゾーン（インフラ配線）

| ファイル | 役割 |
|---|---|
| `identity_helper.py` | Cognito / WorkloadIdentity トークン取得 |
| `mcp_client.py` | Gateway MCP 接続 |
| `logger.py` | ログ設定 |
| `terraform/identity/` | WorkloadIdentity + OAuth2 CredentialProvider |
| `terraform/gateway/cognito.tf` | Cognito M2M 認証 |
| `terraform/*/observability.tf` | CloudWatch Logs + X-Ray 分散トレース |

---

## テスト

AWS 認証情報なしで走る整合性チェック。Python と HCL にまたがっていて
デプロイ時まで顕在化しない結合を守る。

```bash
pip install -r requirements-dev.txt
pytest tests -q
```

| テスト | 守っているもの |
|---|---|
| `test_terraform_references.py` | モジュール内で参照される Terraform リソースがすべて宣言されている（リネーム漏れの検出） |
| `test_config_consistency.py` | 推論プロファイルの接頭辞とプロバイダリージョン、IAM ポリシーと KB の embedding モデル、`agent_config.py` と `memory.tf` の namespace、IAM ワイルドカードの再混入 |
| `test_repo_hygiene.py` | `.gitignore` の state / 認証情報カバレッジ、実 AWS アカウントIDの混入、各子モジュールの `variables.tf` |

CI（GitHub Actions）は上記に加えて、両テンプレートに対して
`terraform init -backend=false` + `terraform validate` を実行する。

---

## バグ修正メモ

**`terraform/memory/memory.tf` — メモリ strategy の race condition**  
`aws_bedrockagentcore_memory` 作成直後は `UPDATING` 状態で strategy をアタッチできない。  
`time_sleep(30s)` + `depends_on` で回避済み。

**`src/agent/agent.py` — session_id がリクエスト間で共有されていた**  
`session_id` がモジュールスコープで生成されており、全リクエストが同一の Memory
ウィンドウを共有していた。`@app.entrypoint` の内側に移動して1リクエスト1セッションに。

**`*/observability.tf` — リネーム後の未宣言リソース参照**  
ワークショップ→テンプレート化の際にリソース名を汎用名へ変更した際、
`aws_cloudwatch_log_delivery_source` 5箇所が旧名（`tech_support` /
`customer_support`）を参照したままだった。`terraform validate` が
knowledge_base・memory・gateway の3モジュールで失敗する状態。
CI 整備中に発見し修正、`tests/test_terraform_references.py` で再発を防止。

**`.gitignore` — `.env.example` が `.env.*` に飲まれていた**  
テンプレートの `.env.example` が `.env.*` パターンで無視され、コミットされていなかった。
`!.env.example` を追加して復旧。

---

## ライセンス

MIT-0 — See [LICENSE](LICENSE). 派生元と改変内容については [NOTICE](NOTICE) を参照。
