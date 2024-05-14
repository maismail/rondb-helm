# Helmchart RonDB

## Capabilities

- Create custom-size, cross-AZ cluster
- Horizontal auto-scaling of MySQLds & RDRS'

## Capabilities of Manual Intervention

- Scale data node replicas:
  1. Use the MGM client to activate Node IDs
  2. Increase `activeDataReplicas` in values.yaml. This will 
     1. Change the config.ini (important in case MGMds restart later)
     2. Increase the StatefulSet replicas.

## TODO

- Create more values.yaml files for production settings
- Move MySQL passwords in secrets
- Make data node memory changeable
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

RONDB_NAMESPACE=rondb-default
kubectl create namespace $RONDB_NAMESPACE

# Create required secrets (not part of Helmchart because visible with `helm get values`)
kubectl create secret generic mysql-passwords \
  --namespace=$RONDB_NAMESPACE \
  --from-literal=root=s0meH@rdPW \
  --from-literal=bench=d1vikult2Gue$

# Run this if both:
# - TLS Ingress/endToEnd is enabled in values
# - We are running standalone (without Hopsworks)
./setup_standalone_tls_dependencies.sh $RONDB_NAMESPACE

# Install and/or upgrade:
helm upgrade -i my-rondb \
    --namespace=$RONDB_NAMESPACE \
    --values ./values.minikube.small.yaml .
```

## Run tests

As soon as the Helmchart has been instantiated, we can run the following tests:

```bash
# Create some dummy data
helm test -n $RONDB_NAMESPACE my-rondb --filter name=generate-data

# Check that data has been created correctly
helm test -n $RONDB_NAMESPACE my-rondb --filter name=verify-data
```

## Run benchmarks

Whilst the `size` in `minikube.<size>.yaml` determines the cluster power, it does not determine any cluster size. For benchmarks, minimal data node replication and many MySQL servers are best.

```bash
helm upgrade -i my-rondb \
    --namespace=$RONDB_NAMESPACE \
    --values ./values.minikube.small.yaml \
    --values ./values.benchmark.yaml .
```

## Teardown

```bash
helm delete --namespace=$RONDB_NAMESPACE my-rondb

# Remove other related resources (non-namespaced objects not removed here e.g. PriorityClass)
kubectl delete namespace $RONDB_NAMESPACE

# Remove cert-manager
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.yaml

# Remove PVCs manually
kubectl delete pvc --all
```

## Minikube Values files

The `minikube.values.yaml` files are for single-machine configurations. Use other values for production settings.

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

## Optimizations

Data nodes strongly profit from being able to lock CPUs. To be able to use a static CPU Manager Policy, one can start Minikube as follows:

```bash
minikube start \
    --driver=docker \
    --cpus=10 \
    --memory=21000MB \
    --feature-gates="CPUManager=true" \
    --extra-config=kubelet.cpu-manager-policy="static" \
    --extra-config=kubelet.cpu-manager-policy-options="full-pcpus-only=true" \
    --extra-config=kubelet.kube-reserved="cpu=500m"
```

## Sysbench Benchmarking


### Normal Setup

Using:
- Minikube on Mac M1 Pro: `minikube start --driver=docker --cpus 10 --memory 20000`
- For "power" of cluster: `values.minikube.small.yaml`

#### Cluster size: 1 MySQLd, 1 data node, max 370%

```bash
Threads: 1 Mean: 180
Threads: 2 Mean: 365
Threads: 4 Mean: 682
Threads: 8 Mean: 741
Threads: 12 Mean: 791
Threads: 16 Mean: 837
Threads: 24 Mean: 887
Threads: 32 Mean: 918
Threads: 64 Mean: 996
Threads: 128 Mean: 993
Threads: 256 Mean: 978
```

#### Cluster size: 2 MySQLds, 1 data node, max 660%

```bash
Threads: 1 Mean: 414
Threads: 2 Mean: 744
Threads: 4 Mean: 1160
Threads: 8 Mean: 1726
Threads: 12 Mean: 1870
Threads: 16 Mean: 1976
Threads: 24 Mean: 2165
Threads: 32 Mean: 2170
Threads: 64 Mean: 2244
Threads: 128 Mean: 2337
Threads: 256 Mean: 2245
```

#### 3 MySQLds, 1 data node, 1 bench, max 930%

```bash
Threads: 1 Mean: 595
Threads: 8 Mean: 2016
Threads: 16 Mean: 2505
Threads: 24 Mean: 2771
Threads: 32 Mean: 2694
Threads: 64 Mean: 3001
Threads: 128 Mean: 3033
Threads: 256 Mean: 2906
```

#### 4 MySQLds, 1 data node, 1 bench, max 980%

```bash
Threads: 1 Mean: 727
Threads: 2 Mean: 1150
Threads: 4 Mean: 1723
Threads: 8 Mean: 2237
Threads: 12 Mean: 2381
Threads: 16 Mean: 2650
Threads: 24 Mean: 2635
Threads: 32 Mean: 2623
Threads: 64 Mean: 2601
Threads: 128 Mean: 2723
Threads: 256 Mean: 2611
```

### Static CPU Setup

Using:
- Minikube on Mac M1 Pro with:
    ```bash
    minikube start \
        --driver=docker \
        --cpus=10 \
        --memory=21000MB \
        --feature-gates="CPUManager=true" \
        --extra-config=kubelet.cpu-manager-policy="static" \
        --extra-config=kubelet.cpu-manager-policy-options="full-pcpus-only=true" \
        --extra-config=kubelet.kube-reserved="cpu=500m"
    ```
- .Values.staticCpuManagerPolicy=true
- For "power" of cluster: `values.minikube.small.yaml`

### 2 MySQLds, 1 data node, 1 bench, max 970%

```bash
Threads: 1 Mean: 413
Threads: 2 Mean: 849
Threads: 4 Mean: 1637
Threads: 8 Mean: 2135
Threads: 12 Mean: 2407
Threads: 16 Mean: 2610
Threads: 24 Mean: 2804
Threads: 32 Mean: 2841
Threads: 64 Mean: 2987
Threads: 128 Mean: 3113
Threads: 256 Mean: 3236
```

### 3 MySQLds, 1 data node, 1 bench, max 980%

```bash
Threads: 1 Mean: 669
Threads: 2 Mean: 1285
Threads: 4 Mean: 2013
Threads: 8 Mean: 2480
Threads: 12 Mean: 2589
Threads: 16 Mean: 2657
Threads: 24 Mean: 2897
Threads: 32 Mean: 2798
Threads: 64 Mean: 2933
Threads: 128 Mean: 3085
Threads: 256 Mean: 3059
```
