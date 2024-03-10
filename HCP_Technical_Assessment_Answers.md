<H1>Technical: AWS Secrets Engine</H1>

1. Setup a basic AWS secrets engine

`vault server -dev`
```zsh
➜  ~ vault server -dev
==> Vault server configuration:

Administrative Namespace: 
             Api Address: http://127.0.0.1:8200
                     Cgo: disabled
         Cluster Address: https://127.0.0.1:8201
...
2024-03-10T16:50:14.415-0500 [INFO]  core: vault is unsealed
2024-03-10T16:50:14.423-0500 [INFO]  core: successful mount: namespace="" path=secret/ type=kv version=""
WARNING! dev mode is enabled! In this mode, Vault runs entirely in-memory
and starts unsealed with a single unseal key. The root token is already
authenticated to the CLI, so you can immediately begin using Vault.

You may need to set the following environment variables:

    $ export VAULT_ADDR='http://127.0.0.1:8200'

The unseal key and root token are displayed below in case you want to
seal/unseal the Vault or re-authenticate.

Unseal Key: SSCB0PgXgXpyJUbfLZliyaLxRD708pzswWwweZ2rEHs=
Root Token: hvs.MzwH2JiVR9Ahra7TMfJjtFKn

Development mode should NOT be used in production installations!

2024-03-10T16:50:43.027-0500 [INFO]  core: successful mount: namespace="" path=aws/ type=aws version=""
```

Open a new tab and make sure to set

`export VAULT_ADDR='http://127.0.0.1:8200'`

`export VAULT_TOKEN='hvs.MzwH2JiVR9Ahra7TMfJjtFKn'`

before running the next command

`vault secrets enable aws` 
```zsh
➜  ~ vault secrets enable aws
Success! Enabled the aws secrets engine at: aws/
```

This will enable the aws secrets engine and allow you to write to the aws/ path in vault

```zsh
➜  ~ vault write aws/config/root \
access_key=AKIA \
secret_key=abcdefg \
region=us-east-1
Success! Data written to: aws/config/root
```

You should see `Success! Data written to: aws/config/root` as the result of running the command above

____

2. Convert example Vault CLI command into a direct Vault API request

```shell
$ vault write aws/roles/my-role \
credential_type=iam_user \
policy_document=-<<EOF
{
"Version": "2012-10-17",
"Statement": [
{
"Effect": "Allow",
"Action": "ec2:*",
"Resource": "*"
}
]
}
EOF
```

I'm using the following doc for reference : https://developer.hashicorp.com/vault/api-docs/secret/aws#create-update-role

It appears we are wanting to create a role in this case, this will require a `POST` request

We can also see that we are naming the role `my-role`, so the request path is `http://127.0.0.1:8200/v1/aws/roles/myrole`

Authentication seems to be the X-Vault-Token which we can get from the output of the `vault server -dev` command that we used to set the `VAULT_TOKEN` variable

For the body of the request we will use the AIM policy example shown in the documents and format it to usable json


```bash
curl \
    --request POST 'http://127.0.0.1:8200/v1/aws/roles/my-role' \
    --header "X-Vault-Token:$VAULT_TOKEN" \
    --json '{
                "credential_type": "iam_user",
                "policy_document": "{ \"Version\": \"2012-10-17\", \"Statement\": [ { \"Effect\": \"Allow\", \"Action\": \"ec2:*\", \"Resource\": \"*\" } ] }"
             }'
```

To match the formatting of the docs and to stay consistent with the customer facing documentation, we would want to format the curl as follows: 

```bash
curl \
    --header "X-Vault-Token:hvs.6czExampleTokenHerexpUUr" \
    --request POST \
    --data '{
                "credential_type": "iam_user",
                "policy_document": "{ \"Version\": \"2012-10-17\", \"Statement\": [ { \"Effect\": \"Allow\", \"Action\": \"ec2:*\", \"Resource\": \"*\" } ] }"
             }' \
    http://127.0.0.1:8200/v1/aws/roles/my-role
```
You can test if your new role was added by running `vault list aws/roles/`

```zsh
➜  ~ curl \
    --request POST 'http://127.0.0.1:8200/v1/aws/roles/my-role' \
    --header "X-Vault-Token:$VAULT_TOKEN" \
    --json '{
                "credential_type": "iam_user",
                "policy_document": "{ \"Version\": \"2012-10-17\", \"Statement\": [ { \"Effect\": \"Allow\", \"Action\": \"ec2:*\", \"Resource\": \"*\" } ] }"
             }'
➜  ~ vault list aws/roles/
Keys
----
my-role
➜  ~ curl \
    --header "X-Vault-Token:hvs.MzwH2JiVR9Ahra7TMfJjtFKn" \
    --request POST \
    --data '{
                "credential_type": "iam_user",
                "policy_document": "{ \"Version\": \"2012-10-17\", \"Statement\": [ { \"Effect\": \"Allow\", \"Action\": \"ec2:*\", \"Resource\": \"*\" } ] }"
             }' \
    http://127.0.0.1:8200/v1/aws/roles/my-role2
➜  ~ vault list aws/roles/
Keys
----
my-role
my-role2
```

____

3. Write a Vault ACL policy that will have the permissions to run the `vault write` command above

First I'd want to check what policies are currently in place using `vault policy list`
in my case, I see default and root

I'll go ahead and make a new policy and add the permissions to execute the `vault write` command:

I'll name the file `exercise-policy.hcl` and add the following to the file:

```bash
# Allow role creation on the aws/roles/* path
path "aws/roles/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}
```

From this documentation https://developer.hashicorp.com/vault/docs/concepts/policies#capabilities I determined that create and update are usually used together. The read , delete and list options may not be necessary in this case, but I included them so the user has the ability to use `vault list aws/roles` , `vault delete aws/roles/<role>` and `vault list aws/roles/`

Now we can create a new policy called `exercise` with the added role creation permissions:

`vault policy write exercise <path to exercise-policy.hcl>` 
```zsh
➜  vault policy write exercise exercise-policy.hcl
Success! Uploaded policy: exercise
```

You can test to see if the new policy is made by running the following:

`vault policy list`
```zsh
➜  vault vault policy list 
default
exercise
root
```

We see that the new `exercise` policy is added.

Now we can use that policy to make a new token and use that token to create a new role:

```zsh
➜  vault policy read exercise
# Allow role creation on the aws/ path
path "aws/roles/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}
➜  vault token create -policy=exercise 
Key                  Value
---                  -----
token                hvs.CAESIAhkiDlg2rf7lZQYQInI4b8RbGlJLkSDM4KtSDTmyWceGh4KHGh2cy5zcWhXaGdTZlhYU3RCTm8wR25YdFlRWGw
token_accessor       NQhghy8fAvoOo5Pvu7iYCl1I
token_duration       768h
token_renewable      true
token_policies       ["default" "exercise"]
identity_policies    []
policies             ["default" "exercise"]
```

We will take that token and override the previous `VAULT_TOKEN` environment variable so it is used when running vault commands going forwards:

`export VAULT_TOKEN="<token from above command>"`

Then running the `vault write aws/roles/my-role...` command results in a successful write to `aws/roles/my-role` using the newly created policy

```zsh
➜  export VAULT_TOKEN='hvs.CAESIAhkiDlg2rf7lZQYQInI4b8RbGlJLkSDM4KtSDTmyWceGh4KHGh2cy5zcWhXaGdTZlhYU3RCTm8wR25YdFlRWGw'
➜  vault write aws/roles/my-role3 \
credential_type=iam_user \
policy_document=-<<EOF
{
"Version": "2012-10-17",
"Statement": [
{
"Effect": "Allow",
"Action": "ec2:*",
"Resource": "*"
}
]
}
EOF
Success! Data written to: aws/roles/my-role3
➜  vault list aws/roles/  
Keys
----
my-role
my-role2
my-role3
```
