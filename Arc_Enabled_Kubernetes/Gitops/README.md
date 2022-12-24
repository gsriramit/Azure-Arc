## Enabling GitOps for the Arc-Enabled Kubernetes clusters

### Prerequisites
**Registering the necessary providers**
```
az feature register --namespace Microsoft.ContainerService --name AKS-GitOps

az provider register --namespace Microsoft.ContainerService

az provider register --namespace Microsoft.KubernetesConfiguration

az feature show --namespace Microsoft.ContainerService --name AKS-GitOps

az aks enable-addons -a gitops -n capi-controlplane -g capi-controlplane
```

### Imperative Method
The following azure cli command shows how to onboard a cluster to GitOps based on Flux v1 (this is an excerpt from Jorge's repository referenced in the main README file, within the Arc_Enabled_Kuberneted directory)  
```
GITOPS_CONFIG_NAME=""
CLUSTER_NAME=""
AZURE_RESOURCE_GROUP=""
OPERATOR_INSTANCE_NAME=""
OPERATOR_NAMESPACE="" # this will be the default namespace if not set
REPOSITORY_URL=""
OPS_SCOPE=""
CLUSTER_TYPE="" #this needs to be set to connectedClusters for arc-enabled clusters and managedClusters for AKS

az k8s-configuration create \
    --name $GITOPS_CONFIG_NAME --cluster-name $CLUSTER_NAME --resource-group $AZURE_RESOURCE_GROUP \
    --operator-instance-name $OPERATOR_INSTANCE_NAME --operator-namespace $OPERATOR_NAMESPACE \
    --repository-url $REPOSITORY_URL \
    --scope $OPS_SCOPE --cluster-type $CLUSTER_TYPE \
    --operator-params "--git-poll-interval 3s --git-readonly --git-path=workloads/ --git-branch main"

# Validation
clusterctl get kubeconfig ${CLUSTER_NAME} > ${CLUSTER_NAME}.kubeconfig
kubectl --kubeconfig=./${CLUSTER_NAME}.kubeconfig get pods -n default -w
```
#### Flux v2
Version 1 of flux will supposedly be sunset and the commands should be upgraded to flux-v2  
https://learn.microsoft.com/en-us/cli/azure/k8s-configuration/flux?view=azure-cli-latest

#### Onboarding AKS clusters to the same application update group
If the same app or microservice runs on the connected cluster and a managed cluster i.e. AKS, then the AKS cluster can also be onboarded to the same group of GitOps update. The --cluster-type parameter should be set to *connectedClusters*. As the path of the application deployment manifests is still going to be the same, the target clusters can be any and anywhere.

### Declarative Method
When onboarding clusters to GitOps through automation i.e. DevOps pipelines, the process involves deploying Flux agent to the cluster. The agent then communicates with the configured source control and then pulls and deploys the updates  
Flux manifest - https://raw.githubusercontent.com/gsriramit/Azure-Arc/main/Arc_Enabled_Kubernetes/Gitops/flux.yaml
