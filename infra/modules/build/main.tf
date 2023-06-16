resource "aws_ecr_repository" "filter-govt-bills" {
  name = "filter-govt-bills"
  image_tag_mutability = "IMMUTABLE"
}
