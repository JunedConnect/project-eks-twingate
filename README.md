# Twin Trust

The project demonstrates a **Zero Trust Network Access (ZTNA) implementation** using **Twingate** to provide secure access to an Amazon EKS cluster and its internal resources. This setup enables secure, identity-based access to Kubernetes services and pods without exposing them to the public internet.

This architecture leverages **Twingate's Zero Trust model** with connectors deployed on EC2 instances and within the Kubernetes cluster. **Zero Trust** is a security model based on the principle of "never trust, always verify" - **every access request** is authenticated and authorised based on user identity, regardless of network location.


![Logo](https://raw.githubusercontent.com/JunedConnect/project-eks-twingate/main/images/twingate-logo.png)

<br>

## Table of Contents

- [Directory Structure](#directory-structure)
- [Prerequisites](#prerequisites)
  - [Create Twingate Network](#create-twingate-network)
  - [Configuration Dependencies](#configuration-dependencies)
- [How to Deploy](#how-to-deploy)
  - [Option A: Operator](#option-a-operator-recommended---kubernetes-native)
  - [Option B: Connector](#option-b-connector-more-manual)
- [Accessing Kubernetes Resources](#accessing-kubernetes-resources)
- [Cleanup](#cleanup)
- [Now the Why](#now-the-why)
  - [Option A vs Option B: Functional Differences](#option-a-vs-option-b-functional-differences)
- [Troubleshooting](#troubleshooting)
- [Resource Link](#resource-link)
  - [Secure Access to EKS Kubernetes API Endpoint](#secure-access-to-eks-kubernetes-api-endpoint)
  - [Secure Access to Internal Kubernetes Cluster Resources (Option A)](#secure-access-to-internal-kubernetes-cluster-resources-option-a)
  - [Secure Access to Internal Kubernetes Cluster Resources (Option B)](#secure-access-to-internal-kubernetes-cluster-resources-option-b)

<br>

## Directory Structure

```
./
├── terraform/                    # Infrastructure as Code
│   ├── modules/                  # Terraform modules
│   └── [terraform files]         # Root Terraform (.tf) files
├── helm-values/                  # Helm chart values
├── .env.example                  # Example environment variables file
├── twingate-resources.yml        # Twingate CRDs (for Twingate Operator Installation Option)
├── test-whoami.yml               # Test application
└── Makefile                      # Automation commands
```

<br>

## Prerequisites

### Create Twingate Network

Before configuring the project, you need to create a Twingate network:

1. **Create a Network**: 
   - In Twingate Console, create a new network
   - Note the name of your network (appears in your Twingate URL: `https://<network>.twingate.com`)

2. **Get Required Information**:
   - **Network Name**: From your Twingate URL
   - **API Token**: Settings → API Keys → Create new API key (Sensitive: DO NOT SHARE)
   - **Access Group ID**: Team → Groups → Select group `Everyone` → Note the Group ID (appears in your Twingate URL: `https://<network>.twingate.com/groups/<access-group-id>`)

3. **Install Twingate Client**:
   - Download and install the Twingate client for your operating system
   - Connect to your Twingate network using your credentials through the client

<br>

**Note**: Terraform will automatically create two separate remote networks:
- `aws-network` - For EC2-based connectors (handles AWS network resources)
- `eks-network` - For Kubernetes connectors (handles Kubernetes network resources)

**Important**: Separate remote networks are required to ensure proper routing. Without them, Twingate may route traffic to the wrong connector, causing DNS resolution failures for Kubernetes services.

<br>

### Configuration Dependencies

After creating your Twingate network, update these configuration values:

**Terraform** (`terraform/terraform.tfvars`):
- `name` - Cluster name
- `twingate_url` - Twingate URL
- `twingate_access_group_id` - Twingate access group ID
- `aws_tags.Owner` - Owner tag (for tagging purposes)

**Terraform Provider** (set environment variables):
- `TWINGATE_API_TOKEN` - Twingate API token
- `TWINGATE_NETWORK` - Twingate network name

**Environment Variables** (`.env` file):
- `TWINGATE_NETWORK` - Twingate network name
- `TWINGATE_API_TOKEN` - Twingate API token

**Note for `.env` file**: 
- Only `TWINGATE_NETWORK` and `TWINGATE_API_TOKEN` need to be filled in
- `TWINGATE_OPERATOR_VERSION` and `TWINGATE_CONNECTOR_VERSION` are already set
- `KUBERNETES_CONNECTOR_ACCESS_TOKEN` and `KUBERNETES_CONNECTOR_REFRESH_TOKEN` are only required for Option B (Connector installation)

<br>

## How to Deploy

### Prerequisites:
- Terraform
- kubectl
- Helm
- AWS CLI
- Twingate Network

<br>

1. **Deploy Infrastructure**:
   ```bash
   export TWINGATE_API_TOKEN="your-api-token"
   export TWINGATE_NETWORK="your-network"
   cd terraform && terraform init && terraform apply
   ```

2. **Configure kubeconfig**:
   ```bash
   aws eks update-kubeconfig --name <cluster-name> --region eu-west-2
   ```
   Replace `<cluster-name>` with your actual cluster name.

3. **Install Twingate** (choose one):

<br>

### Option A: Operator (Recommended - Kubernetes-native)

   ```bash
   make setup-operator
   ```
   Manages resources via CRDs. Automatically applies Twingate resources (e.g., `twingate-resources.yml`).
   
   **Connecting to Cluster via Kubernetes Access Gateway**:
   The Operator automatically creates a Kubernetes Access Gateway resource. To connect:
   1. In your Twingate client, enable **"Sync Kubernetes Configuration"** to update your kubeconfig
   2. The gateway automatically adds a kubeconfig context to your kubeconfig
   3. Switch to the gateway context:
      ```bash
      kubectl config use-context twingate-twop-kubernetes-access-gateway-resource
      ```
   4. You can now use `kubectl` commands to access the cluster through Twingate

   **Note**: By default, the gateway context is assigned the `view` ClusterRole (read-only access). To change permissions, update the `ClusterRoleBinding` resource in `twingate-resources.yml`.

<br>

### Option B: Connector (More Manual):

   1. After Terraform creates the connector `kubernetes-connector-1` within the `eks-network` remote network, get the tokens from Twingate Console:
      - Go to Connectors → Select `kubernetes-connector-1` → Get tokens
   2. Add tokens to your `.env` file:
      ```bash
      KUBERNETES_CONNECTOR_ACCESS_TOKEN="your-access-token"
      KUBERNETES_CONNECTOR_REFRESH_TOKEN="your-refresh-token"
      ```
   3. Run the setup command:
      ```bash
      make setup-connector
      ```

<br>

## Accessing Kubernetes Resources

Once connected via Twingate client, access resources using DNS names:

- **Services**: `<service-name>.<namespace>.svc.cluster.local`
- **Pods**: `<pod-ip-with-dashes>.<namespace>.pod.cluster.local`
- **StatefulSet Pods**: `<pod-name>.<service-name>.<namespace>.svc.cluster.local`

<br>

## Cleanup

```bash
make destroy-operator    # Remove Operator
cd terraform && terraform destroy  # Remove Infrastructure
#or
make destroy-connector   # Remove Connector
cd terraform && terraform destroy  # Remove Infrastructure
```

<br>

## Now the Why

**EKS Cluster Network Architecture**:

The EKS cluster is deployed in private subnets within the AWS VPC, meaning the cluster API endpoint is not directly accessible from the internet. To authenticate with the EKS API endpoint and access the cluster, you need a connector deployed on the AWS VPC network. This is why the **AWS EC2 Connector** (`aws-ec2-connector`) is required - it runs on EC2 instances within the same VPC as the EKS cluster, allowing you to reach the private API endpoint.

<br>

**Dual Connector Architecture**:

This project uses two separate connectors for proper routing:
- **AWS EC2 Connector** (`aws-ec2-connector`): Deployed on EC2 instances within the AWS VPC, handles AWS network resources (e.g., EKS API endpoint) communication. Associated with the `aws-network` remote network
- **Kubernetes Connector** (`kubernetes-connector-1/2`): Deployed within the cluster, handles Kubernetes internal resources communication (services, pods). Associated with the `eks-network` remote network

**Why separate connectors?**

Each connector is optimised for its network context. The EC2 connector handles AWS-level resources, whilst the Kubernetes connector understands cluster DNS resolution (`*.cluster.local`). This separation prevents routing conflicts and DNS resolution failures.

<br>

**API Endpoint vs Internal Cluster Resources**:
- **EKS API Endpoint Communication**: Accessing the cluster API (for `kubectl` commands) requires connectivity to the EKS API endpoint, which is a VPC-level resource. This is handled by the AWS EC2 Connector, which is on the same VPC network and can reach the private API endpoint.
- **Internal Cluster Resources**: Accessing Kubernetes services and pods (e.g., `whoami.whoami.svc.cluster.local`) requires DNS resolution within the cluster's internal network. This is handled by the Kubernetes Connector, which runs inside the cluster and understands Kubernetes DNS resolution (`*.cluster.local`).

<br>

### Option A vs Option B: Functional Differences

**Option A (Operator)**:
- **Advanced option**: Provides `kubectl` access and Twingate group-based Kubernetes permissions
- **Kubernetes-native management**: Uses Custom Resource Definitions (CRDs) to manage Twingate resources declaratively
- **Automated resource management**: Resources defined in `twingate-resources.yml` are automatically synced to Twingate
- **Kubernetes Access Gateway**: Adds a kubeconfig context to your kubeconfig that allows you to authenticate to the cluster as your Twingate user identity. This enables you to access the cluster API through the Kubernetes Access Gateway instead of the AWS EC2 connector (`aws-ec2-connector`), providing secure `kubectl` access through Twingate
- **RBAC integration**: Links Twingate groups with Kubernetes RBAC via ClusterRoleBindings, keeping access permissions in sync. This integration is specifically for the Kubernetes Access Gateway, allowing Twingate group membership to automatically map to Kubernetes ClusterRoles

**Option B (Connector)**:
- **Basic cluster connectivity**: A simpler, more basic version of Option A that simply allows connection to resources inside the cluster itself
- **Manual resource creation**: Requires manually creating the Twingate connector and Twingate resources (in this project, Terraform handles this automatically)
- **Manual token management**: Requires retrieving and managing connector tokens from Twingate Console
- **No Kubernetes Access Gateway**: You only have access to the cluster via the EKS API endpoint through the AWS EC2 connector (`aws-ec2-connector`)
- **No RBAC integration**: The Kubernetes Access Gateway and RBAC integration are linked features that work together to control cluster access based on Twingate groups. Option B does not include these features, so you cannot use Twingate groups to manage Kubernetes permissions (and vice versa)

<br>

## Troubleshooting

**DNS Resolution Failures**:
- Verify separate remote networks (`aws-network` / `eks-network`)
- Check connectors are on correct remote network
- Verify resources associated with correct network

**Verify Installation**:
```bash
kubectl get pods -n tg
kubectl get twingateconnectors -n tg
kubectl get twingateresources -n tg
```

**Verify Helm Values**:
To check if Helm values have been applied properly:
```bash
helm get values twop -n tg          # For Operator
helm get values twingate-connector -n tg  # For Connector
```

**Option A: Switching to Twingate Context**:
If you're unable to switch to the Twingate kubeconfig context or the context is not appearing:
1. Check Twingate client logs to verify if it was able to update your kubeconfig
2. Ensure "Sync Kubernetes Configuration" is enabled in your Twingate client settings
3. Verify the Kubernetes Access Gateway resource is created and accessible:
   ```bash
   kubectl get twingateresources -n tg
   ```
4. Check if the context exists in your kubeconfig:
   ```bash
   kubectl config get-contexts
   ```

<br>

## Resource Link

### Secure Access to EKS Kubernetes API Endpoint
https://www.twingate.com/docs/k8s-kubectl
https://www.twingate.com/docs/terraform-aws

<br>

### Secure Access to Internal Kubernetes Cluster Resources (Option A)

https://www.twingate.com/docs/k8s-private-services

https://www.twingate.com/docs/kubernetes-access
https://github.com/Twingate/kubernetes-operator
https://github.com/Twingate/kubernetes-operator/wiki/Getting-Started

https://github.com/Twingate/kubernetes-access-gateway?tab=readme-ov-file
https://github.com/Twingate/kubernetes-access-gateway/wiki/Quick-Start-Guide
https://github.com/Twingate/kubernetes-access-gateway/wiki/Installation

<br>

### Secure Access to Internal Kubernetes Cluster Resources (Option B)

https://www.twingate.com/docs/k8s-private-services

https://www.twingate.com/docs/k8s-helm-chart
https://github.com/Twingate/helm-charts/tree/master/stable/connector