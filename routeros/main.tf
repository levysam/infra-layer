terraform {
  required_providers {
    routeros = {
      source  = "terraform-routeros/routeros"
      version = "1.62.0"
    }
  }
}

locals {
  dns_records_flat = flatten([
    for name, addresses in var.dns_records : [
      for addr in addresses : {
        name    = name
        address = addr
      }
    ]
  ])
}

resource "routeros_ip_dns_record" "static_dns" {
  for_each = { for idx, record in local.dns_records_flat : "${record.name}-${record.address}" => record }

  name    = each.value.name
  address = each.value.address
  type    = "A"
  ttl     = "300"
}

# Use local_asn or bgp_asn_router if provided
locals {
  router_asn = coalesce(var.bgp_asn_router, var.local_asn, "65000")
}

resource "routeros_routing_bgp_connection" "bgp_peer" {
  for_each = var.bgp_peers

  name = each.key
  as   = tostring(local.router_asn)
  remote {
    address = each.value.remote_address
    as      = each.value.remote_asn
  }
}
