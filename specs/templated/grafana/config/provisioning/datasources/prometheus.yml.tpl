---
apiVersion: 1

deleteDatasources:
  - name: prometheus
    orgId: 1

datasources:
  - name: prometheus
    type: prometheus
    access: direct
    orgId: 1
    url: http://{{ range $i, $s := service "prometheus-svc" }}{{ if eq $i 0 }}{{.Address}}:{{.Port}}{{end}}{{end}}
    user:
    password:
    database:
    basicAuth: false
    basicAuthUser:
    basicAuthPassword:
    isDefault: true
    jsonData:
      httpMethod: GET
    editable: true
