#!/usr/bin/env bash

WD=$(dirname "$0")
WD=$(cd "$WD"; pwd)

set -eux

# This script sets up the plain text rendered deployments for addons
# See samples/addons/README.md for more information

TEMPLATES="${WD}/../templates"
DASHBOARDS="${WD}/dashboards"
TMP=$(mktemp -d)

# Set up prometheus
helm template prometheus prometheus \
  --namespace "replace-me-namespace" \
  --version 13.2.1 \
  --repo https://prometheus-community.github.io/helm-charts \
  -f "${WD}/values-prometheus.yaml" \
  > "${TEMPLATES}/prometheus.yaml"

sed -i'.orig' 's/replace-me-namespace/{{ .Release.Namespace }}/g' "${TEMPLATES}/prometheus.yaml"
sed -i'.orig' '1i\
{{- if .Values.prometheus.enabled }}
' "${TEMPLATES}/prometheus.yaml"
sed -i'.orig' -e '$a\
{{- end }}' "${TEMPLATES}/prometheus.yaml"
rm "${TEMPLATES}/prometheus.yaml.orig"

function compressDashboard() {
  < "${DASHBOARDS}/$1" jq -c  > "${TMP}/$1"
}

# Set up grafana
{
  helm template grafana grafana \
    --namespace "replace-me-namespace" \
    --version 6.2.1 \
    --repo https://grafana.github.io/helm-charts \
    -f "${WD}/values-grafana.yaml"

  # Set up grafana dashboards. Compress to single line json to avoid Kubernetes size limits
  compressDashboard "consul-server-monitoring.json"
  echo -e "\n---\n"
  kubectl create configmap -n "replace-me-namespace" consul-grafana-dashboards \
    --dry-run=client -oyaml \
    --from-file=consul-server-monitoring.json="${TMP}/consul-server-monitoring.json"

} > "${TEMPLATES}/grafana.yaml"

sed -i'.orig' 's/replace-me-namespace/{{ .Release.Namespace }}/g' "${TEMPLATES}/grafana.yaml"
sed -i'.orig' '1i\
{{- if .Values.grafana.enabled }}
' "${TEMPLATES}/grafana.yaml"
sed -i'.orig' -e '$a\
{{- end }}' "${TEMPLATES}/grafana.yaml"
rm "${TEMPLATES}/grafana.yaml.orig"