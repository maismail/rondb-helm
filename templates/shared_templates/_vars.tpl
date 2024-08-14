{{- define "rondb.rcloneRestoreRemoteName" -}}
restoreRemote
{{- end -}}

{{- define "rondb.rcloneBackupRemoteName" -}}
backupRemote
{{- end -}}

{{- define "rondb.mgmdHostname" -}}
{{ printf "%s-0.%s.%s.svc.cluster.local"
        $.Values.meta.mgmd.statefulSetName
        $.Values.meta.mgmd.headlessClusterIp.name
        $.Release.Namespace
}}
{{- end -}}

{{- define "rondb.mysqldPodname" -}}
{{ printf "%s-0" $.Values.meta.mysqld.statefulSetName }}
{{- end -}}

{{- define "rondb.mysqldServiceHostname" -}}
{{ printf "%s.%s.svc.cluster.local"
        $.Values.meta.mysqld.service.name
        $.Release.Namespace
}}
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
