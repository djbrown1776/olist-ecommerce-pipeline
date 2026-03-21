output "bucket_name" {
  value = aws_s3_bucket.data_bucket.bucket
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.this.repository_url
  description = "ECR repo URL — use this for docker tag and push"
}

output "cluster_name" {
  value       = aws_ecs_cluster.this.name
  description = "ECS cluster name — use this for run-task"
}

output "task_definition_arn" {
  value       = aws_ecs_task_definition.this.arn
  description = "Task definition ARN"
}

output "log_group_name" {
  value       = aws_cloudwatch_log_group.this.name
  description = "CloudWatch log group for viewing pipeline output"
}

output "glue_job_name" {
  value       = aws_glue_job.transform.name
  description = "Glue job name — use this for aws glue start-job-run"
}

output "redshift_workgroup_endpoint" {
  description = "Redshift Serverless endpoint — use as the host in dbt profiles.yml"
  value       = aws_redshiftserverless_workgroup.this.endpoint
}

output "redshift_namespace_id" {
  description = "Redshift namespace ID"
  value       = aws_redshiftserverless_namespace.this.id
}

output "redshift_db_name" {
  description = "Redshift database name"
  value       = var.redshift_db_name
}

output "redshift_iam_role_arn" {
  description = "Redshift IAM role ARN — used in COPY commands"
  value       = aws_iam_role.redshift.arn
}