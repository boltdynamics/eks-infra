SHELL = /bin/bash
SHELLFLAGS = -ex

include ./settings/defaults.conf
ifneq ("$(wildcard ./settings/$(ENVIRONMENT).conf"), "")
-include ./settings/$(ENVIRONMENT).conf
endif

help:  ## Makefile help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(firstword $(MAKEFILE_LIST)) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
.PHONY: help

install:  ## Create/re-create pipenv virtual environment
	$(info [+] Running pipenv install...)
	@pipenv install --dev
.PHONY: install

update-kubeconfig:  ## Update local kubeconfig to interact with the cluster
	$(info [+] Updating local kubeconfig...)
	$(eval EKS_CLUSTER_NAME := $(shell aws ssm get-parameter --name $(EKS_CLUSTER_NAME_SSM_PATH) --query Parameter.Value --output text))
	$(info [+] Cluster name: $(EKS_CLUSTER_NAME))
	aws eks update-kubeconfig --name $(EKS_CLUSTER_NAME)
.PHONY: update-kubeconfig

deploy-3-tier-vpc: ## Deploy EKS Pre-requisites - 3 tier VPC
	$(info [+] Deploying EKS VPC...)
	@aws cloudformation deploy \
		--s3-bucket $(CFN_ARTIFACT_BUCKET_NAME) \
	    --template-file cloudformation/3-tier-vpc.yaml \
		--stack-name $(APPLICATION_NAME)-3-tier-vpc \
		--capabilities CAPABILITY_NAMED_IAM \
		--no-fail-on-empty-changeset \
		--parameter-overrides \
			AppName=$(APPLICATION_NAME) \
			VpcNetwork=$(VPC_NETWORK) \
			SubnetCidrs=$(SUBNET_CIDRS) \
		--tags \
			Name='$(APPLICATION_NAME) EKS Resources - 2 Tier VPC'
.PHONY: deploy-3-tier-vpc

deploy-eks-cluster: ## Deploy EKS Resources - Cluster
	$(eval HOME_NETWORK_PUBLIC_IP := $(shell dig +short myip.opendns.com @resolver1.opendns.com))
	$(info [+] Your Public IP: $(HOME_NETWORK_PUBLIC_IP), access to Kube API Server is restricted to your public IP only.)
	@aws cloudformation deploy \
		--s3-bucket $(CFN_ARTIFACT_BUCKET_NAME) \
	    --template-file cloudformation/eks-cluster.yaml \
		--stack-name $(APPLICATION_NAME)-eks-cluster \
		--capabilities CAPABILITY_NAMED_IAM \
		--no-fail-on-empty-changeset \
		--parameter-overrides \
			OidcProviderUrlSsmPath=$(OIDC_PROVIDER_URL_SSM_PATH) \
			EksClusterNameSsmPath=$(EKS_CLUSTER_NAME_SSM_PATH) \
			AppNamespace=$(APPLICATION_NAMESPACE) \
			AppNamespaceSsmPath=$(APPLICATION_NAMESPACE_SSM_PATH) \
			AppName=$(APPLICATION_NAME) \
			EksVersion=$(EKS_VERSION) \
			ServiceCidr=$(SERVICE_CIDR) \
			HomeNetworkCidr=$(HOME_NETWORK_PUBLIC_IP)/32 \
		--tags \
			Name='Kubernetes Cluster Resources - Control Plane Resources'
.PHONY: deploy-eks-cluster

deploy-eks-addons: ## Deploy EKS Resources - Addons like Vpc Cni
	@aws cloudformation deploy \
		--s3-bucket $(CFN_ARTIFACT_BUCKET_NAME) \
	    --template-file cloudformation/eks-addons.yaml \
		--stack-name $(APPLICATION_NAME)-eks-addons \
		--capabilities CAPABILITY_NAMED_IAM \
		--no-fail-on-empty-changeset \
		--parameter-overrides \
			EksClusterName=$(EKS_CLUSTER_NAME_SSM_PATH) \
		--tags \
			Name='Kubernetes Cluster Resources - EKS Addons'
.PHONY: deploy-eks-addons

deploy-node-groups: ## Deploy EKS Resources - Node Group
	@aws cloudformation deploy \
		--s3-bucket $(CFN_ARTIFACT_BUCKET_NAME) \
	    --template-file cloudformation/eks-nodegroup.yaml \
		--stack-name $(APPLICATION_NAME)-nodegroup \
		--capabilities CAPABILITY_NAMED_IAM \
		--no-fail-on-empty-changeset \
		--parameter-overrides \
			EksClusterName=$(EKS_CLUSTER_NAME_SSM_PATH) \
			AppName=$(APPLICATION_NAME) \
			InstanceTypes=$(INSTANCE_TYPES) \
			MinimumInstances=$(MINIMUM_NODES) \
			DesiredInstances=$(DESIRED_NODES) \
			MaximumInstances=$(MAXIMUM_NODES) \
			CapacityType=$(CAPACITY_TYPE) \
		--tags \
			Name='Kubernetes Cluster Resources - Worker Nodes'
.PHONY: deploy-node-groups

deploy-all: deploy-3-tier-vpc deploy-eks-cluster deploy-eks-addons deploy-node-groups update-kubeconfig ## Deploy all EKS Resources
.PHONY: deploy-all

delete-node-groups: ## Delete node groups
	aws cloudformation delete-stack --stack-name $(APPLICATION_NAME)-nodegroup
.PHONY: delete-node-groups

delete-addons: ## Delete addons
	aws cloudformation delete-stack --stack-name $(APPLICATION_NAME)-eks-addons
.PHONY: delete-addons

delete-cluster: ## Delete cluster
	aws cloudformation delete-stack --stack-name $(APPLICATION_NAME)-eks-cluster
.PHONY: delete-cluster
