output "dns_records_created" {
  description = "List of DNS records created"
  value       = keys(routeros_ip_dns_record.static_dns)
}

output "bgp_peers_created" {
  description = "List of BGP peers configured"
  value       = keys(routeros_routing_bgp_connection.bgp_peer)
}
