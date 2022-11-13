resource "aws_iam_service_linked_role" "es" {
  count = var.elasticsearch_enabled ? 1 : 0

  aws_service_name = "es.amazonaws.com"
}

resource "aws_kms_alias" "name" {
  count = var.elasticsearch_enabled ? 1 : 0

  name = "alias/${var.elasticsearch_name}"
  target_key_id = aws_kms_key.es.key_id
}

resource "aws_kms_key" "es" {
  count = var.elasticsearch_enabled ? 1 : 0
  
  deletion_window_in_days = 10
}

resource "aws_elasticsearch_domain" "es" {
  count = var.elasticsearch_enabled ? 1 : 0

  domain_name           = var.elasticsearch_name
  elasticsearch_version = var.elasticsearch_version

  cluster_config {
    dedicated_master_enabled = var.master_instance_enabled
    dedicated_master_count   = var.master_instance_enabled ? var.master_instance_count : null
    dedicated_master_type    = var.master_instance_enabled ? var.master_instance_type : null

    instance_count = var.hot_instance_count
    instance_type  = var.hot_instance_type

    warm_enabled = var.warm_instance_enabled
    warm_count   = var.warm_instance_enabled ? var.warm_instance_count : null
    warm_type    = var.warm_instance_enabled ? var.warm_instance_type : null

    zone_awareness_enabled = (var.availability_zones > 1) ? true : false

    dynamic "zone_awareness_config" {
      for_each = (var.availability_zones > 1) ? [var.availability_zones] : []
      content {
        availability_zone_count = zone_awareness_config.value
      }
    }
  }

  ebs_options {
    ebs_enabled = var.ebs_enabled
    volume_size = var.elasticsearch_volume_size
    volume_type = var.ebs_volume_type
    iops        = var.ebs_iops
  }

  encrypt_at_rest {
    enabled = var.elasticsearch_encrypt_at_rest
    kms_key_id = aws_kms_key.es.key_id
  }

  node_to_node_encryption {
    enabled = var.elasticsearch_node_to_node_encryption
  }

  domain_endpoint_options {
    enforce_https       = false
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled = false
  }

  tags = {
    Domain = var.elasticsearch_name
  }

  vpc_options {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.es_sec_grp.id]
  }

  access_policies = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "es:*",
        "Principal" : "*",
        "Effect" : "Allow",
        "Resource" : "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.elasticsearch_name}/*"
      }
    ]
  })

  depends_on = [aws_iam_service_linked_role.es]
}
