SHELL              := $(shell which bash)

NO_COLOR           := \033[0m
OK_COLOR           := \033[32;01m
ERR_COLOR          := \033[31;01m
WARN_COLOR         := \033[36;01m
ATTN_COLOR         := \033[33;01m

EXT_DIR            := ./.ext
EXT_BIN_DIR        := ${EXT_DIR}/bin
EXT_TMP_DIR        := ${EXT_DIR}/tmp
DEPLOY_DIR         := ./deploy

GOOS               := $(shell go env GOOS)
GOARCH             := $(shell go env GOARCH)

EXT_DIR            := ./.ext
EXT_BIN_DIR        := ${EXT_DIR}/bin
EXT_TMP_DIR        := ${EXT_DIR}/tmp

.DEFAULT_GOAL      := build

POLICY_NAME        := policy-rebac
TOPAZ_IMAGE        := ghcr.io/aserto-dev/topaz:0.32.23
DIRECTORY_SVC      := directory.prod.aserto.com:8443
DIRECTORY_HTTP_SVC := https://directory.prod.aserto.com
DISCOVERY_SVC      := https://discovery.prod.aserto.com/api/v2/discovery

RG_NAME            := topaz-demo-rg
RG_LOCATION        := eastus

CG_NAME_STATEFULL  := topaz-cg-1
CONFIG_STATEFULL   := config-statefull.yaml
DEPLOY_STATEFULL   := ${DEPLOY_DIR}/topaz-deploy-aci-statefull.yaml
TEMPLATE_STATEFULL := topaz-deploy-aci-statefull.tmpl.yaml
DNS_STATEFULL      := topaz-svc-1
HOST_STATEFULL     := ${DNS_STATEFULL}.${RG_LOCATION}.azurecontainer.io
FQDN_STATEFULL     := "https://${HOST_STATEFULL}"

CG_NAME_STATELESS  := topaz-cg-2
CONFIG_STATELESS   := config-stateless.yaml
DEPLOY_STATELESS   := ${DEPLOY_DIR}/topaz-deploy-aci-stateless.yaml
TEMPLATE_STATELESS := topaz-deploy-aci-stateless.tmpl.yaml
DNS_STATELESS      := topaz-svc-2
HOST_STATELESS     := ${DNS_STATELESS}.${RG_LOCATION}.azurecontainer.io
FQDN_STATELESS     := "https://${HOST_STATELESS}"

.PHONY: deps
deps: info install-vault install-svu install-yq
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"

.PHONY: info
info:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@echo "GOOS:        ${GOOS}"
	@echo "GOARCH:      ${GOARCH}"
	@echo "EXT_DIR:     ${EXT_DIR}"
	@echo "EXT_BIN_DIR: ${EXT_BIN_DIR}"
	@echo "EXT_TMP_DIR: ${EXT_TMP_DIR}"
	@echo "RELEASE_TAG: ${RELEASE_TAG}"
	@echo "RG_NAME:     ${RG_NAME}"
	@echo "RG_LOCATION: ${RG_LOCATION}"
	@echo "CG_NAME:     ${CG_NAME}"
	@echo "POLICY_NAME: ${POLICY_NAME}"
	
.PHONY: create-resource-group
create-resource-group:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	az group create --name ${RG_NAME} --location ${RG_LOCATION}

.PHONY: delete-resource-group
delete-resource-group:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	az group delete --name ${RG_NAME} --yes

.PHONY: create-container-statefull
create-container-statefull: ${DEPLOY_STATEFULL}
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	az container create --resource-group ${RG_NAME} --name ${CG_NAME_STATEFULL} --file ${DEPLOY_STATEFULL}

.PHONY: delete-container-statefull
delete-container-statefull:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	az container delete --resource-group ${RG_NAME} --name ${CG_NAME_STATEFULL} --yes

.PHONY: create-container-stateless
create-container-stateless: ${DEPLOY_STATELESS}
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	az container create --resource-group ${RG_NAME} --name ${CG_NAME_STATELESS} --file ${DEPLOY_STATELESS}

.PHONY: delete-container-stateless
delete-container-stateless:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	az container delete --resource-group ${RG_NAME} --name ${CG_NAME_STATELESS} --yes

${DEPLOY_DIR}/sidecar.crt:
${DEPLOY_DIR}/sidecar.key: ${DEPLOY_DIR}
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	aserto cp get certificates $$(aserto tn list connections --kind=PROVIDER_KIND_EDGE_AUTHORIZER | jq -r '.results[] | (select(.name | contains ("aci-topaz-demo") | . ) | .id)') --directory ${DEPLOY_DIR}

.PHONY: expand-template-statefull
expand-template-statefull: ${DEPLOY_DIR} ${DEPLOY_DIR}/sidecar.crt ${DEPLOY_DIR}/sidecar.key ${CONFIG_STATEFULL}
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@cp ./${TEMPLATE_STATEFULL} ./${DEPLOY_STATEFULL}
	
	RG_LOCATION=${RG_LOCATION} ${EXT_BIN_DIR}/yq -i '.location = strenv(RG_LOCATION)' ${DEPLOY_STATEFULL}
	CG_NAME_STATEFULL=${CG_NAME_STATEFULL} ${EXT_BIN_DIR}/yq -i '.name = strenv(CG_NAME_STATEFULL)' ${DEPLOY_STATEFULL}

	TOPAZ_IMAGE=${TOPAZ_IMAGE} ${EXT_BIN_DIR}/yq -i '.properties.containers[0].properties.image = strenv(TOPAZ_IMAGE)' ${DEPLOY_STATEFULL}

	DIRECTORY_SVC=${DIRECTORY_SVC} ${EXT_BIN_DIR}/yq -i '.properties.containers[0].properties.environmentVariables[0].value = strenv(DIRECTORY_SVC)' ${DEPLOY_STATEFULL}
	DIRECTORY_KEY=$$(aserto user get directory-read-key) ${EXT_BIN_DIR}/yq -i '.properties.containers[0].properties.environmentVariables[1].secureValue = strenv(DIRECTORY_KEY)' ${DEPLOY_STATEFULL}

	DISCOVERY_SVC=${DISCOVERY_SVC} ${EXT_BIN_DIR}/yq -i '.properties.containers[0].properties.environmentVariables[2].value = strenv(DISCOVERY_SVC)' ${DEPLOY_STATEFULL}
	DISCOVERY_KEY=$$(aserto user get discovery-key) ${EXT_BIN_DIR}/yq -i '.properties.containers[0].properties.environmentVariables[3].secureValue = strenv(DISCOVERY_KEY)' ${DEPLOY_STATEFULL}

	TENANT_ID=$$(aserto user get tenant-id) ${EXT_BIN_DIR}/yq -i '.properties.containers[0].properties.environmentVariables[4].secureValue = strenv(TENANT_ID)' ${DEPLOY_STATEFULL}

	POLICY_NAME=${POLICY_NAME} ${EXT_BIN_DIR}/yq -i '.properties.containers[0].properties.environmentVariables[5].value = strenv(POLICY_NAME)' ${DEPLOY_STATEFULL}
	
	FQDN_STATEFULL=${FQDN_STATEFULL} ${EXT_BIN_DIR}/yq -i '.properties.containers[0].properties.environmentVariables[6].value = strenv(FQDN_STATEFULL)' ${DEPLOY_STATEFULL}

	CONFIG_STATEFULL=$$(cat ${CONFIG_STATEFULL} | base64) ${EXT_BIN_DIR}/yq -i '.properties.volumes[0].secret."config.yaml" = strenv(CONFIG_STATEFULL)' ${DEPLOY_STATEFULL}
	
	SIDECAR_CRT=$$(cat ${DEPLOY_DIR}/sidecar.crt | base64) ${EXT_BIN_DIR}/yq -i '.properties.volumes[1].secret."sidecar.crt" = strenv(SIDECAR_CRT)' ${DEPLOY_STATEFULL}
	SIDECAR_KEY=$$(cat ${DEPLOY_DIR}/sidecar.key | base64) ${EXT_BIN_DIR}/yq -i '.properties.volumes[1].secret."sidecar.key" = strenv(SIDECAR_KEY)' ${DEPLOY_STATEFULL}

	DNS_STATEFULL=${DNS_STATEFULL} ${EXT_BIN_DIR}/yq -i '.properties.ipAddress.dnsNameLabel = strenv(DNS_STATEFULL)' ${DEPLOY_STATEFULL}

.PHONY: expand-template-stateless
expand-template-stateless: ${DEPLOY_DIR} ${DEPLOY_DIR}/sidecar.crt ${DEPLOY_DIR}/sidecar.key ${CONFIG_STATELESS}
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@cp ./${TEMPLATE_STATELESS} ./${DEPLOY_STATELESS}
	
	RG_LOCATION=${RG_LOCATION} ${EXT_BIN_DIR}/yq -i '.location = strenv(RG_LOCATION)' ${DEPLOY_STATELESS}
	CG_NAME_STATELESS=${CG_NAME_STATELESS} ${EXT_BIN_DIR}/yq -i '.name = strenv(CG_NAME_STATELESS)' ${DEPLOY_STATELESS}

	TOPAZ_IMAGE=${TOPAZ_IMAGE} ${EXT_BIN_DIR}/yq -i '.properties.containers[0].properties.image = strenv(TOPAZ_IMAGE)' ${DEPLOY_STATELESS}

	DIRECTORY_SVC=${DIRECTORY_SVC} ${EXT_BIN_DIR}/yq -i '.properties.containers[0].properties.environmentVariables[0].value = strenv(DIRECTORY_SVC)' ${DEPLOY_STATELESS}
	DIRECTORY_KEY=$$(aserto user get directory-read-key) ${EXT_BIN_DIR}/yq -i '.properties.containers[0].properties.environmentVariables[1].secureValue = strenv(DIRECTORY_KEY)' ${DEPLOY_STATELESS}

	DISCOVERY_SVC=${DISCOVERY_SVC} ${EXT_BIN_DIR}/yq -i '.properties.containers[0].properties.environmentVariables[2].value = strenv(DISCOVERY_SVC)' ${DEPLOY_STATELESS}
	DISCOVERY_KEY=$$(aserto user get discovery-key) ${EXT_BIN_DIR}/yq -i '.properties.containers[0].properties.environmentVariables[3].secureValue = strenv(DISCOVERY_KEY)' ${DEPLOY_STATELESS}

	TENANT_ID=$$(aserto user get tenant-id) ${EXT_BIN_DIR}/yq -i '.properties.containers[0].properties.environmentVariables[4].secureValue = strenv(TENANT_ID)' ${DEPLOY_STATELESS}

	POLICY_NAME=${POLICY_NAME} ${EXT_BIN_DIR}/yq -i '.properties.containers[0].properties.environmentVariables[5].value = strenv(POLICY_NAME)' ${DEPLOY_STATELESS}

	FQDN_STATELESS=${FQDN_STATELESS} ${EXT_BIN_DIR}/yq -i '.properties.containers[0].properties.environmentVariables[6].value = strenv(FQDN_STATELESS)' ${DEPLOY_STATELESS}

	CONFIG_STATELESS=$$(cat ${CONFIG_STATELESS} | base64) ${EXT_BIN_DIR}/yq -i '.properties.volumes[0].secret."config.yaml" = strenv(CONFIG_STATELESS)' ${DEPLOY_STATELESS}
	
	SIDECAR_CRT=$$(cat ${DEPLOY_DIR}/sidecar.crt | base64) ${EXT_BIN_DIR}/yq -i '.properties.volumes[1].secret."sidecar.crt" = strenv(SIDECAR_CRT)' ${DEPLOY_STATELESS}
	SIDECAR_KEY=$$(cat ${DEPLOY_DIR}/sidecar.key | base64) ${EXT_BIN_DIR}/yq -i '.properties.volumes[1].secret."sidecar.key" = strenv(SIDECAR_KEY)' ${DEPLOY_STATELESS}

	DNS_STATELESS=${DNS_STATELESS} ${EXT_BIN_DIR}/yq -i '.properties.ipAddress.dnsNameLabel = strenv(DNS_STATELESS)' ${DEPLOY_STATELESS}

.PHONY: run-ds-test-statefull
run-ds-test-statefull:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	aserto ds test exec ./assertions/gdrive_assertions.json --host=${HOST_STATEFULL}:8443 --insecure

.PHONY: run-az-test-statefull
run-az-test-statefull:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	aserto az test exec ./assertions/gdrive_decisions.json --host=${HOST_STATEFULL}:8443  --insecure

.PHONY: run-ds-test-stateless
run-ds-test-stateless:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@echo directory endpoint not enabled in stateless mode
	
.PHONY: run-az-test-stateless
run-az-test-stateless:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	aserto az test exec ./assertions/gdrive_decisions.json --host=${HOST_STATELESS}:8443  --insecure

.PHONY: install-yq
install-yq: ${EXT_TMP_DIR} ${EXT_BIN_DIR}
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@gh release download --repo https://github.com/mikefarah/yq --pattern "yq_${GOOS}_${GOARCH}" --output "${EXT_BIN_DIR}/yq" --clobber
	@chmod +x ${EXT_BIN_DIR}/yq
	@${EXT_BIN_DIR}/yq --version 

.PHONY: clean
clean:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@rm -rf ${EXT_DIR}
	@rm -rf ${DEPLOY_DIR}

${DEPLOY_DIR}:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@mkdir -p ${DEPLOY_DIR}

${EXT_BIN_DIR}:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@mkdir -p ${EXT_BIN_DIR}

${EXT_TMP_DIR}:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@mkdir -p ${EXT_TMP_DIR}
