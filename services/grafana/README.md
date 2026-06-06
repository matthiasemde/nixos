# Create certs for alloy mTLS
## 1. CA
```bash
 openssl genrsa -out ca.key 4096
 openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt \
   -subj "/CN=alloy-ca"
```
 ## 2. Server cert (mahler) — SANs cover both ingest subdomains
```bash
 openssl genrsa -out server.key 4096
 openssl req -new -key server.key -out server.csr \
   -subj "/CN=alloy-metrics.emdecloud.de"
 openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
   -days 3650 -sha256 \
   -extfile <(echo "subjectAltName=DNS:alloy-metrics.emdecloud.de,DNS:alloy-logs.emdecloud.de") \
   -out server.crt
```

 ## 3. Client cert (bartok)
```bash
 openssl genrsa -out client.key 4096
 openssl req -new -key client.key -out client.csr -subj "/CN=bartok"
 openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
   -days 3650 -sha256 -out client.crt
```

 ## 4. Verify
```bash
 openssl verify -CAfile ca.crt server.crt client.crt
```
