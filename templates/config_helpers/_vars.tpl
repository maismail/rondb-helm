{{- define "rondb.rcloneRestoreRemoteName" -}}
restoreRemote
{{- end -}}

{{- define "rondb.rcloneBackupRemoteName" -}}
backupRemote
{{- end -}}

{{- define "rondb.helmSqlInitFile" -}}
helm-user-supplied.sql
{{- end -}}

{{- define "rondb.mgmdHostname" -}}
{{ $.Values.meta.mgmd.statefulSetName }}-0.{{ $.Values.meta.mgmd.headlessClusterIp.name }}.{{ $.Release.Namespace }}.svc.cluster.local
{{- end -}}

{{- define "rondb.mysqldPodname" -}}
{{ printf "%s-0" $.Values.meta.mysqld.statefulSetName }}
{{- end -}}

{{- define "rondb.mysqldServiceHostname" -}}
{{ $.Values.meta.mysqld.service.name }}.{{ .Release.Namespace }}.svc.cluster.local
{{- end -}}

{{- define "rondb.rawRCloneConf" -}}
/home/hopsworks/rclone-raw.conf
{{- end -}}

{{- define "rondb.mysqldDataDir" -}}
/srv/hops/mysql-cluster/mysql
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

---

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

{{- define "rondb.restoreNativeBackupJobname" -}}
restore-native-backup
{{- end -}}

---

{{- define "rondb.sqlInitScriptsDir" -}}
/srv/hops/docker/rondb_standalone/sql_init_scripts
{{- end -}}

{{- define "rondb.sqlRestoreScriptsDir" -}}
/srv/hops/docker/rondb_standalone/sql_init_scripts_restore
{{- end -}}
