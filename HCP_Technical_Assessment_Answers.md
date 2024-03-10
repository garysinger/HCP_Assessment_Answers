<H1>Technical: AWS Secrets Engine</H1>

1. Setup a basic AWS secrets engine

`vault server -dev`

The command above runs a vault server in memory and should only be used for development and experimentation purposes.

Notes:
	Binds to 127.0.0.1:8200 by default without TLS

Open a new tab and make sure to set

`export VAULT_ADDR='http://127.0.0.1:8200'`

`export VAULT_TOKEN=<insert your vault token here>` 

before running the next command

`vault secrets enable aws` 

This will enable the aws secrets engine and allow you to write to the aws/ path in vault

```shell
$ vault write aws/config/root \
access_key=AKIA \
secret_key=abcdefg \
region=us-east-1
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

Deleting roles is done by specifing a specific role:
`vault delete aws/roles/<role to delete>`

____

3. Write a Vault ACL policy that will have the permissions to run the `vault write` command above

First I'd want to check what policies are currently in place using `vault policy list`
in my case, I see default and root

I'll go ahead and make a new policy and add the permissions to execute the `vault write` command:

I'll name the file `exercise-policy.hcl` and add the following to the file:

```bash
# Allow role creation on the aws/roles/* path
path "aws/roles/*" {
  capabilities = [ "create", "read", "update", "delete" ]
}
```

From this documentation https://developer.hashicorp.com/vault/docs/concepts/policies#capabilities I determined that create and update are usually used together. The read and delete options may not be necessary in this case, but I included them so the user has the ability to use `vault list aws/roles` and `vault delete aws/roles/<role>`

Now we can create a new policy called `exercise` with the added role creation permissions:

`vault policy write exercise <path to exercise-policy.hcl>` 

You can test to see if the new policy is made by running the following:

`vault policy list`

We see that the new `exercise` policy is added.

Now we can use that policy to make a new token and use that token to create a new role:

```bash
$ vault token create -policy=exercise
Key                  Value
---                  -----
token                hvs.CAESIG134ux5NAMEOFTOKENGOESHEREKHGh2cy5YWUQ4dENhMnRXTkFZZ0dXZmNKZzhiTVo
token_accessor       avlAv8oG7O4UisOBT9PxXhBU
token_duration       768h
token_renewable      true
token_policies       ["default" "exercise"]
identity_policies    []
policies             ["default" "exercise"]
```

We will take that token and override the previous `VAULT_TOKEN` environment variable so it is used when running vault commands going forwards:

`export VAULT_TOKEN="<token from above command>"`

Then running the `vault write aws/roles/my-role...` command results in a successful write to `aws/roles/my-role` using the newly created policy

```bash
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
Success! Data written to: aws/roles/my-role
```
