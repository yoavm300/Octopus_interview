{{- define "apples-app.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{- define "apples-app.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "apples-app.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "apples-app.labels" -}}
app.kubernetes.io/name: {{ include "apples-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "apples-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "apples-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
