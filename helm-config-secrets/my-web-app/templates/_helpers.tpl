{{- define "my-web-app.name" -}}
{{ .Release.Name }}-{{ .Chart.Name }}
{{- end }}

## We can have different releases
#helm list -n helm-learning
#NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
#config-web      helm-learning   1               2026-09-30 09:34:20.216631811 -0500 CDT deployed        my-web-app-0.1.0        1.0        
#cpu-test        helm-learning   2               2026-09-28 15:47:53.462000636 -0500 CDT deployed        my-web-app-0.1.0        1.0        
#dev-web         helm-learning   25              2026-09-29 16:45:34.508057962 -0500 CDT deployed        my-web-app-0.1.0        1.0  

{{- define "my-web-app.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "my-web-app.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}