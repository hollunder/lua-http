local openssl_ctx = require "openssl.ssl.context"
local openssl_pkey = require "openssl.pkey"

-- Detect if openssl was compiled with ALPN enabled
local has_alpn = openssl_ctx.new().setAlpnSelect ~= nil

-- Creates a cipher list suitable for passing to `setCipherList`
local function cipher_list(arr)
	return table.concat(arr, ":")
end

-- Cipher lists from Mozilla.
-- https://wiki.mozilla.org/Security/Server_Side_TLS
-- This list of ciphers should be kept up to date.

-- "Modern" cipher list
local modern_cipher_list = cipher_list {
	"ECDHE-ECDSA-AES256-GCM-SHA384";
	"ECDHE-RSA-AES256-GCM-SHA384";
	"ECDHE-ECDSA-CHACHA20-POLY1305";
	"ECDHE-RSA-CHACHA20-POLY1305";
	"ECDHE-ECDSA-AES128-GCM-SHA256";
	"ECDHE-RSA-AES128-GCM-SHA256";
	"ECDHE-ECDSA-AES256-SHA384";
	"ECDHE-RSA-AES256-SHA384";
	"ECDHE-ECDSA-AES128-SHA256";
	"ECDHE-RSA-AES128-SHA256";
}

-- "Intermediate" cipher list
local intermediate_cipher_list = cipher_list {
	"ECDHE-ECDSA-CHACHA20-POLY1305";
	"ECDHE-RSA-CHACHA20-POLY1305";
	"ECDHE-ECDSA-AES128-GCM-SHA256";
	"ECDHE-RSA-AES128-GCM-SHA256";
	"ECDHE-ECDSA-AES256-GCM-SHA384";
	"ECDHE-RSA-AES256-GCM-SHA384";
	"DHE-RSA-AES128-GCM-SHA256";
	"DHE-RSA-AES256-GCM-SHA384";
	"ECDHE-ECDSA-AES128-SHA256";
	"ECDHE-RSA-AES128-SHA256";
	"ECDHE-ECDSA-AES128-SHA";
	"ECDHE-RSA-AES256-SHA384";
	"ECDHE-RSA-AES128-SHA";
	"ECDHE-ECDSA-AES256-SHA384";
	"ECDHE-ECDSA-AES256-SHA";
	"ECDHE-RSA-AES256-SHA";
	"DHE-RSA-AES128-SHA256";
	"DHE-RSA-AES128-SHA";
	"DHE-RSA-AES256-SHA256";
	"DHE-RSA-AES256-SHA";
	"ECDHE-ECDSA-DES-CBC3-SHA";
	"ECDHE-RSA-DES-CBC3-SHA";
	"EDH-RSA-DES-CBC3-SHA";
	"AES128-GCM-SHA256";
	"AES256-GCM-SHA384";
	"AES128-SHA256";
	"AES256-SHA256";
	"AES128-SHA";
	"AES256-SHA";
	"DES-CBC3-SHA";
	"!DSS";
}

-- A map from the cipher identifiers used in specifications to
-- the identifiers used by OpenSSL.
local spec_to_openssl = {
	-- SSL cipher suites

	SSL_DH_DSS_WITH_3DES_EDE_CBC_SHA        = "DH-DSS-DES-CBC3-SHA";
	SSL_DH_RSA_WITH_3DES_EDE_CBC_SHA        = "DH-RSA-DES-CBC3-SHA";
	SSL_DHE_DSS_WITH_3DES_EDE_CBC_SHA       = "DHE-DSS-DES-CBC3-SHA";
	SSL_DHE_RSA_WITH_3DES_EDE_CBC_SHA       = "DHE-RSA-DES-CBC3-SHA";

	SSL_DH_anon_WITH_RC4_128_MD5            = "ADH-RC4-MD5";
	SSL_DH_anon_WITH_3DES_EDE_CBC_SHA       = "ADH-DES-CBC3-SHA";


	-- TLS v1.0 cipher suites.

	TLS_RSA_WITH_NULL_MD5                   = "NULL-MD5";
	TLS_RSA_WITH_NULL_SHA                   = "NULL-SHA";
	TLS_RSA_WITH_RC4_128_MD5                = "RC4-MD5";
	TLS_RSA_WITH_RC4_128_SHA                = "RC4-SHA";
	TLS_RSA_WITH_IDEA_CBC_SHA               = "IDEA-CBC-SHA";
	TLS_RSA_WITH_DES_CBC_SHA                = "DES-CBC-SHA";
	TLS_RSA_WITH_3DES_EDE_CBC_SHA           = "DES-CBC3-SHA";

	TLS_DH_DSS_WITH_DES_CBC_SHA             = "DH-DSS-DES-CBC-SHA";
	TLS_DH_RSA_WITH_DES_CBC_SHA             = "DH-RSA-DES-CBC-SHA";
	TLS_DH_DSS_WITH_3DES_EDE_CBC_SHA        = "DH-DSS-DES-CBC3-SHA";
	TLS_DH_RSA_WITH_3DES_EDE_CBC_SHA        = "DH-RSA-DES-CBC3-SHA";
	TLS_DHE_DSS_WITH_DES_CBC_SHA            = "EDH-DSS-DES-CBC-SHA";
	TLS_DHE_RSA_WITH_DES_CBC_SHA            = "EDH-RSA-DES-CBC-SHA";
	TLS_DHE_DSS_WITH_3DES_EDE_CBC_SHA       = "DHE-DSS-DES-CBC3-SHA";
	TLS_DHE_RSA_WITH_3DES_EDE_CBC_SHA       = "DHE-RSA-DES-CBC3-SHA";

	TLS_DH_anon_WITH_RC4_128_MD5            = "ADH-RC4-MD5";
	TLS_DH_anon_WITH_DES_CBC_SHA            = "ADH-DES-CBC-SHA";
	TLS_DH_anon_WITH_3DES_EDE_CBC_SHA       = "ADH-DES-CBC3-SHA";


	-- AES ciphersuites from RFC3268, extending TLS v1.0

	TLS_RSA_WITH_AES_128_CBC_SHA            = "AES128-SHA";
	TLS_RSA_WITH_AES_256_CBC_SHA            = "AES256-SHA";

	TLS_DH_DSS_WITH_AES_128_CBC_SHA         = "DH-DSS-AES128-SHA";
	TLS_DH_DSS_WITH_AES_256_CBC_SHA         = "DH-DSS-AES256-SHA";
	TLS_DH_RSA_WITH_AES_128_CBC_SHA         = "DH-RSA-AES128-SHA";
	TLS_DH_RSA_WITH_AES_256_CBC_SHA         = "DH-RSA-AES256-SHA";

	TLS_DHE_DSS_WITH_AES_128_CBC_SHA        = "DHE-DSS-AES128-SHA";
	TLS_DHE_DSS_WITH_AES_256_CBC_SHA        = "DHE-DSS-AES256-SHA";
	TLS_DHE_RSA_WITH_AES_128_CBC_SHA        = "DHE-RSA-AES128-SHA";
	TLS_DHE_RSA_WITH_AES_256_CBC_SHA        = "DHE-RSA-AES256-SHA";

	TLS_DH_anon_WITH_AES_128_CBC_SHA        = "ADH-AES128-SHA";
	TLS_DH_anon_WITH_AES_256_CBC_SHA        = "ADH-AES256-SHA";


	-- Camellia ciphersuites from RFC4132, extending TLS v1.0

	TLS_RSA_WITH_CAMELLIA_128_CBC_SHA       = "CAMELLIA128-SHA";
	TLS_RSA_WITH_CAMELLIA_256_CBC_SHA       = "CAMELLIA256-SHA";

	TLS_DH_DSS_WITH_CAMELLIA_128_CBC_SHA    = "DH-DSS-CAMELLIA128-SHA";
	TLS_DH_DSS_WITH_CAMELLIA_256_CBC_SHA    = "DH-DSS-CAMELLIA256-SHA";
	TLS_DH_RSA_WITH_CAMELLIA_128_CBC_SHA    = "DH-RSA-CAMELLIA128-SHA";
	TLS_DH_RSA_WITH_CAMELLIA_256_CBC_SHA    = "DH-RSA-CAMELLIA256-SHA";

	TLS_DHE_DSS_WITH_CAMELLIA_128_CBC_SHA   = "DHE-DSS-CAMELLIA128-SHA";
	TLS_DHE_DSS_WITH_CAMELLIA_256_CBC_SHA   = "DHE-DSS-CAMELLIA256-SHA";
	TLS_DHE_RSA_WITH_CAMELLIA_128_CBC_SHA   = "DHE-RSA-CAMELLIA128-SHA";
	TLS_DHE_RSA_WITH_CAMELLIA_256_CBC_SHA   = "DHE-RSA-CAMELLIA256-SHA";

	TLS_DH_anon_WITH_CAMELLIA_128_CBC_SHA   = "ADH-CAMELLIA128-SHA";
	TLS_DH_anon_WITH_CAMELLIA_256_CBC_SHA   = "ADH-CAMELLIA256-SHA";


	-- SEED ciphersuites from RFC4162, extending TLS v1.0

	TLS_RSA_WITH_SEED_CBC_SHA               = "SEED-SHA";

	TLS_DH_DSS_WITH_SEED_CBC_SHA            = "DH-DSS-SEED-SHA";
	TLS_DH_RSA_WITH_SEED_CBC_SHA            = "DH-RSA-SEED-SHA";

	TLS_DHE_DSS_WITH_SEED_CBC_SHA           = "DHE-DSS-SEED-SHA";
	TLS_DHE_RSA_WITH_SEED_CBC_SHA           = "DHE-RSA-SEED-SHA";

	TLS_DH_anon_WITH_SEED_CBC_SHA           = "ADH-SEED-SHA";


	-- GOST ciphersuites from draft-chudov-cryptopro-cptls, extending TLS v1.0

	TLS_GOSTR341094_WITH_28147_CNT_IMIT = "GOST94-GOST89-GOST89";
	TLS_GOSTR341001_WITH_28147_CNT_IMIT = "GOST2001-GOST89-GOST89";
	TLS_GOSTR341094_WITH_NULL_GOSTR3411 = "GOST94-NULL-GOST94";
	TLS_GOSTR341001_WITH_NULL_GOSTR3411 = "GOST2001-NULL-GOST94";

	-- Additional Export 1024 and other cipher suites

	TLS_DHE_DSS_WITH_RC4_128_SHA            = "DHE-DSS-RC4-SHA";


	-- Elliptic curve cipher suites.

	TLS_ECDH_RSA_WITH_NULL_SHA              = "ECDH-RSA-NULL-SHA";
	TLS_ECDH_RSA_WITH_RC4_128_SHA           = "ECDH-RSA-RC4-SHA";
	TLS_ECDH_RSA_WITH_3DES_EDE_CBC_SHA      = "ECDH-RSA-DES-CBC3-SHA";
	TLS_ECDH_RSA_WITH_AES_128_CBC_SHA       = "ECDH-RSA-AES128-SHA";
	TLS_ECDH_RSA_WITH_AES_256_CBC_SHA       = "ECDH-RSA-AES256-SHA";

	TLS_ECDH_ECDSA_WITH_NULL_SHA            = "ECDH-ECDSA-NULL-SHA";
	TLS_ECDH_ECDSA_WITH_RC4_128_SHA         = "ECDH-ECDSA-RC4-SHA";
	TLS_ECDH_ECDSA_WITH_3DES_EDE_CBC_SHA    = "ECDH-ECDSA-DES-CBC3-SHA";
	TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA     = "ECDH-ECDSA-AES128-SHA";
	TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA     = "ECDH-ECDSA-AES256-SHA";

	TLS_ECDHE_RSA_WITH_NULL_SHA             = "ECDHE-RSA-NULL-SHA";
	TLS_ECDHE_RSA_WITH_RC4_128_SHA          = "ECDHE-RSA-RC4-SHA";
	TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA     = "ECDHE-RSA-DES-CBC3-SHA";
	TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA      = "ECDHE-RSA-AES128-SHA";
	TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA      = "ECDHE-RSA-AES256-SHA";

	TLS_ECDHE_ECDSA_WITH_NULL_SHA           = "ECDHE-ECDSA-NULL-SHA";
	TLS_ECDHE_ECDSA_WITH_RC4_128_SHA        = "ECDHE-ECDSA-RC4-SHA";
	TLS_ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA   = "ECDHE-ECDSA-DES-CBC3-SHA";
	TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA    = "ECDHE-ECDSA-AES128-SHA";
	TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA    = "ECDHE-ECDSA-AES256-SHA";

	TLS_ECDH_anon_WITH_NULL_SHA             = "AECDH-NULL-SHA";
	TLS_ECDH_anon_WITH_RC4_128_SHA          = "AECDH-RC4-SHA";
	TLS_ECDH_anon_WITH_3DES_EDE_CBC_SHA     = "AECDH-DES-CBC3-SHA";
	TLS_ECDH_anon_WITH_AES_128_CBC_SHA      = "AECDH-AES128-SHA";
	TLS_ECDH_anon_WITH_AES_256_CBC_SHA      = "AECDH-AES256-SHA";


	-- TLS v1.2 cipher suites

	TLS_RSA_WITH_NULL_SHA256                  = "NULL-SHA256";

	TLS_RSA_WITH_AES_128_CBC_SHA256           = "AES128-SHA256";
	TLS_RSA_WITH_AES_256_CBC_SHA256           = "AES256-SHA256";
	TLS_RSA_WITH_AES_128_GCM_SHA256           = "AES128-GCM-SHA256";
	TLS_RSA_WITH_AES_256_GCM_SHA384           = "AES256-GCM-SHA384";

	TLS_DH_RSA_WITH_AES_128_CBC_SHA256        = "DH-RSA-AES128-SHA256";
	TLS_DH_RSA_WITH_AES_256_CBC_SHA256        = "DH-RSA-AES256-SHA256";
	TLS_DH_RSA_WITH_AES_128_GCM_SHA256        = "DH-RSA-AES128-GCM-SHA256";
	TLS_DH_RSA_WITH_AES_256_GCM_SHA384        = "DH-RSA-AES256-GCM-SHA384";

	TLS_DH_DSS_WITH_AES_128_CBC_SHA256        = "DH-DSS-AES128-SHA256";
	TLS_DH_DSS_WITH_AES_256_CBC_SHA256        = "DH-DSS-AES256-SHA256";
	TLS_DH_DSS_WITH_AES_128_GCM_SHA256        = "DH-DSS-AES128-GCM-SHA256";
	TLS_DH_DSS_WITH_AES_256_GCM_SHA384        = "DH-DSS-AES256-GCM-SHA384";

	TLS_DHE_RSA_WITH_AES_128_CBC_SHA256       = "DHE-RSA-AES128-SHA256";
	TLS_DHE_RSA_WITH_AES_256_CBC_SHA256       = "DHE-RSA-AES256-SHA256";
	TLS_DHE_RSA_WITH_AES_128_GCM_SHA256       = "DHE-RSA-AES128-GCM-SHA256";
	TLS_DHE_RSA_WITH_AES_256_GCM_SHA384       = "DHE-RSA-AES256-GCM-SHA384";

	TLS_DHE_DSS_WITH_AES_128_CBC_SHA256       = "DHE-DSS-AES128-SHA256";
	TLS_DHE_DSS_WITH_AES_256_CBC_SHA256       = "DHE-DSS-AES256-SHA256";
	TLS_DHE_DSS_WITH_AES_128_GCM_SHA256       = "DHE-DSS-AES128-GCM-SHA256";
	TLS_DHE_DSS_WITH_AES_256_GCM_SHA384       = "DHE-DSS-AES256-GCM-SHA384";

	TLS_ECDH_RSA_WITH_AES_128_CBC_SHA256      = "ECDH-RSA-AES128-SHA256";
	TLS_ECDH_RSA_WITH_AES_256_CBC_SHA384      = "ECDH-RSA-AES256-SHA384";
	TLS_ECDH_RSA_WITH_AES_128_GCM_SHA256      = "ECDH-RSA-AES128-GCM-SHA256";
	TLS_ECDH_RSA_WITH_AES_256_GCM_SHA384      = "ECDH-RSA-AES256-GCM-SHA384";

	TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA256    = "ECDH-ECDSA-AES128-SHA256";
	TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA384    = "ECDH-ECDSA-AES256-SHA384";
	TLS_ECDH_ECDSA_WITH_AES_128_GCM_SHA256    = "ECDH-ECDSA-AES128-GCM-SHA256";
	TLS_ECDH_ECDSA_WITH_AES_256_GCM_SHA384    = "ECDH-ECDSA-AES256-GCM-SHA384";

	TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256     = "ECDHE-RSA-AES128-SHA256";
	TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384     = "ECDHE-RSA-AES256-SHA384";
	TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256     = "ECDHE-RSA-AES128-GCM-SHA256";
	TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384     = "ECDHE-RSA-AES256-GCM-SHA384";

	TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256   = "ECDHE-ECDSA-AES128-SHA256";
	TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384   = "ECDHE-ECDSA-AES256-SHA384";
	TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256   = "ECDHE-ECDSA-AES128-GCM-SHA256";
	TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384   = "ECDHE-ECDSA-AES256-GCM-SHA384";

	TLS_DH_anon_WITH_AES_128_CBC_SHA256       = "ADH-AES128-SHA256";
	TLS_DH_anon_WITH_AES_256_CBC_SHA256       = "ADH-AES256-SHA256";
	TLS_DH_anon_WITH_AES_128_GCM_SHA256       = "ADH-AES128-GCM-SHA256";
	TLS_DH_anon_WITH_AES_256_GCM_SHA384       = "ADH-AES256-GCM-SHA384";

	TLS_RSA_WITH_AES_128_CCM                  = "AES128-CCM";
	TLS_RSA_WITH_AES_256_CCM                  = "AES256-CCM";
	TLS_DHE_RSA_WITH_AES_128_CCM              = "DHE-RSA-AES128-CCM";
	TLS_DHE_RSA_WITH_AES_256_CCM              = "DHE-RSA-AES256-CCM";
	TLS_RSA_WITH_AES_128_CCM_8                = "AES128-CCM8";
	TLS_RSA_WITH_AES_256_CCM_8                = "AES256-CCM8";
	TLS_DHE_RSA_WITH_AES_128_CCM_8            = "DHE-RSA-AES128-CCM8";
	TLS_DHE_RSA_WITH_AES_256_CCM_8            = "DHE-RSA-AES256-CCM8";
	TLS_ECDHE_ECDSA_WITH_AES_128_CCM          = "ECDHE-ECDSA-AES128-CCM";
	TLS_ECDHE_ECDSA_WITH_AES_256_CCM          = "ECDHE-ECDSA-AES256-CCM";
	TLS_ECDHE_ECDSA_WITH_AES_128_CCM_8        = "ECDHE-ECDSA-AES128-CCM8";
	TLS_ECDHE_ECDSA_WITH_AES_256_CCM_8        = "ECDHE-ECDSA-AES256-CCM8";


	-- Camellia HMAC-Based ciphersuites from RFC6367, extending TLS v1.2

	TLS_ECDHE_ECDSA_WITH_CAMELLIA_128_CBC_SHA256 = "ECDHE-ECDSA-CAMELLIA128-SHA256";
	TLS_ECDHE_ECDSA_WITH_CAMELLIA_256_CBC_SHA384 = "ECDHE-ECDSA-CAMELLIA256-SHA384";
	TLS_ECDH_ECDSA_WITH_CAMELLIA_128_CBC_SHA256  = "ECDH-ECDSA-CAMELLIA128-SHA256";
	TLS_ECDH_ECDSA_WITH_CAMELLIA_256_CBC_SHA384  = "ECDH-ECDSA-CAMELLIA256-SHA384";
	TLS_ECDHE_RSA_WITH_CAMELLIA_128_CBC_SHA256   = "ECDHE-RSA-CAMELLIA128-SHA256";
	TLS_ECDHE_RSA_WITH_CAMELLIA_256_CBC_SHA384   = "ECDHE-RSA-CAMELLIA256-SHA384";
	TLS_ECDH_RSA_WITH_CAMELLIA_128_CBC_SHA256    = "ECDH-RSA-CAMELLIA128-SHA256";
	TLS_ECDH_RSA_WITH_CAMELLIA_256_CBC_SHA384    = "ECDH-RSA-CAMELLIA256-SHA384";


	-- Pre shared keying (PSK) ciphersuites

	TLS_PSK_WITH_NULL_SHA                         = "PSK-NULL-SHA";
	TLS_DHE_PSK_WITH_NULL_SHA                     = "DHE-PSK-NULL-SHA";
	TLS_RSA_PSK_WITH_NULL_SHA                     = "RSA-PSK-NULL-SHA";

	TLS_PSK_WITH_RC4_128_SHA                      = "PSK-RC4-SHA";
	TLS_PSK_WITH_3DES_EDE_CBC_SHA                 = "PSK-3DES-EDE-CBC-SHA";
	TLS_PSK_WITH_AES_128_CBC_SHA                  = "PSK-AES128-CBC-SHA";
	TLS_PSK_WITH_AES_256_CBC_SHA                  = "PSK-AES256-CBC-SHA";

	TLS_DHE_PSK_WITH_RC4_128_SHA                  = "DHE-PSK-RC4-SHA";
	TLS_DHE_PSK_WITH_3DES_EDE_CBC_SHA             = "DHE-PSK-3DES-EDE-CBC-SHA";
	TLS_DHE_PSK_WITH_AES_128_CBC_SHA              = "DHE-PSK-AES128-CBC-SHA";
	TLS_DHE_PSK_WITH_AES_256_CBC_SHA              = "DHE-PSK-AES256-CBC-SHA";

	TLS_RSA_PSK_WITH_RC4_128_SHA                  = "RSA-PSK-RC4-SHA";
	TLS_RSA_PSK_WITH_3DES_EDE_CBC_SHA             = "RSA-PSK-3DES-EDE-CBC-SHA";
	TLS_RSA_PSK_WITH_AES_128_CBC_SHA              = "RSA-PSK-AES128-CBC-SHA";
	TLS_RSA_PSK_WITH_AES_256_CBC_SHA              = "RSA-PSK-AES256-CBC-SHA";

	TLS_PSK_WITH_AES_128_GCM_SHA256               = "PSK-AES128-GCM-SHA256";
	TLS_PSK_WITH_AES_256_GCM_SHA384               = "PSK-AES256-GCM-SHA384";
	TLS_DHE_PSK_WITH_AES_128_GCM_SHA256           = "DHE-PSK-AES128-GCM-SHA256";
	TLS_DHE_PSK_WITH_AES_256_GCM_SHA384           = "DHE-PSK-AES256-GCM-SHA384";
	TLS_RSA_PSK_WITH_AES_128_GCM_SHA256           = "RSA-PSK-AES128-GCM-SHA256";
	TLS_RSA_PSK_WITH_AES_256_GCM_SHA384           = "RSA-PSK-AES256-GCM-SHA384";
	TLS_PSK_WITH_AES_128_CBC_SHA256               = "PSK-AES128-CBC-SHA256";
	TLS_PSK_WITH_AES_256_CBC_SHA384               = "PSK-AES256-CBC-SHA384";
	TLS_PSK_WITH_NULL_SHA256                      = "PSK-NULL-SHA256";
	TLS_PSK_WITH_NULL_SHA384                      = "PSK-NULL-SHA384";
	TLS_DHE_PSK_WITH_AES_128_CBC_SHA256           = "DHE-PSK-AES128-CBC-SHA256";
	TLS_DHE_PSK_WITH_AES_256_CBC_SHA384           = "DHE-PSK-AES256-CBC-SHA384";
	TLS_DHE_PSK_WITH_NULL_SHA256                  = "DHE-PSK-NULL-SHA256";
	TLS_DHE_PSK_WITH_NULL_SHA384                  = "DHE-PSK-NULL-SHA384";
	TLS_RSA_PSK_WITH_AES_128_CBC_SHA256           = "RSA-PSK-AES128-CBC-SHA256";
	TLS_RSA_PSK_WITH_AES_256_CBC_SHA384           = "RSA-PSK-AES256-CBC-SHA384";
	TLS_RSA_PSK_WITH_NULL_SHA256                  = "RSA-PSK-NULL-SHA256";
	TLS_RSA_PSK_WITH_NULL_SHA384                  = "RSA-PSK-NULL-SHA384";

	TLS_ECDHE_PSK_WITH_RC4_128_SHA                = "ECDHE-PSK-RC4-SHA";
	TLS_ECDHE_PSK_WITH_3DES_EDE_CBC_SHA           = "ECDHE-PSK-3DES-EDE-CBC-SHA";
	TLS_ECDHE_PSK_WITH_AES_128_CBC_SHA            = "ECDHE-PSK-AES128-CBC-SHA";
	TLS_ECDHE_PSK_WITH_AES_256_CBC_SHA            = "ECDHE-PSK-AES256-CBC-SHA";
	TLS_ECDHE_PSK_WITH_AES_128_CBC_SHA256         = "ECDHE-PSK-AES128-CBC-SHA256";
	TLS_ECDHE_PSK_WITH_AES_256_CBC_SHA384         = "ECDHE-PSK-AES256-CBC-SHA384";
	TLS_ECDHE_PSK_WITH_NULL_SHA                   = "ECDHE-PSK-NULL-SHA";
	TLS_ECDHE_PSK_WITH_NULL_SHA256                = "ECDHE-PSK-NULL-SHA256";
	TLS_ECDHE_PSK_WITH_NULL_SHA384                = "ECDHE-PSK-NULL-SHA384";

	TLS_PSK_WITH_CAMELLIA_128_CBC_SHA256          = "PSK-CAMELLIA128-SHA256";
	TLS_PSK_WITH_CAMELLIA_256_CBC_SHA384          = "PSK-CAMELLIA256-SHA384";

	TLS_DHE_PSK_WITH_CAMELLIA_128_CBC_SHA256      = "DHE-PSK-CAMELLIA128-SHA256";
	TLS_DHE_PSK_WITH_CAMELLIA_256_CBC_SHA384      = "DHE-PSK-CAMELLIA256-SHA384";

	TLS_RSA_PSK_WITH_CAMELLIA_128_CBC_SHA256      = "RSA-PSK-CAMELLIA128-SHA256";
	TLS_RSA_PSK_WITH_CAMELLIA_256_CBC_SHA384      = "RSA-PSK-CAMELLIA256-SHA384";

	TLS_ECDHE_PSK_WITH_CAMELLIA_128_CBC_SHA256    = "ECDHE-PSK-CAMELLIA128-SHA256";
	TLS_ECDHE_PSK_WITH_CAMELLIA_256_CBC_SHA384    = "ECDHE-PSK-CAMELLIA256-SHA384";

	TLS_PSK_WITH_AES_128_CCM                      = "PSK-AES128-CCM";
	TLS_PSK_WITH_AES_256_CCM                      = "PSK-AES256-CCM";
	TLS_DHE_PSK_WITH_AES_128_CCM                  = "DHE-PSK-AES128-CCM";
	TLS_DHE_PSK_WITH_AES_256_CCM                  = "DHE-PSK-AES256-CCM";
	TLS_PSK_WITH_AES_128_CCM_8                    = "PSK-AES128-CCM8";
	TLS_PSK_WITH_AES_256_CCM_8                    = "PSK-AES256-CCM8";
	TLS_DHE_PSK_WITH_AES_128_CCM_8                = "DHE-PSK-AES128-CCM8";
	TLS_DHE_PSK_WITH_AES_256_CCM_8                = "DHE-PSK-AES256-CCM8";


	-- Export ciphers

	TLS_RSA_EXPORT_WITH_RC4_40_MD5                = "EXP-RC4-MD5";
	TLS_RSA_EXPORT_WITH_RC2_CBC_40_MD5            = "EXP-RC2-CBC-MD5";
	TLS_RSA_EXPORT_WITH_DES40_CBC_SHA             = "EXP-DES-CBC-SHA";
	TLS_DH_anon_EXPORT_WITH_DES40_CBC_SHA         = "EXP-ADH-DES-CBC-SHA";
	TLS_DH_anon_EXPORT_WITH_RC4_40_MD5            = "EXP-ADH-RC4-MD5";
	TLS_DHE_RSA_EXPORT_WITH_DES40_CBC_SHA         = "EXP-EDH-RSA-DES-CBC-SHA";
	TLS_DHE_DSS_EXPORT_WITH_DES40_CBC_SHA         = "EXP-EDH-DSS-DES-CBC-SHA";
	TLS_DH_DSS_EXPORT_WITH_DES40_CBC_SHA          = "EXP-DH-DSS-DES-CBC-SHA";
	TLS_DH_RSA_EXPORT_WITH_DES40_CBC_SHA          = "EXP-DH-RSA-DES-CBC-SHA";


	-- KRB5

	TLS_KRB5_WITH_DES_CBC_SHA                     = "KRB5-DES-CBC-SHA";
	TLS_KRB5_WITH_3DES_EDE_CBC_SHA                = "KRB5-DES-CBC3-SHA";
	TLS_KRB5_WITH_RC4_128_SHA                     = "KRB5-RC4-SHA";
	TLS_KRB5_WITH_IDEA_CBC_SHA                    = "KRB5-IDEA-CBC-SHA";
	TLS_KRB5_WITH_DES_CBC_MD5                     = "KRB5-DES-CBC-MD5";
	TLS_KRB5_WITH_3DES_EDE_CBC_MD5                = "KRB5-DES-CBC3-MD5";
	TLS_KRB5_WITH_RC4_128_MD5                     = "KRB5-RC4-MD5";
	TLS_KRB5_WITH_IDEA_CBC_MD5                    = "KRB5-IDEA-CBC-MD5";
	TLS_KRB5_EXPORT_WITH_DES_CBC_40_SHA           = "EXP-KRB5-DES-CBC-SHA";
	TLS_KRB5_EXPORT_WITH_RC2_CBC_40_SHA           = "EXP-KRB5-RC2-CBC-SHA";
	TLS_KRB5_EXPORT_WITH_RC4_40_SHA               = "EXP-KRB5-RC4-SHA";
	TLS_KRB5_EXPORT_WITH_DES_CBC_40_MD5           = "EXP-KRB5-DES-CBC-MD5";
	TLS_KRB5_EXPORT_WITH_RC2_CBC_40_MD5           = "EXP-KRB5-RC2-CBC-MD5";
	TLS_KRB5_EXPORT_WITH_RC4_40_MD5               = "EXP-KRB5-RC4-MD5";


	-- SRP5

	TLS_SRP_SHA_WITH_3DES_EDE_CBC_SHA             = "SRP-3DES-EDE-CBC-SHA";
	TLS_SRP_SHA_RSA_WITH_3DES_EDE_CBC_SHA         = "SRP-RSA-3DES-EDE-CBC-SHA";
	TLS_SRP_SHA_DSS_WITH_3DES_EDE_CBC_SHA         = "SRP-DSS-3DES-EDE-CBC-SHA";
	TLS_SRP_SHA_WITH_AES_128_CBC_SHA              = "SRP-AES-128-CBC-SHA";
	TLS_SRP_SHA_RSA_WITH_AES_128_CBC_SHA          = "SRP-RSA-AES-128-CBC-SHA";
	TLS_SRP_SHA_DSS_WITH_AES_128_CBC_SHA          = "SRP-DSS-AES-128-CBC-SHA";
	TLS_SRP_SHA_WITH_AES_256_CBC_SHA              = "SRP-AES-256-CBC-SHA";
	TLS_SRP_SHA_RSA_WITH_AES_256_CBC_SHA          = "SRP-RSA-AES-256-CBC-SHA";
	TLS_SRP_SHA_DSS_WITH_AES_256_CBC_SHA          = "SRP-DSS-AES-256-CBC-SHA";


	-- CHACHA20+POLY1305

	TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256   = "ECDHE-RSA-CHACHA20-POLY1305";
	TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256 = "ECDHE-ECDSA-CHACHA20-POLY1305";
	TLS_DHE_RSA_WITH_CHACHA20_POLY1305_SHA256     = "DHE-RSA-CHACHA20-POLY1305";
}

-- Banned ciphers from https://http2.github.io/http2-spec/#BadCipherSuites
local banned_ciphers = {}
for _, v in ipairs {
	"TLS_NULL_WITH_NULL_NULL";
	"TLS_RSA_WITH_NULL_MD5";
	"TLS_RSA_WITH_NULL_SHA";
	"TLS_RSA_EXPORT_WITH_RC4_40_MD5";
	"TLS_RSA_WITH_RC4_128_MD5";
	"TLS_RSA_WITH_RC4_128_SHA";
	"TLS_RSA_EXPORT_WITH_RC2_CBC_40_MD5";
	"TLS_RSA_WITH_IDEA_CBC_SHA";
	"TLS_RSA_EXPORT_WITH_DES40_CBC_SHA";
	"TLS_RSA_WITH_DES_CBC_SHA";
	"TLS_RSA_WITH_3DES_EDE_CBC_SHA";
	"TLS_DH_DSS_EXPORT_WITH_DES40_CBC_SHA";
	"TLS_DH_DSS_WITH_DES_CBC_SHA";
	"TLS_DH_DSS_WITH_3DES_EDE_CBC_SHA";
	"TLS_DH_RSA_EXPORT_WITH_DES40_CBC_SHA";
	"TLS_DH_RSA_WITH_DES_CBC_SHA";
	"TLS_DH_RSA_WITH_3DES_EDE_CBC_SHA";
	"TLS_DHE_DSS_EXPORT_WITH_DES40_CBC_SHA";
	"TLS_DHE_DSS_WITH_DES_CBC_SHA";
	"TLS_DHE_DSS_WITH_3DES_EDE_CBC_SHA";
	"TLS_DHE_RSA_EXPORT_WITH_DES40_CBC_SHA";
	"TLS_DHE_RSA_WITH_DES_CBC_SHA";
	"TLS_DHE_RSA_WITH_3DES_EDE_CBC_SHA";
	"TLS_DH_anon_EXPORT_WITH_RC4_40_MD5";
	"TLS_DH_anon_WITH_RC4_128_MD5";
	"TLS_DH_anon_EXPORT_WITH_DES40_CBC_SHA";
	"TLS_DH_anon_WITH_DES_CBC_SHA";
	"TLS_DH_anon_WITH_3DES_EDE_CBC_SHA";
	"TLS_KRB5_WITH_DES_CBC_SHA";
	"TLS_KRB5_WITH_3DES_EDE_CBC_SHA";
	"TLS_KRB5_WITH_RC4_128_SHA";
	"TLS_KRB5_WITH_IDEA_CBC_SHA";
	"TLS_KRB5_WITH_DES_CBC_MD5";
	"TLS_KRB5_WITH_3DES_EDE_CBC_MD5";
	"TLS_KRB5_WITH_RC4_128_MD5";
	"TLS_KRB5_WITH_IDEA_CBC_MD5";
	"TLS_KRB5_EXPORT_WITH_DES_CBC_40_SHA";
	"TLS_KRB5_EXPORT_WITH_RC2_CBC_40_SHA";
	"TLS_KRB5_EXPORT_WITH_RC4_40_SHA";
	"TLS_KRB5_EXPORT_WITH_DES_CBC_40_MD5";
	"TLS_KRB5_EXPORT_WITH_RC2_CBC_40_MD5";
	"TLS_KRB5_EXPORT_WITH_RC4_40_MD5";
	"TLS_PSK_WITH_NULL_SHA";
	"TLS_DHE_PSK_WITH_NULL_SHA";
	"TLS_RSA_PSK_WITH_NULL_SHA";
	"TLS_RSA_WITH_AES_128_CBC_SHA";
	"TLS_DH_DSS_WITH_AES_128_CBC_SHA";
	"TLS_DH_RSA_WITH_AES_128_CBC_SHA";
	"TLS_DHE_DSS_WITH_AES_128_CBC_SHA";
	"TLS_DHE_RSA_WITH_AES_128_CBC_SHA";
	"TLS_DH_anon_WITH_AES_128_CBC_SHA";
	"TLS_RSA_WITH_AES_256_CBC_SHA";
	"TLS_DH_DSS_WITH_AES_256_CBC_SHA";
	"TLS_DH_RSA_WITH_AES_256_CBC_SHA";
	"TLS_DHE_DSS_WITH_AES_256_CBC_SHA";
	"TLS_DHE_RSA_WITH_AES_256_CBC_SHA";
	"TLS_DH_anon_WITH_AES_256_CBC_SHA";
	"TLS_RSA_WITH_NULL_SHA256";
	"TLS_RSA_WITH_AES_128_CBC_SHA256";
	"TLS_RSA_WITH_AES_256_CBC_SHA256";
	"TLS_DH_DSS_WITH_AES_128_CBC_SHA256";
	"TLS_DH_RSA_WITH_AES_128_CBC_SHA256";
	"TLS_DHE_DSS_WITH_AES_128_CBC_SHA256";
	"TLS_RSA_WITH_CAMELLIA_128_CBC_SHA";
	"TLS_DH_DSS_WITH_CAMELLIA_128_CBC_SHA";
	"TLS_DH_RSA_WITH_CAMELLIA_128_CBC_SHA";
	"TLS_DHE_DSS_WITH_CAMELLIA_128_CBC_SHA";
	"TLS_DHE_RSA_WITH_CAMELLIA_128_CBC_SHA";
	"TLS_DH_anon_WITH_CAMELLIA_128_CBC_SHA";
	"TLS_DHE_RSA_WITH_AES_128_CBC_SHA256";
	"TLS_DH_DSS_WITH_AES_256_CBC_SHA256";
	"TLS_DH_RSA_WITH_AES_256_CBC_SHA256";
	"TLS_DHE_DSS_WITH_AES_256_CBC_SHA256";
	"TLS_DHE_RSA_WITH_AES_256_CBC_SHA256";
	"TLS_DH_anon_WITH_AES_128_CBC_SHA256";
	"TLS_DH_anon_WITH_AES_256_CBC_SHA256";
	"TLS_RSA_WITH_CAMELLIA_256_CBC_SHA";
	"TLS_DH_DSS_WITH_CAMELLIA_256_CBC_SHA";
	"TLS_DH_RSA_WITH_CAMELLIA_256_CBC_SHA";
	"TLS_DHE_DSS_WITH_CAMELLIA_256_CBC_SHA";
	"TLS_DHE_RSA_WITH_CAMELLIA_256_CBC_SHA";
	"TLS_DH_anon_WITH_CAMELLIA_256_CBC_SHA";
	"TLS_PSK_WITH_RC4_128_SHA";
	"TLS_PSK_WITH_3DES_EDE_CBC_SHA";
	"TLS_PSK_WITH_AES_128_CBC_SHA";
	"TLS_PSK_WITH_AES_256_CBC_SHA";
	"TLS_DHE_PSK_WITH_RC4_128_SHA";
	"TLS_DHE_PSK_WITH_3DES_EDE_CBC_SHA";
	"TLS_DHE_PSK_WITH_AES_128_CBC_SHA";
	"TLS_DHE_PSK_WITH_AES_256_CBC_SHA";
	"TLS_RSA_PSK_WITH_RC4_128_SHA";
	"TLS_RSA_PSK_WITH_3DES_EDE_CBC_SHA";
	"TLS_RSA_PSK_WITH_AES_128_CBC_SHA";
	"TLS_RSA_PSK_WITH_AES_256_CBC_SHA";
	"TLS_RSA_WITH_SEED_CBC_SHA";
	"TLS_DH_DSS_WITH_SEED_CBC_SHA";
	"TLS_DH_RSA_WITH_SEED_CBC_SHA";
	"TLS_DHE_DSS_WITH_SEED_CBC_SHA";
	"TLS_DHE_RSA_WITH_SEED_CBC_SHA";
	"TLS_DH_anon_WITH_SEED_CBC_SHA";
	"TLS_RSA_WITH_AES_128_GCM_SHA256";
	"TLS_RSA_WITH_AES_256_GCM_SHA384";
	"TLS_DH_RSA_WITH_AES_128_GCM_SHA256";
	"TLS_DH_RSA_WITH_AES_256_GCM_SHA384";
	"TLS_DH_DSS_WITH_AES_128_GCM_SHA256";
	"TLS_DH_DSS_WITH_AES_256_GCM_SHA384";
	"TLS_DH_anon_WITH_AES_128_GCM_SHA256";
	"TLS_DH_anon_WITH_AES_256_GCM_SHA384";
	"TLS_PSK_WITH_AES_128_GCM_SHA256";
	"TLS_PSK_WITH_AES_256_GCM_SHA384";
	"TLS_RSA_PSK_WITH_AES_128_GCM_SHA256";
	"TLS_RSA_PSK_WITH_AES_256_GCM_SHA384";
	"TLS_PSK_WITH_AES_128_CBC_SHA256";
	"TLS_PSK_WITH_AES_256_CBC_SHA384";
	"TLS_PSK_WITH_NULL_SHA256";
	"TLS_PSK_WITH_NULL_SHA384";
	"TLS_DHE_PSK_WITH_AES_128_CBC_SHA256";
	"TLS_DHE_PSK_WITH_AES_256_CBC_SHA384";
	"TLS_DHE_PSK_WITH_NULL_SHA256";
	"TLS_DHE_PSK_WITH_NULL_SHA384";
	"TLS_RSA_PSK_WITH_AES_128_CBC_SHA256";
	"TLS_RSA_PSK_WITH_AES_256_CBC_SHA384";
	"TLS_RSA_PSK_WITH_NULL_SHA256";
	"TLS_RSA_PSK_WITH_NULL_SHA384";
	"TLS_RSA_WITH_CAMELLIA_128_CBC_SHA256";
	"TLS_DH_DSS_WITH_CAMELLIA_128_CBC_SHA256";
	"TLS_DH_RSA_WITH_CAMELLIA_128_CBC_SHA256";
	"TLS_DHE_DSS_WITH_CAMELLIA_128_CBC_SHA256";
	"TLS_DHE_RSA_WITH_CAMELLIA_128_CBC_SHA256";
	"TLS_DH_anon_WITH_CAMELLIA_128_CBC_SHA256";
	"TLS_RSA_WITH_CAMELLIA_256_CBC_SHA256";
	"TLS_DH_DSS_WITH_CAMELLIA_256_CBC_SHA256";
	"TLS_DH_RSA_WITH_CAMELLIA_256_CBC_SHA256";
	"TLS_DHE_DSS_WITH_CAMELLIA_256_CBC_SHA256";
	"TLS_DHE_RSA_WITH_CAMELLIA_256_CBC_SHA256";
	"TLS_DH_anon_WITH_CAMELLIA_256_CBC_SHA256";
	"TLS_EMPTY_RENEGOTIATION_INFO_SCSV";
	"TLS_ECDH_ECDSA_WITH_NULL_SHA";
	"TLS_ECDH_ECDSA_WITH_RC4_128_SHA";
	"TLS_ECDH_ECDSA_WITH_3DES_EDE_CBC_SHA";
	"TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA";
	"TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA";
	"TLS_ECDHE_ECDSA_WITH_NULL_SHA";
	"TLS_ECDHE_ECDSA_WITH_RC4_128_SHA";
	"TLS_ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA";
	"TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA";
	"TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA";
	"TLS_ECDH_RSA_WITH_NULL_SHA";
	"TLS_ECDH_RSA_WITH_RC4_128_SHA";
	"TLS_ECDH_RSA_WITH_3DES_EDE_CBC_SHA";
	"TLS_ECDH_RSA_WITH_AES_128_CBC_SHA";
	"TLS_ECDH_RSA_WITH_AES_256_CBC_SHA";
	"TLS_ECDHE_RSA_WITH_NULL_SHA";
	"TLS_ECDHE_RSA_WITH_RC4_128_SHA";
	"TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA";
	"TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA";
	"TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA";
	"TLS_ECDH_anon_WITH_NULL_SHA";
	"TLS_ECDH_anon_WITH_RC4_128_SHA";
	"TLS_ECDH_anon_WITH_3DES_EDE_CBC_SHA";
	"TLS_ECDH_anon_WITH_AES_128_CBC_SHA";
	"TLS_ECDH_anon_WITH_AES_256_CBC_SHA";
	"TLS_SRP_SHA_WITH_3DES_EDE_CBC_SHA";
	"TLS_SRP_SHA_RSA_WITH_3DES_EDE_CBC_SHA";
	"TLS_SRP_SHA_DSS_WITH_3DES_EDE_CBC_SHA";
	"TLS_SRP_SHA_WITH_AES_128_CBC_SHA";
	"TLS_SRP_SHA_RSA_WITH_AES_128_CBC_SHA";
	"TLS_SRP_SHA_DSS_WITH_AES_128_CBC_SHA";
	"TLS_SRP_SHA_WITH_AES_256_CBC_SHA";
	"TLS_SRP_SHA_RSA_WITH_AES_256_CBC_SHA";
	"TLS_SRP_SHA_DSS_WITH_AES_256_CBC_SHA";
	"TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256";
	"TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384";
	"TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA256";
	"TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA384";
	"TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256";
	"TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384";
	"TLS_ECDH_RSA_WITH_AES_128_CBC_SHA256";
	"TLS_ECDH_RSA_WITH_AES_256_CBC_SHA384";
	"TLS_ECDH_ECDSA_WITH_AES_128_GCM_SHA256";
	"TLS_ECDH_ECDSA_WITH_AES_256_GCM_SHA384";
	"TLS_ECDH_RSA_WITH_AES_128_GCM_SHA256";
	"TLS_ECDH_RSA_WITH_AES_256_GCM_SHA384";
	"TLS_ECDHE_PSK_WITH_RC4_128_SHA";
	"TLS_ECDHE_PSK_WITH_3DES_EDE_CBC_SHA";
	"TLS_ECDHE_PSK_WITH_AES_128_CBC_SHA";
	"TLS_ECDHE_PSK_WITH_AES_256_CBC_SHA";
	"TLS_ECDHE_PSK_WITH_AES_128_CBC_SHA256";
	"TLS_ECDHE_PSK_WITH_AES_256_CBC_SHA384";
	"TLS_ECDHE_PSK_WITH_NULL_SHA";
	"TLS_ECDHE_PSK_WITH_NULL_SHA256";
	"TLS_ECDHE_PSK_WITH_NULL_SHA384";
	"TLS_RSA_WITH_ARIA_128_CBC_SHA256";
	"TLS_RSA_WITH_ARIA_256_CBC_SHA384";
	"TLS_DH_DSS_WITH_ARIA_128_CBC_SHA256";
	"TLS_DH_DSS_WITH_ARIA_256_CBC_SHA384";
	"TLS_DH_RSA_WITH_ARIA_128_CBC_SHA256";
	"TLS_DH_RSA_WITH_ARIA_256_CBC_SHA384";
	"TLS_DHE_DSS_WITH_ARIA_128_CBC_SHA256";
	"TLS_DHE_DSS_WITH_ARIA_256_CBC_SHA384";
	"TLS_DHE_RSA_WITH_ARIA_128_CBC_SHA256";
	"TLS_DHE_RSA_WITH_ARIA_256_CBC_SHA384";
	"TLS_DH_anon_WITH_ARIA_128_CBC_SHA256";
	"TLS_DH_anon_WITH_ARIA_256_CBC_SHA384";
	"TLS_ECDHE_ECDSA_WITH_ARIA_128_CBC_SHA256";
	"TLS_ECDHE_ECDSA_WITH_ARIA_256_CBC_SHA384";
	"TLS_ECDH_ECDSA_WITH_ARIA_128_CBC_SHA256";
	"TLS_ECDH_ECDSA_WITH_ARIA_256_CBC_SHA384";
	"TLS_ECDHE_RSA_WITH_ARIA_128_CBC_SHA256";
	"TLS_ECDHE_RSA_WITH_ARIA_256_CBC_SHA384";
	"TLS_ECDH_RSA_WITH_ARIA_128_CBC_SHA256";
	"TLS_ECDH_RSA_WITH_ARIA_256_CBC_SHA384";
	"TLS_RSA_WITH_ARIA_128_GCM_SHA256";
	"TLS_RSA_WITH_ARIA_256_GCM_SHA384";
	"TLS_DH_RSA_WITH_ARIA_128_GCM_SHA256";
	"TLS_DH_RSA_WITH_ARIA_256_GCM_SHA384";
	"TLS_DH_DSS_WITH_ARIA_128_GCM_SHA256";
	"TLS_DH_DSS_WITH_ARIA_256_GCM_SHA384";
	"TLS_DH_anon_WITH_ARIA_128_GCM_SHA256";
	"TLS_DH_anon_WITH_ARIA_256_GCM_SHA384";
	"TLS_ECDH_ECDSA_WITH_ARIA_128_GCM_SHA256";
	"TLS_ECDH_ECDSA_WITH_ARIA_256_GCM_SHA384";
	"TLS_ECDH_RSA_WITH_ARIA_128_GCM_SHA256";
	"TLS_ECDH_RSA_WITH_ARIA_256_GCM_SHA384";
	"TLS_PSK_WITH_ARIA_128_CBC_SHA256";
	"TLS_PSK_WITH_ARIA_256_CBC_SHA384";
	"TLS_DHE_PSK_WITH_ARIA_128_CBC_SHA256";
	"TLS_DHE_PSK_WITH_ARIA_256_CBC_SHA384";
	"TLS_RSA_PSK_WITH_ARIA_128_CBC_SHA256";
	"TLS_RSA_PSK_WITH_ARIA_256_CBC_SHA384";
	"TLS_PSK_WITH_ARIA_128_GCM_SHA256";
	"TLS_PSK_WITH_ARIA_256_GCM_SHA384";
	"TLS_RSA_PSK_WITH_ARIA_128_GCM_SHA256";
	"TLS_RSA_PSK_WITH_ARIA_256_GCM_SHA384";
	"TLS_ECDHE_PSK_WITH_ARIA_128_CBC_SHA256";
	"TLS_ECDHE_PSK_WITH_ARIA_256_CBC_SHA384";
	"TLS_ECDHE_ECDSA_WITH_CAMELLIA_128_CBC_SHA256";
	"TLS_ECDHE_ECDSA_WITH_CAMELLIA_256_CBC_SHA384";
	"TLS_ECDH_ECDSA_WITH_CAMELLIA_128_CBC_SHA256";
	"TLS_ECDH_ECDSA_WITH_CAMELLIA_256_CBC_SHA384";
	"TLS_ECDHE_RSA_WITH_CAMELLIA_128_CBC_SHA256";
	"TLS_ECDHE_RSA_WITH_CAMELLIA_256_CBC_SHA384";
	"TLS_ECDH_RSA_WITH_CAMELLIA_128_CBC_SHA256";
	"TLS_ECDH_RSA_WITH_CAMELLIA_256_CBC_SHA384";
	"TLS_RSA_WITH_CAMELLIA_128_GCM_SHA256";
	"TLS_RSA_WITH_CAMELLIA_256_GCM_SHA384";
	"TLS_DH_RSA_WITH_CAMELLIA_128_GCM_SHA256";
	"TLS_DH_RSA_WITH_CAMELLIA_256_GCM_SHA384";
	"TLS_DH_DSS_WITH_CAMELLIA_128_GCM_SHA256";
	"TLS_DH_DSS_WITH_CAMELLIA_256_GCM_SHA384";
	"TLS_DH_anon_WITH_CAMELLIA_128_GCM_SHA256";
	"TLS_DH_anon_WITH_CAMELLIA_256_GCM_SHA384";
	"TLS_ECDH_ECDSA_WITH_CAMELLIA_128_GCM_SHA256";
	"TLS_ECDH_ECDSA_WITH_CAMELLIA_256_GCM_SHA384";
	"TLS_ECDH_RSA_WITH_CAMELLIA_128_GCM_SHA256";
	"TLS_ECDH_RSA_WITH_CAMELLIA_256_GCM_SHA384";
	"TLS_PSK_WITH_CAMELLIA_128_GCM_SHA256";
	"TLS_PSK_WITH_CAMELLIA_256_GCM_SHA384";
	"TLS_RSA_PSK_WITH_CAMELLIA_128_GCM_SHA256";
	"TLS_RSA_PSK_WITH_CAMELLIA_256_GCM_SHA384";
	"TLS_PSK_WITH_CAMELLIA_128_CBC_SHA256";
	"TLS_PSK_WITH_CAMELLIA_256_CBC_SHA384";
	"TLS_DHE_PSK_WITH_CAMELLIA_128_CBC_SHA256";
	"TLS_DHE_PSK_WITH_CAMELLIA_256_CBC_SHA384";
	"TLS_RSA_PSK_WITH_CAMELLIA_128_CBC_SHA256";
	"TLS_RSA_PSK_WITH_CAMELLIA_256_CBC_SHA384";
	"TLS_ECDHE_PSK_WITH_CAMELLIA_128_CBC_SHA256";
	"TLS_ECDHE_PSK_WITH_CAMELLIA_256_CBC_SHA384";
	"TLS_RSA_WITH_AES_128_CCM";
	"TLS_RSA_WITH_AES_256_CCM";
	"TLS_RSA_WITH_AES_128_CCM_8";
	"TLS_RSA_WITH_AES_256_CCM_8";
	"TLS_PSK_WITH_AES_128_CCM";
	"TLS_PSK_WITH_AES_256_CCM";
	"TLS_PSK_WITH_AES_128_CCM_8";
	"TLS_PSK_WITH_AES_256_CCM_8";
} do
	local openssl_cipher_name = spec_to_openssl[v]
	if openssl_cipher_name then
		banned_ciphers[openssl_cipher_name] = true
	end
end

local function new_client_context()
	local ctx = openssl_ctx.new("TLSv1_2", false)
	ctx:setCipherList(intermediate_cipher_list)
	ctx:setOptions(openssl_ctx.OP_NO_COMPRESSION+openssl_ctx.OP_SINGLE_ECDH_USE)
	ctx:setEphemeralKey(openssl_pkey.new{ type = "EC", curve = "prime256v1" })
	return ctx
end

local function new_server_context()
	local ctx = openssl_ctx.new("TLSv1_2", true)
	ctx:setCipherList(intermediate_cipher_list)
	ctx:setOptions(openssl_ctx.OP_NO_COMPRESSION+openssl_ctx.OP_SINGLE_ECDH_USE)
	ctx:setEphemeralKey(openssl_pkey.new{ type = "EC", curve = "prime256v1" })
	return ctx
end

return {
	has_alpn = has_alpn;
	modern_cipher_list = modern_cipher_list;
	intermediate_cipher_list = intermediate_cipher_list;
	banned_ciphers = banned_ciphers;
	new_client_context = new_client_context;
	new_server_context = new_server_context;
}
