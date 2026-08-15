# AgentCore Gateway Template

## Overview

[Amazon Bedrock AgentCore Gateway](https://aws.amazon.com/bedrock/agentcore/) translates Lambda functions and HTTP services into [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) endpoints that any agent framework can discover and call. It handles authentication, authorization, request/response transformation, and secure outbound identity — all without changes to your tool implementations.

This template deploys a production-ready AgentCore Gateway with:

- **Cognito M2M auth** (JWT `client_credentials` flow)
- **Cedar Policy Engine** in ENFORCE mode (scope-based per-tool access)
- **Interceptor Lambda** for request/response hooks
- **Two Lambda tools**: `tool-read` (open to all JWT bearers) and `tool-write` (requires `gateway/write` scope)
- **CloudWatch + X-Ray observability**

```
                        ┌─────────────────────────────────────────────────┐
                        │           Amazon Bedrock AgentCore              │
                        │                                                 │
 Agent (Strands)        │  ┌──────────────┐    ┌──────────────────────┐  │
  mcp_client.py  ──MCP──►  │   Gateway    │───►│  Cedar Policy Engine │  │
                        │  │  (JWT auth)  │    │  (scope enforcement) │  │
                        │  └──────┬───────┘    └──────────────────────┘  │
                        │         │                                       │
                        │  ┌──────▼──────────────────────────────────┐   │
                        │  │           Interceptor Lambda             │   │
                        │  │   (REQUEST hook → tool → RESPONSE hook)  │   │
                        │  └──────┬──────────────────────┬────────────┘   │
                        └─────────┼──────────────────────┼────────────────┘
                                  │                      │
                          ┌───────▼──────┐    ┌──────────▼──────┐
                          │  tool-read   │    │   tool-write    │
                          │   Lambda     │    │    Lambda       │
                          │ (open read)  │    │ (write scope)   │
                          └──────────────┘    └─────────────────┘

 Auth flow:
  1. Agent requests token from Cognito (client_credentials)
  2. Cognito issues JWT with scopes (gateway/read or gateway/read + gateway/write)
  3. Gateway validates JWT signature + issuer
  4. Cedar policy checks scope tag on every tool call
  5. Interceptor Lambda runs before/after tool execution
```

## Authorization model

```
Cognito scope       Cedar policy          Lambda tool
──────────────      ────────────────────  ───────────
gateway/read    →   allow_tool_read       tool-read
gateway/write   →   allow_tool_write      tool-write
```

Cedar policy format for tool actions:
```
AgentCore::Action::"<target-name>___<tool-schema-name>"
```

Example forbid rule (block specific input values):
```cedar
forbid(
  principal,
  action == AgentCore::Action::"tool-write___tool-write",
  resource == AgentCore::Gateway::"<gateway-arn>"
)
when {
  context.input.someField == "blocked_value"
};
```

## Quick start

### Prerequisites

- AWS CLI configured for `ap-northeast-1` (Tokyo)
- Terraform >= 1.5
- Node.js 22 (for Lambda development)
- Python 3.12 + `uv` (for agent)

### Deploy

```bash
make deploy-infra
```

### Get a token and call a tool

```bash
make get-token       # fetches Cognito JWT, saves to tmp/access_token.txt
make list-tools      # lists available MCP tools
make tool-read       # calls tool-read Lambda
make tool-write      # calls tool-write Lambda (needs gateway/write scope)
```

### Run the Python agent

```bash
make run-agent            # read-only scope
make run-agent-read-write # read + write scope (requires read_write client in cognito-module4.tf)
```

### Teardown

```bash
make destroy
```

## Customizing for your use case

| File | What to edit |
|------|-------------|
| `terraform/bootstrap.tf` | `project_name_short` |
| `terraform/cognito-module3.tf` | Scope names in `aws_cognito_resource_server.gateway` |
| `terraform/cognito-module4.tf` | Uncomment and adjust additional client blocks |
| `terraform/gateway.tf` | `allowed_scopes`, tool names, input schemas |
| `terraform/gateway-policies.tf` | Cedar permit/forbid rules |
| `src/lambdas/tool-read/index.js` | Read Lambda business logic |
| `src/lambdas/tool-write/index.js` | Write Lambda business logic |
| `src/agent/system_prompt.py` | Agent persona and instructions |
| `src/agent/agent.py` | `MODEL_ID` (default: `ap.anthropic.claude-sonnet-4-6`) |

## Project structure

```
terraform/
  bootstrap.tf           # project name, account/region locals
  providers.tf           # aws + awscc providers (ap-northeast-1)
  gateway.tf             # AgentCore Gateway, targets, interceptor
  gateway-policies.tf    # Cedar Policy Engine + permit/forbid rules
  gateway-iam.tf         # minimal IAM for gateway role
  gateway-observability.tf # CloudWatch log delivery + X-Ray traces
  cognito-module3.tf     # Cognito user pool, resource server, default client
  cognito-module4.tf     # Additional clients (commented, uncomment as needed)
  lambda-tool-read.tf    # tool-read Lambda infra
  lambda-tool-write.tf   # tool-write Lambda infra
  lambda-interceptor.tf  # interceptor Lambda infra

src/
  agent/
    agent.py             # Strands agent with MCP client
    mcp_client.py        # MCP session and tool list
    identity_helper.py   # Cognito token helper
    system_prompt.py     # Agent instructions
  lambdas/
    tool-read/           # Read-only Lambda (Node.js 22)
    tool-write/          # Write Lambda (Node.js 22)
    interceptor/         # Interceptor Lambda (REQUEST + RESPONSE hooks)
```
