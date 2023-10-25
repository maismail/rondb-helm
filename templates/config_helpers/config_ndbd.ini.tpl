{{ define "config_ndbd" }}
[NDBD]
NodeId={{ .nodeId }}
NodeGroup={{ .nodeGroup }}
NodeActive={{ .isActive }}
HostName={{ .hostname }}
LocationDomainId=0
ServerPort=11860
DataDir=/srv/hops/mysql-cluster/log
FileSystemPath=/srv/hops/mysql-cluster/ndb_data
FileSystemPathDD=/srv/hops/mysql-cluster/ndb_disk_columns
BackupDataDir=/srv/hops/mysql-cluster/ndb/backups
{{ end }}
