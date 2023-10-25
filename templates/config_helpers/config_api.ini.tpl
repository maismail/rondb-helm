{{ define "config_api" }}
[API]
NodeId={{ .nodeId }}
LocationDomainId=0
NodeActive={{ .isActive }}
ArbitrationRank=1
HostName={{ .hostname }}
{{ end }}
