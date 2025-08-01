variable "pm_api_url" {
  type = string
}

variable "pm_api_token_id" {
  type = string
}

variable "pm_api_token_secret" {
  type = string
  sensitive = true
}

variable "vm_csv_file" {
  description = "Path to CSV file containing VM definitions"
  type        = string
  default     = "vms.csv"
}

variable "gateway" {
  description = "Default gateway for VMs"
  type        = string
  default     = "10.200.0.254"
}

variable "storage" {
  description = "Default storage for VMs"
  type        = string
  default     = "local"
}

variable "ssh_keys" {
  description = "List of SSH public keys"
  type        = list(string)
  default = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCimmpqbCVR2pFNWmVbNuwpVSqkZSrINkmLrc1NFLqKUDYtNP8l65PbwcfN/y/Htpy1D7SpB1KrgUJR7CLtb759SUOL/+2C38qwnVItXvjsQDmnBR4VdZjcfLuDJVKjA+Dm3L7KkV3tyHmLnzkOkeM4lR3U2AAnyYqoFQ3U1yhra38z/VN8EYxSW07BUa0AeqwtfE48KMUWGUSQvl7DFOgS250IVAiUhmORY6V/YIeBmY2wQz6dESM2rd9C+DoSdOroTxiK9VRl5+yiXDRMdPHmlYoLA/uRFECO2lUE6qieAKPSentRXHL4x1SYRiiaTVGBMoqHHPr8SxMVqYkaIFJAwHPef/JSO3TlKHFhMRksgzrt/8HvJyps+ln4MwMk7WwJJNBLT+uxXZgulZ9DFLCcxW7MlqMFViEUprFosPEXKbRKs3i322Xnnr2nkd1mHiAQHbkeW6pS0KDkqy/SOJ8JTErveHA7QRZmeoMsWilbsB69aOX1N+sdVhHTvT6lkvM= root@bastion",
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDXuKLSiMAJFyGFt8AtQOYXGXuCppMMXrccjtT/BbuSVyyh20h1j+glVJX/6D0EapAy/nY+z/R13mVD3sUhovmOQttG6uCv9LGcGYMLJePTyT3Vzf/kZ66cK1q/iTdkmc9IqddjLX+MEzAmlcYs+CDFal/o+ZMeQLxLHORWWSwo/JTXOlgO/hQ2fgsNkxurfMGWVzntNr1GU+I1B59n1cXD7tzD/6CLklGDKMDBr8kOfkG/1dD2KBRHgUJ9pf0pD3ShK/KZGjN9Qru/to0t+XzW3G1eVfByqwxReQCDJlO/J+cln6wy5khY+DurIhgB6cenIvI0sDhT9nubKF4vgrDnK3aDJzgUmLv5/FKbbSvn2n2I1pg/hcAwgzMNd+plzEUUaTaoETjZyexYGIAqPVL7JmiyklTfvR5WaBDjcdaLNWHPyH0dXVa2I8BOo2A0B6zMXeErm2PjACn+maiBv0oJ3rPCC/S7HBof6wfFVDU+lnyKJEQlM3tRpCYsubujI7k= root@cicd",
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC1h/Ehx1Z6RvF5BAFFzSz0E4onUaUam3JYEnJs24UziiI6ww0XPVgvQTqIqBb3nGjrlQ+sSswXhjt/MQk7SimaELtF5YSzvO8Zp81f0cIA5wByUjJ2YGJkvEB8RW7/QwGcU5PEEjICC5Goy3XPlUgVUeOWKNALzIPVpW8gx2x9BGG23YPFMXmjrD9CaNBhnEvEByiltFvIrYkwcniKvI3XvfuZOUHOnoIQgEWtp63IwtQH3jnurViAxeDA/Uz7xG0SKrZV/neALBHoOQ8HFnzt/0x8XIyuUa0tOxE7KVukFZEB09m64PBxk3nvutexUXlk4JH8CvKLl3TseawaQyKbizL3XtYxD/ANqyXuTUxprFfj5N/YBaAage8xz9v3jungFht67USp6SayGHQJNUPTVj/VVZVoS6ReeYocqlkxS+tZEGFMWjgpu+7/wO7i8oXTSKFEXrRRycqX955Rqcgf+L0ean+JQelwXGoUrsftDAQLxRUYPooD+Zn6+NJqJK8= jenkins@cicd"
  ]
}