# topaz-cfg

Steps 

```
ACI_PERS_RESOURCE_GROUP=dev-container-apps
ACI_PERS_STORAGE_ACCOUNT_NAME=devcontainerstorage1
ACI_PERS_LOCATION=eastus
ACI_PERS_SHARE_NAME=topaz-test-1-share

DIRECTORY_SVC=directory.prod.aserto.com:8443
DIRECTORY_KEY=<REDACTED directory read-only api-key>
TENANT_ID=<REDACTED tenant-id>

az storage account create \
    --resource-group $ACI_PERS_RESOURCE_GROUP \
    --name $ACI_PERS_STORAGE_ACCOUNT_NAME \
    --location $ACI_PERS_LOCATION \
    --sku Standard_LRS

az storage share create \
  --name $ACI_PERS_SHARE_NAME \
  --account-name $ACI_PERS_STORAGE_ACCOUNT_NAME

STORAGE_KEY=$(az storage account keys list --resource-group $ACI_PERS_RESOURCE_GROUP --account-name $ACI_PERS_STORAGE_ACCOUNT_NAME --query "[0].value" --output tsv)

az container create \
  --resource-group $ACI_PERS_RESOURCE_GROUP \
  --name topaz-test-1  \
  --image ghcr.io/aserto-dev/topaz:aci-v31 \
  --dns-name-label topaz-test-1 \
  --cpu 2 \
  --memory 4 \
  --environment-variables DIRECTORY_SVC=${DIRECTORY_SVC} DIRECTORY_KEY=${DIRECTORY_KEY} TENANT_ID=${TENANT_ID} TOPAZ_DIR=/topaz_dir \
  --ports 8080 8282 8383 9292 9393 \
  --azure-file-volume-account-name $ACI_PERS_STORAGE_ACCOUNT_NAME \
  --azure-file-volume-account-key $STORAGE_KEY \
  --azure-file-volume-share-name $ACI_PERS_SHARE_NAME \
  --azure-file-volume-mount-path /topaz_dir
```

```
ACI_PERS_RESOURCE_GROUP=dev-container-apps
ACI_PERS_STORAGE_ACCOUNT_NAME=devcontainerstorage1
ACI_PERS_LOCATION=eastus
ACI_PERS_SHARE_NAME=topaz-test-2-share

DIRECTORY_SVC=directory.prod.aserto.com:8443
DIRECTORY_KEY=<REDACTED directory read-only api-key>
TENANT_ID=<REDACTED tenant-id>

az storage account create \
    --resource-group $ACI_PERS_RESOURCE_GROUP \
    --name $ACI_PERS_STORAGE_ACCOUNT_NAME \
    --location $ACI_PERS_LOCATION \
    --sku Standard_LRS

az storage share create \
  --name $ACI_PERS_SHARE_NAME \
  --account-name $ACI_PERS_STORAGE_ACCOUNT_NAME

STORAGE_KEY=$(az storage account keys list --resource-group $ACI_PERS_RESOURCE_GROUP --account-name $ACI_PERS_STORAGE_ACCOUNT_NAME --query "[0].value" --output tsv)

az container create \
  --resource-group $ACI_PERS_RESOURCE_GROUP \
  --name topaz-test-2  \
  --image ghcr.io/aserto-dev/topaz:aci-v31 \
  --dns-name-label topaz-test-2 \
  --cpu 2 \
  --memory 4 \
  --environment-variables DIRECTORY_SVC=${DIRECTORY_SVC} DIRECTORY_KEY=${DIRECTORY_KEY} TENANT_ID=${TENANT_ID} TOPAZ_DIR=/topaz_dir \
  --ports 8080 8282 8383 9292 9393 \
  --azure-file-volume-account-name $ACI_PERS_STORAGE_ACCOUNT_NAME \
  --azure-file-volume-account-key $STORAGE_KEY \
  --azure-file-volume-share-name $ACI_PERS_SHARE_NAME \
  --azure-file-volume-mount-path /topaz_dir

```