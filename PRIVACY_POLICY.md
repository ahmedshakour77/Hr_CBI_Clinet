# Privacy Policy — CBI HR Application

**Effective Date:** October 21, 2026  
**Application Name:** CBI HR (`cbi_app`)

This Privacy Policy describes how the **CBI HR** mobile application and backend service process employee, authentication, device, and identity-document information.

---

## 1. Information We Process

To provide single sign-on authentication, security management, employee profile access, and the optional identity-document workflow, the application may process:

- **Employee Profile Data:** Full Name, Corporate Email Address, Position, Job Title, Department, Employee ID, Hire Date, and Birth Date.
- **Identity & Authentication Identifiers:** Microsoft Entra ID subject identifiers, OpenID Connect ID tokens, application session tokens, and OAuth refresh tokens.
- **Security & Passkey Credentials:** WebAuthn / FIDO2 public keys, credential IDs, device labels, and signature counters. Raw fingerprint or Face ID templates are not provided to the application.
- **Identity Document Data:** When the ID-reader feature is used, the application may process MRZ data, document numbers, issue/expiry dates, document photographs, and data read from an NFC identity-document chip.
- **Biometric Portrait from Identity Documents:** Electronic identity documents may contain a facial portrait in ICAO Data Group 2 (DG2). This is document data read from the chip and is distinct from the fingerprint/Face ID biometric used by the operating system for Passkeys. When the workflow requires synchronization with the HR backend, the DG2 portrait may be transmitted to the backend together with the document record.

### Device biometric authentication notice

The CBI HR application does **not** receive or store the raw fingerprint image, Face ID template, or other biometric template used by Android/iOS to unlock a Passkey. Passkey user verification is performed by the operating system and device security hardware.

---

## 2. How We Use Data

Data is used for operational and security purposes, including:

- Authenticating employee identity via Microsoft Entra ID Single Sign-On.
- Enabling passwordless logins using Passkeys (FIDO2 / WebAuthn).
- Rendering employee profile information and authorized HR services.
- Managing registered Passkeys and devices.
- Reading and, when explicitly used by an authorized workflow, synchronizing identity-document information with the HR backend.
- Protecting application endpoints and maintaining security/audit controls.

---

## 3. Data Storage & Security

- **Device Credential Storage:** Authentication tokens are stored using platform secure storage backed by Android Keystore / iOS Keychain where supported.
- **Network Encryption:** Communications with Microsoft Entra ID and the HR backend use HTTPS/TLS.
- **Document Data:** Identity-document images and DG2 portrait data must be treated as sensitive identity data. Access should be restricted by backend authorization and audit logging, and retention should follow the institution's approved records policy.
- **Passkeys:** The private Passkey credential is controlled by the platform credential provider and is not stored by the CBI HR backend.

---

## 4. Third-Party / Platform Services

The application may interact with:

- **Microsoft Entra ID** for OAuth 2.0 / OpenID Connect authentication.
- **Android Credential Manager / Google Play Services** or **Apple Authentication Services / iCloud Keychain** for Passkeys, depending on device configuration.
- **Platform camera and NFC frameworks** when the identity-document reader is explicitly used.

---

## 5. User Rights & Data Control

- **Sign Out:** Users can sign out to clear local application session tokens.
- **Passkey Management:** Registered Passkeys can be managed through the application where supported and through the device credential provider.
- **Identity Documents:** Access, correction, retention, and deletion of official employee-document records are governed by the institution's HR/records policy and applicable authorization rules.
- **Account / Record Requests:** Requests concerning employee records should be directed to the authorized HR/IT administration channel.

---

## 6. Contact Information

For questions regarding this privacy policy, identity-document processing, or data security practices, contact the authorized corporate HR/IT support team.
