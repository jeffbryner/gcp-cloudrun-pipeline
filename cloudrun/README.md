Directory of cloudrun resources built by our /cicd pipeline

This directory is a standalone terraform concern, separate from the /cicd directory.

Be sure to rename backend.tf.example to backend.tf including the name of the state bucket created from your work in the /cicd directory.

It is called from the same triggers, so change source and push to trigger a build.

Put whatever you'd like in the /cloudrun/container directory and that'll be your container.