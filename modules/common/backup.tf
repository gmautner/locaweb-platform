# =============================================================================
# OFFSITE AWS BACKUP
# =============================================================================

module "backup" {
  count  = var.enable_backup ? 1 : 0
  source = "../backup"

  cluster_name = var.cluster_name
}
