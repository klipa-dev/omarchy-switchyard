.PHONY: check lint test validate

check: lint test validate

lint:
	shellcheck -x $(wildcard bin/* lib/*.sh tests/*.bash)
	qmllint $(wildcard *.qml)

test:
	bats tests/

validate:
	omarchy plugin validate $(CURDIR)
