#!/bin/bash

# Config
COMPARTMENT_ID="<compartment_ocid>"
SUBNET_ID="<subnet_ocid>"
AVAILABILITY_DOMAIN=$(oci iam availability-domain list --query "data[0].name" --raw-output)
IMAGE_ID="<oci_image_ocid>"
SHAPE="VM.Standard.E2.1.Micro"
SSH_KEY=$(cat ~/.ssh/id_rsa.pub)

# Launch instance
oci compute instance launch \
  --availability-domain "$AVAILABILITY_DOMAIN" \
  --compartment-id "$COMPARTMENT_ID" \
  --shape "$SHAPE" \
  --subnet-id "$SUBNET_ID" \
  --image-id "$IMAGE_ID" \
  --metadata '{"ssh_authorized_keys":"'"$SSH_KEY"'"}' \
  --display-name "auto-scaled-instance-$(date +%s)" \
  --wait-for-state RUNNING
