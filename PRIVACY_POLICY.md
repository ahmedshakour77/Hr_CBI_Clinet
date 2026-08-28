# Privacy Policy — CBI HR Application

**Effective Date:** August 14, 2026  
**Application Name:** CBI HR (`cbi_app`)

This Privacy Policy describes how the **CBI HR** mobile application and backend service ("we", "our", or "us") collect, use, store, and protect user and device information when you use our application.

---

## 1. Information We Collect

To provide single sign-on authentication, security management, and employee profile access, we process the following data:

- **Employee Profile Data:** Full Name, Corporate Email Address, Position, Job Title, Department, Employee ID, Hire Date, and Birth Date.
- **Identity & Authentication Identifiers:** Microsoft Entra ID Subject ID (`sub`), OpenID Connect ID tokens, and OAuth refresh tokens.
- **Security & Passkey Credentials:** WebAuthn / FIDO2 public keys, credential IDs, and signature counters for passwordless authentication.

### Biometric Data Protection Notice
The CBI HR application **NEVER collects, receives, stores, or transmits raw biometric data** (such as fingerprint images or facial recognition templates). All biometric authentication is handled strictly on your device's hardware security enclave (Android Keystore / Apple Secure Enclave) via standard OS prompts.

---

## 2. How We Use Your Data

We use your data exclusively for operational and security purposes:
- Authenticating employee identity via Microsoft Entra ID Single Sign-On (SSO).
- Enabling fast, secure, passwordless logins using Passkeys (FIDO2 / WebAuthn).
- Rendering your employee profile details inside the application.
- Securing application endpoints against unauthorized access.

---

## 3. Data Storage & Security

- **Device Encryption:** Authentication tokens saved on your device are encrypted using hardware-backed keystores (Android Keystore and iOS Keychain with `first_unlock_this_device` accessibility rules).
- **Network Encryption:** All communications between the app, Microsoft Entra ID, and our backend relying party server occur strictly over encrypted HTTPS/TLS 1.2+ connections.

---

## 4. Third-Party Services

We interact only with trusted authentication infrastructure:
- **Microsoft Entra ID:** OAuth 2.0 / OIDC identity provider.
- **Google Play Services / Android Credential Manager:** FIDO2 / WebAuthn passkey provider.

---

## 5. Your Rights & Data Control

- **Sign Out:** You can sign out at any time to clear local session tokens from your device.
- **Passkey Management:** Enrolled passkeys can be managed or deleted from your device settings (Google Password Manager or Apple Keychain).
- **Account Deletion Requests:** To request deletion of your employee record, contact your corporate HR IT Administrator.

---

## 6. Contact Information

For questions regarding this privacy policy or data security practices, contact your corporate HR IT Support team.
