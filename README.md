# M23CSA508 

# Anindya Bandopadhyay

## Assignment 3 

Create a local VM and implement a mechanism to monitor resource usage. Configure it to auto-scale to a public cloud (e.g., GCP, AWS, or Azure) when resource usage exceeds 75%.

## Prerequisites
- VirtualBox 6.1+ or VMware Workstation/Player
- Ubuntu 22.04 LTS ISO
- OCI account with proper permissions
- OCI CLI installed and configured
- Host machine with at least 4GB RAM and 20GB free disk space

## 1. Setting Up the Local VM

### 1.1 Create a VM in VirtualBox

1. Download Ubuntu 22.04 LTS ISO from the official website
2. Open VirtualBox and click "New"
3. Configure the VM:
   - Name: Ubuntu
   - Type: Linux
   - Version: Ubuntu (64-bit)
   - Memory: 4096 MB
   - Create a virtual hard disk: 20 GB (VDI, dynamically allocated)
4. Configure VM settings:
   - System > Processor: 3 CPUs
   - Display > Video Memory: 128 MB
   - Storage: Attach the Ubuntu ISO
   - Network: Bridged Adapter

### 1.2 Install Ubuntu

1. Start the VM and follow the Ubuntu installation prompts
2. Choose minimal installation to save resources
3. Set up your username and password 
4. Complete the installation and ACPI Shutdown

### 1.3 Initial Configuration

1. Update the system:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. Install essential tools:
   ```bash
   sudo apt install -y git curl wget stress-ng htop iftop net-tools python3-pip
   ```

3. Install OCI CLI:
   ```bash
   bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
   ```

## 2. OCI Configuration

### 2.1 Set Up Your OCI Account

1. Log in to the OCI Console at [cloud.oracle.com](https://cloud.oracle.com)
2. Navigate to your user profile
3. Note down your Tenancy OCID and User OCID
4. Generate an API key:
   - In the OCI Console, go to Profile > User Settings > API Keys
   - Click "Add API Key"
   - Choose "Generate API Key Pair"
   - Download the private key
   - Click "Add"
5. Copy the Configuration File Preview content

### 2.2 Configure OCI CLI

1. On your Ubuntu VM, run the configuration command:
   ```bash
   oci setup config
   ```

2. Enter the following information when prompted:
   - User OCID
   - Tenancy OCID
   - Region 
   - Location for the config file (accept default)
   - Generate a new RSA key pair? (No)
   - Path to private key file (use the one you downloaded)

3. Verify the configuration:
   ```bash
   oci compute shape list --compartment-id <your-compartment-id> --limit 5
   ```

### 2.3 Prepare OCI for Auto-Scaling

1. Create a Virtual Cloud Network (VCN) if you don't have one:
   ```bash
   oci network vcn create --compartment-id <compartment-id> \
     --display-name "Production-VCN" \
     --cidr-block "10.0.0.0/16" \
     --dns-label "monitorvcn"
   ```

2. Create a subnet:
   ```bash
   oci network subnet create --compartment-id <compartment-id> \
     --vcn-id <vcn-id> \
     --display-name "Private-App-Subnet" \
     --cidr-block "10.0.0.0/24" \
     --dns-label "monitorsubnet"
   ```

## 3. Implementing Resource Monitoring

### 3.1 Create the Monitoring Script

1. Create a directory for monitoring:
   ```bash
   mkdir -p ~/tools
   cd ~/tools
   ```

2. Create a bash script for monitoring CPU usage:
   ```bash
   nano monitor.sh
   ```

3. Add the following content to the script:
   ```bash
   #!/bin/bash

   CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
   MEM_USAGE=$(free | grep Mem | awk '{print ($3/$2) * 100.0}')

   THRESHOLD=75.0

   if (( $(echo "$CPU_USAGE > $THRESHOLD" | bc -l) )) || (( $(echo "$MEM_USAGE > $THRESHOLD" | bc -l) )); then
      echo "[WARNING] High usage detected: CPU=$CPU_USAGE%, RAM=$MEM_USAGE%"
      ./scale_to_oci.sh
   else
      echo "[OK] CPU=$CPU_USAGE%, RAM=$MEM_USAGE%"
   fi
   ```

   ```bash
      chmod +x monitor.sh
      ./monitor.sh
   ```

4. OCI CLI Setup (One-time on Local VM)
    ```bash
      oci setup config
   ```
   Upload the generated public key to OCI Console → User → API Keys

   Verify 
   ```bash
      oci os ns get
   ```

5. Script to Launch OCI Compute Instance
   ```bash
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
   ```
Make the script executable:
   ```bash
   chmod +x scale_to_oci.sh
   ```

## 4. Sample Application Deployment

### 4.1 Create a Load-Generating Test Application

1. Create a script to generate load:
   ```bash
   stress-ng --cpu $(nproc) --cpu-load 90 --timeout 30s
   ```
   
### 4.3 Test the Auto-Scaling Process

1. Run the monitoring script:
   ```bash
   ./monitor.sh
   ```

2.  Run the load generator with various patterns:
   ```bash
   # Short burst (should not trigger scaling)
   stress-ng --cpu $(nproc) --cpu-load 90 --timeout 30s
   
   # Sustained load (should trigger scaling)
   stress-ng --cpu $(nproc) --cpu-load 90 --timeout 120s
   ```

3. When CPU usage exceeds 75% for the defined duration:
   - The monitoring script will detect sustained high CPU
   - A new OCI instance will be created

4. Verify the new OCI instance:
   - Login into OCI Console 
   - Goto Compute > Instances 
   - Apply the compartment filter 

   or 

     ```bash
     oci compute instance list --compartment-id <compartment-id> --output table
     ```

### 4.4 Clean Up Resources

1. Goto OCI console terminate test instances when done.

![Auto-Scaling Architecture](images/m23csa508_vcc_assignment.svg)
