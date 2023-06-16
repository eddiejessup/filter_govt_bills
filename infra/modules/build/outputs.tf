output "repository_name" {
  value = aws_ecr_repository.filter-govt-bills.name
}

output "repository_url" {
  value = aws_ecr_repository.filter-govt-bills.repository_url
}
