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
.PHONY: apply destroy-backend destroy destroy-target plan-destroy plan plan-target init
CURRENT_FOLDER=$(shell basename "$$(pwd)")
WORKSPACE ?= $(shell terraform workspace show)
GCP_PROJECT ?= $(shell gcloud config get project)
GCS_BUCKET_PROJECT="wlcm-terraform-pla-23"
GCS_BUCKET_PREFIX="terraform/state"
FIRESTORE_TABLE="$(WORKSPACE)-wlcmtech-terraform"
TF_VARS="vars/$(WORKSPACE).tfvars"
# Change output
RESET=$(shell tput sgr0)
BOLD=$(shell tput bold)
# https://unix.stackexchange.com/a/269085
BLACK=$(shell tput setaf 0)
RED=$(shell tput setaf 1)
GREEN=$(shell tput setaf 2)
YELLOW=$(shell tput setaf 3)
BLUE=$(shell tput setaf 4)
MAGENTA=$(shell tput setaf 5)
CYAN=$(shell tput setaf 6)
WHITE=$(shell tput setaf 7)

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
	@echo "This Makefile provides targets that wrap terraform commands while providing sane defaults for terraform environment"
	echo ""
	echo "Usage:\n$(BOLD)GCP_PROJECT=demo WORKSPACE=demo make init$(RESET)"
	echo ""
	echo "Available commands:"
	echo ""
	grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

set-env:
	@echo "$(BOLD)Setting environment variables...$(RESET)"
	if [ -z $(WORKSPACE) ]; then \
		echo "$(BOLD)$(RED)WORKSPACE was not set$(RESET)"; \
		_ERROR=1; \
	fi; \
	if [ ! -f "$(TF_VARS)" ]; then \
		echo "$(BOLD)$(RED)Could not find variables file: $(TF_VARS)$(RESET)"; \
		_ERROR=1; \
	 fi; \
	if [ ! -z "$${_ERROR}" ] && [ "$${_ERROR}" -eq 1 ]; then \
		# https://stackoverflow.com/a/3267187
		echo "$(BOLD)$(RED)Failed to set environment variables$(RESET)"
		exit 1; \
	fi
	echo "$(BOLD)$(GREEN)Done setting environment variables$(RESET)"

init: set-env ## Init a new workspace (environment) if needed, configure the tfstate backend, update any modules, and switch to the workspace
	@echo "$(BOLD)Checking GCP project...$(RESET)"
	_CURRENT_PROJECT=$$(gcloud config get project | tr -d '[:space:]'); \
	if [ ! -z $(GCP_PROJECT) ] && [ "$(GCP_PROJECT)" != "$${_CURRENT_PROJECT}" ]; then \
		read -p "$(BOLD)$(MAGENTA)Current project $${_CURRENT_PROJECT}. Do you want to switch project? [y/Y]: $(RESET)" ANSWER; \
		if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
			gcloud config set project $(GCP_PROJECT) && \
			gcloud auth login --update-adc ; \
	  	echo "$(BOLD)$(GREEN)Project changed to $(GCP_PROJECT)$(RESET)"; \
		else
			echo "$(BOLD)$(CYAN)Using project ($${_CURRENT_PROJECT})$(RESET)"; \
		fi; \
	else
		read -p "$(BOLD)$(MAGENTA)Do you want to re-login and update ADC with ($${_CURRENT_PROJECT}) project? [y/Y]: $(RESET)" ANSWER; \
		if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
			gcloud auth login --update-adc ; \
		fi; \
		echo "$(BOLD)$(CYAN)Project is set to ($${_CURRENT_PROJECT})$(RESET)"; \
	fi

	echo "$(BOLD)Configuring the terraform backend...$(RESET)"
	_GCS_BUCKET=$$(gcloud storage buckets list --project $(GCS_BUCKET_PROJECT) --format='get(name)' | grep 'tfstate' | head -n1 | tr -d '[:space:]'); \
	_BUCKET_POSTFIX="test"; \
	if [ ! -z $(WORKSPACE) ] && [ "$(WORKSPACE)" = "prod" ]; then \
		_BUCKET_POSTFIX="prod"; \
	fi; \
	_BUCKET_PATH="$(GCS_BUCKET_PREFIX)/$${_BUCKET_POSTFIX}"
	echo "$(BOLD)Using bucket ($${_GCS_BUCKET}) with path ($${_BUCKET_PATH})$(RESET)"
	read -p "$(BOLD)$(MAGENTA)Do you want to proceed? [y/Y]: $(RESET)" ANSWER; \
	if [ "$${ANSWER}" != "y" ] && [ "$${ANSWER}" != "Y" ]; then \
		echo "$(BOLD)$(YELLOW)Exiting...$(RESET)"; \
		exit 0; \
	fi
	terraform init \
		-reconfigure \
		-input=false \
		-force-copy \
		-lock=true \
		-upgrade \
		-backend=true \
		-backend-config="bucket=$${_GCS_BUCKET}" \
		-backend-config="prefix=$${_BUCKET_PATH}"

	echo "$(BOLD)Checking terraform workspace...$(RESET)"
	_CURRENT_WORKSPACE=$$(terraform workspace show | tr -d '[:space:]'); \
	if [ ! -z $(WORKSPACE) ] && [ "$(WORKSPACE)" != "$${_CURRENT_WORKSPACE}" ]; then \
	  echo "$(BOLD)Switching to workspace ($(WORKSPACE))$(RESET)"
		terraform workspace select $(WORKSPACE) || terraform workspace new $(WORKSPACE); \
	else
		echo "$(BOLD)$(CYAN)Using workspace ($${_CURRENT_WORKSPACE})$(RESET)"; \
	fi

format: ## Rewrites all Terraform configuration files to a canonical format.
	@terraform fmt \
		-write=true \
		-recursive

# https://github.com/terraform-linters/tflint
# https://github.com/liamg/tfsec
lint: ## Lint the code and run static analysis to spot potential security issues.
	@tflint && tfsec .

