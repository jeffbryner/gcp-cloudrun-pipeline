# run terraform init/apply with this file inert (backend.tf.example)
# grab output of the bucket created in terraform apply
# and enter here
# then rename to backend.tf
# and run terraform init --force-copy

terraform {
  backend "gcs" {
    bucket = "bkt-tfstate-prj-cloudrun-sample-6271"
    prefix = "cicd"
  }
}
