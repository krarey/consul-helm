#!/usr/bin/env bash

WD=$(dirname "$0")
WD=$(cd "$WD"; pwd)

set -eux

TEMPLATES="${WD}/../templates"
DASHBOARDS="${WD}/dashboards"
TMP=$(mktemp -d)

# create Prometheus template
helm template prometheus prometheus \
  --repo https://prometheus-community.github.io/helm-charts \
  --namespace "replace-me-namespace" \
  --version 13.2.1 \
  -f "${WD}/values/prometheus.yaml" \
  > "${TEMPLATES}/prometheus.yaml"

sed -i'.orig' 's/replace-me-namespace/{{ .Release.Namespace }}/g' "${TEMPLATES}/prometheus.yaml"
sed -i'.orig' '1i\
{{- if .Values.prometheus.enabled }}
' "${TEMPLATES}/prometheus.yaml"
sed -i'.orig' -e '$a\
{{- end }}' "${TEMPLATES}/prometheus.yaml"
rm "${TEMPLATES}/prometheus.yaml.orig"

# create Grafana template
{
  helm template grafana grafana \
    --repo https://grafana.github.io/helm-charts \
    --namespace "replace-me-namespace" \
    --version 6.2.1 \
    -f "${WD}/values/grafana.yaml"

  # Set up grafana dashboards and reduce to a single line json to avoid Kubernetes size limits
  < "${DASHBOARDS}/consul-server-monitoring.json" jq -c  > "${TMP}/consul-server-monitoring.json"
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