pid_file = "/tmp/pidfile"

vault {
  address = "http://vault:8200"
}

auto_auth {
  method "approle" {
    mount_path = "auth/approle"
    config = {
      role_id_file_path = "/vault/config/role-id"
      secret_id_file_path = "/vault/config/secret-id"
      remove_secret_id_file_after_reading = false
    }
  }

  sink "file" {
    config = {
      path = "/vault/data/.vault-token"
      mode = 0640
    }
  }
}

template {
  source = "/vault/config/database.ctmpl"
  destination = "/vault/secrets/database.conf"
  perms = 0640
  command = "pkill -HUP myapp"
}

template {
  source = "/vault/config/api-keys.ctmpl"
  destination = "/vault/secrets/api-keys.json"
  perms = 0640
  command = "pkill -HUP myapp"
}
