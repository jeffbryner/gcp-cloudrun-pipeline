# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

terraform {
  required_version = ">=0.14"
  required_providers {
    google      = "~> 3.0"
    google-beta = "~> 3.0"
  }

}

# inert terraform stub
resource "random_id" "suffix" {
  byte_length = 2
}


data "google_project" "cloudrun" {
  project_id = "prj-cloudrun-sample-6271"
}

locals {

  project_name      = data.google_project.cloudrun.name
  project_id        = data.google_project.cloudrun.project_id
  state_bucket_name = format("bkt-%s-%s", "tfstate", local.project_id)
  art_bucket_name   = format("bkt-%s-%s", "artifacts", local.project_id)
  repo_name         = format("cicd-%s", local.project_name)
  gar_repo_name     = format("%s-%s", "prj", "containers")
}

/**
cloud build container
**/

resource "null_resource" "cloudbuild_cloudrun_container" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<EOT
      gcloud builds submit ./container/ --project ${local.project_id} --config=./container/cloudbuild.yaml
  EOT
  }
}
