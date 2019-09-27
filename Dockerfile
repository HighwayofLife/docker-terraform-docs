FROM golang:alpine3.9 as builder

# Install dependencies
RUN set -x \
	&& apk add --no-cache \
		curl \
		gcc \
		git \
		make \
		musl-dev \
	&& curl https://raw.githubusercontent.com/golang/dep/master/install.sh | sh

# Get and build terraform-docs
ARG VERSION=latest
ARG GOOS=linux
ARG GOARCH=amd64

RUN set -x \
	&& export GOPATH=/go \
	&& mkdir -p /go/src/github.com/segmentio \
	&& git clone https://github.com/segmentio/terraform-docs /go/src/github.com/segmentio/terraform-docs \
	&& cd /go/src/github.com/segmentio/terraform-docs \
	&& if [ "${VERSION}" != "latest" ]; then \
		git checkout v${VERSION}; \
	fi \
	# Build terraform-docs <= 0.3.0
	&& if [ "${VERSION}" = "0.3.0" ] || [ "${VERSION}" = "0.2.0" ] || [ "${VERSION}" = "0.1.1" ] || [ "${VERSION}" = "0.1.0" ]; then \
		go get github.com/hashicorp/hcl \
		&& go get github.com/mitchellh/gox \
		&& go get github.com/tj/docopt \
		&& sed -i'' 's/darwin//g' Makefile \
		&& sed -i'' 's/windows//g' Makefile \
		&& make \
		&& mv dist/terraform-docs_linux_amd64 /usr/local/bin/terraform-docs; \
	# Build terraform-docs > 0.3.0
	else \
		make vendor \
		&& make test \
		&& make build \
		&& if [ "${VERSION}" = "0.4.0" ]; then \
			mv bin/terraform-docs-v${VERSION}-linux-amd64 /usr/local/bin/terraform-docs; \
		else \
			mv bin/linux-amd64/terraform-docs /usr/local/bin/terraform-docs; \
		fi \
	fi \
	&& chmod +x /usr/local/bin/terraform-docs

# Version pre-check
RUN set -x \
	&& if [ "${VERSION}" != "latest" ]; then \
		terraform-docs --version | grep "${VERSION}"; \
	else \
		terraform-docs --version | grep -E "terraform-docs\s+version\s+(.*?)\s"; \
	fi


# Use a clean tiny image to store artifacts in
FROM alpine:3.8
LABEL \
	maintainer="cytopia <cytopia@everythingcli.org>" \
	repo="https://github.com/cytopia/docker-terraform-docs"
COPY --from=builder /usr/local/bin/terraform-docs /usr/local/bin/terraform-docs
COPY ./data/docker-entrypoint.sh /docker-entrypoint.sh
COPY ./data/terraform-docs.awk /terraform-docs.awk

ENV WORKDIR /data
WORKDIR /data

CMD ["terraform-docs", "--version"]
ENTRYPOINT ["/docker-entrypoint.sh"]
