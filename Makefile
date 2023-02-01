short_ver = 2.18.0
long_ver = $(shell git describe --long 2>/dev/null || echo $(short_ver)-0-unknown-g`git describe --always`)
PYTHON ?= python3
PYTHON_DIRS = aiven tests
RPM=rpms/noarch/aiven-client-$(short_ver)-$(subst -,.,$(subst $(short_ver)-,,$(long_ver))).*.noarch.rpm

.PHONY: aiven/client/version.py
aiven/client/version.py:
	$(PYTHON) -m setuptools_scm

test: pytest
lint: flake8 mypy pylint

reformat:
	$(PYTHON) -m isort $(PYTHON_DIRS)
	$(PYTHON) -m black $(PYTHON_DIRS)

validate-style:
	$(eval CHANGES_BEFORE := $(shell mktemp))
	git diff > $(CHANGES_BEFORE)
	$(MAKE) reformat
	$(eval CHANGES_AFTER := $(shell mktemp))
	git diff > $(CHANGES_AFTER)
	diff $(CHANGES_BEFORE) $(CHANGES_AFTER)
	-rm $(CHANGES_BEFORE) $(CHANGES_AFTER)


flake8:
	$(PYTHON) -m flake8 $(PYTHON_DIRS)

mypy:
	$(PYTHON) -m mypy $(PYTHON_DIRS)

pylint:
	$(PYTHON) -m pylint $(PYTHON_DIRS)

pytest:
	$(PYTHON) -m pytest -vv tests/

coverage:
	$(PYTHON) -m coverage run --source aiven -m pytest $(PYTEST_ARG) tests/
	$(PYTHON) -m coverage report --show-missing

clean:
	$(RM) -r rpms

build-dep-fedora:
	sudo dnf install -y --best --allowerasing \
		black \
		python3-devel \
		python3-flake8 \
		python3-isort \
		python3-mypy \
		python3-pylint \
		python3-pytest \
		python3-requests \
		python3-types-requests \
		rpmdevtools \
		tar

.PHONY: rpm
rpm: $(RPM)

$(RPM):
	git archive --prefix=aiven-client/ HEAD -o rpm-src-aiven-client.tar
	# add generated files to the tar, they're not in git repository
	tar -r -f rpm-src-aiven-client.tar --transform=s,aiven/,aiven-client/aiven/, $(generated)
	rpmbuild -bb aiven-client.spec \
		--define '_sourcedir $(CURDIR)' \
		--define '_rpmdir $(PWD)/rpms' \
		--define 'major_version $(short_ver)' \
		--define 'minor_version $(subst -,.,$(subst $(short_ver)-,,$(long_ver)))'
	$(RM) rpm-src-aiven-client.tar

.PHONY: install-rpm
install-rpm: $(RPM)
	sudo dnf install $<

.PHONY: build-dep-fedora clean coverage pytest mypy pylint flake8 reformat test validate-style

