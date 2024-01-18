{{ define "config_ndbd" }}
[NDBD]
NodeId={{ .nodeId }}
NodeGroup={{ .nodeGroup }}
NodeActive={{ .isActive }}
HostName={{ .hostname }}
LocationDomainId=0
{{ end }}
