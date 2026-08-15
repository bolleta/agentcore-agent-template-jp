# =============================================================================
# ADDITIONAL COGNITO CLIENTS
# Add one aws_cognito_user_pool_client block per persona (read-only, read-write, admin…).
# All scopes must be declared first in aws_cognito_resource_server.gateway (cognito-module3.tf).
#
# EDIT: uncomment / copy these blocks to create additional clients.
# =============================================================================

# Read-only client — can call tool-read only (Cedar policy enforces this).
# resource "aws_cognito_user_pool_client" "read_only" {
#   name         = "${local.project_name}-read-only"
#   user_pool_id = aws_cognito_user_pool.this.id
#
#   generate_secret                      = true
#   allowed_oauth_flows_user_pool_client = true
#   allowed_oauth_flows                  = ["client_credentials"]
#   allowed_oauth_scopes                 = ["gateway/read"]
#   supported_identity_providers         = ["COGNITO"]
#
#   depends_on = [aws_cognito_resource_server.gateway]
# }

# Read-write client — can call both tool-read and tool-write.
# resource "aws_cognito_user_pool_client" "read_write" {
#   name         = "${local.project_name}-read-write"
#   user_pool_id = aws_cognito_user_pool.this.id
#
#   generate_secret                      = true
#   allowed_oauth_flows_user_pool_client = true
#   allowed_oauth_flows                  = ["client_credentials"]
#   allowed_oauth_scopes                 = ["gateway/read", "gateway/write"]
#   supported_identity_providers         = ["COGNITO"]
#
#   depends_on = [aws_cognito_resource_server.gateway]
# }

# resource "local_file" "cognito_read_only_client_id" {
#   content  = aws_cognito_user_pool_client.read_only.id
#   filename = "${path.root}/../tmp/cognito_read_only_client_id.txt"
# }

# resource "local_file" "cognito_read_only_client_secret" {
#   content  = aws_cognito_user_pool_client.read_only.client_secret
#   filename = "${path.root}/../tmp/cognito_read_only_client_secret.txt"
# }

# resource "local_file" "cognito_read_write_client_id" {
#   content  = aws_cognito_user_pool_client.read_write.id
#   filename = "${path.root}/../tmp/cognito_read_write_client_id.txt"
# }

# resource "local_file" "cognito_read_write_client_secret" {
#   content  = aws_cognito_user_pool_client.read_write.client_secret
#   filename = "${path.root}/../tmp/cognito_read_write_client_secret.txt"
# }
