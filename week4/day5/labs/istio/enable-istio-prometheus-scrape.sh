#!/usr/bin/env bash
set -euo pipefail

PROM_NAMESPACE="${PROM_NAMESPACE:-monitoring}"
PROM_NAME="${PROM_NAME:-kube-prometheus-stack-prometheus}"
SECRET_NAME="${SECRET_NAME:-istio-additional-scrape-configs}"
SECRET_KEY="${SECRET_KEY:-prometheus-additional.yaml}"
MESH_NAMESPACES="${MESH_NAMESPACES:-mesh-demo mesh-msa-demo}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

scrape_config="${tmp_dir}/${SECRET_KEY}"
patch_file="${tmp_dir}/prometheus-patch.json"

{
  cat <<'YAML'
- job_name: kubernetes-pods-istio
  kubernetes_sd_configs:
    - role: pod
      namespaces:
        names:
YAML
  for namespace in ${MESH_NAMESPACES}; do
    printf '          - %s\n' "${namespace}"
  done
  cat <<'YAML'
  relabel_configs:
    - action: keep
      source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
      regex: true
    - action: replace
      source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
      target_label: __metrics_path__
      regex: (.+)
    - action: replace
      source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
      target_label: __address__
      regex: ([^:]+)(?::\d+)?;(\d+)
      replacement: $1:$2
    - action: labelmap
      regex: __meta_kubernetes_pod_label_(.+)
    - action: replace
      source_labels: [__meta_kubernetes_namespace]
      target_label: namespace
    - action: replace
      source_labels: [__meta_kubernetes_pod_name]
      target_label: pod
YAML
} >"${scrape_config}"

kubectl -n "${PROM_NAMESPACE}" create secret generic "${SECRET_NAME}" \
  --from-file="${SECRET_KEY}=${scrape_config}" \
  --dry-run=client \
  -o yaml \
  | kubectl apply -f -

cat >"${patch_file}" <<JSON
{
  "spec": {
    "additionalScrapeConfigs": {
      "name": "${SECRET_NAME}",
      "key": "${SECRET_KEY}"
    }
  }
}
JSON

kubectl -n "${PROM_NAMESPACE}" patch prometheus "${PROM_NAME}" \
  --type merge \
  --patch-file "${patch_file}"

echo "[prometheus] Istio pod scrape config enabled for namespaces: ${MESH_NAMESPACES}"
echo "[prometheus] Wait 30-60 seconds, then query: istio_requests_total"
