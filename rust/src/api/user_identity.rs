use ed25519_dalek::{Signature, SigningKey, VerifyingKey, Signer, Verifier};
use flutter_rust_bridge::frb;
use rand::rngs::OsRng;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(opaque)]
pub struct UserIdentity {
    pub private_key: String,
    pub public_key: String,
    pub address: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(opaque)]
pub struct SignatureResult {
    pub signature: String,
    pub message: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(opaque)]
pub struct HashResult {
    pub hash: String,
    pub algorithm: String,
}

impl UserIdentity {
    fn generate_seed() -> [u8; 32] {
        let mut seed = [0u8; 32];
        OsRng
            .try_fill_bytes(&mut seed)
            .expect("Failed to generate seed");
        seed
    }

    fn generate_keypair_from_seed(seed: &[u8; 32]) -> SigningKey {
        SigningKey::from_bytes(seed)
    }

    fn get_public_key(signing_key: &SigningKey) -> VerifyingKey {
        signing_key.verifying_key()
    }

    fn hash_public_key(public_key: &VerifyingKey) -> [u8; 20] {
        let public_key_bytes = public_key.to_bytes();
        let mut hasher = blake3::Hasher::new();
        hasher.update(&public_key_bytes);
        let hash_result = hasher.finalize();

        let mut result = [0u8; 20];
        result.copy_from_slice(&hash_result.as_bytes()[..20]);
        result
    }

    fn build_address_data(hash: &[u8; 20]) -> Vec<u8> {
        let mut data = Vec::new();
        data.push(0x00);
        data.extend_from_slice(hash);
        let checksum = Self::calculate_checksum(&data);
        data.extend_from_slice(&checksum);
        data
    }

    fn calculate_checksum(data: &[u8]) -> [u8; 4] {
        let hash1 = Sha256::digest(data);
        let hash2 = Sha256::digest(&hash1);

        let mut checksum = [0u8; 4];
        checksum.copy_from_slice(&hash2[..4]);
        checksum
    }

    pub fn generate_identity() -> UserIdentity {
        let seed = Self::generate_seed();
        let signing_key = Self::generate_keypair_from_seed(&seed);
        let verifying_key = Self::get_public_key(&signing_key);
        let hash = Self::hash_public_key(&verifying_key);
        let address_data = Self::build_address_data(&hash);

        let address = bs58::encode(&address_data).into_string();
        let private_key_base58 = bs58::encode(&seed).into_string();
        let public_key_base58 = bs58::encode(&verifying_key.to_bytes()).into_string();

        UserIdentity {
            private_key: private_key_base58,
            public_key: public_key_base58,
            address,
        }
    }

    pub fn sign_message(&self, message: &str) -> Result<SignatureResult, String> {
        let private_key_bytes = bs58::decode(&self.private_key)
            .map_err(|e| format!("Failed to decode private key: {}", e))?;

        let signing_key = SigningKey::from_bytes(&private_key_bytes);
        let signature: Signature = signing_key.sign(message.as_bytes());

        Ok(SignatureResult {
            signature: bs58::encode(signature.to_bytes()).into_string(),
            message: message.to_string(),
        })
    }

    pub fn verify_signature(&self, message: &str, signature: &str) -> Result<bool, String> {
        let public_key_bytes = bs58::decode(&self.public_key)
            .map_err(|e| format!("Failed to decode public key: {}", e))?;

        let signature_bytes = bs58::decode(signature)
            .map_err(|e| format!("Failed to decode signature: {}", e))?;

        let verifying_key = VerifyingKey::from_bytes(&public_key_bytes)
            .map_err(|e| format!("Failed to create verifying key: {}", e))?;

        let signature = Signature::from_bytes(&signature_bytes)
            .map_err(|e| format!("Failed to create signature: {}", e))?;

        Ok(verifying_key.verify(message.as_bytes(), &signature).is_ok())
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn generate_user_identity() -> UserIdentity {
    UserIdentity::generate_identity()
}

#[flutter_rust_bridge::frb(sync)]
pub fn sign_message(private_key: &str, message: &str) -> Result<SignatureResult, String> {
    let private_key_bytes = bs58::decode(private_key)
        .map_err(|e| format!("Failed to decode private key: {}", e))?;

    let signing_key = SigningKey::from_bytes(&private_key_bytes);
    let signature: Signature = signing_key.sign(message.as_bytes());

    Ok(SignatureResult {
        signature: bs58::encode(signature.to_bytes()).into_string(),
        message: message.to_string(),
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn verify_signature(public_key: &str, message: &str, signature: &str) -> Result<bool, String> {
    let public_key_bytes = bs58::decode(public_key)
        .map_err(|e| format!("Failed to decode public key: {}", e))?;

    let signature_bytes = bs58::decode(signature)
        .map_err(|e| format!("Failed to decode signature: {}", e))?;

    let verifying_key = VerifyingKey::from_bytes(&public_key_bytes)
        .map_err(|e| format!("Failed to create verifying key: {}", e))?;

    let signature = Signature::from_bytes(&signature_bytes)
        .map_err(|e| format!("Failed to create signature: {}", e))?;

    Ok(verifying_key.verify(message.as_bytes(), &signature).is_ok())
}

#[flutter_rust_bridge::frb(sync)]
pub fn hash_data(data: &str, algorithm: &str) -> HashResult {
    let hash = match algorithm {
        "sha256" => {
            let hash = Sha256::digest(data.as_bytes());
            hex::encode(hash)
        }
        "blake3" => {
            let hash = blake3::hash(data.as_bytes());
            hex::encode(hash)
        }
        _ => {
            let hash = Sha256::digest(data.as_bytes());
            hex::encode(hash)
        }
    };

    HashResult {
        hash,
        algorithm: algorithm.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_user_identity_generation() {
        let identity = UserIdentity::generate_identity();
        assert!(!identity.address.is_empty());
        assert!(!identity.private_key.is_empty());
        assert!(!identity.public_key.is_empty());

        println!("Generated Address: {}", identity.address);
        println!("Private Key: {}", identity.private_key);
        println!("Public Key: {}", identity.public_key);
    }

    #[test]
    fn test_sign_and_verify() {
        let identity = UserIdentity::generate_identity();
        let message = "Hello, World!";

        let signature_result = identity.sign_message(message).unwrap();
        assert!(!signature_result.signature.is_empty());

        let is_valid = identity.verify_signature(message, &signature_result.signature).unwrap();
        assert!(is_valid);

        let is_invalid = identity.verify_signature("Wrong message", &signature_result.signature).unwrap();
        assert!(!is_invalid);
    }

    #[test]
    fn test_hash_functions() {
        let data = "Test data for hashing";

        let sha256_result = hash_data(data, "sha256");
        assert!(!sha256_result.hash.is_empty());
        assert_eq!(sha256_result.algorithm, "sha256");

        let blake3_result = hash_data(data, "blake3");
        assert!(!blake3_result.hash.is_empty());
        assert_eq!(blake3_result.algorithm, "blake3");

        assert_ne!(sha256_result.hash, blake3_result.hash);
    }
}
