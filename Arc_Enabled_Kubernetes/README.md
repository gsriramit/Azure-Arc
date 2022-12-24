## Deployment of Arc Enabled Kubernetes using the Azure Provider for Cluster API

### Introduction to Cluster API and working

#### Cluster API concepts

[Introduction to Cluster API](https://cluster-api.sigs.k8s.io/user/concepts.html)  

[Cluster API Github Repository](https://github.com/kubernetes-sigs/cluster-api)  

[Components in a Cluster API Management Cluster](https://cluster-api.sigs.k8s.io/user/concepts.html)

[Kubeadm based bootstrap config](https://cluster-api.sigs.k8s.io/tasks/bootstrap/kubeadm-bootstrap.html)

Examples of controllers - Cluster & Machine controllers that help in reconciling specific requests  
https://cluster-api.sigs.k8s.io/developer/architecture/controllers/cluster.html  
https://cluster-api.sigs.k8s.io/developer/architecture/controllers/machine.html  

Concrete implementation of the Cluster API infrastructure interfaces  
Azure Machine Pools  
https://capz.sigs.k8s.io/topics/machinepools.html  
https://capz.sigs.k8s.io/topics/machinepools.html#example-machinepool-azuremachinepool-and-kubeadmconfig-resources

Cluster API Provider for Azure  
https://cloudblogs.microsoft.com/opensource/2020/12/15/introducing-cluster-api-provider-azure-capz-kubernetes-cluster-management/  
https://capz.sigs.k8s.io/  

[Overview of Clusterctl](https://cluster-api.sigs.k8s.io/clusterctl/overview.html#:~:text=The%20clusterctl%20CLI%20tool%20handles,provider%20components%20and%20installing%20them.)  

#### Working of Cluster API
From the Cluster API Book docs:  

“Cluster API requires an existing Kubernetes cluster accessible via kubectl; during the installation process the Kubernetes cluster will be transformed into a management cluster by installing the Cluster API provider components, so it is recommended to keep it separated from any application workload.”  
In this scenario, an AKS cluster will be created initially and the same would then be initialized as cluster api Management Cluster. This cluster will then be used to deploy the workload cluster using the Cluster API Azure provider (CAPZ)  

### Setup
**Note:** The instructions in the following section has been put together based on the documentation from the following 3 sources  
- [Azure Arc Jumpstart](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/cluster_api/capi_azure/)
- [Microsoft Reactor session on Cluster api by Jorge](https://github.com/azuretar/clusterapi-gitops)
- [Official Cluster API Quickstart guide](https://cluster-api.sigs.k8s.io/user/quick-start.html)  

#### Service Principal Creation
Create an Azure service principal (SP).The Azure service principal assigned with “Contributor” Role-based access control (RBAC) is required for provisioning Azure resources when the workload cluster components are created. After the creation of the SP, make a note of the application/client ID and the secret/password.

```
# Login using the --tenant switch if you have access to multiple tenants
# Define the Azure subscription id that will be used to host the management and workload clusters
AZURE_SUBSCRIPTION_ID=""
az login
az account set --subscription $AZURE_SUBSCRIPTION_ID
az ad sp create-for-rbac -n "ArcK8s" --role "Contributor" --scopes /subscriptions/$AZURE_SUBSCRIPTION_ID
```
#### Installation of the required tools and dependencies

**Install Azure CLI (az)**
```
curl -L https://aka.ms/InstallAzureCli | bash
```

**Install Clusterctl**
```
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.3.0/clusterctl-linux-arm64 -o clusterctl
clusterctl version
chmod +x ./clusterctl
sudo mv ./clusterctl /usr/local/bin/clusterctl
```

**Install Kubernetes CLIs**
```
az aks install-cli
```

**Install Helm3 CLI**
```
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

**Install/Update Extensions**
```
az extension list -o table
az upgrade

az extension add -n connectedk8s  or  az extension update -n connectedk8s
az extension add -n k8s-configuration  or  az extension update -n k8s-configuration
az extension add -n aks-preview  or  az extension update -n aks-preview
```

**Register Azure Arc Providers**
```
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait

az provider show -n Microsoft.Kubernetes -o table
az provider show -n Microsoft.KubernetesConfiguration -o table
az provider show -n Microsoft.ExtendedLocation -o table
```

#### (Management Cluster) Create AKS - Azure Kubernetes Services to install Cluster API management

**Create Azure resource Group on eastus regions where GitOps preview is also available**
az group create -l eastus -n capi-controlplane

**Create Azure Kubernetes Service that will be used as the management cluster (Edit Script with your IDs)**
```
AKS_ADMINGRP_OBJECTID=""
az aks create --resource-group capi-controlplane --name capi-controlplane \
    --node-count 1 --node-vm-size Standard_D4s_v3 \
    --network-plugin azure --network-policy calico \
    --enable-addons monitoring,azure-policy \
    --enable-managed-identity --generate-ssh-keys \
    --vm-set-type VirtualMachineScaleSets --load-balancer-sku standard \
    --enable-aad --aad-admin-group-object-ids $AKS_ADMINGRP_OBJECTID \
    --max-pods 110 \
    --yes  
```
#### Variable initialization
Initialize the azure environment variables before the AKS cluster can be converted into the cluster api management cluster and the workload cluster can be created based on the CAPZ (Azure provider)  
```
# This var should have been initialized already when logging into azure and setting the context. If logging into a new session, then this should be reinitialized
#export AZURE_SUBSCRIPTION_ID="<SubscriptionId>"

# Create an Azure Service Principal and paste the output here
export AZURE_TENANT_ID="<Tenant>"
export AZURE_CLIENT_ID="<AppId>" # to be used from the SP that was created earlier
export AZURE_CLIENT_SECRET="<Password>"

export CAPI_PROVIDER="azure" # Do not change!
export CAPI_PROVIDER_VERSION="1.5.4" # Do not change!
export KUBERNETES_VERSION="1.23.6" # Do not change!

# Base64 encode the variables
export AZURE_SUBSCRIPTION_ID_B64="$(echo -n "$AZURE_SUBSCRIPTION_ID" | base64 | tr -d '\n')"
export AZURE_TENANT_ID_B64="$(echo -n "$AZURE_TENANT_ID" | base64 | tr -d '\n')"
export AZURE_CLIENT_ID_B64="$(echo -n "$AZURE_CLIENT_ID" | base64 | tr -d '\n')"
export AZURE_CLIENT_SECRET_B64="$(echo -n "$AZURE_CLIENT_SECRET" | base64 | tr -d '\n')"

# Settings needed for AzureClusterIdentity used by the AzureCluster
export AZURE_CLUSTER_IDENTITY_SECRET_NAME="cluster-identity-secret"
export CLUSTER_IDENTITY_NAME="cluster-identity"
export AZURE_CLUSTER_IDENTITY_SECRET_NAMESPACE="default"

# Create a secret to include the password of the Service Principal identity created in Azure
# This secret will be referenced by the AzureClusterIdentity used by the AzureCluster
kubectl create secret generic "${AZURE_CLUSTER_IDENTITY_SECRET_NAME}" --from-literal=clientSecret="${AZURE_CLIENT_SECRET}" --namespace "${AZURE_CLUSTER_IDENTITY_SECRET_NAMESPACE}"
```
#### Initialize the management cluster
```
clusterctl init --infrastructure=azure:v${CAPI_PROVIDER_VERSION} --wait-providers  
# The current context (kubeconfig) should be now pointing to the management cluster. Wait for all the necessary components to complete intialization
kubectl wait --for=condition=Available --timeout=90s --all deployments -A >/dev/null
```

#### Creation of the Workload Cluster
The clusterctl generate cluster command returns a YAML template for creating a workload cluster  
```
# Make sure you choose a VM size which is available in the desired location for your subscription. To see available SKUs, use 
az vm list-skus -l <your_location> -r virtualMachines -o table

# Name of the Azure datacenter location. Change this value to your desired location.
export AZURE_LOCATION="eastus"

# Select VM types.
export AZURE_CONTROL_PLANE_MACHINE_TYPE="Standard_D2s_v3"
export AZURE_NODE_MACHINE_TYPE="Standard_D2s_v3"

# Set the deployment resource group
export AZURE_RESOURCE_GROUP="<ResourceGroupName>"

#Set the workload cluster name
export WORKLOAD_CLUSTER_NAME=""

#Set the instance counts of the control plane and the user node pools
export CONTROL_PLANE_INSTANCE_COUNT=2
export USERNODEPOOL_PLANE_INSTANCE_COUNT=2

clusterctl generate cluster ${WORKLOAD_CLUSTER_NAME} --kubernetes-version ${KUBERNETES_VERSION} | kubectl apply -f -

clusterctl generate cluster ${WORKLOAD_CLUSTER_NAME} \
  --kubernetes-version ${KUBERNETES_VERSION} \
  --control-plane-machine-count=${CONTROL_PLANE_INSTANCE_COUNT} \
  --worker-machine-count=${USERNODEPOOL_PLANE_INSTANCE_COUNT} \
  > capi-workloadcluster.yaml

# Apply the kubernetes manifest to create the cluster
kubectl apply -f capi-workloadcluster.yaml
```

#### Validations
The cluster will now start provisioning. You can check status with:
```
kubectl get cluster
#You can also get an “at glance” view of the cluster and its resources by running:
clusterctl describe cluster capi-quickstart
```
To verify the first control plane is up:
```
kubectl get kubeadmcontrolplane
```

After the first control plane node is up and running, we can retrieve the workload cluster Kubeconfig.  
```
clusterctl get kubeconfig ${WORKLOAD_CLUSTER_NAME} > ${WORKLOAD_CLUSTER_NAME}.kubeconfig
```

#### Deploy a CNI solution
Azure does not currently support Calico networking. As a workaround, it is recommended that Azure clusters use the Calico spec below that uses VXLAN.  
```
kubectl --kubeconfig=./${WORKLOAD_CLUSTER_NAME}.kubeconfig \
  apply -f https://raw.githubusercontent.com/kubernetes-sigs/cluster-api-provider-azure/main/templates/addons/calico.yaml
# Validation
kubectl --kubeconfig=./${WORKLOAD_CLUSTER_NAME}.kubeconfig get nodes
```

### Connecting the workload cluster to Azure
```
az connectedk8s connect --name $WORKLOAD_CLUSTER_NAME --resource-group $AZURE_RESOURCE_GROUP --location $AZURE_LOCATION --kube-config $WORKLOAD_CLUSTER_NAME.kubeconfig
```
