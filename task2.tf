


/*......................................................................>>>>>TASK 2>>>>>>>..........................................................................*/




/*===============================================providing aws to terraform ==========================================================*/



provider "aws" {
    region = "ap-south-1"
}



/*==================================================== Creating a VPC & SUBNET============================================================*/


resource "aws_vpc" "first" {
  cidr_block = "10.0.0.0/16"
}


resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.first.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Main"
  }
}



/*=====================================CReating key for accessing via ssh=========================================================*/




resource "tls_private_key" "key" {
  algorithm = "RSA"
}

  module "key_pair" {

    source     = "terraform-aws-modules/key-pair/aws"
    key_name   = "mytask2key"
    public_key = tls_private_key.key.public_key_openssh
}








/*====================================creating security group with port no. 22, 443, 80==================================================*/





resource "aws_security_group" "task2sg" {
 
  name        = "allow_tls and port 80"
  description = "Allow TLS and port 80 inbound traffic"
 
  ingress {
    description = "SSH connection"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tls and port 80"
  }
}


/*==========================================launching EC2 instance ===========================================================================*/



resource "aws_instance" "web" {
  ami           = "ami-052c08d70def0ac62"
  instance_type = "t2.micro"
  key_name = "mytask2key"
  security_groups = ["allow_tls and port 80"]


  tags = {
    Name = "myinstance"
  }

connection {
    type         = "ssh"
    user         = "ec2-user"
    private_key  = tls_private_key.key.private_key_pem 
    host         = aws_instance.web.public_ip
  }
provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl start httpd",
      "sudo mount -t nfs4 ${aws_efs_mount_target.target.ip_address}:/ /var/www/html",
      "sudo rm -f /var/www/html/*",
      "sudo git clone https://github.com/rakeshrdec/newrepo.git  /var/www/html",
    ]
  }


}




/*==========================================creating and mounting EFS================================================================================*/


resource "aws_efs_file_system" "efs" {

  tags = {
    Name = "My_efs_vol"
  }
} 


resource "aws_efs_mount_target" "target" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = aws_subnet.main.id
}




/*========================================creating null resource for provisioner=========================================================*/




resource "null_resource" "null2"{

provisioner "local-exec" {
    command = "git clone https://github.com/rakeshrdec/imagerepo.git git_image"
  }
}




/*===============================================creating a new s3 bucket===============================================================*/




resource "aws_s3_bucket" "buckt" {

  bucket = "rakeshrdec"
  acl    = "public-read-write"

  tags = {
    Name        = "My_terra_bucket"
  }


provisioner "local-exec" {
    when = destroy
    command = "echo Y|rmdir /s git_image"
  }

}



/*==============================================uploading image in s3 bucket==============================================================*/




resource "aws_s3_bucket_object" "bucket_object" {
  key    = "bucket.jpg"
  bucket = aws_s3_bucket.buckt.id
  source = "git_image/1.jpg"
  acl = "public-read-write"
}


locals {
  s3_origin_id = "aws_s3_bucket.buckt.id"
}












/*============================================cloudfront didtribution of s3 bucket image======================================================*/



resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.buckt.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "this image"
  default_root_object = "1.jpg"

  

default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }


  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }
price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IN"]
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

/*=========================================================giving null rresouces for adding image===================================================================*/


resource "null_resource" "null3" {
depends_on = [
    aws_cloudfront_distribution.s3_distribution,
  ]

 connection {
           type     = "ssh"
           user     = "ec2-user"
           private_key = tls_private_key.key.private_key_pem
           host     = aws_instance.web.public_ip
                   }
      
provisioner "remote-exec" {
           inline = [
    "echo \"<img src='https://${aws_cloudfront_distribution.s3_distribution.domain_name}/bucket.jpg' width='400' lenght='500' >\"  | sudo tee -a /var/www/html/index.html",
 
    "sudo systemctl start httpd"
                    ]
                           }
}

/*================================================checking output as a client==========================================================================*/

resource "null_resource" "null1"{

depends_on  = [null_resource.null3 ,]


provisioner "local-exec" {


    command = "start chrome http://${aws_instance.web.public_ip}/index.html "

  }
}





