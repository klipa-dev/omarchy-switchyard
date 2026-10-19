OMARCHY_PATH ?= /usr/share/omarchy

.PHONY: check lint test validate

check: lint test validate

lint:
	shellcheck -x $(wildcard bin/* lib/*.sh tests/*.bash)
	qmllint -I /usr/lib/qt6/qml -I $(OMARCHY_PATH)/shell $(wildcard *.qml)

test:
	bats tests/

validate:
	omarchy plugin validate $(CURDIR)
