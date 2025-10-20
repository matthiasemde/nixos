# Build the docker image

```bash
$ docker build -t nextcloud-derived:v32.0.0 .
```

Disable password login after enabling oauth

```bash
$ docker exec --user www-data -it nextcloud-aio-nextcloud php occ config:app:set --value=0 user_oidc allow_multiple_user_backends
```
