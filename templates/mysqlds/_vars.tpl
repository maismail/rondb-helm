{{- define "rondb.mysqldDataDir" -}}
{{ include "rondb.dataDir" $ }}/mysql
{{- end -}}

---

{{- define "rondb.helmSqlInitFile" -}}
helm-user-supplied.sql
{{- end -}}

---

{{- define "rondb.sqlInitScriptsDir" -}}
/srv/hops/docker/rondb_standalone/sql_init_scripts
{{- end -}}

{{- define "rondb.sqlRestoreScriptsDir" -}}
/srv/hops/docker/rondb_standalone/sql_init_scripts_restore
{{- end -}}

---

# A successful Pod can be removed; don't remove the successful Job itself though
{{- define "rondb.mysqldSetupJobName" -}}
setup-mysqld-dont-remove
{{- end -}}

{{- define "rondb.mysqldSetupServiceAccountName" -}}
restore-backup-watcher-sa
{{- end -}}

{{- define "rondb.mysqldSetupRole" -}}
restore-backup-watcher
{{- end -}}

{{- define "rondb.mysqldSetupRoleBinding" -}}
restore-backup-watcher-binding
{{- end -}}

---

{{- define "rondb.mysqldServiceAccountName" -}}
wait-init-jobs-sa
{{- end -}}

{{- define "rondb.mysqldRole" -}}
wait-init-jobs
{{- end -}}

{{- define "rondb.mysqldRoleBinding" -}}
wait-init-jobs-binding
{{- end -}}
