# Run benchmarks

Whilst the `size` in `minikube.<size>.yaml` determines the cluster power, it does not determine any cluster size. For benchmarks, minimal data node replication and many MySQL servers are best.

```bash
helm upgrade -i my-rondb \
    --namespace=$RONDB_NAMESPACE \
    --values ./values/minikube/small.yaml \
    --values ./values/benchmark.yaml .
```

## Sysbench Benchmarking

### Normal Setup

Using:
- Minikube on Mac M1 Pro: `minikube start --driver=docker --cpus 10 --memory 20000`
- For "power" of cluster: `values/minikube/small.yaml`

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
- For "power" of cluster: `values/minikube/small.yaml`

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
