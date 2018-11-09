+++
title = "Getting the MySQL Secret Backend Up and Running With Vault"
date = 2016-09-10T16:01:46-04:00
draft = false
tags = []
categories = []

+++

Vault is a product from hashicorp that is for storing and retrieving secrets. In their words 
> Vault is a tool for securely accessing secrets. A secret is anything that you want to tightly control access to, such as API keys, passwords, certificates, and more.

Vault has the a concept of secret backends that are components to store and generate secrets. One of these backends is the mysql backend that has offers some neat features. For example you can have vault automatically create mysql users and grants in addition to deleting the created users automatically after a specific period of time. 

I am going to walk through how one can set up and use the mysql backend and some of the less than obvious things I ran in to and how I made it work for my environment. I followed the vault [documentation](https://www.vaultproject.io/docs/secrets/mysql/index.html), which is pretty good. Although it is a basic walk through and I hit some things that were not covered and had to go digging in the mailing lists to figure out. 


## Setting up the mysql backend
#### The Mount
The firs step in using the mysql backend is to mount it. In the vault documentation their example is `vault mount mysql`, however this only works if you only have one database you want to create credentials for. I however have many more than just one. The recommended method at this time is to create a different path for you mount which can be done by passion options to the mount command. I use RDS from Amazon and I am setting vault to work in my dev environment. I made my path to make that clear to understand and I also added a description
```bash
vault mount -description="RDS DEV" -path=rds.dev mysql
```
In the above command we have the `-description` option where you can put in a string to describe this mount. The `-path` option where you specify the actual path to mount the back end to. and the final part that is just `mysql` is the mount type. Because I specified a path all data for this mount will not start with `rds.dev/` which will be shown below.

#### Connections
Next we have to specify our connection information. This will be a standard [DSN](https://en.wikipedia.org/wiki/Data_source_name) format.
```
vault write rds.dev/config/connection connection_url="root:root@tcp(rds.dev.yourdomain.com:3306)/
```
In the above command you do _not_ have to use the root user, but it does have to be a user that has the `GRANT` privilege to create users. Something to be aware of is that when you add this connection vault will try to connect to the database with these credentials. If authentication fails, your command will fail to. If need be you can pass an option to make vault not try this user at the time of saving. 

#### Lease Period
The lease period is optional, but it is one of the parts that provides a way to have constantly changing usernames and passwords with out any human intervention. The lease period specifies how long the generated credentials are valid before they are revoked. 

```
vault write rds.dev/config/lease lease=1h lease_max=24h
```
From the vault documentation
> This restricts each credential to being valid or leased for 1 hour at a time, with a maximum use period of 24 hours. This forces an application to renew their credentials at least hourly, and to recycle them once per day.

#### Roles
Now we are going to create a role. The role name will be part of the path you use to generate credentials later, so you may want to make the name meaningful to you in some way. The role also specifies how it constructs the username and how long the user name can be. The defaults for this are sensible so I am not changing. For those of you who have the 16 character limit for user names are in luck. The default username length is 16 characters. The role is also where we define the `SQL` command that creates the mysql users. 

```
vault write rds.dev/roles/vaulttest sql="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT SELECT ON *.* TO '{{name}}'@'%';"
```
The `{{name}}` and `{{password}}` parts are where vault populates the username and password it generates. So make sure have those and do not replace them with any sort of real username or password.

#### Generate Credentials
You now have a fully functional mysql secret backend for vault. To generate credentials all you need to do is 
```
vault read rds.dev/creds/vaulttest
```
Which will give you output something like 
```
Key             Value
lease_id        rds.dev/creds/vaulttest/bd404e98-0f35-b378-269a-b7770ef01897
lease_duration  3600
password        132ae3ef-5a64-7499-351e-bfe59f3a2a21
username        vaul-aefa635a-18
```

## Testing it
While you can do all this with the vault cli tool there are HTTP apis for all the above commands. In order to test how it would work with a real application I wrote a small [Go](http://golang.org) app to test and demo my setup. The test application connects to vault, generates new credentials and then continually opens connects to the database in a loop doing a simple `SELECT` command for one User from the `mysql.users` table. In order to make this easy to test I changed the lease time for my role to thirty seconds. Below you can see the output from the test.

```
./vault_mysql_test  -db <your.database.server> -vault <your.vault.server> -creds rds.dev/creds/vaulttest
2016/09/10 00:24:04 Reading mysql creds from vault
2016/09/10 00:24:08 Username: vaul-toke-1be24a
2016/09/10 00:24:08 Password: 401a69d1-959a-4c12-de22-0c6769d605e1
2016/09/10 00:24:08 Connecting to <your.database.server>
2016/09/10 00:24:09 Results jpweber
2016/09/10 00:24:14 Results jpweber
2016/09/10 00:24:20 Results jpweber
2016/09/10 00:24:25 Results jpweber
2016/09/10 00:24:30 Results jpweber
2016/09/10 00:24:35 Results jpweber
something is wrong trying to reach database
2016/09/10 00:24:41 Error 1045: Access denied for user 'vaul-toke-1be24a'@'10.0.0.2' (using password: YES)
```
As you can see I was able to generate new credentials. I then began connecting to the database executing the query. After thirty seconds when I tried to connected it failed with an access denied error. This is because the lease was 30 seconds and vault deleted the user after 30 seconds. In a real application you would want to request new credentials before you connect to your database at a time and interval that makes sense for you. For example every time you open a new connection you first request new credentials then open the connection with those new credentials. 

On the server side of things the vault logs look like this.
```
{"time":"2016-09-10T04:24:08.641437277Z","type":"request","auth":{"display_name":"token-Jim-Weber","policies":["root"],"metadata":null},"request":{"id":"89bdbf28-a60f-617e-fb1f-ba800b02625d","operation":"read","client_token":"hmac-sha256:2899dd40271276c2bb032c431c5d63fd1de350597a7e6b4a219ef95a0c816aeb","path":"rds.dev/creds/vaulttest","data":null,"remote_address":"10.0.0.2","wrap_ttl":0},"error":""}
```



This is from the audit log when generating new credentials. 

```
==> /var/log/vault.log <==
2016/09/10 04:24:38.692994 [INF] expire: revoked lease lease_id=rds.dev/creds/vaulttest/295a8108-7d98-aede-0495-0a9cebe6e452
```
Then after thirty seconds this is the vault server log showing that its revoking the lease on the credentials I generated. 

If you want to build and run the code yourself here is a [gist](https://gist.github.com/jpweber/11a36a39ef40097b23d496bb3c76281d) with the source

Vault is a powerful tool, but it is pretty young and sometimes documentation can be tough to find for things beyond the basics. But with some time and effort it can be a great addition to your infrastructure.