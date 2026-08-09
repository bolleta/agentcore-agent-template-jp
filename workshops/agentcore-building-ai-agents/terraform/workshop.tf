# =============================================================================
# INFRASTRUCTURE MODULES
# All modules are enabled by default. Comment out any you don't need.
#
# Module dependency order:
#   knowledge_base  (independent)
#   memory          (independent)
#   gateway         (independent — deploys Cognito + Lambda tools)
#   identity        (depends on: gateway)
#   runtime         (depends on: knowledge_base, memory, gateway, identity)
# =============================================================================

module "knowledge_base" {
  source       = "./knowledge_base"
  project_name = local.project_name
  region       = data.aws_region.current.region
}

module "memory" {
  source       = "./memory"
  project_name = local.project_name
  region       = data.aws_region.current.region
}

module "gateway" {
  source       = "./gateway"
  project_name = local.project_name
  region       = data.aws_region.current.region
}

module "identity" {
  source                        = "./identity"
  project_name                  = local.project_name
  oauth2_provider_client_id     = module.gateway.cognito_client_id
  oauth2_provider_client_secret = module.gateway.cognito_client_secret
  oauth2_discovery_url          = module.gateway.cognito_discovery_url
}

module "runtime" {
  source                   = "./runtime"
  project_name             = local.project_name
  region                   = data.aws_region.current.region
  agentcore_memory_id      = module.memory.memory_id
  knowledge_base_id        = module.knowledge_base.kb_id
  gateway_url              = module.gateway.gateway_url
  cognito_scope            = module.gateway.cognito_scope
  credential_provider_name = module.identity.credential_provider_name
  workload_identity_name   = module.identity.workload_identity_name
}
