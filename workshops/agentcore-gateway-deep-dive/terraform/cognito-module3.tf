resource "aws_cognito_user_pool" "this" {
  name = local.project_name
}

resource "aws_cognito_user_pool_domain" "this" {
  domain       = local.project_name
  user_pool_id = aws_cognito_user_pool.this.id
}

# =============================================================================
# EDIT: define one scope per logical permission level.
# Convention: gateway/<operation>  (e.g. gateway/read, gateway/write)
# Each scope maps to a Cedar permit policy in gateway-policies.tf.
# =============================================================================
resource "aws_cognito_resource_server" "gateway" {
  identifier   = "gateway"
  name         = "Gateway"
  user_pool_id = aws_cognito_user_pool.this.id

  scope {
    scope_name        = "read"
    scope_description = "Read-only access to gateway tools"
  }
  scope {
    scope_name        = "write"
    scope_description = "Write access to gateway tools"
  }
}

# Default client — read scope only.
# Add clients with write scope in cognito-clients.tf as needed.
resource "aws_cognito_user_pool_client" "default" {
  name         = "${local.project_name}-default"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret                      = true
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["client_credentials"]
  allowed_oauth_scopes                 = ["gateway/read"]
  supported_identity_providers         = ["COGNITO"]

  access_token_validity = 3
  token_validity_units {
    access_token = "hours"
  }

  depends_on = [aws_cognito_resource_server.gateway]
}

locals {
  cognito_issuer_url     = "https://cognito-idp.${local.region}.amazonaws.com/${aws_cognito_user_pool.this.id}"
  cognito_discovery_url  = "${local.cognito_issuer_url}/.well-known/openid-configuration"
  cognito_token_endpoint = "https://${local.project_name}.auth.${local.region}.amazoncognito.com/oauth2/token"
  cognito_scope          = "gateway/read"
}

resource "local_file" "cognito_token_endpoint" {
  content  = local.cognito_token_endpoint
  filename = "${path.root}/../tmp/cognito_token_endpoint.txt"
}

resource "local_file" "cognito_client_id" {
  content  = aws_cognito_user_pool_client.default.id
  filename = "${path.root}/../tmp/cognito_client_id.txt"
}

resource "local_file" "cognito_client_secret" {
  content  = aws_cognito_user_pool_client.default.client_secret
  filename = "${path.root}/../tmp/cognito_client_secret.txt"
}

resource "local_file" "cognito_scope" {
  content  = local.cognito_scope
  filename = "${path.root}/../tmp/cognito_scope.txt"
}
