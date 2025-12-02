## List users
```bash
$ docker exec -it kopia kopia server users list
```
## Add a user
```bash
$ docker exec -it kopia kopia server users add <username>
```

## Connect client
./kopia repository connect server --url=https://kopia.emdecloud.de:443 --override-username=matthias --override-hostname=vogel --server-cert-fingerprint 3c9a31b5f4e7c216e0500d543bf13bdabeaefebd2842a9017b8cff6c548e3f41
