# Add users to radicale
```bash
$ nix shell nixpkgs#apacheHttpd
```
inside nix shell
```bash
$ htpasswd -5 -c ./services/radicale/users newuser
```
