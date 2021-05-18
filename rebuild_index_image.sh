#!/bin/bash
set -ex

PACKAGE_NAME="kubevirt-hyperconverged"
IMAGE_REGISTRY=${IMAGE_REGISTRY:-quay.io}
IMAGE_NAMESPACE=${IMAGE_NAMESPACE:-tiraboschi}
INDEX_TAG="${INDEX_TAG:-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)}"
IMAGE_PREFIX="${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/${PACKAGE_NAME}"
IMAGE_BUNDLE="${IMAGE_PREFIX}-bundle"
IMAGE_INDEX="${IMAGE_PREFIX}-index"
OPM=${OPM:-opm}
PODMAN=${PODMAN:-podman}
OLM_MERMAID_GRAPH=olm-mermaid-graph

rm -rf _out
mkdir -p _out/

tmp_dir=$(mktemp -d -t tmp-XXXXXXXXXX)

versions=( $(find . -maxdepth 1 -mindepth 1 -type d -regex "./[0-9]\.[0-9]\.[0-9]" -exec basename {} \; | sort) )
printf -v bundlelist "${IMAGE_BUNDLE}:%s," "${versions[@]}"

for VERSION in "${versions[@]}"; do
    echo "--- ${VERSION} ---"
    ${PODMAN} build  --build-arg VERSION=${VERSION}  -t ${IMAGE_BUNDLE}:${VERSION} -f bundle.Dockerfile .
    ${PODMAN} push ${IMAGE_BUNDLE}:${VERSION}
done

echo "--- index ---"
opm index add --bundles  "${bundlelist%,}" --tag ${IMAGE_INDEX}:${INDEX_TAG}
${PODMAN} push ${IMAGE_INDEX}:${INDEX_TAG}

CNAME=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
${PODMAN} create --name=${CNAME} ${IMAGE_INDEX}:${INDEX_TAG}
${PODMAN} cp ${CNAME}:/database/index.db _out/index.db
${PODMAN} rm -f ${CNAME}

sed "s+olm_catalog_indexes/index.db.4.6.redhat-operators+_out/index.db+" index-mermaid-graph/sqlite3.sql > _out/sqlite3_exec.sql
sqlite3 -bail -init _out/sqlite3_exec.sql 2>/dev/null | ${OLM_MERMAID_GRAPH} ${PACKAGE_NAME} 1>_out/mermaid.mer
${PODMAN} pull docker.io/minlag/mermaid-cli
${PODMAN} run \
    -v $(pwd)/_out/mermaid.mer:/mermaid.mer:z \
    -v $(pwd)/index-mermaid-graph/config.json:/config.json:z \
    -v ${tmp_dir}:${tmp_dir}:z -it \
    docker.io/minlag/mermaid-cli:20210503120233a6e5e8 \
    -c /config.json -i /mermaid.mer -o ${tmp_dir}/${PACKAGE_NAME}-index-${INDEX_TAG}.png
cp ${tmp_dir}/${PACKAGE_NAME}-index-${INDEX_TAG}.png .
rm -rf ${tmp_dir}

echo "Your new index image is available at ${IMAGE_INDEX}:${INDEX_TAG}"
