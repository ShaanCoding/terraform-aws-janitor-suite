locals {
  null_device = substr(lower(trimspace(chomp("${path.module}"))), 0, 1) == "/" ? "/dev/null" : "NUL"
}