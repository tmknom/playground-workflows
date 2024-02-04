-include .makefiles/reusable-workflows/Makefile
.makefiles/reusable-workflows/Makefile:
	@git clone https://github.com/tmknom/makefiles.git .makefiles >/dev/null 2>&1

.PHONY: docs
docs: ## Generate documentation for README
	$(ACTDOCS) inject --sort --file=$(ACTION_DIR)/yamllint-action/first/tmp/README.md $(ACTION_DIR)/yamllint-action/first/action.yml
	$(ACTDOCS) inject --sort --file=$(ACTION_DIR)/yamllint-action/second/tmp/README.md $(ACTION_DIR)/yamllint-action/second/action.yml
	$(ACTDOCS) inject --sort --file=$(ACTION_DIR)/git-push-action/tmp/README.md $(ACTION_DIR)/git-push-action/action.yml
	@echo "Done: make docs"

ACTDOCS ?= $(SECURE_DOCKER_RUN) ghcr.io/tmknom/actdocs:latest
ACTION_DIR ?= ./.github/actions
