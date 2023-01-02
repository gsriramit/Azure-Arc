# Arc-Enabled App-Services
## Introduction
*What arc-enabled app services are*

## Architecture diagram
*Build an architecture on top of the one that is available for arc-enabled Kubernetes*

### Function of the pods enabling the app-services functionality
**copy the documentation table from the MS docs on the list of pods that run in the custom namespace*  
https://learn.microsoft.com/en-us/azure/app-service/overview-arc-integration#pods-created-by-the-app-service-extension

## References
Deployment of Arc-Enabled App Services using ARM template  
https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_app_svc/cluster_api/capi_azure/apps_service_arm_template/  

Reference to the GitHub repo with the ARM template and the associated scripts  
https://github.com/microsoft/azure_arc/tree/main/azure_arc_app_services_jumpstart/cluster_api/capi_azure/ARM  

Azure Arc architecture diagrams  
https://github.com/microsoft/azure_arc/tree/main/docs/ppt  

Deploying app services on an Arc-Enabled K8s cluster using Azure CLI  
https://www.cloudwithchris.com/blog/azure-arc-for-apps-part-2/  

Public Preview Limitations  
https://learn.microsoft.com/en-us/azure/app-service/overview-arc-integration#public-preview-limitations  

Installation of CSI Driver using Helm Charts
https://github.com/kubernetes-sigs/azuredisk-csi-driver/blob/master/charts/README.md

## Troubleshooting
- CSI driver had to be installed after the workload cluster was created. This is required so that the app-svc-buildse pod can create a persistent volume based on a persistent volume claim. The pod uses this to store the configuration of the app service
- A specific zone topology label has to be applied on the node so that the newly created Azure Managed Disk and the node are in the same availability zone. If this is missing, then the PV will not be bound to the PVC and the pod would still be in the pending state
- 