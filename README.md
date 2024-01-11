# Helmchart RonDB

## Capabilities

- Create custom-size, cross-AZ cluster
- Horizontal auto-scaling of MySQLds & RDRS'

## Capabilities with Manual Intervention

- Scale data node replicas:
  1. Use the MGM client to activate Node Ids
  2. Increase `activeDataReplicas` in values.yaml. This will 
     1. Change the config.ini (important in case MGMds restart later in time)
     2. Increase the StatefulSet replicas.

- Increase data node memory:
  1. Make sure we have >=2 active data node replicas
  2. Increase TotalMemoryConfig in values.yaml
  3. Recreate MGMds
  4. Increase memory limits of ndbmtds in values.yaml. The ndbdmtds will then perform a rolling update.

## TODO

- Create more values.yaml files for production settings
- Move MySQL passwords in secrets
- Add YCSB to benchmark options
- Figure out how to run `SELECT count(*) FROM ndbinfo.nodes` as MySQL readiness check.
  - Using  `--defaults-file=$RONDB_DATA_DIR/my.cnf` and `GRANT SELECT ON ndbinfo.nodes TO 'hopsworks'@'%';` does not work
  - Error: `ERROR 1356 (HY000): View 'ndbinfo.nodes' references invalid table(s) or column(s) or function(s) or definer/invoker of view lack rights to use them`

Kubernetes Jobs to add:
- Increasing logfile group sizes
- Backups

## Quickstart

```bash
helm lint
helm template .

# Install and/or upgrade:
helm upgrade -i my-rondb .

# To merge default values with custom ones:
helm upgrade -i my-rondb . --values ./values.minikube.mini.yaml
```

## Minikube Values files

The minikube.values.yaml files are for single-machine configurations. Use other values for production settings.

- **mini**: 
  - Cluster setup: 1 MGM server, 1 data node, 1 MySQL server and 1 API node
  - Docker resource utilisation: 2.5 GB of memory and up to 4 CPUs
  - Recommended machine: 8 GB of memory

- **small** (default):
  - Cluster setup: 1 MGM server, 2 data nodes, 2 MySQL servers and 1 API node
  - Docker resource utilisation: 6 GB of memory and up to 16 CPUs
  - Recommended machine: 16 GB of memory and 16 CPUs

- **medium**:
  - Cluster setup: Same as **small**
  - Docker resource utilisation: 16 GB of memory and up to 16 CPUs
  - Recommended machine: 32 GB of memory and 16 CPUs

- **large**:
  - Cluster setup: Same as **small**
  - Docker resource utilisation: 20 GB of memory and up to 32 CPUs
  - Recommended machine: 32 GB of memory and 32 CPUs

- **xlarge**:
  - Cluster setup: Same as **small**
  - Docker resource utilisation: 30 GB of memory and up to 50 CPUs
  - Recommended machine: 64 GB of memory and 64 CPUs

## Benchmarking

Using Minikube on Mac M1 Pro: `minikube start --driver=docker --cpus 10 --memory 20000`

1 MySQLd, 1 data node, 1 bench, max 430%, sysbench, CPU requests < limits

```bash
--> CPU reaches max at 8 threads...
Threads: 1 Mean: 140
Threads: 2 Mean: 321
Threads: 4 Mean: 618
Threads: 8 Mean: 684
Threads: 12 Mean: 762
Threads: 16 Mean: 824
Threads: 24 Mean: 886
Threads: 32 Mean: 914
```

2 MySQLds, 1 data node, 1 bench, max 730%, sysbench, CPU requests < limits

```bash
Threads: 2 Mean: 600
Threads: 4 Mean: 996
Threads: 8 Mean: 1499
Threads: 12 Mean: 1601
Threads: 16 Mean: 1649
Threads: 24 Mean: 1860
Threads: 32 Mean: 1844
Threads: 64 Mean: 1926
```

3 MySQLds, 1 data node, 1 bench, max 930%, sysbench, CPU requests < limits

```bash
Threads: 1 Mean: 465
Threads: 2 Mean: 862
Threads: 4 Mean: 1200
Threads: 8 Mean: 1717
Threads: 12 Mean: 1916
Threads: 16 Mean: 2035
Threads: 24 Mean: 2240
Threads: 32 Mean: 2332
Threads: 64 Mean: 2250
```

4 MySQLds, 1 data node, 1 bench, max 960%, sysbench, CPU requests < limits

```bash
Threads: 1 Mean: 603
Threads: 2 Mean: 997
Threads: 4 Mean: 1419
Threads: 8 Mean: 1774
Threads: 12 Mean: 1988
Threads: 16 Mean: 2170
Threads: 24 Mean: 2228
Threads: 32 Mean: 2240
Threads: 64 Mean: 2347
```

5 MySQLds, 1 data node, 1 bench, max 955%, sysbench, CPU requests < limits

```bash
Threads: 1 Mean: 649
Threads: 2 Mean: 1025
Threads: 4 Mean: 1504
Threads: 8 Mean: 1812
Threads: 12 Mean: 1941
Threads: 16 Mean: 1895
Threads: 24 Mean: 2091
Threads: 32 Mean: 1834
Threads: 64 Mean: 1278
```
