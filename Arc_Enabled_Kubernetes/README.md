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
SUBSCRIPTIONID=""
az login
az account set --subscription $SUBSCRIPTIONID
az ad sp create-for-rbac -n "JumpstartArcK8s" --role "Contributor" --scopes /subscriptions/$SUBSCRIPTIONID
```
#### Installation of the required tools and dependencies

**Install Azure CLI (az)**
    curl -L https://aka.ms/InstallAzureCli | bash

### (Dependencies) Install Clusterctl
    //curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v0.4.4/clusterctl-linux-amd64 -o clusterctl
    curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.3.0/clusterctl-linux-arm64 -o clusterctl
    clusterctl version
    chmod +x ./clusterctl
    sudo mv ./clusterctl /usr/local/bin/clusterctl

### (Dependencies) Install Kubernetes CLIs
    az aks install-cli

### (Dependencies) Install Helm3 CLI
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh

### (Dependencies) Install/Update Extensions
    az extension list -o table

    az upgrade

    az extension add -n connectedk8s  or  az extension update -n connectedk8s

    az extension add -n k8s-configuration  or  az extension update -n k8s-configuration

    az extension add -n aks-preview  or  az extension update -n aks-preview
### (Management Cluster) Create AKS - Azure Kubernetes Services to install Cluster API management
    ### Create Azure resource Group on eastus regions where GitOps preview is available
    az group create -l eastus2 -n capi-controlplane
    
    # Create Azure Kubernetes Services (Edit Script with your IDs)
    az aks create --resource-group capi-controlplane --name capi-controlplane \
        --node-count 1 --node-vm-size Standard_D4s_v3 \
        --network-plugin azure --network-policy calico \
        --enable-addons monitoring,azure-policy \
        --enable-managed-identity --generate-ssh-keys \
        --vm-set-type VirtualMachineScaleSets --load-balancer-sku standard \
        --enable-aad --aad-admin-group-object-ids "bc14d443-d2c4-420d-ac61-22fc19eab6c0" \
        --max-pods 110 \
        --yes 