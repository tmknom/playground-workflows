-include .makefiles/reusable-workflows/Makefile
.makefiles/reusable-workflows/Makefile:
	@git clone https://github.com/tmknom/makefiles.git .makefiles >/dev/null 2>&1

.PHONY: docs
docs: ## Generate documentation for README
	$(ACTDOCS) inject --sort --file=$(ACTION_DIR)/git-config-action/tmp/README.md $(ACTION_DIR)/git-config-action/action.yml
	$(ACTDOCS) inject --sort --file=$(ACTION_DIR)/labeler-action/first/tmp/README.md $(ACTION_DIR)/labeler-action/first/action.yml
	$(ACTDOCS) inject --sort --file=$(ACTION_DIR)/labeler-action/second/tmp/README.md $(ACTION_DIR)/labeler-action/second/action.yml
	$(ACTDOCS) inject --sort --file=$(ACTION_DIR)/labeler-action/third/tmp/README.md $(ACTION_DIR)/labeler-action/third/action.yml
	$(ACTDOCS) inject --sort --file=$(ACTION_DIR)/yamllint-action/first/tmp/README.md $(ACTION_DIR)/yamllint-action/first/action.yml
	$(ACTDOCS) inject --sort --file=$(ACTION_DIR)/yamllint-action/second/tmp/README.md $(ACTION_DIR)/yamllint-action/second/action.yml
	@echo "Done: make docs"

ACTDOCS ?= $(SECURE_DOCKER_RUN) ghcr.io/tmknom/actdocs:latest
ACTION_DIR ?= ./.github/actions
