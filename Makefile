-include .shared/Makefile
.shared/Makefile:
	@git clone git@github.com:tmknom/shared-composite-actions.git .shared >/dev/null 2>&1

.PHONY: release
release: ## release new version
	@select LEBEL in 'patch' 'minor' 'major'; do \
	  case "$${LEBEL}" in \
		'patch') gh workflow run release.yml -f level=patch; break ;; \
		'minor') gh workflow run release.yml -f level=minor; break ;; \
		'major') gh workflow run release.yml -f level=major; break ;; \
		*) echo 'Error: invalid parameter'; exit 1 ;; \
	  esac; \
	done
