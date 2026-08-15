enable-cloudwatch-transactional-search:
	-aws xray update-indexing-rule --name Default --rule '{"Probabilistic":{"DesiredSamplingPercentage":100}}'

	-aws logs put-resource-policy \
  		--policy-name xray-cloudwatch-logs-policy \
  		--policy-document file://xray-cloudwatch-logs-policy.json

	-aws xray update-trace-segment-destination --destination CloudWatchLogs

deploy-infra:
	@echo "Running terraform apply..."
	cd terraform && \
		terraform init && \
		terraform apply --auto-approve

redeploy-gateway:
	@echo "Destroying log deliveries (must precede gateway deletion)..."
	cd terraform && terraform apply --auto-approve \
		-destroy \
		-target=aws_cloudwatch_log_delivery.gateway_logs \
		-target=aws_cloudwatch_log_delivery.gateway_traces

	@echo "Replacing AgentCore Gateway..."
	cd terraform && terraform apply --auto-approve \
		-replace=awscc_bedrockagentcore_gateway.this

destroy:
	@echo "Destroying everything..."
	cd terraform && terraform destroy --auto-approve
	rm -rf tmp

status:
	@echo "=== Gateway ==="
	@cat ./tmp/gateway_url.txt 2>/dev/null && echo "" || echo "(not deployed)"
	@cat ./tmp/gateway_id.txt 2>/dev/null && echo "" || true
	@echo "=== Cognito ==="
	@cat ./tmp/cognito_token_endpoint.txt 2>/dev/null && echo "" || echo "(not deployed)"
	@cat ./tmp/cognito_scope.txt 2>/dev/null && echo "" || true

# ── Basic gateway tests ───────────────────────────────────────────────────────
list-tools:
	$(eval GATEWAY_URL := $(shell cat ./tmp/gateway_url.txt))
	$(eval ACCESS_TOKEN := $(shell cat ./tmp/access_token.txt 2>/dev/null || echo ""))
	curl -s -X POST $(GATEWAY_URL) \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer $(ACCESS_TOKEN)" \
		-d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | jq .

tool-read:
	$(eval GATEWAY_URL := $(shell cat ./tmp/gateway_url.txt))
	$(eval ACCESS_TOKEN := $(shell cat ./tmp/access_token.txt 2>/dev/null || echo ""))
	curl -s -X POST $(GATEWAY_URL) \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer $(ACCESS_TOKEN)" \
		-d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"tool-read___tool-read","arguments":{}}}' | jq .

# EDIT: update the "input" value and field names to match your tool-write schema
tool-write:
	$(eval GATEWAY_URL := $(shell cat ./tmp/gateway_url.txt))
	$(eval ACCESS_TOKEN := $(shell cat ./tmp/access_token.txt 2>/dev/null || echo ""))
	curl -s -X POST $(GATEWAY_URL) \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer $(ACCESS_TOKEN)" \
		-d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"tool-write___tool-write","arguments":{"input":"example"}}}' | jq .

# ── Cognito JWT ───────────────────────────────────────────────────────────────
get-token:
	@echo "Fetching Cognito access token..."
	$(eval COGNITO_TOKEN_ENDPOINT := $(shell cat ./tmp/cognito_token_endpoint.txt))
	$(eval COGNITO_CLIENT_ID := $(shell cat ./tmp/cognito_client_id.txt))
	$(eval COGNITO_CLIENT_SECRET := $(shell cat ./tmp/cognito_client_secret.txt))
	$(eval COGNITO_SCOPE := $(shell cat ./tmp/cognito_scope.txt))

	$(info > COGNITO_TOKEN_ENDPOINT=$(COGNITO_TOKEN_ENDPOINT))
	$(info > COGNITO_CLIENT_ID=$(COGNITO_CLIENT_ID))
	$(info > COGNITO_SCOPE=$(COGNITO_SCOPE))

	$(eval ACCESS_TOKEN := $(shell curl -s -X POST $(COGNITO_TOKEN_ENDPOINT) \
		-H "Content-Type: application/x-www-form-urlencoded" \
		-d "grant_type=client_credentials&client_id=$(COGNITO_CLIENT_ID)&client_secret=$(COGNITO_CLIENT_SECRET)&scope=$(COGNITO_SCOPE)" \
		| jq -r '.access_token'))
	@echo ""
	@echo "Retrieved access token: $(ACCESS_TOKEN)"
	@echo $(ACCESS_TOKEN) > ./tmp/access_token.txt
	@echo "Token saved to ./tmp/access_token.txt"

# ── Multi-client testing (requires clients defined in cognito-module4.tf) ──────
get-read-only-token:
	@echo "Fetching token for read-only client..."
	$(eval COGNITO_TOKEN_ENDPOINT := $(shell cat ./tmp/cognito_token_endpoint.txt))
	$(eval CLIENT_ID := $(shell cat ./tmp/cognito_read_only_client_id.txt))
	$(eval CLIENT_SECRET := $(shell cat ./tmp/cognito_read_only_client_secret.txt))
	$(eval ACCESS_TOKEN := $(shell curl -s -X POST $(COGNITO_TOKEN_ENDPOINT) \
		-H "Content-Type: application/x-www-form-urlencoded" \
		-d "grant_type=client_credentials&client_id=$(CLIENT_ID)&client_secret=$(CLIENT_SECRET)&scope=gateway/read" \
		| jq -r '.access_token'))
	@echo $(ACCESS_TOKEN) > ./tmp/access_token.txt
	@echo "read-only token saved to ./tmp/access_token.txt"

get-read-write-token:
	@echo "Fetching token for read-write client..."
	$(eval COGNITO_TOKEN_ENDPOINT := $(shell cat ./tmp/cognito_token_endpoint.txt))
	$(eval CLIENT_ID := $(shell cat ./tmp/cognito_read_write_client_id.txt))
	$(eval CLIENT_SECRET := $(shell cat ./tmp/cognito_read_write_client_secret.txt))
	$(eval ACCESS_TOKEN := $(shell curl -s -X POST $(COGNITO_TOKEN_ENDPOINT) \
		-H "Content-Type: application/x-www-form-urlencoded" \
		-d "grant_type=client_credentials&client_id=$(CLIENT_ID)&client_secret=$(CLIENT_SECRET)&scope=gateway/read gateway/write" \
		| jq -r '.access_token'))
	@echo $(ACCESS_TOKEN) > ./tmp/access_token.txt
	@echo "read-write token saved to ./tmp/access_token.txt"

# ── Python agent ──────────────────────────────────────────────────────────────
run-agent:
	@echo "Starting gateway agent (read scope)..."
	$(eval GATEWAY_URL := $(shell cat ./tmp/gateway_url.txt))
	$(eval COGNITO_TOKEN_ENDPOINT := $(shell cat ./tmp/cognito_token_endpoint.txt 2>/dev/null || echo ""))
	$(eval CLIENT_ID := $(shell cat ./tmp/cognito_client_id.txt 2>/dev/null || echo ""))
	$(eval CLIENT_SECRET := $(shell cat ./tmp/cognito_client_secret.txt 2>/dev/null || echo ""))
	cd src/agent && \
		GATEWAY_URL=$(GATEWAY_URL) \
		COGNITO_CLIENT_ID=$(CLIENT_ID) \
		COGNITO_CLIENT_SECRET=$(CLIENT_SECRET) \
		COGNITO_TOKEN_ENDPOINT=$(COGNITO_TOKEN_ENDPOINT) \
		COGNITO_SCOPE="gateway/read" \
		uv run agent.py

run-agent-read-write:
	@echo "Starting gateway agent (read+write scope)..."
	$(eval GATEWAY_URL := $(shell cat ./tmp/gateway_url.txt))
	$(eval COGNITO_TOKEN_ENDPOINT := $(shell cat ./tmp/cognito_token_endpoint.txt 2>/dev/null || echo ""))
	$(eval CLIENT_ID := $(shell cat ./tmp/cognito_read_write_client_id.txt 2>/dev/null || echo ""))
	$(eval CLIENT_SECRET := $(shell cat ./tmp/cognito_read_write_client_secret.txt 2>/dev/null || echo ""))
	cd src/agent && \
		GATEWAY_URL=$(GATEWAY_URL) \
		COGNITO_CLIENT_ID=$(CLIENT_ID) \
		COGNITO_CLIENT_SECRET=$(CLIENT_SECRET) \
		COGNITO_TOKEN_ENDPOINT=$(COGNITO_TOKEN_ENDPOINT) \
		COGNITO_SCOPE="gateway/read gateway/write" \
		uv run agent.py
