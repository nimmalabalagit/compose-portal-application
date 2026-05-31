output "istiod_release_name" {
  value = helm_release.istiod.name
}

output "istio_version" {
  value = var.istio_version
}
