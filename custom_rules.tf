# https://developers.cloudflare.com/waf/custom-rules/
resource "cloudflare_ruleset" "my_custom_rules" {
  kind    = "zone"
  name    = "default"
  phase   = "http_request_firewall_custom"
  zone_id = var.cloudflare_zone_id

  # rules {
  #   ref         = "Sequence Mitigation 1"
  #   action      = "block"
  #   description = "Block store/inventory if not visited /pet/{var1} before"
  #   enabled     = true
  #   expression  = "cf.sequence.current_op eq \"36074bb2\" and not any(cf.sequence.previous_ops[*] == \"dbab25d2\")"
  #   action_parameters {
  #     response {
  #       content      = "WAF Block: Visit https://petstore.${var.cloudflare_zone}/api/v3/pet/1 before being allowed to visit this endpoint."
  #       content_type = "text/plain"
  #       status_code  = 403
  #     }
  #   }
  # }

  # rules {
  #   ref         = "Sequence Mitigation 2"
  #   action      = "block"
  #   description = "Block /pet/{var1} if previous endpoint visited was not /pet/findByStatus"
  #   enabled     = true
  #   expression  = "cf.sequence.current_op eq \"dbab25d2\" and cf.sequence.previous_ops[0] != \"965a3361\""
  #   action_parameters {
  #     response {
  #       content      = "WAF Block: Visit https://petstore.${var.cloudflare_zone}/api/v3/pet/findByStatus?status=available right before you are allowed to visit this endpoint."
  #       content_type = "text/plain"
  #       status_code  = 403
  #     }
  #   }
  # }

  # rules {
  #   ref         = "Sequence Mitigation 3"
  #   action      = "block"
  #   description = "Block /pet/findByStatus if you haven't visitted /user/login less than 2 minutes ago"
  #   enabled     = true
  #   expression  = "cf.sequence.current_op eq \"965a3361\" and not cf.sequence.msec_since_op[\"6ef5fb59\"] le 120000"
  #   action_parameters {
  #     response {
  #       content      = "WAF Block: You must have visited https://petstore.${var.cloudflare_zone}/api/v3/user/login less than 2 minutes before being allowed to visit this endpoint."
  #       content_type = "text/plain"
  #       status_code  = 403
  #     }
  #   }
  # }

  # rules {
  #   ref         = "Sequence Mitigation 4"
  #   action      = "block"
  #   description = "Visit specific sequence first"
  #   enabled     = true
  #   expression  = <<-EOT
  #   (
  #   cf.sequence.current_op eq "3305be41" and 
  #   not (
  #     cf.sequence.previous_ops[0] == "965a3361" and
  #     cf.sequence.previous_ops[1] == "36074bb2" and
  #     cf.sequence.previous_ops[2] == "dbab25d2"
  #     )
  #   )
  #   EOT
  #   action_parameters {
  #     response {
  #       content      = "WAF Block: Visit these endpoints in order to be allowedd\n1-> /api/v3/pet/{var1}\n2-> /api/v3/store/inventory\n3-> /api/v3/pet/findByStatus"
  #       content_type = "text/plain"
  #       status_code  = 403
  #     }
  #   }
  # }

  rules {
    action      = "block"
    description = "Block all requests to admin portal"
    enabled     = true
    expression  = <<-EOT
    (
    http.host eq "httpbin.${var.cloudflare_zone}" 
      and 
    lower(url_decode(http.request.uri.path)) matches "^/admin.*"
    )
    EOT
    action_parameters {
      response {
        content      = "You obviously don't have access"
        content_type = "text/plain"
        status_code  = 403
      }
    }
  }

  rules {
    action      = "skip"
    description = "Allow pentesters to bypass security"
    enabled     = false
    expression  = "(http.host eq \"httpbin.${var.cloudflare_zone}\" and ip.src in $allowlist)"
    action_parameters {
      phases = [
        "http_ratelimit",
        "http_request_firewall_managed",
        "http_request_sbfm",
      ]
      products = [
        "bic",
        "hot",
        "securityLevel",
        "uaBlock",
        "zoneLockdown",
      ]
      ruleset = "current"
    }
    logging {
      enabled = true
    }
  }

  rules {
    action      = "block"
    description = "Block truncated requests"
    enabled     = true
    expression  = "(http.request.headers.truncated or http.request.body.truncated)"
    action_parameters {
      response {
        content      = "No teapots allowed"
        content_type = "text/plain"
        status_code  = 418
      }
    }
  }

  rules {
    action      = "block"
    description = "Block non-allowlisted IP's from Admin"
    enabled     = true
    expression  = "(http.host eq \"httpbin.${var.cloudflare_zone}\" and url_decode(http.request.uri.path) matches \"^/admin.*\" and not ip.src in $allowlist)"
  }

  rules {
    action      = "skip"
    description = "Bots: Whitelist Good Bots"
    enabled     = true
    expression  = "http.host eq \"httpbin.${var.cloudflare_zone}\" and (cf.bot_management.verified_bot or ip.src in $allowlist)"
    action_parameters {
      phases = [
        "http_request_sbfm",
      ]
      ruleset = "current"
    }
    logging {
      enabled = true
    }
  }

  rules {
    action      = "block"
    description = "Bots: Block all Botscore < 30"
    enabled     = true
    expression  = "(http.host eq \"httpbin.${var.cloudflare_zone}\" and cf.bot_management.score lt 30)"
  }

  rules {
    action      = "managed_challenge"
    description = "Geo Challenge"
    enabled     = true
    expression  = "(not ip.geoip.country in {\"AU\" \"NZ\"})"
  }
}
