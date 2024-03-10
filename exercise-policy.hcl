# Allow role creation on the aws/ path
path "aws/roles/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}
