variable "DB_NAME" {
  type        = string
  description = "The name for the database"
  default     = env("DB_NAME")
}

variable "DB_USER" {
  type        = string
  description = "The username for the database"
  default     = env("DB_USER")
}

variable "DB_PASSWORD" {
  type        = string
  description = "The password for the database"
  default     = env("DB_PASSWORD")
}

variable "DATABASE_URL" {
  type        = string
  description = "The name of the database"
  default     = env("DATABASE_URL")
}


variable "GCP_AUTH_CREDS" {
  type        = string
  description = "The JSON credentials for the service account"
  default     = env("GOOGLE_AUTH_SERVICE")
}

variable "aws_machine_image_details" {
  type = object({
    region        = string
    profile       = string
    source_ami    = string
    instance_type = string
    ssh_username  = string
    subnet_id     = string
    ami_users     = list(string)
  })

  default = {
    region        = env("AWS_REGION")
    profile       = env("AWS_PROFILE")
    source_ami    = env("AWS_SOURCE_AMI")
    instance_type = env("AWS_INSTANCE_TYPE")
    ssh_username  = env("AWS_SSH_USERNAME")
    subnet_id     = env("AWS_SUBNET_ID")
    ami_users     = [env("AWS_AMI_USERS")]
  }
}



# variable "gcp_machine_image_details" {
#   type = object({
#     project_id              = string
#     source_image_family     = string
#     zone                    = string
#     image_name              = string
#     image_family            = string
#     image_storage_locations = string
#     image_description       = string
#     communicator            = string
#     ssh_username            = string
#     disk_type               = string
#   })


#   default = {
#     project_id              = env("GOOGLE_PROJECT_ID")
#     source_image_family     = env("GCP_SOURCE_IMAGE_FAMILY")
#     zone                    = env("GCP_ZONE")
#     image_name              = env("GCP_IMAGE_NAME")
#     image_family            = env("GCP_IMAGE_FAMILY")
#     image_storage_locations = env("GCP_IMAGE_STORAGE_LOCATIONS")
#     image_description       = "This is a custom image for CSYE6255 Cloud Computing"
#     communicator            = "ssh"
#     ssh_username            = "ubuntu"
#     disk_type               = env("GCP_DISK_TYPE")
#   }
# }

variable "webapp_source" {
  type    = string
  default = "./webapp.zip"
}

variable "webapp_destination" {
  type    = string
  default = "/tmp/webapp.zip"
}

variable "postproject_scripts" {
  type = list(string)
  default = [
    "packer/create_service.sh",
    "packer/start_service.sh"
  ]
}
packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
    # googlecompute = {
    #   source  = "github.com/hashicorp/googlecompute"
    #   version = ">=1.0.0"
    # }
  }
}

# source "googlecompute" "machineimage" {
#   project_id              = var.gcp_machine_image_details["project_id"]
#   source_image_family     = var.gcp_machine_image_details["source_image_family"]
#   credentials_json        = "${var.GCP_AUTH_CREDS}"
#   zone                    = var.gcp_machine_image_details["zone"]
#   image_name              = var.gcp_machine_image_details["image_name"]
#   image_family            = var.gcp_machine_image_details["image_family"]
#   image_storage_locations = [var.gcp_machine_image_details["image_storage_locations"]]
#   image_description       = var.gcp_machine_image_details["image_description"]
#   communicator            = var.gcp_machine_image_details["communicator"]
#   ssh_username            = var.gcp_machine_image_details["ssh_username"]
#   disk_type               = var.gcp_machine_image_details["disk_type"]

# }

source "amazon-ebs" "csye6225-aws-ami" {
  ami_name      = "csye6225_dev_fin${formatdate("YYYYMMDDHHmmss", timestamp())}"
  region        = var.aws_machine_image_details["region"]
  profile       = var.aws_machine_image_details["profile"]
  source_ami    = var.aws_machine_image_details["source_ami"]
  instance_type = var.aws_machine_image_details["instance_type"]
  ssh_username  = var.aws_machine_image_details["ssh_username"]
  subnet_id     = var.aws_machine_image_details["subnet_id"]
  ami_users     = var.aws_machine_image_details["ami_users"]

  aws_polling {
    delay_seconds = 60
    max_attempts  = 50
  }

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 8
    volume_type           = "gp2"
    delete_on_termination = true
  }

}

build {
  sources = ["source.amazon-ebs.csye6225-aws-ami"]

  provisioner "file" {
    source      = var.webapp_source
    destination = var.webapp_destination
  }

  provisioner "shell" {
    script = "packer/main_script.sh"
    environment_vars = [
      "DB_USER=${var.DB_USER}",
      "DB_PASSWORD=${var.DB_PASSWORD}",
      "DB_NAME=${var.DB_NAME}",
      "DATABASE_URL=${var.DATABASE_URL}"
    ]
  }


  provisioner "shell" {
    scripts = var.postproject_scripts

    environment_vars = [
      "DB_USER=${var.DB_USER}",
      "DB_PASSWORD=${var.DB_PASSWORD}",
      "DB_NAME=${var.DB_NAME}",
      "DATABASE_URL=${var.DATABASE_URL}"
    ]
  }

}