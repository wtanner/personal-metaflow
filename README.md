# personal-metaflow
Configures an opinionated personal Metaflow system by way of a Terraform module.

## Features
- Saves money by using Spot instances
- Saves money by running the metaflow service and database locally, instead of an always-on RDS instance and ECS service.
- Creates a VPC and a public subnet in each availability zone, such that AWS Batch can optimally schedule in the Region.
- Runs AWS Batch compute in a public subnet with a reasonable security group default (no ingress, permissive egress). This saves money by not requiring a NAT gateway.
- Follows the [principle of least privilege](https://en.wikipedia.org/wiki/Principle_of_least_privilege).
- Configured to use a Managed compute environment for AWS Batch with instance type "optimal", which allows AWS Batch to choose between C, M, and R instance families.
- Adds a few GPU instance types by default, in case there is a need for GPU workloads.
- AWS Batch configured with an allocation strategy  SPOT_CAPACITY_OPTIMIZED, which allows AWS Batch to select instance types that are large enough to meet the requirements of the jobs in the queue, with a preference for instance types that are less likely to be interrupted.

## Usage

Add the following to your terraform:

```hcl-terraform
module "metaflow" {
  source = "github.com/wtanner/personal-metaflow"
}
```

Check that everything looks ok:

```bash
terraform plan
```

Apply the changes:

```bash
terraform apply
```

If Metaflow hasn't been installed, you can do so via [pip](https://docs.metaflow.org/getting-started/install):

```bash
pip install metaflow
```

Metaflow will then need to be setup with the generated S3 bucket and AWS Batch compute parameters.
This can be done via the configure command, and following the prompts. When asked to configure Metadata Service as the metadata provider, say no.

```bash
metaflow configure aws
```

Example configuration parameters:

```yaml
"METAFLOW_BATCH_JOB_QUEUE": "metaflow",
"METAFLOW_DATASTORE_SYSROOT_S3": "s3://metaflow20200735061527122100000001",
"METAFLOW_DATATOOLS_SYSROOT_S3": "s3://metaflow20200735061527122100000001/data",
"METAFLOW_DEFAULT_DATASTORE": "s3",
"METAFLOW_ECS_S3_ACCESS_IAM_ROLE": "metaflow_iam_role"
```

To verify everything is configured properly, we can run one of the Metaflow tutorials. First, pull down the tutorials

```bash
metaflow tutorials pull
cd metaflow-tutorials
```

Run the basic AWS tutorial, and verify it succeeds:

```bash
python 05-helloaws/helloaws.py run
```

Success looks something like:

```text
2020-08-02 14:43:30.490 [1596404434936190/end/3 (pid 24045)] Task finished successfully.
```

While it runs (and after), you can check out the AWS Batch jobs in the AWS console. You should see submitted jobs, an instance turning on, etc. The state changes are also logged out by Metaflow locally as it executes.

