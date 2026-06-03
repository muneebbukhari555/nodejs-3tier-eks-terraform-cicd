resource "aws_ecr_repository" "ecr" {
  for_each             = toset(var.repositories)
  name                 = "${var.name}/${each.value}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "AES256"
  }
  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "ecr_lifecycle" {
  for_each   = aws_ecr_repository.ecr
  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last ${var.keep_last} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.keep_last
      }
      action = { type = "expire" }
    }]
  })
}
