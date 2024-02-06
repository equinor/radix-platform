output "data" {
  value = local.outputs
}

output "mi_id" {
  value = module.mi.data.id
}

output "workspace_id" {
  value = module.loganalytics.workspace_id
}
