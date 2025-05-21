terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.35.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# resource "google_service_account" "test-cfcife-sa-delete" {
#   account_id                   = var.service_account_id
#   display_name                 = var.service_account_id
#   create_ignore_already_exists = true
# }

resource "google_project_service" "project_service" {
  project                    = var.project_id
  for_each                   = toset(var.apis_to_enable)
  service                    = each.value
  disable_dependent_services = false
  disable_on_destroy = false
}

# data "google_compute_default_service_account" "default" {

#   depends_on = [google_compute_instance.tf-cfcife-vm-delete]
# }

# # IF COMPUTE INSTANCE ALREADY EXISTS, THEN DO NOT CREATE A NEW ONE

# # data "google_compute_instance" "tf-cfcife-vm-delete" {
# #   name = var.compute_instance_name
# #   zone = var.zone
# # }

# resource "google_compute_instance" "tf-cfcife-vm-delete" {
#   boot_disk {
#     auto_delete = true
#     device_name = var.compute_instance_name
#     initialize_params {
#       image = var.compute_instance_image
#       size  = 50
#       type  = "pd-balanced"
#     }

#     mode = "READ_WRITE"
#   }

#   can_ip_forward      = false
#   deletion_protection = false
#   enable_display      = false

#   labels = {
#     goog-ec-src = "vm_add-tf"
#   }

#   machine_type = var.compute_instance_machine_type
#   name         = var.compute_instance_name

#   network_interface {
#     access_config {
#       network_tier = "PREMIUM"
#     }

#     queue_count = 0
#     stack_type  = "IPV4_ONLY"
#     subnetwork  = "projects/${var.project_name}/regions/${var.region}/subnetworks/default"
#   }

#   scheduling {
#     automatic_restart   = true
#     on_host_maintenance = "MIGRATE"
#     preemptible         = false
#     provisioning_model  = "STANDARD"
#   }

#   service_account {
#     email  = google_service_account.test-cfcife-sa-delete.email
#     scopes = ["https://www.googleapis.com/auth/devstorage.read_only", "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring.write", "https://www.googleapis.com/auth/service.management.readonly", "https://www.googleapis.com/auth/servicecontrol", "https://www.googleapis.com/auth/trace.append"]
#   }

#   shielded_instance_config {
#     enable_integrity_monitoring = true
#     enable_secure_boot          = false
#     enable_vtpm                 = true
#   }

#   zone = var.zone
# }

# resource "google_pubsub_topic" "tf-pubsub-topics-delete" {
#   for_each = var.scheduler_jobs
#   name     = each.value.topic_name
#   project  = var.project_name
# }

# resource "google_cloud_scheduler_job" "tf_cfcife_cloud_scheduler" {
#   for_each    = var.scheduler_jobs
#   name        = "${var.cloud_scheduler_job_name}-${each.key}"
#   description = "${var.cloud_scheduler_job_name}-${each.key}"
#   project     = var.project_name
#   region      = var.region
#   schedule    = each.value.schedule
#   time_zone   = "America/Los_Angeles"

#   pubsub_target {
#     topic_name = google_pubsub_topic.tf-pubsub-topics-delete[each.key].id
#     data       = base64encode(jsonencode(each.value.data))
#   }
# }
