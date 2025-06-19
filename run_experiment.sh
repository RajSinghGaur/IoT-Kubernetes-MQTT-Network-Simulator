#!/bin/bash

# Usage: ./run_experiment.sh [duration_seconds] [num_nodes_label]
# Default duration is 1200 seconds (20 minutes)

DURATION=${1:-1200}
NODES_LABEL=${2:-nodes}
RESULTS_DIR="results/experiment_${NODES_LABEL}_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

# Load Docker Hub username from .env
if [ -f .env ]; then
  export $(cat .env | xargs)
else
  echo ".env file not found! Please create one with DOCKERHUB_USERNAME."
  exit 1
fi

# Build and push Docker image
IMAGE_NAME="$DOCKERHUB_USERNAME/iot-mqtt:latest"
echo "Building Docker image: $IMAGE_NAME"
docker build -t $IMAGE_NAME .
echo "Pushing Docker image to Docker Hub..."
docker push $IMAGE_NAME

echo "Deploying resources with envsubst..."
# Use envsubst to substitute Docker Hub username in k8s.yaml
kubectl apply -f k8s_test.yaml
kubectl apply -f mqtt-broker.yaml

echo "Experiment started. Will run for $DURATION seconds..."
sleep $DURATION

echo "Collecting logs..."
for pod in $(kubectl get pods -l app=iot-device -o jsonpath='{.items[*].metadata.name}'); do
  kubectl logs $pod > "$RESULTS_DIR/${pod}.log"
done
BROKER_POD=$(kubectl get pods -l app=mqtt-broker -o jsonpath='{.items[0].metadata.name}')
kubectl logs $BROKER_POD > "$RESULTS_DIR/broker.log"

echo "Cleaning up resources..."
# Use envsubst for deletion as well to match applied resources
kubectl apply -f k8s_test.yaml
kubectl delete -f mqtt-broker.yaml

echo "Experiment complete. Logs saved in $RESULTS_DIR"
