# Deploy a managed EKS Cluster

This guide will walk you through deploying a managed EKS cluster in AWS.

## Prerequisites

### Software Requirements

* [AWS CLI](https://aws.amazon.com/cli/)
* [Docker](https://www.docker.com/)
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
* [make](https://www.gnu.org/software/make/)

### Configurable parameters

The file `defaults.conf` located under `settings` directory contains configurable parameters which are loaded when you run `make` commands (see lines 4-7 of `Makefile`). Some important ones are described below, feel free to update other values to suit your development needs.

* CFN_ARTIFACT_BUCKET_NAME - The name of the S3 bucket where the CloudFormation artifacts are stored.
    * Default: `demo-app-cloudformation-artifacts-bucket` (change this to your own bucket name)
    * Required: `true`

* EKS_VERSION - EKS version to be used
    * Default: `1.21`
    * Required: `true`

* APPLICATION_NAME - Name of the application
    * Default: `demo-app`
    * Required: `true`

* APPLICATION_NAMESPACE - Namespace to be used for the application
    * Default: `demo-app-namespace`
    * Required: `true`

* VPC_NETWORK - VPC network CIDR range to be used
    * Default: `10.0.0.0/16`
    * Required: `true`

* SUBNET_CIDRS - Subnet CIDR ranges to be used
    * Default: `10.0.0.0/19,10.0.32.0/19,10.0.64.0/19,10.0.96.0/19,10.0.128.0/19,10.0.160.0/19`
    * Required: `true`

* SERVICE_CIDR - Kubernetes services will leverage this CIDR range
    * Default: `192.168.0.0/16` (ensure this is different from the VPC CIDR range)
    * Required: `true`

* INSTANCE_TYPES - Instance types to be used for the worker nodes
    * Default: `t3.large,t3.xlarge`
    * Required: `true`

### Deploy VPC for EKS

Run `make deploy-3-tier-vpc` to deploy a VPC with 3 public and 3 private subnets.

The network ranges for the VPC and subnets are defined in the `defaults.conf` file. The default values are:

* VPC Network CIDR: `10.0.0.0/16`
* Public Subnet 1 CIDR: `10.0.0.0/19`
* Public Subnet 2 CIDR: `10.0.32.0/19`
* Public Subnet 3 CIDR: `10.0.64.0/19`
* Private Subnet 1 CIDR: `10.0.96.0/19`
* Private Subnet 2 CIDR: `10.0.128.0/19`
* Private Subnet 3 CIDR: `10.0.160.0/19`

### Deploy Eks Cluster

Run `make deploy-eks-cluster` to deploy an EKS cluster and supporting resources.

The resources deployed by the template `cloudformation/eks-cluster.yaml` are,

* Security Group for the cluster
    * An egress rule to allow all traffic
* Eks Cluster
    * IAM Role
    * Cluster name stored in SSM parameter store
    * Cluster OIDC provider
    * OIDC Issuer URL stored in SSM parameter store
* Application Namespace stored in SSM parameter store

The cluster is created with the following configuration:

* Cluster is configured to utilize both public and private subnets.
* Both public and private access enabled to the Kubernetes API Server.
* Kubernetes version is set to `1.21`.
* Logging is enabled for the api, audit, controllerManager, authenticator, and scheduler.
* Public access to the Kubernetes API Server is restricted to your home network.

Because EKS is a managed service, we do not have access to the control plane components managed by AWS EKS for us like the controller manager, scheduler, etc. We can enable logging for control plane components which will allow us to look at logs from these different control plane components in cloudwatch. Be aware that logging everything can increase the cost of your cluster.

### Deploy Eks Addons

Run `make deploy-eks-addons` to deploy EKS Addons. The following addons are deployed:

#### VPC CNI

Amazon EKS supports native VPC networking with the Amazon VPC Container Network Interface (CNI) plugin for Kubernetes.

### Deploy Eks Node Groups

Run `make deploy-node-groups` to deploy EKS Node Groups.

The node groups are deployed with the following configuration:

* Minimum number of nodes: 1
* Desired number of nodes: 1
* Maximum number of nodes: 3
* Instance types: t3.large, t3.xlarge

The worker nodes are deployed in private subnets. In order to access the worker nodes, you will need to use AWS Session Manager to create a new session on the worker nodes. Look at https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-instance-profile.html for more information.
