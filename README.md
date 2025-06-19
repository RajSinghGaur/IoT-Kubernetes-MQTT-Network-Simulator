# IoT Kubernetes MQTT Network Simulator

This project simulates a network of IoT devices using Kubernetes. Each device is represented by a pod running a Python application that communicates with other devices via MQTT, using an Eclipse Mosquitto broker deployed in the same cluster.

## Features
- Simulates multiple IoT devices as Kubernetes pods (default: 9 replicas)
- Communication using MQTT (paho-mqtt)
- Devices publish periodic heartbeats and can send custom messages
- REST API for status and message publishing
- Simulates network latency, packet loss, and device failures for realism
- Easily scalable and customizable

## Project Structure
- `mqtt_device.py` – Python app for each IoT device (Flask + paho-mqtt)
- `Dockerfile` – Containerizes the device app
- `k8s.yaml` – Deploys the device network (Deployment + headless Service)
- `mqtt-broker.yaml` – Deploys Eclipse Mosquitto MQTT broker
- `README.md` – Project documentation

## Prerequisites
- Docker
- Kubernetes cluster (e.g., Minikube, Kind, or cloud provider)
- kubectl configured for your cluster

## Setup Instructions

### 1. Build and Push the Device Image
Replace `<your-dockerhub-username>` with your Docker Hub username:

```sh
docker build -t <your-dockerhub-username>/iot-mqtt:latest .
docker push <your-dockerhub-username>/iot-mqtt:latest
```

### 2. Deploy the MQTT Broker
```sh
kubectl apply -f mqtt-broker.yaml
```

### 3. Deploy the IoT Devices
Edit `k8s.yaml` to use your image name, then:
```sh
kubectl apply -f k8s.yaml
```

## Running with Parameterized Docker Hub Username

To deploy your Kubernetes resources using your Docker Hub username from the `.env` file, run:

```sh
export $(cat .env | xargs)
envsubst < k8s.yaml | kubectl apply -f -
```

This will substitute `${DOCKERHUB_USERNAME}` in your `k8s.yaml` with the value from your `.env` file (e.g., `rajsinghgaur`).

You only need to update your Docker Hub username in the `.env` file, and it will be used everywhere in your deployment.

## Interacting with the Network

### Check Device Status
1. Get a pod name:
   ```sh
   kubectl get pods -l app=iot-device
   ```
2. Port-forward to a pod:
   ```sh
   kubectl port-forward <pod-name> 5000:5000
   ```
3. Check status:
   ```sh
   curl http://localhost:5000/status
   # This command checks the status endpoint of your Flask app running inside the pod.
   # Make sure you have run the port-forward command in another terminal window/tab before running this.
   # If you get a connection refused error, ensure the pod is running and the app is listening on port 5000.
   ```

### Publish a Custom Message
```sh
curl -X POST -H "Content-Type: application/json" -d '{"message": "Hello network!"}' http://localhost:5000/publish
```

### View Device Activity
```sh
kubectl logs <pod-name>
```

## Metrics and Experiment Data Collection

Each device pod now exposes a `/metrics` HTTP endpoint that provides real-time statistics:

- **sent**: Number of messages sent by this device
- **received**: Number of messages received by this device
- **avg_latency**: Average message latency (seconds) for received messages
- **latency_samples**: Last 10 message latencies (seconds)

### Accessing Device Metrics

1. Get a pod name:
   ```sh
   kubectl get pods -l app=iot-device
   ```
2. Port-forward to a pod:
   ```sh
   kubectl port-forward <pod-name> 5000:5000
   ```
3. Query the metrics endpoint:
   ```sh
   curl http://localhost:5000/metrics
   ```
   Example output:
   ```json
   {
     "sent": 42,
     "received": 39,
     "avg_latency": 0.123,
     "latency_samples": [0.120, 0.130, 0.125, ...]
   }
   ```

### Collecting Metrics from All Devices

You can automate metrics collection from all pods using a script. For example:

```sh
for pod in $(kubectl get pods -l app=iot-device -o jsonpath='{.items[*].metadata.name}'); do
  kubectl port-forward $pod 5000:5000 &
  sleep 2
  echo "$pod metrics:"
  curl -s http://localhost:5000/metrics
  kill %1
  sleep 1
done
```

> For large-scale experiments, consider aggregating metrics centrally or using a logging/monitoring stack.

## Realism: Simulated IoT Constraints
- **Resource limits:** Each pod is limited to 64Mi RAM and 0.1 CPU, similar to real IoT devices.
- **Network latency:** Each message may be delayed by 10–500ms.
- **Packet loss:** 10% chance any message is dropped.
- **Device failures:** 5% chance every 30 seconds for a device to go offline for 30 seconds.
- **Simulates true MQTT client inactivity:** during a simulated device failure, the MQTT network loop is paused (no heartbeats or messages sent), allowing the broker to disconnect the client after the keep alive timeout. The device then automatically reconnects and resumes normal operation.

## Customization
- Change the number of devices by editing `replicas` in `k8s.yaml`.
- Modify `mqtt_device.py` to simulate different device behaviors or protocols.
- Update MQTT broker settings as needed in `mqtt-broker.yaml`.
- Tune the probabilities and durations in `mqtt_device.py` for different simulation scenarios.

## Notes
- The MQTT broker is deployed with default settings and no authentication. For production or advanced simulation, secure the broker accordingly.
- The network logic is basic and can be extended for routing, failure simulation, or data aggregation.

## Citation

If you use this simulator in your work, please cite:

Usmani, Mohammad Faiz. "MQTT Protocol for the IoT." International Journal of Internet of Things 12, no. 3 (2020): 45-50.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Running Timed Experiments and Collecting Logs

You can automate your experiments and ensure logs are saved for each run using the provided shell script. This script:
- Deploys the MQTT broker and device pods
- Waits for a specified duration (default: 20 minutes)
- Collects logs from all pods and saves them in a timestamped results folder
- Cleans up all resources

### Example: `run_experiment.sh`

```sh
#!/bin/bash

# Duration of experiment in seconds (default: 1200 = 20 minutes)
DURATION=${1:-1200}
RESULTS_DIR="results/experiment_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

# Deploy resources
kubectl apply -f mqtt-broker.yaml
kubectl apply -f k8s.yaml

echo "Experiment started. Will run for $DURATION seconds..."
sleep $DURATION

echo "Collecting logs..."
for pod in $(kubectl get pods -l app=iot-device -o jsonpath='{.items[*].metadata.name}'); do
  kubectl logs $pod > "$RESULTS_DIR/${pod}.log"
done
BROKER_POD=$(kubectl get pods -l app=mqtt-broker -o jsonpath='{.items[0].metadata.name}')
kubectl logs $BROKER_POD > "$RESULTS_DIR/broker.log"

echo "Cleaning up resources..."
kubectl delete -f k8s.yaml
kubectl delete -f mqtt-broker.yaml

echo "Experiment complete. Logs saved in $RESULTS_DIR"
```

#### Usage

```sh
chmod +x run_experiment.sh
./run_experiment.sh         # Runs for 20 minutes (default)
./run_experiment.sh 600     # Runs for 10 minutes
```

Each run will create a new folder under `results/` with all logs for that experiment.

## Experiment Results Structure and Completeness

All experiment runs are saved in the `results/` directory. Each experiment creates a timestamped folder containing:

- `broker.log`: MQTT broker activity log
- One log per device pod (e.g., `iot-mqtt-<pod>.log`)

For example:

```
results/experiment_10nodes_20250619_074111/
  broker.log
  iot-mqtt-757f69fd8f-5nbgr.log
  iot-mqtt-757f69fd8f-6zkj7.log
  ...
results/experiment_50nodes_20250619_082124/
  broker.log
  iot-mqtt-757f69fd8f-2bc8x.log
  iot-mqtt-757f69fd8f-2gfpf.log
  ...
```

- All log files are present and non-empty for every experiment.
- Device logs contain thousands of lines, suitable for detailed analysis.
- No missing or empty logs were found in any experiment batch.

This structure ensures your results are reproducible, analyzable, and ready for publication or further processing.

---

## Experimental Environment

All experiments were conducted using the following Minikube-based Kubernetes environment:

- **Minikube version:** v1.36.0
- **Kubernetes version:** v1.33.1
- **VM resources:** 12 vCPUs, 8 GB RAM
- **Node OS:** Ubuntu 22.04 LTS (kernel 6.x)
- **Container runtime:** Docker
- **Cluster type:** Single-node (control-plane only)
- **Status:** All components running and healthy

This configuration ensures reproducibility and provides a realistic resource-constrained environment for IoT simulation at moderate scale.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
