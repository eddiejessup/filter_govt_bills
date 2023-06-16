variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "image_tag" {
  description = "Tag of the image to deploy"
  type        = string
}

variable "port" {
  description = "Port that the application should listen on"
  type        = number
}

variable "domain" {
  description = "The name of the domain to serve the application at"
  type        = string
}

variable "subdomain" {
  description = "The name of the sub-domain to serve the application at"
  type        = string
}
