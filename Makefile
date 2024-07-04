# Copyright 2024- Serhii Prodanov
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

.ONESHELL:
.SHELL := /usr/bin/bash
.SHELLFLAGS := -ec
.PHONY: apply destroy-backend destroy destroy-target plan-destroy plan plan-target prep
VARS="vars/$(WORKSPACE).tfvars"
CURRENT_FOLDER=$(shell basename "$$(pwd)")
WORKSPACE ?= $(shell terraform workspace show)
GCP_PROJECT ?= $(shell gcloud config get project)
GCS_BUCKET_PROJECT="wlcm-terraform-pla-23"
GCS_BUCKET ?= $(shell gcloud storage buckets list --project $(GCS_BUCKET_PROJECT) --format="get(name)")
GCS_BUCKET_PREFIX="terraform/state"
FIRESTORE_TABLE="$(WORKSPACE)-wlcmtech-terraform"
BOLD=$(shell tput bold)
RED=$(shell tput setaf 1)
GREEN=$(shell tput setaf 2)
YELLOW=$(shell tput setaf 3)
RESET=$(shell tput sgr0)

# Check for necessary tools
ifeq (, $(shell which gcloud))
	$(error "No gcloud in $(PATH), go to https://cloud.google.com/sdk/docs/install, pick your OS, and follow the instructions")
endif
ifeq (, $(shell which jq))
	$(error "No jq in $(PATH), please install jq: https://github.com/jqlang/jq?tab=readme-ov-file#installation")
endif
ifeq (, $(shell which terraform))
	$(error "No terraform in $(PATH), get it from https://www.terraform.io/downloads.html")
endif

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

set-ws:
	@if [ -z $(WORKSPACE) ]; then \
		echo "$(BOLD)$(RED)WORKSPACE was not set$(RESET)"; \
		ERROR=1; \
	 fi
	@if [ ! -z $${ERROR} ] && [ $${ERROR} -eq 1 ]; then \
		echo "$(BOLD)Example usage: \`WORKSPACE=demo make plan\`$(RESET)"; \
		exit 1; \
	 fi
	@if [ ! -f "$(VARS)" ]; then \
		echo "$(BOLD)$(RED)Could not find variables file: $(VARS)$(RESET)"; \
		exit 1; \
	 fi

prep: set-ws ## Prepare a new workspace (environment) if needed, configure the tfstate backend, update any modules, and switch to the workspace
	@echo "$(BOLD)Checking GCP project...$(RESET)"
	CURRENT_PROJECT=$$(gcloud config get project | tr -d '[:space:]'); \
	if [ ! -z $(GCP_PROJECT) ] && [ "$(GCP_PROJECT)" != "$${CURRENT_PROJECT}" ]; then \
		read -p "$(BOLD)Current project $${CURRENT_PROJECT}. Do you want to switch project? [y/Y]: $(RESET)" ANSWER; \
		if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
			gcloud config set project $(GCP_PROJECT) && \
			gcloud auth login --update-adc ; \
	  	echo "$(BOLD)$(GREEN)Project changed to $(GCP_PROJECT)$(RESET)"; \
		else
			echo "$(BOLD)Using project ($${CURRENT_PROJECT})$(RESET)"; \
		fi; \
	else
		echo "$(BOLD)Project is set to ($${CURRENT_PROJECT})$(RESET)"; \
	fi

	echo "$(BOLD)Configuring the terraform backend...$(RESET)"
	BUCKET_POSTFIX="test"; \
	if [ ! -z $(WORKSPACE) ] && [ "$(WORKSPACE)" = "prod" ]; then \
		BUCKET_POSTFIX="prod"; \
	fi; \
	echo "$(BOLD)Using bucket postfix ($${BUCKET_POSTFIX})$(RESET)"; \
	terraform init \
		-reconfigure \
		-input=false \
		-force-copy \
		-lock=true \
		-upgrade \
		-backend=true \
		-backend-config="bucket=$(GCS_BUCKET)" \
		-backend-config="prefix=$(GCS_BUCKET_PREFIX)/$${BUCKET_POSTFIX}"

	echo "$(BOLD)Checking terraform wokrspace...$(RESET)"
	CURRENT_WORKSPACE=$$(terraform workspace show | tr -d '[:space:]'); \
	if [ ! -z $(WORKSPACE) ] && [ "$(WORKSPACE)" != "$${CURRENT_WORKSPACE}" ]; then \
		terraform workspace select $(WORKSPACE) || terraform workspace new $(WORKSPACE); \
	else
		echo "$(BOLD)Using workspace ($${CURRENT_WORKSPACE})$(RESET)"; \
	fi

