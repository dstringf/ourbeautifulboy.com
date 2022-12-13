# Welcome ...
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.45.0"
    }
  }
}
# ... to the cloud
provider "aws" {
  # Configuration options
}

# Create bucket to host website at http://www.ourbeautifulboy.com/
resource "aws_s3_bucket" "www-ourbeautifulboy-com" {
  bucket = "www.ourbeautifulboy.com"
}
# Create a public ACL so that visitors can access the bucket
resource "aws_s3_bucket_acl" "www-ourbeautifulboy-com_acl" {
 bucket = aws_s3_bucket.www-ourbeautifulboy-com.bucket
 acl = "public-read"
}
# Apply a bucket policy so that visitors can access the webpages
resource "aws_s3_bucket_policy" "www-ourbeautifulboy-com_policy" {
  bucket = aws_s3_bucket.www-ourbeautifulboy-com.id
  policy = data.aws_iam_policy_document.public.json
}
# Here's where we define the policy that is passed as json above
data "aws_iam_policy_document" "public" {
  statement {
    sid = "AllowPublic"
    effect = "Allow"
    principals {
      type  = "AWS"
      identifiers = ["*"]
    }
    actions = ["s3:GetObject"]
    resources = ["arn:aws:s3:::www.ourbeautifulboy.com/*"]
  }
}
# Unblock all the public bucket settings for our main website
resource "aws_s3_bucket_public_access_block" "www-ourbeautifulboy-com_block" {
  bucket = aws_s3_bucket.www-ourbeautifulboy-com.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
# Configure the bucket to operate in website mode
resource "aws_s3_bucket_website_configuration" "www-ourbeautifulboy-com-website" {
  bucket = aws_s3_bucket.www-ourbeautifulboy-com.bucket

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }

}
# Define the source location for the website content
module "static_files" {
    source  = "hashicorp/dir/template"
  version = "1.0.2"
  base_dir = "./content/www.ourbeautifulboy.com/"
  default_file_type = "text/html"
  }
# Iterate through all the files to set the content type correctly
resource "aws_s3_object" "www-ourbeautifulboy-com_content" {
  acl = "public-read"
  for_each = module.static_files.files
  bucket = aws_s3_bucket.www-ourbeautifulboy-com.bucket
  key = each.key
  content_type = each.value.content_type
  source  = each.value.source_path
  content = each.value.content
  etag = each.value.digests.md5
}
# Create another bucket to store our main website's access logs
resource "aws_s3_bucket" "accesslogs-www-ourbeautifulboy-com" {
  bucket = "accesslogs-www.ourbeautifulboy.com"
}
# Block all the public bucket settings to prevent the access logs from being public
resource "aws_s3_bucket_public_access_block" "accesslogs-www-ourbeautifulboy-com_block" {
  bucket = aws_s3_bucket.accesslogs-www-ourbeautifulboy-com.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_lifecycle_configuration" "accesslogs-www-ourbeautifulboy-com_lifecycle" {
  bucket = aws_s3_bucket.accesslogs-www-ourbeautifulboy-com.id
  rule {
    id = "low-cost-logs"
    status = "Enabled"
    transition {
      days = 30
      storage_class = "ONEZONE_IA"      
    }
    expiration {
      days = 365
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}
# Turn on access logs and send them to the access log bucket just created
resource "aws_s3_bucket_logging" "www-ourbeautifulboy-com_accesslogs" {
  bucket = aws_s3_bucket.www-ourbeautifulboy-com.id
  target_bucket = aws_s3_bucket.accesslogs-www-ourbeautifulboy-com.id
  target_prefix = ""
}
# Apply a bucket policy so that the S3 logging service can write to our bucket
resource "aws_s3_bucket_policy" "accesslogs-www-ourbeautifulboy-com_policy" {
  bucket = aws_s3_bucket.accesslogs-www-ourbeautifulboy-com.id
  policy = data.aws_iam_policy_document.logging.json
}
# Define the policy that is passed above
data "aws_iam_policy_document" "logging" {
  statement {
    sid = "S3PolicyStmt-DO-NOT-MODIFY-1670552220168"
    effect = "Allow"
    principals {
      type  = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.accesslogs-www-ourbeautifulboy-com.arn}/*"]
  }
}
# Create the zone to host our DNS configuration
resource "aws_route53_zone" "ourbeautifulboy-com" {
  name = "ourbeautifulboy.com"
}
# Create the DNS record that points the website to the S3 bucket
resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.ourbeautifulboy-com.zone_id
  name = "www.ourbeautifulboy.com"
  type = "CNAME"
  ttl = 300
  records = ["www.ourbeautifulboy.com.s3-website.us-east-2.amazonaws.com."]
}