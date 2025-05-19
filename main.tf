terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.35.0"
    }
  }
}

provider "time" {}

provider "google" {
  project = local.project_id
  region  = local.region
  zone    = local.zone
}
locals {
  apis_to_enable = [
    "compute.googleapis.com",
    "cloudscheduler.googleapis.com",
    "cloudfunctions.googleapis.com",
    "iam.googleapis.com",
    "pubsub.googleapis.com",
    "storage.googleapis.com",
    "cloudbuild.googleapis.com",
    "eventarc.googleapis.com",
    "artifactregistry.googleapis.com"
  ]
  project_id = "682348490962"
  region     = "us-central1"
  zone       = "us-central1-f"
}

variable "scheduler_jobs" {
  description = "Map of Cloud Scheduler jobs with schedule and pubsub topic"
  type = map(object({
    schedule   = string
    topic_name = string
    data = object({
      project_id       = string
      zone             = string
      instance_name    = string
      new_machine_type = string
    })
  }))
  default = {
    resize_up = {
      schedule   = "0 9 1 * *"
      topic_name = "tf-pubsub-resize_up-delete"
      data = {
        project_id       = "682348490962"
        zone             = "us-central1-f"
        instance_name    = "tf-jessica-vm-delete"
        new_machine_type = "e2-micro"
      }
    }
    resize_down = {
      schedule   = "0 9 7 * *"
      topic_name = "tf-pubsub-resize_down-delete"
      data = {
        project_id       = "682348490962"
        zone             = "us-central1-f"
        instance_name    = "tf-jessica-vm-delete"
        new_machine_type = "e2-small"
      }
    }
  }
}

data "google_service_account" "test-jessica-sa-delete" {
  account_id = "test-jessica-sa-delete@test-jessica-delete.iam.gserviceaccount.com"
}

resource "google_project_service" "project_service" {
  project  = local.project_id
  for_each = toset(local.apis_to_enable)
  service  = each.value
}

resource "google_compute_instance" "tf-jessica-vm-delete" {
  boot_disk {
    auto_delete = true
    device_name = "tf-jessica-vm-delete"
    initialize_params {
      image = "projects/windows-cloud/global/images/windows-server-2025-dc-v20250515"
      size  = 50
      type  = "pd-balanced"
    }

    mode = "READ_WRITE"
  }

  can_ip_forward      = false
  deletion_protection = false
  enable_display      = false

  labels = {
    goog-ec-src = "vm_add-tf"
  }

  machine_type = "e2-small"
  name         = "tf-jessica-vm-delete"

  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }

    queue_count = 0
    stack_type  = "IPV4_ONLY"
    subnetwork  = "projects/test-jessica-delete/regions/${local.region}/subnetworks/default"
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
    provisioning_model  = "STANDARD"
  }

  service_account {
    email  = "682348490962-compute@developer.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only", "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring.write", "https://www.googleapis.com/auth/service.management.readonly", "https://www.googleapis.com/auth/servicecontrol", "https://www.googleapis.com/auth/trace.append"]
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = false
    enable_vtpm                 = true
  }

  zone = local.zone
}

resource "google_pubsub_topic" "tf-pubsub-topics-delete" {
  for_each = var.scheduler_jobs
  name     = each.value.topic_name
  project  = "test-jessica-delete"
}

resource "google_cloud_scheduler_job" "tf_jessica_cloud_scheduler" {
  for_each    = var.scheduler_jobs
  name        = "tf-jessica-cloud-scheduler-${each.key}-delete"
  description = "tf-jessica-cloud-scheduler-${each.key}-delete"
  project     = "test-jessica-delete"
  region      = local.region
  schedule    = each.value.schedule
  time_zone   = "America/Los_Angeles"

  pubsub_target {
    topic_name = google_pubsub_topic.tf-pubsub-topics-delete[each.key].id
    data       = base64encode(jsonencode(each.value.data))
  }
}

resource "google_storage_bucket" "tf-jessica-bucket-delete" {
  name                        = "tf-jessica-bucket-delete"
  location                    = "US"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "tf-jessica-bucket-object-delete" {
  name   = "tf-jessica-function.zip"
  bucket = google_storage_bucket.tf-jessica-bucket-delete.name
  source = "tf-function.zip"
}

resource "google_cloudfunctions2_function" "tf-jessica-function-delete" {
  for_each    = var.scheduler_jobs
  name        = "tf-jessica-function-${each.key}-delete"
  project     = "test-jessica-delete"
  location    = local.region
  description = "tf-jessica-function-${each.key}-delete"

  build_config {
    runtime     = "python312"
    entry_point = "pubsub_handler"

    source {
      storage_source {
        bucket = google_storage_bucket.tf-jessica-bucket-delete.name
        object = google_storage_bucket_object.tf-jessica-bucket-object-delete.name
      }
    }
  }
  service_config {
    min_instance_count    = 1
    max_instance_count    = 3
    available_memory      = "512M"
    timeout_seconds       = 60
    service_account_email = "682348490962-compute@developer.gserviceaccount.com"
  }
  event_trigger {
    pubsub_topic   = google_pubsub_topic.tf-pubsub-topics-delete[each.key].id
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    trigger_region = local.region
    retry_policy   = "RETRY_POLICY_DO_NOT_RETRY"
  }
}

data "google_iam_policy" "tf-jessica-policy" {
  binding {
    role    = "roles/cloudfunctions.invoker"
    members = ["serviceAccount:${data.google_service_account.test-jessica-sa-delete.email}", "serviceAccount:682348490962-compute@developer.gserviceaccount.com"]
  }
}

resource "google_cloudfunctions2_function_iam_policy" "tf-jessica-iam-invoker" {
  for_each       = var.scheduler_jobs
  project        = google_cloudfunctions2_function.tf-jessica-function-delete[each.key].project
  location       = google_cloudfunctions2_function.tf-jessica-function-delete[each.key].location
  cloud_function = google_cloudfunctions2_function.tf-jessica-function-delete[each.key].name
  policy_data    = data.google_iam_policy.tf-jessica-policy.policy_data
}
