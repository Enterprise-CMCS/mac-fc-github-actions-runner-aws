resource "aws_dynamodb_table" "lock_table" {
  name                        = "github-actions-runner-dev-lock-table"
  read_capacity               = 20
  write_capacity              = 20
  hash_key                    = "LockID"
  deletion_protection_enabled = true

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "github-actions-runner-dev-lock-table"
  }
}

resource "aws_s3_bucket" "tfstate" {
  lifecycle {
    prevent_destroy = true
  }

  bucket = "github-actions-runner-dev-tfstate"

  tags = {
    Name = "github-actions-runner-dev-tfstate"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "private"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 14
    }

    expiration {
      expired_object_delete_marker = true
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
