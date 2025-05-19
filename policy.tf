resource "google_project_iam_member" "tf-cfcife-invoke" {
  project = var.project_name
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.test-cfcife-sa-delete.email}"
}

resource "google_project_iam_member" "tf-cfcife-event-receiving" {
  project    = var.project_name
  role       = "roles/eventarc.eventReceiver"
  member     = "serviceAccount:${google_service_account.test-cfcife-sa-delete.email}"
  depends_on = [google_project_iam_member.tf-cfcife-invoke]
}

resource "google_project_iam_member" "tf-cfcife-artifact-reader" {
  project    = var.project_name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${data.google_compute_default_service_account.default.email}"
  depends_on = [google_compute_instance.tf-cfcife-vm-delete, google_project_iam_member.tf-cfcife-event-receiving]
}

# Compute Admin role on instance
resource "google_project_iam_member" "tf-cfcife-compute-admin" {
  project    = var.project_name
  role       = "roles/compute.admin"
  member     = "serviceAccount:${google_service_account.test-cfcife-sa-delete.email}"
  depends_on = [google_project_iam_member.tf-cfcife-artifact-reader]
}

# Compute Admin role on instance
resource "google_project_iam_member" "tf-cfcife-log-writing" {
  project    = var.project_name
  role       = "roles/logging.logWriter"
  member     = "serviceAccount:${data.google_compute_default_service_account.default.email}"
  depends_on = [google_compute_instance.tf-cfcife-vm-delete]
}

resource "google_project_iam_member" "tf-cfcife-storage-viewer" {
  project    = var.project_name
  role       = "roles/storage.objectViewer"
  member     = "serviceAccount:${data.google_compute_default_service_account.default.email}"
  depends_on = [google_compute_instance.tf-cfcife-vm-delete]
}
