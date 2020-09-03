/*--------------Providing aws to terraform------------------*/

provider "aws" {
    region    = "ap-south-1"
    profile   = "sonu"
}


/*--------------------------CReating key for accessing via ssh-----------------*/
resource "tls_private_key" "key" {
  algorithm = "RSA"
}

  module "key_pair" {

    source     = "terraform-aws-modules/key-pair/aws"
    key_name   = "sonu_ka_terraform_key"
    public_key = tls_private_key.key.public_key_openssh
}



/*-------------Creating security group for ssh ,http----------------------------*/


resource "aws_security_group" "security_group" {
  name        = "myterra_security_group"
  description = "Allow ssh and http"

  
 ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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
    Name = "sonu_ka_terraform_security_group"
  }
}


/*----------------launching ec2 instance with above key and security---------------*/
/*---and installing some software using provisiner remote-exec------*/
 


resource "aws_instance" "sonu_terraform_instance" {
  
  ami            = "ami-0447a12f28fddb066"
  instance_type  = "t2.micro"
  key_name = "sonu_ka_terraform_key"
  security_groups = ["myterra_security_group"]

 tags = {
    Name = "terraform_instance"
  }

connection {
    type         = "ssh"
    user         = "ec2-user"
    private_key  = tls_private_key.key.private_key_pem 
    host         = aws_instance.sonu_terraform_instance.public_ip
  }
provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd",
      "mkfs.ext4 /dev/xvdd",
      "sudo mount /dev/xvdd  /var/www/html",
      "sudo rm -f /var/www/html/*",
      "sudo git clone https://github.com/rakeshrdec/newrepo.git  /var/www/html",
    ]
  }

}


/*------------creating an ebs volume------------*/

resource "aws_ebs_volume" "terra_volume" {
  availability_zone = aws_instance.sonu_terraform_instance.availability_zone
  size = 1


}


/*------------------attaching the created volume with instace-----------*/




resource "aws_volume_attachment" "ebsvol_att" {

  device_name = "/dev/sdd"
  volume_id   = aws_ebs_volume.terra_volume.id
  instance_id = aws_instance.sonu_terraform_instance.id

}


/*-----------creating null resource for provisioner--------------*/




resource "null_resource" "null2"{

provisioner "local-exec" {
    command = "git clone https://github.com/rakeshrdec/imagerepo.git git_image"
  }
}



/*-----------creating a new s3 bucket--------------------------------*/


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



/*------------------uploading image in s3 bucket-----------------*/




resource "aws_s3_bucket_object" "bucket_object" {
  key    = "bucket.jpg"
  bucket = aws_s3_bucket.buckt.id
  source = "git_image/1.jpg"
  acl = "public-read-write"
}


locals {
  s3_origin_id = "aws_s3_bucket.buckt.id"
}




/*-----------cloudfront didtribution of s3 bucket image-----------------------------*/



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




resource "null_resource" "null3" {
depends_on = [
    aws_cloudfront_distribution.s3_distribution,
  ]

 connection {
           type     = "ssh"
           user     = "ec2-user"
           private_key = tls_private_key.key.private_key_pem
           host     = aws_instance.sonu_terraform_instance.public_ip
                   }
      
provisioner "remote-exec" {
           inline = [
    "echo \"<img src='https://${aws_cloudfront_distribution.s3_distribution.domain_name}/bucket.jpg' width='400' lenght='500' >\"  | sudo tee -a /var/www/html/index.html",
 
    "sudo systemctl start httpd"
                    ]
                           }
}

resource "null_resource" "null1"{

depends_on  = [null_resource.null3 ,]


provisioner "local-exec" {


    command = "start chrome http://${aws_instance.sonu_terraform_instance.public_ip}/index.html "

  }
}





output "out1" {
value = aws_cloudfront_distribution.s3_distribution.domain_name
}

output  "out2" {
value = aws_instance.sonu_terraform_instance.public_ip
}
