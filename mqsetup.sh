#!/bin/bash
PROJECT_NAME="mq-ami-ubi-factory"
mkdir -p $PROJECT_NAME/roles/ibm_mq/{tasks,vars}

echo "[+] Generating UBI-based Dockerfile..."
cat <<EOF > $PROJECT_NAME/Dockerfile
FROM redhat/ubi9:latest

# Install system dependencies
RUN dnf install -y python3-pip python3-devel gcc openssh-clients unzip yum-utils

# Install Packer
RUN yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo && \
    dnf install -y packer

# Install Ansible and AWS requirements
RUN pip3 install --no-cache-dir ansible botocore boto3

# Pre-install Ansible AWS collection
RUN ansible-galaxy collection install amazon.aws

WORKDIR /app
EOF

echo "[+] Generating docker-compose.yml..."
cat <<EOF > $PROJECT_NAME/docker-compose.yml
services:
  mq-builder:
    build: .
    volumes:
      - .:/app
    environment:
      - AWS_ACCESS_KEY_ID
      - AWS_SECRET_ACCESS_KEY
      - AWS_SESSION_TOKEN
      - AWS_DEFAULT_REGION
    # Runs init to fetch plugins, then builds using the var-file
    command: /bin/bash -c "packer init . && packer build -var-file=variables.pkrvars.hcl ."
EOF

echo "[+] Generating Packer Template..."
cat <<EOF > $PROJECT_NAME/template.pkr.hcl
variable "aws_region"  { type = string }
variable "mq_version"  { type = string default = "9.3" }
variable "dept"        { type = string }
variable "cost_center" { type = string }

packer {
  required_plugins {
    amazon = { version = ">= 1.2.0", source = "github.com/hashicorp/amazon" }
    ansible = { version = ">= 1.1.0", source = "github.com/hashicorp/ansible" }
  }
}

source "amazon-ebs" "ibm_mq" {
  ami_name      = "ibm-mq-\${var.mq_version}-{{timestamp}}"
  instance_type = "t3.medium"
  region        = var.aws_region
  
  tags = {
    Name         = "IBM-MQ-Golden-Image"
    Version      = var.mq_version
    Department   = var.dept
    CostCenter   = var.cost_center
    ManagedBy    = "Packer-Ansible-UBI"
  }

  source_ami_filter {
    filters = {
      name = "RHEL-9*"
      root-device-type = "ebs"
    }
    most_recent = true
    owners      = ["309956199498"]
  }
  ssh_username = "ec2-user"
}

build {
  sources = ["source.amazon-ebs.ibm_mq"]
  provisioner "ansible" {
    playbook_file = "./playbook.yml"
    user          = "ec2-user"
    ansible_env_vars = ["ANSIBLE_ROLES_PATH=./roles"]
  }
}
EOF

echo "[+] Generating variables.pkrvars.hcl..."
cat <<EOF > $PROJECT_NAME/variables.pkrvars.hcl
aws_region  = "us-east-1"
mq_version  = "9.3"
dept        = "Middleware-Engineering"
cost_center = "ACC-9988-XT"
EOF

echo "[+] Generating Ansible Role..."
cat <<EOF > $PROJECT_NAME/roles/ibm_mq/tasks/main.yml
---
- name: Install MQ dependencies on Target
  dnf:
    name: [ksh, libstdc++, glibc, tar, procps-ng]
    state: present

- name: Create mqm user and group
  user: { name: mqm, group: mqm, home: /var/mqm, shell: /bin/bash }

- name: Download MQ from S3
  amazon.aws.s3_object:
    bucket: "{{ s3_bucket }}"
    object: "{{ mq_package_name }}"
    dest: "/tmp/mq.tar.gz"
    mode: get

- name: Extract and Install MQ
  shell: |
    tar -xzf /tmp/mq.tar.gz -C /tmp
    # Finds the directory extracted from the tarball
    cd /tmp/MQServer
    ./mqlicense.sh -accept
    rpm -ivh MQSeriesRuntime*.rpm MQSeriesServer*.rpm
  args:
    creates: /opt/mqm/bin/dspmqver

- name: Verify installation
  command: /opt/mqm/bin/dspmqver
  register: mq_ver
  changed_when: false

- name: Print MQ Version for Logs
  debug:
    msg: "Installed MQ Version: {{ mq_ver.stdout_lines[0] }}"

- name: Final Cleanup
  file: { path: "{{ item }}", state: absent }
  loop: ["/tmp/mq.tar.gz", "/tmp/MQServer"]
EOF

echo "[+] Generating Ansible Vars..."
cat <<EOF > $PROJECT_NAME/roles/ibm_mq/vars/main.yml
---
s3_bucket: "REPLACE_WITH_YOUR_S3_BUCKET"
mq_package_name: "IBM_MQ_9.3_LINUX_X86-64.tar.gz"
EOF

echo -e "---\n- hosts: all\n  become: yes\n  roles: [ibm_mq]" > $PROJECT_NAME/playbook.yml

echo "Done! Run: cd $PROJECT_NAME && docker-compose up --build"
