variable "project_id" {
  description = "The Google Cloud project everything lives in."
  type        = string
}

variable "region" {
  description = "Region for every resource, as in every lesson since L02."
  type        = string
  default     = "europe-west1"
}

variable "owner" {
  description = "Whose resources these are: used in names and labels."
  type        = string
}
