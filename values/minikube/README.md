# Minikube Values files

The `values/minikube/*.yaml` files are for single-machine configurations. Use other values for production settings.

- **mini**: 
  - Cluster setup: 1 MGM server, 1 data node, 1 MySQL server and 1 API node
  - Docker resource utilization: 2.5 GB of memory and up to 4 CPUs
  - Recommended machine: 8 GB of memory

- **small** (default):
  - Cluster setup: 1 MGM server, 2 data nodes, 2 MySQL servers and 1 API node
  - Docker resource utilization: 6 GB of memory and up to 16 CPUs
  - Recommended machine: 16 GB of memory and 16 CPUs

- **medium**:
  - Cluster setup: Same as **small**
  - Docker resource utilization: 16 GB of memory and up to 16 CPUs
  - Recommended machine: 32 GB of memory and 16 CPUs

- **large**:
  - Cluster setup: Same as **small**
  - Docker resource utilization: 20 GB of memory and up to 32 CPUs
  - Recommended machine: 32 GB of memory and 32 CPUs

- **xlarge**:
  - Cluster setup: Same as **small**
  - Docker resource utilization: 30 GB of memory and up to 50 CPUs
  - Recommended machine: 64 GB of memory and 64 CPUs
