# Helmchart RonDB

## TODO

- Create more values.yaml files for production settings
- Move MySQL passwords in secrets
- Add affinities to availability zones
- Add YCSB to benchmark options

Add scaling:
- In entrypoint, always activate the Node Id using the MGM client
- When stopping, always deactivate the Node Id again
  - Can then easily increase / decrease replication factor

Rolling upgrades:
- Rolling restarts with config.ini
  - --> Make sure this has already taken into account the MGM client changes
- Figure out how to upgrade services in order

Jobs to add:
- Increasing logfile group sizes
- Backups

## Quickstart

```bash
helm lint
helm install --dry-run --debug --generate-name .

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

minikube start --driver=docker --cpus 10 --memory 20000

1 MySQLd, 1 data node, 1 bench (1 CPU), max 430%, sysbench

Final results for this test run
Threads: 1 Mean: 141
Threads: 2 Mean: 310
Threads: 4 Mean: 631
Threads: 8 Mean: 703
Threads: 12 Mean: 745
Threads: 16 Mean: 797
Threads: 24 Mean: 844
Threads: 32 Mean: 937

1 MySQLd, 1 data node, 1 bench (no CPU specified), max 430%, sysbench

Final results for this test run
Threads: 1 Mean: 137
Threads: 2 Mean: 320
Threads: 4 Mean: 608
Threads: 8 Mean: 677
Threads: 12 Mean: 734
Threads: 16 Mean: 747
Threads: 24 Mean: 816
Threads: 32 Mean: 861

1 MySQLd, 1 data node, 1 bench, max 430%, sysbench, USING explicit CPU requests

--> CPU maxes out at 8 threads...
Final results for this test run
Threads: 1 Mean: 140
Threads: 2 Mean: 321
Threads: 4 Mean: 618
Threads: 8 Mean: 684
Threads: 12 Mean: 762
Threads: 16 Mean: 824
Threads: 24 Mean: 886
Threads: 32 Mean: 914

2 MySQLds, 1 data node, 1 bench, max 730%, sysbench, CPU requests < limits

Threads: 2 Mean: 600
Threads: 4 Mean: 996
Threads: 8 Mean: 1499
Threads: 12 Mean: 1601
Threads: 16 Mean: 1649
Threads: 24 Mean: 1860
Threads: 32 Mean: 1844
Threads: 64 Mean: 1926

2 MySQLds, 1 data node, 1 bench, max 800%, sysbench, resource limits==requests

Threads: 1 Mean: 306
Threads: 2 Mean: 601
Threads: 4 Mean: 1007
Threads: 8 Mean: 1439
Threads: 12 Mean: 1632
Threads: 16 Mean: 1745
Threads: 24 Mean: 1897
Threads: 32 Mean: 1967
Threads: 64 Mean: 1972 <-- extra..

2 MySQLds, 1 data node, 1 bench, max 850%, sysbench, OMITTING resource requests

Threads: 1 Mean: 320
Threads: 2 Mean: 614
Threads: 4 Mean: 1023
Threads: 8 Mean: 1492
Threads: 12 Mean: 1659
Threads: 16 Mean: 1767
Threads: 24 Mean: 1985
Threads: 32 Mean: 2065
