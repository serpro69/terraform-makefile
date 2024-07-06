# Copyright 2024- Serhii Prodanov
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

.ONESHELL:
.SHELL := /usr/bin/env bash
.SHELLFLAGS := -ec
.PHONY: apply destroy format help init lint plan-destroy plan
# Use below for reference on how to use variables in a Makefile:
# - https://www.gnu.org/software/make/manual/html_node/Using-Variables.html
# - https://www.gnu.org/software/make/manual/html_node/Flavors.html
# - https://www.gnu.org/software/make/manual/html_node/Setting.html
# - https://www.gnu.org/software/make/manual/html_node/Shell-Function.html
CURRENT_FOLDER=$(shell basename "$$(pwd)")
WORKSPACE ?= $(shell terraform workspace show)
GCP_PROJECT ?= $(shell gcloud config get project)
GCP_BASENAME ?= "wlcm"
BUCKET_PROJECT="$(BASENAME)-terraform-pla-23"
BUCKET_DIR="terraform/state"
FIRESTORE_TABLE="$(BASENAME)-$(WORKSPACE)-terraform"
TFVARS_PATH="vars/$(WORKSPACE).tfvars"
# Change output
# https://www.mankier.com/5/terminfo#Description-Highlighting,_Underlining,_and_Visible_Bells
# https://www.linuxquestions.org/questions/linux-newbie-8/tput-for-bold-dim-italic-underline-blinking-reverse-invisible-4175704737/#post6308097
RESET=$(shell tput sgr0)
BLINK=$(shell tput blink)
BOLD=$(shell tput bold)
DIM=$(shell tput dim)
SITM=$(shell tput sitm)
REV=$(shell tput rev)
SMSO=$(shell tput smso)
SMUL=$(shell tput smul)
# https://www.mankier.com/5/terminfo#Description-Color_Handling
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

help: ## Save our souls! 🛟
	@echo "This Makefile provides targets that wrap terraform commands while providing sane defaults for terraform environment"
	echo ""
	echo "Usage:\n$(BOLD)> GCP_PROJECT=demo WORKSPACE=demo make init\n> make plan$(RESET)"
	echo ""
	echo "$(DIM)$(SITM)Tip: Add a $(BLINK)<space>$(RESET) $(DIM)$(SITM)before the command if it contains sensitive information, to keep it from bash history$(RESET)"
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
	if [ ! -f "$(TFVARS_PATH)" ]; then \
		echo "$(BOLD)$(RED)Could not find variables file: $(TFVARS_PATH)$(RESET)"; \
		_ERROR=1; \
	 fi; \
	if [ ! -z "$${_ERROR}" ] && [ "$${_ERROR}" -eq 1 ]; then \
		# https://stackoverflow.com/a/3267187
		echo "$(BOLD)$(RED)Failed to set environment variables\nRun $(DIM)$(BLINK)make help$(RESET) $(BOLD)$(RED)for usage details$(RESET)"
		exit 1; \
	fi
	echo "$(BOLD)$(GREEN)Done setting environment variables$(RESET)"

init: set-env ## Hoist the sails and prepare for the voyage! 🌬️💨
	@echo "$(BOLD)Initializing terraform...$(RESET)"
	echo "$(BOLD)Checking GCP project...$(RESET)"
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
	_BUCKET_NAME=$$(gcloud storage buckets list --project $(BUCKET_PROJECT) --format='get(name)' | grep 'tfstate' | head -n1 | tr -d '[:space:]'); \
	_BUCKET_SUBDIR="test"; \
	if [ ! -z $(WORKSPACE) ] && [ "$(WORKSPACE)" = "prod" ]; then \
		_BUCKET_SUBDIR="prod"; \
	fi; \
	_BUCKET_PATH="$(BUCKET_DIR)/$${_BUCKET_SUBDIR}"
	echo "$(BOLD)Using bucket ($${_BUCKET_NAME}) with path ($${_BUCKET_PATH})$(RESET)"
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
		-backend-config="bucket=$${_BUCKET_NAME}" \
		-backend-config="prefix=$${_BUCKET_PATH}"

	echo "$(BOLD)Checking terraform workspace...$(RESET)"
	_CURRENT_WORKSPACE=$$(terraform workspace show | tr -d '[:space:]'); \
	if [ ! -z $(WORKSPACE) ] && [ "$(WORKSPACE)" != "$${_CURRENT_WORKSPACE}" ]; then \
	  echo "$(BOLD)Switching to workspace ($(WORKSPACE))$(RESET)"
		terraform workspace select $(WORKSPACE) || terraform workspace new $(WORKSPACE); \
	else
		echo "$(BOLD)$(CYAN)Using workspace ($${_CURRENT_WORKSPACE})$(RESET)"; \
	fi
	echo "$(BOLD)$(GREEN)Done initializing terraform$(RESET)"
	echo "$(BOLD)$(CYAN)You can now run other commands, for example:\nrun $(DIM)make plan$(RESET) $(BOLD)$(CYAN)to preview what terraform thinks it will do when applying changes,\nor $(DIM)make help$(RESET) $(BOLD)$(CYAN)to see all available make targets$(RESET)"

format: ## Swab the deck and tidy up! 🧹
	@terraform fmt \
		-write=true \
		-recursive

# https://github.com/terraform-linters/tflint
# https://github.com/liamg/tfsec
lint: ## Inspect the rigging and spot any issues! 🔍
	@tflint && tfsec .

plan: set-env ## Chart the course before you sail! 🗺️
	@terraform plan \
		-lock=true \
		-input=false \
		-refresh=true \
		-var-file="$(TFVARS_PATH)"

plan-destroy: set-env ## What would happen if we blow it all to smithereens? 💣
	@terraform plan \
		-input=false \
		-refresh=true \
		-destroy \
		-var-file="$(TFVARS_PATH)"

apply: set-env ## Set course and full speed ahead! ⛵ This will cost you! 💰
	@terraform apply \
		-lock=true \
		-input=false \
		-refresh=true \
		-var-file="$(TFVARS_PATH)"

destroy: set-env ## Release the Kraken! 🐙 This can't be undone! ☠️
	@terraform destroy \
		-lock=true \
		-input=false \
		-refresh=true \
		-var-file="$(TFVARS_PATH)"

