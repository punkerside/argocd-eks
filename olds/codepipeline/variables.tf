variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "services" {
  type    = list(string)
  default = ["golang", "python"]
}