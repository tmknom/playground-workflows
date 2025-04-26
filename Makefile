-include .makefiles/test/Makefile
.makefiles/test/Makefile:
	@git clone https://github.com/tmknom/makefiles.git .makefiles >/dev/null 2>&1

.PHONY: docs
docs: ## Generate documentation for README
	$(ACTDOCS) --file=$(ACTION_DIR)/traceable-identifier-action/README.md $(ACTION_DIR)/traceable-identifier-action/action.yml
	@echo "Done: make docs"

ACTDOCS ?= $(SECURE_DOCKER_RUN) ghcr.io/tmknom/actdocs:latest inject --sort
ACTION_DIR ?= ./.github/actions
