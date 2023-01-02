arcClusterName="capi-quickstart-v2"
customLocationName="$arcClusterName-appsvc" # Name of the custom location
arcResourceGroupName=capi-controlplane
extensionName=arc-app-services-capi
appsvcnamespace=appservices
appsvcPipName="$arcClusterName-appsvc-pip"

# Create a Public IP address to be used as the Public Static IP for our App Service Kubernetes environment. We'll assign that to a variable called staticIp.
az network public-ip create --resource-group $arcResourceGroupName --name $appsvcPipName --sku STANDARD
staticIp=$(az network public-ip show --resource-group $aksComponentsResourceGroupName --name $appsvcPipName --output tsv --query ipAddress)

# Obtain the Azure Arc enabled Kubernetes Cluster Resource ID. We'll need this for later Azure CLI commands.
connectedClusterId=$(az connectedk8s show --resource-group $arcResourceGroupName --name $arcClusterName --query id --output tsv)

# Now save the id property of the App Service Extension resource (created above) which is associated with your Azure Arc enabled Kubernetes Cluster. We'll need this later on, and saving it as a variable means that we can easily refer to it when we create the App Service Kubernetes Environment.
extensionId=$(az k8s-extension show \
--cluster-type connectedClusters \
--cluster-name $arcClusterName \
--resource-group $arcResourceGroupName \
--name $extensionName \
--query id \
--output tsv)

# Now create a custom location based upon the information we've been gathering over the course of this post
az customlocation create \
    --resource-group $arcResourceGroupName \
    --name $customLocationName \
    --host-resource-id $connectedClusterId \
    --namespace $appsvcnamespace \
    --cluster-extension-ids $extensionId

# The above resource should be created quite quickly. We'll need the Custom Location Resource ID for a later step, so let's go 
# ahead and assign it to a variable.
customLocationId=$(az customlocation show \
    --resource-group $arcResourceGroupName \
    --name $customLocationName \
    --query id \
    --output tsv)

# Let's double check that the variable was appropriately assigned and isn't empty.
echo $customLocationId

# For anyone interested, the below step is where I encountered issues when attempting to create an App Service Kubernetes Environment for
  # a local Kubernetes cluster. I believe it's due to the Static IP requirement. The command kept on 'running', though didn't seem to 
  # be doing anything. Instead, when I executed this for an Azure Kubernetes Service (AKS) environment with an accessible Public Static IP,
  # I had no issues. I'd love to hear if anyone tries this, or has any issues along the way. I'll update this as I receive further info.
  az appservice kube create \
      --resource-group $arcResourceGroupName \
      --name $arcClusterName \
      --custom-location $customLocationId \
      --static-ip $staticIp

  # Be prepared to wait. The above step took me a good few minutes to complete, so the below may not be available for some time.
  az appservice kube show \
    --resource-group $arcResourceGroupName \
    --name $arcClusterName