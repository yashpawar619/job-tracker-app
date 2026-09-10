{{/*
============================================================
_helpers.tpl — Reusable template snippets
============================================================
Called from other templates via {{ include "name" . }}
============================================================
*/}}

{{/*
Expand the name of the chart.
Used when you want just "java-app" (without release prefix).
*/}}
{{- define "java-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a fully qualified app name.
Format: <release-name>-<chart-name>, truncated to 63 chars (K8s limit).
Example: "my-release-java-app"
*/}}
{{- define "java-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart name and version — used as a label.
Example: "java-app-0.1.0"
*/}}
{{- define "java-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels — attached to EVERY resource in this chart.
Follows Kubernetes recommended labels convention:
https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/
*/}}
{{- define "java-app.labels" -}}
helm.sh/chart: {{ include "java-app.chart" . }}
{{ include "java-app.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Postgres selector labels — deliberately DISTINCT from the app's.
If the database reused "java-app.selectorLabels", the app's LoadBalancer
Service would match postgres pods too and route public traffic to them.
*/}}
{{- define "java-app.postgresSelectorLabels" -}}
app.kubernetes.io/name: {{ include "java-app.name" . }}-postgres
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Full label set for postgres resources.
*/}}
{{- define "java-app.postgresLabels" -}}
helm.sh/chart: {{ include "java-app.chart" . }}
{{ include "java-app.postgresSelectorLabels" . }}
app.kubernetes.io/component: database
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels — used by Deployment/Service to identify pods.
MUST be a subset of labels and MUST NOT change after creation
(K8s immutable field — changing this breaks upgrades).
*/}}
{{- define "java-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "java-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}