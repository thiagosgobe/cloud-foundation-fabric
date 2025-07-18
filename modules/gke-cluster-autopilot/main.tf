/**
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

resource "google_container_cluster" "cluster" {
  provider    = google-beta
  project     = var.project_id
  name        = var.name
  description = var.description
  location    = var.location
  node_locations = (
    length(var.node_locations) == 0 ? null : var.node_locations
  )
  min_master_version       = var.min_master_version
  network                  = var.vpc_config.network
  subnetwork               = var.vpc_config.subnetwork
  resource_labels          = var.labels
  enable_multi_networking  = var.enable_features.multi_networking
  enable_l4_ilb_subsetting = var.enable_features.l4_ilb_subsetting
  enable_tpu               = var.enable_features.tpu
  initial_node_count       = 1
  enable_autopilot         = true
  allow_net_admin          = var.enable_features.allow_net_admin
  deletion_protection      = var.deletion_protection

  addons_config {
    # HTTP Load Balancing is required to be enabled in Autopilot clusters
    http_load_balancing {
      disabled = false
    }
    # Horizontal Pod Autoscaling is required to be enabled in Autopilot clusters
    horizontal_pod_autoscaling {
      disabled = false
    }
    cloudrun_config {
      disabled = !var.enable_addons.cloudrun
    }

    kalm_config {
      enabled = var.enable_addons.kalm
    }
    config_connector_config {
      enabled = var.enable_addons.config_connector
    }
    gke_backup_agent_config {
      enabled = var.backup_configs.enable_backup_agent
    }
  }
  dynamic "authenticator_groups_config" {
    for_each = var.enable_features.groups_for_rbac != null ? [""] : []
    content {
      security_group = var.enable_features.groups_for_rbac
    }
  }
  dynamic "binary_authorization" {
    for_each = var.enable_features.binary_authorization ? [""] : []
    content {
      evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
    }
  }
  dynamic "cost_management_config" {
    for_each = var.enable_features.cost_management == true ? [""] : []
    content {
      enabled = true
    }
  }
  cluster_autoscaling {
    auto_provisioning_defaults {
      boot_disk_kms_key = var.node_config.boot_disk_kms_key
      service_account   = var.node_config.service_account
    }
  }
  control_plane_endpoints_config {
    dns_endpoint_config {
      allow_external_traffic = var.access_config.dns_access == true
    }
    ip_endpoints_config {
      enabled = var.access_config.ip_access != null
    }
  }
  dynamic "database_encryption" {
    for_each = var.enable_features.database_encryption != null ? [""] : []
    content {
      state    = var.enable_features.database_encryption.state
      key_name = var.enable_features.database_encryption.key_name
    }
  }
  dynamic "default_snat_status" {
    for_each = var.vpc_config.disable_default_snat == null ? [] : [""]
    content {
      disabled = var.vpc_config.disable_default_snat
    }
  }
  dynamic "dns_config" {
    for_each = var.enable_features.dns != null ? [""] : []
    content {
      additive_vpc_scope_dns_domain = var.enable_features.dns.additive_vpc_scope_dns_domain
      cluster_dns                   = var.enable_features.dns.provider
      cluster_dns_scope             = var.enable_features.dns.scope
      cluster_dns_domain            = var.enable_features.dns.domain
    }
  }
  dynamic "enable_k8s_beta_apis" {
    for_each = var.enable_features.beta_apis != null ? [""] : []
    content {
      enabled_apis = var.enable_features.beta_apis
    }
  }
  dynamic "gateway_api_config" {
    for_each = var.enable_features.gateway_api ? [""] : []
    content {
      channel = "CHANNEL_STANDARD"
    }
  }
  dynamic "ip_allocation_policy" {
    for_each = var.vpc_config.secondary_range_blocks != null ? [""] : []
    content {
      cluster_ipv4_cidr_block  = var.vpc_config.secondary_range_blocks.pods
      services_ipv4_cidr_block = var.vpc_config.secondary_range_blocks.services
      stack_type               = var.vpc_config.stack_type
      dynamic "additional_pod_ranges_config" {
        for_each = var.vpc_config.additional_ranges != null ? [""] : []
        content {
          pod_range_names = var.vpc_config.additional_ranges
        }
      }
    }
  }
  dynamic "ip_allocation_policy" {
    for_each = var.vpc_config.secondary_range_names != null ? [""] : []
    content {
      cluster_secondary_range_name  = var.vpc_config.secondary_range_names.pods
      services_secondary_range_name = var.vpc_config.secondary_range_names.services
      stack_type                    = var.vpc_config.stack_type
      dynamic "additional_pod_ranges_config" {
        for_each = var.vpc_config.additional_ranges != null ? [""] : []
        content {
          pod_range_names = var.vpc_config.additional_ranges
        }
      }
    }
  }
  logging_config {
    enable_components = toset(compact([
      var.logging_config.enable_api_server_logs ? "APISERVER" : null,
      var.logging_config.enable_controller_manager_logs ? "CONTROLLER_MANAGER" : null,
      var.logging_config.enable_scheduler_logs ? "SCHEDULER" : null,
      "SYSTEM_COMPONENTS",
      "WORKLOADS",
    ]))
  }
  maintenance_policy {
    dynamic "daily_maintenance_window" {
      for_each = (
        try(var.maintenance_config.daily_window_start_time, null) != null
        ? [""]
        : []
      )
      content {
        start_time = var.maintenance_config.daily_window_start_time
      }
    }
    dynamic "recurring_window" {
      for_each = (
        try(var.maintenance_config.recurring_window, null) != null
        ? [""]
        : []
      )
      content {
        start_time = var.maintenance_config.recurring_window.start_time
        end_time   = var.maintenance_config.recurring_window.end_time
        recurrence = var.maintenance_config.recurring_window.recurrence
      }
    }
    dynamic "maintenance_exclusion" {
      for_each = (
        try(var.maintenance_config.maintenance_exclusions, null) == null
        ? []
        : var.maintenance_config.maintenance_exclusions
      )
      iterator = exclusion
      content {
        exclusion_name = exclusion.value.name
        start_time     = exclusion.value.start_time
        end_time       = exclusion.value.end_time
        dynamic "exclusion_options" {
          for_each = exclusion.value.scope != null ? [""] : []
          content {
            scope = exclusion.value.scope
          }
        }
      }
    }
  }
  master_auth {
    client_certificate_config {
      issue_client_certificate = var.issue_client_certificate
    }
  }
  dynamic "master_authorized_networks_config" {
    for_each = (
      try(var.access_config.ip_access.private_endpoint_authorized_ranges_enforcement, null) != null ||
      try(var.access_config.ip_access.authorized_ranges, null) != null ||
      try(var.access_config.ip_access.gcp_public_cidrs_access_enabled, null) != null
    ) ? [""] : []
    content {
      gcp_public_cidrs_access_enabled = try(
        var.access_config.ip_access.gcp_public_cidrs_access_enabled,
        null
      )
      private_endpoint_enforcement_enabled = try(
        var.access_config.ip_access.private_endpoint_authorized_ranges_enforcement,
        null
      )
      dynamic "cidr_blocks" {
        for_each = coalesce(var.access_config.ip_access.authorized_ranges, {})
        iterator = range
        content {
          cidr_block   = range.value
          display_name = range.key
        }
      }
    }
  }
  dynamic "mesh_certificates" {
    for_each = var.enable_features.mesh_certificates != null ? [""] : []
    content {
      enable_certificates = var.enable_features.mesh_certificates
    }
  }
  monitoring_config {
    enable_components = toset(compact([
      # System metrics collection cannot be disabled for Autopilot clusters.
      "SYSTEM_COMPONENTS",
      # Control plane metrics:
      var.monitoring_config.enable_api_server_metrics ? "APISERVER" : null,
      var.monitoring_config.enable_controller_manager_metrics ? "CONTROLLER_MANAGER" : null,
      var.monitoring_config.enable_scheduler_metrics ? "SCHEDULER" : null,
      # Kube state metrics:
      var.monitoring_config.enable_daemonset_metrics ? "DAEMONSET" : null,
      var.monitoring_config.enable_deployment_metrics ? "DEPLOYMENT" : null,
      var.monitoring_config.enable_hpa_metrics ? "HPA" : null,
      var.monitoring_config.enable_pod_metrics ? "POD" : null,
      var.monitoring_config.enable_statefulset_metrics ? "STATEFULSET" : null,
      var.monitoring_config.enable_storage_metrics ? "STORAGE" : null,
      var.monitoring_config.enable_cadvisor_metrics ? "CADVISOR" : null,
    ]))
    managed_prometheus {
      enabled = var.monitoring_config.enable_managed_prometheus
    }
  }
  dynamic "notification_config" {
    for_each = var.enable_features.upgrade_notifications != null ? [""] : []
    content {
      pubsub {
        enabled = true
        topic = (
          try(var.enable_features.upgrade_notifications.topic_id, null) != null
          ? var.enable_features.upgrade_notifications.topic_id
          : google_pubsub_topic.notifications[0].id
        )
      }
    }
  }
  node_pool_auto_config {
    node_kubelet_config {
      insecure_kubelet_readonly_port_enabled = upper(var.node_config.kubelet_readonly_port_enabled)
    }
    dynamic "network_tags" {
      for_each = var.node_config.tags != null ? [""] : []
      content {
        tags = toset(var.node_config.tags)
      }
    }
  }
  dynamic "private_cluster_config" {
    for_each = var.access_config.private_nodes == true ? [""] : []
    content {
      enable_private_nodes = true
      enable_private_endpoint = (
        var.access_config.ip_access == null
        # when ip_access is disabled, the API returns true. We return
        # true to avoid a permadiff
        ? true
        : try(var.access_config.ip_access.disable_public_endpoint, null)
      )
      master_ipv4_cidr_block = try(var.access_config.master_ipv4_cidr_block, null)
      private_endpoint_subnetwork = try(
        var.access_config.ip_access.private_endpoint_config.endpoint_subnetwork,
        null
      )
      dynamic "master_global_access_config" {
        for_each = try(var.access_config.ip_access.private_endpoint_config.global_access, false) == true ? [""] : []
        content {
          enabled = (
            var.access_config.ip_access.private_endpoint_config.global_access
          )
        }
      }
    }
  }
  dynamic "pod_security_policy_config" {
    for_each = var.enable_features.pod_security_policy ? [""] : []
    content {
      enabled = var.enable_features.pod_security_policy
    }
  }
  dynamic "secret_manager_config" {
    for_each = var.enable_features.secret_manager_config != null ? [""] : []
    content {
      enabled = var.enable_features.secret_manager_config
    }
  }
  dynamic "security_posture_config" {
    for_each = var.enable_features.security_posture_config != null ? [""] : []
    content {
      mode               = var.enable_features.security_posture_config.mode
      vulnerability_mode = var.enable_features.security_posture_config.vulnerability_mode
    }
  }
  release_channel {
    channel = var.release_channel
  }
  dynamic "resource_usage_export_config" {
    for_each = (
      try(var.enable_features.resource_usage_export.dataset, null) != null
      ? [""]
      : []
    )
    content {
      enable_network_egress_metering = (
        var.enable_features.resource_usage_export.enable_network_egress_metering
      )
      enable_resource_consumption_metering = (
        var.enable_features.resource_usage_export.enable_resource_consumption_metering
      )
      bigquery_destination {
        dataset_id = var.enable_features.resource_usage_export.dataset
      }
    }
  }
  dynamic "service_external_ips_config" {
    for_each = !var.enable_features.service_external_ips ? [""] : []
    content {
      enabled = var.enable_features.service_external_ips
    }
  }
  dynamic "vertical_pod_autoscaling" {
    for_each = var.enable_features.vertical_pod_autoscaling ? [""] : []
    content {
      enabled = var.enable_features.vertical_pod_autoscaling
    }
  }
  dynamic "enterprise_config" {
    for_each = var.enable_features.enterprise_cluster != null ? [""] : []
    content {
      desired_tier = var.enable_features.enterprise_cluster ? "ENTERPRISE" : "STANDARD"
    }
  }
}

resource "google_gke_backup_backup_plan" "backup_plan" {
  for_each = var.backup_configs.enable_backup_agent ? var.backup_configs.backup_plans : {}
  name     = each.key
  cluster  = google_container_cluster.cluster.id
  location = each.value.region
  project  = var.project_id
  labels   = each.value.labels
  retention_policy {
    backup_delete_lock_days = try(each.value.retention_policy_delete_lock_days)
    backup_retain_days      = try(each.value.retention_policy_days)
    locked                  = try(each.value.retention_policy_lock)
  }
  backup_schedule {
    cron_schedule = each.value.schedule
  }

  backup_config {
    include_volume_data = each.value.include_volume_data
    include_secrets     = each.value.include_secrets

    dynamic "encryption_key" {
      for_each = each.value.encryption_key != null ? [""] : []
      content {
        gcp_kms_encryption_key = each.value.encryption_key
      }
    }

    all_namespaces = lookup(each.value, "namespaces", null) != null ? null : true
    dynamic "selected_namespaces" {
      for_each = each.value.namespaces != null ? [""] : []
      content {
        namespaces = each.value.namespaces
      }
    }
  }
}

resource "google_pubsub_topic" "notifications" {
  count = (
    try(var.enable_features.upgrade_notifications, null) != null &&
    try(var.enable_features.upgrade_notifications.topic_id, null) == null ? 1 : 0
  )
  project = var.project_id
  name    = "gke-pubsub-notifications"
  labels = {
    content = "gke-notifications"
  }
}
