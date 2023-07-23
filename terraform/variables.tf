variable "name" {
  type = string
}

variable "eks_version" {
  type = string
}

variable "services" {
  type    = list(string)
  default = ["golang", "python"]
}