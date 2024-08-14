{{- define "rondb.rcloneRestoreRemoteName" -}}
restoreRemote
{{- end -}}

{{- define "rondb.rcloneBackupRemoteName" -}}
backupRemote
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

{{- define "rondb.restoreNativeBackupJobname" -}}
restore-native-backup
{{- end -}}
