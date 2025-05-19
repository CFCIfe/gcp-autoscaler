# IF BUCKET ALREADY EXISTS, THEN DO NOT CREATE A NEW ONE
# data "google_storage_bucket" "tf-cfcife-bucket-delete" {
#   name = var.bucket_name
# }

resource "google_storage_bucket" "tf-cfcife-bucket-delete" {
  name                        = var.bucket_name
  location                    = "US"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "tf-cfcife-bucket-object-delete" {
  name   = var.object_name
  bucket = google_storage_bucket.tf-cfcife-bucket-delete.name
  source = var.object_source_path
}

resource "google_cloudfunctions2_function" "tf-cfcife-function-delete" {
  for_each    = var.scheduler_jobs
  name        = "${var.cloud_function_job_name}-${each.key}"
  project     = var.project_name
  location    = var.region
  description = "${var.cloud_function_job_name}-${each.key}"

  build_config {
    runtime     = "python312"
    entry_point = var.function_entry_point

    source {
      storage_source {
        bucket = google_storage_bucket.tf-cfcife-bucket-delete.name
        object = google_storage_bucket_object.tf-cfcife-bucket-object-delete.name
      }
    }
  }
  service_config {
    min_instance_count    = 1
    max_instance_count    = 3
    available_memory      = "512M"
    timeout_seconds       = 60
    service_account_email = google_service_account.test-cfcife-sa-delete.email
  }
  event_trigger {
    pubsub_topic          = google_pubsub_topic.tf-pubsub-topics-delete[each.key].id
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    trigger_region        = var.region
    retry_policy          = "RETRY_POLICY_DO_NOT_RETRY"
    service_account_email = google_service_account.test-cfcife-sa-delete.email
  }
}
