source "amazon-ebs" "ec2_ami" {
  profile                   = "terraform"
  region                    = "us-east-1"
  ami_name                  = "awsgridwithsqs-{{timestamp}}"
  instance_type             = "c5.large"
  source_ami_filter {
      filters = {
        virtualization-type = "hvm"
        name                = "amzn2-ami-hvm-2*"
        root-device-type    = "ebs"
        architecture        = "x86_64"
      }
      owners                = ["amazon"]
      most_recent           = true
  }
  communicator              = "ssh"
  ssh_username              = "ec2-user"
}

build {
  sources = [
    "source.amazon-ebs.ec2_ami"
  ]

  provisioner "shell" {
      script                = "packer_script.sh"
  }
}
