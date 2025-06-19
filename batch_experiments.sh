#!/bin/bash
# batch_experiments.sh
# Run all critical experiments for IoT Kubernetes MQTT simulator

# Experiment duration in seconds
DURATION=1200
export 

# 1. Scalability Test (Vary Node Count)
for nodes in 5 10 20 50; do
  export NODE_COUNT=$nodes
  export POD_CPU="100m"
  export POD_MEM="64Mi"
  export POD_CPU_REQ="50m"
  export POD_MEM_REQ="32Mi"
  export SIM_LATENCY="0.5"
  export SIM_LOSS="0.1"
  export FAIL_PROB="0.05"
  export FAIL_DUR="40"
  export $(cat .env | xargs)
  envsubst < k8s.yaml.template > k8s.yaml
  ./run_experiment.sh $DURATION "${nodes}nodes"
done

# 2. Network Condition Impact (Vary Latency and Packet Loss)
for latency in 0.01 0.1 0.5; do
  for loss in 0.0 0.1 0.2; do
    export NODE_COUNT=10
    export POD_CPU="100m"
    export POD_MEM="64Mi"
    export POD_CPU_REQ="50m"
    export POD_MEM_REQ="32Mi"
    export SIM_LATENCY="$latency"
    export SIM_LOSS="$loss"
    export FAIL_PROB="0.05"
    export FAIL_DUR="40"
    envsubst < k8s.yaml.template > k8s.yaml
    ./run_experiment.sh $DURATION "lat${latency}_loss${loss}"
  done
done

# 3. Device Failure and Recovery (Vary Failure Probability/Duration)
for fail_prob in 0.02 0.05 0.1; do
  for fail_dur in 20 40; do
    export NODE_COUNT=10
    export POD_CPU="100m"
    export POD_MEM="64Mi"
    export POD_CPU_REQ="50m"
    export POD_MEM_REQ="32Mi"
    export SIM_LATENCY="0.5"
    export SIM_LOSS="0.1"
    export FAIL_PROB="$fail_prob"
    export FAIL_DUR="$fail_dur"
    envsubst < k8s.yaml.template > k8s_test.yaml
    ./run_experiment.sh $DURATION "fail${fail_prob}_dur${fail_dur}"
  done
done

# 4. Resource Constraint Effects (Vary CPU/Memory Limits)
for cpu in 100m 250m; do
  for mem in 64Mi 128Mi; do
    export NODE_COUNT=10
    export POD_CPU="$cpu"
    export POD_MEM="$mem"
    export POD_CPU_REQ="50m"
    export POD_MEM_REQ="32Mi"
    export SIM_LATENCY="0.5"
    export SIM_LOSS="0.1"
    export FAIL_PROB="0.05"
    export FAIL_DUR="40"
    envsubst < k8s.yaml.template > k8s.yaml
    ./run_experiment.sh $DURATION "cpu${cpu}_mem${mem}"
  done
done
