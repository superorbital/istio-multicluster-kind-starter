#! /bin/sh

set -e

export VAULT_ADDR=http://vault:8200

# give some time for Vault to start and be ready
sleep 3

MOUNTED_DIR=/certs
# login with root token at $VAULT_ADDR
vault login root

vault secrets enable pki
vault secrets tune -max-lease-ttl=87600h pki
vault write pki/root/generate/internal common_name=sample.mesh ttl=87600h issuer_name=root-2024
vault write pki/config/urls issuing_certificates="http://vault.example.com:8200/v1/pki/ca" crl_distribution_points="http://vault.example.com:8200/v1/pki/crl"

vault secrets enable -path=pki_int1 pki
vault secrets tune -max-lease-ttl=43800h pki_int1
vault write pki_int1/config/urls issuing_certificates="http://127.0.0.1:8200/v1/pki_int1/ca" crl_distribution_points="http://127.0.0.1:8200/v1/pki_int1/crl"
vault write pki_int1/intermediate/generate/internal common_name="sample.mesh Intermediate Authority" ttl=43800h -format=json | jq -r '.data.csr' > pki_int1.csr
vault write pki/root/sign-intermediate csr=@pki_int1.csr format=pem ttl=43800h > signed_certificate.pem
vault write -format=json pki/root/sign-intermediate csr=@pki_int1.csr ttl=43800h > signed.json
cat signed.json | jq -r '.data.certificate' > cluster1-chain.pem
cat signed.json | jq -r '.data.issuing_ca' >> cluster1-chain.pem

vault write pki_int1/intermediate/set-signed certificate=@cluster1-chain.pem

vault write pki_int1/roles/cluster1-issuer \
    allowed_domains=istio-ca \
    enforce_hostnames=false \
    allow_any_name=true \
    require_cn=false \
    allowed_uri_sans="spiffe://*" \
    allow_subdomains=true max_ttl=72h


vault secrets enable -path=pki_int2 pki
vault secrets tune -max-lease-ttl=43800h pki_int2
vault write pki_int2/config/urls issuing_certificates="http://127.0.0.1:8200/v1/pki_int2/ca" crl_distribution_points="http://127.0.0.1:8200/v1/pki_int2/crl"
vault write pki_int2/intermediate/generate/internal common_name="sample.mesh Intermediate Authority" ttl=43800h -format=json | jq -r '.data.csr' > pki_int2.csr
vault write pki/root/sign-intermediate csr=@pki_int2.csr format=pem ttl=43800h > signed_certificate.pem
vault write -format=json pki/root/sign-intermediate csr=@pki_int2.csr ttl=43800h > signed.json
cat signed.json | jq -r '.data.certificate' > cluster2-chain.pem
cat signed.json | jq -r '.data.issuing_ca' >> cluster2-chain.pem

vault write pki_int2/intermediate/set-signed certificate=@cluster2-chain.pem

vault write pki_int2/roles/cluster2-issuer \
    allowed_domains=istio-ca \
    enforce_hostnames=false \
    allow_any_name=true \
    allowed_uri_sans="spiffe://*" \
    require_cn=false \
    allow_subdomains=true max_ttl=72h

