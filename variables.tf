variable "project_id" {
  description = "The project ID to deploy the resources"
  type        = string
}

variable "project_name" {
  description = "The project name to deploy the resources"
  type        = string
}

variable "region" {
  description = "The region to deploy the resources"
  type        = string
}

variable "zone" {
  description = "The zone to deploy the resources"
  type        = string
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

variable "apis_to_enable" {
  description = "values to enable APIs"
  type        = list(string)
  default = [
    "compute.googleapis.com",
    "cloudscheduler.googleapis.com",
    "cloudfunctions.googleapis.com",
    "iam.googleapis.com",
    "pubsub.googleapis.com",
    "storage.googleapis.com",
    "eventarc.googleapis.com",
    "artifactregistry.googleapis.com",
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
  ]
}

variable "service_account_id" {
  description = "The service account ID to deploy the resources"
  type        = string
}

variable "compute_instance_name" {
  description = "The compute instance name to deploy the resources"
  type        = string
}

variable "compute_instance_image" {
  description = "The compute instance image to deploy the resources"
  type        = string
  default     = "projects/windows-cloud/global/images/windows-server-2025-dc-v20250515"
}

variable "compute_instance_machine_type" {
  description = "The compute instance machine type to deploy the resources"
  type        = string
  default     = "e2-small"
}

variable "cloud_scheduler_job_name" {
  description = "The cloud scheduler job name to deploy the resources"
  type        = string
}

variable "bucket_name" {
  description = "The bucket name to deploy the resources"
  type        = string
}

variable "object_name" {
  description = "The object name to deploy the resources"
  type        = string
}

variable "object_source_path" {
  description = "The object source path to deploy the resources"
  type        = string
}

variable "cloud_function_job_name" {
  description = "The cloud scheduler job name to deploy the resources"
  type        = string
}

variable "function_entry_point" {
  description = "The function entry point to deploy the resources"
  type        = string
}
