module "bucket"{
    source = "./modules/bucket-aws"
    bucket_prefix = var.pipe_bucket_prefix
    region = var.pipe_region
}

