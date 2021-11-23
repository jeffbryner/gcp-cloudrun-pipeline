
# GCP-Project-Pipeline

A goldilocks effort for bootstraping a GCP project with it's own ci/cd pipeline:

Inspired by these great repos:

  - https://github.com/GoogleCloudPlatform/healthcare-data-protection-suite
  - https://github.com/terraform-google-modules/terraform-example-foundation

## Why?
The healthcare data protection suite is great at making a simple project that gets you a functional ci/cd pipeline for terraforming GCP all using GCP resources. However, it's templated terraform eminating from a golang engine. This project cuts to the chase using just terraform.

The terraform example foundation is about building a complete GCP org, not an individual project and can be overkill. It also doesn't setup source control/triggers for the cicd pipeline itself, which is odd.

This is meant to simply satisfy the urge to dream up a project, give it a name and location in the org tree, terraform apply and then immediately begin using the ci/cd pipeline to build the remaining infrastructure.


## Continuous integration (CI) and continuous deployment (CD)

The CI and CD pipelines use
[Google Cloud Build](https://cloud.google.com/cloud-build) and
[Cloud Build triggers](https://cloud.google.com/cloud-build/docs/automating-builds/create-manage-triggers)
to detect changes in a cloud source repo, trigger builds, and implement terraform changes.

## Concept of operations
The desired end state is a GCP project with a cloud source repo and cloud build triggers that terraform plan/apply on code commits. The build triggers will run terraform against a list of directories you choose (cicd by default) so you can use it to build the pipeline, infrastructure, groups, compute, databases, iam, etc as separate concerns as you see fit.

The `_managed_dirs` list in the `triggers.tf` file in the cicd directory sets the directories that will be managed by this cicd pipeline.

## Setup
You will need to be able to create a project with billing in the appropriate place in your particular org structure. First you'll run terraform locallly to initialize the project and the pipeline. After the project is created, we will transfer terraform state to the cloud bucket and from then on you can use git commits to trigger terraform changes without any local resources or permissions.

1. Clone this repo

2. Change directory (cd) to the cicd directory and edit the terraform.tfvars to match your GCP organization.

3. Run the following commands in the cicd directory to enable the necessary APIs,
   grant the Cloud Build service account the necessary permissions, and create
   Cloud Build triggers and the terraform state bucket:

    ```shell
    terraform init
    terraform apply
    ```
4. Get the name of the terraform state bucket from the terraform output

    ```shell
    terraform output
    ```
  and copy backend.tf.example as backend.tf with the proper bucket name.

    ```terraform
        terraform {
      backend "gcs" {
        bucket = "UPDATE_ME_WITH_OUTPUT_OF_INITIAL_INIT"
        prefix = "cicd"
      }
    }
    ```

  Note that if you create other directories for other terraform concerns, you should duplicate this backend.tf file in those directories with a different prefix so your state bucket matches your directory layout.

5. Now terraform can transfer state from your local environment into GCP. From the cicd directory:
    ```shell
    terraform init -force-copy
    ```

6. Follow the instructions at https://source.cloud.google.com/<project name>/<repository name> to then push your code (from the parent directory of cicd, i.e. not the cicd directory) into your new CICD pipeline. Basically:

    ```shell
    git init
    gcloud init && git config --global credential.https://source.developers.google.com.helper gcloud.sh
    git remote add google  https://source.developers.google.com/p/<project name>/r/<repository name>
    git checkout -b main
    git add cicd/configs/* cicd/backend.tf cicd/main.tf cicd/outputs.tf cicd/terraform.tfvars cicd/triggers.tf cicd/variables.tf
    git commit -m 'first push after bootstrap'
    git push --all google

7. After the repo and pipeline is established you should be able to view the build triggers and history by visiting:
https://console.cloud.google.com/cloud-build/dashboard?project=<project id here>


## CICD Container/Container Creation

The Docker container used for CICD executions are inspired by those built and maintained by the
Cloud Foundation Toolkit (CFT) team.


Documentations and source can be found [here](https://github.com/GoogleCloudPlatform/cloud-foundation-toolkit/tree/master/infra/build/developer-tools-light). Images can be found [here](https://console.cloud.google.com/gcr/images/cloud-foundation-cicd/GLOBAL/cft/developer-tools-light).

This version of the container includes necessary dependencies (e.g. bash, terraform, gcloud, python, pip, pipenv) to validate and deploy Terraform configs and is based on hashicorp's native terraform and alpine linux.

To build the container, cd to the container directory and issue the command

```bash
gcloud builds submit
```
Which will kick off a build using the cloudbuild.yaml and Dockerfile in the container directory, creating a 'cloudbuilder' container ( gcr.io/${PROJECT_ID}/cloudbuilder )in your project that is used by the triggers.


## Features

### Event-triggered builds

Two presubmit and one postsubmit triggers are created by default.

* \[Presubmit\] `tf-validate`: Perform Terraform format and syntax check.
  * It does not access Terraform remote state.
* \[Presubmit\] `tf-plan`: Generate speculative plans to show a set of
    potential changes if the pending config changes are deployed.
  * It accesses Terraform remote state but does not lock it.
  * This also performs a non-blocking check for resource deletions. These
        are worth reviewing, as deletions are potentially destructive.
* \[Postsubmit\] `tf-apply`: Apply the terraform configs that are checked into
    the config source repo.
  * It accesses Terraform remote state and locks it.
  * This trigger is only applicable post-submit.
  * When this trigger is set in the Terraform engine config, the Cloud Build
        service account is given broader permissions to be able to make changes
        to the infrastructure.

Every new push to the Pull Request at the configured branches automatically
triggers presubmit runs.

The postsubmit Cloud Build job automatically starts after a Pull Ruquest is
submitted to a configured branch. To view the result of the Cloud Build run, go
to [Build history](https://console.cloud.google.com/cloud-build/builds) and look
for your commit to view the Cloud Build job triggered by your merged commit.

The `build_viewers` members can view detailed log output.

The triggers all use a [helper runner script](./cicd/configs/run.sh) to perform
actions. The `DIRS` var within the script lists the directories that are managed by the triggers and the order they are
run.

### Deletion check allowlist

The deletion check run as part of the `tf-plan` trigger optionally accepts an
allowlist of resources to ignore, using
[grep extended regex patterns](https://en.wikipedia.org/wiki/Regular_expression#POSIX_extended)
matched against the Terraform resource **address** from the plan.

To configure an allowlist:

1. Create a file `tf-deletion-allowlist.txt` in the `cicd/configs/` directory.
2. Add patterns to it, one per line.

Example:

```text
network
^module.cloudsql.module.safer_mysql.google_sql_database.default$
google_sql_user.db_users\["user-creds"\]
```

Each line allows, respectively:

1. Any resource whose address contains the string "network".
2. A specific resource within a module.
3. A specific resource with a generated name, i.e. from `for_each` or `count`.
