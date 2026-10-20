# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

Ships on both Android and iOS from one Flutter codebase with a single shared, Material-based design. The design language does not adapt per OS; iOS receives the same design as Android.

## Users

Employees of the Central Bank of Iraq (البنك المركزي العراقي). They use their phones to sign in with their corporate identity, check their employment record, and reach HR self-services without visiting the HR department. The interface is Arabic-only and right-to-left.

## Product Purpose

CBI HR (`cbi_app`) is the bank's official, secure self-service HR app. It lets an employee:

- sign in through Microsoft Entra ID (OIDC + PKCE), then use a device passkey (FIDO2 / WebAuthn, fingerprint or face) for later sign-ins without a password;
- view their employee profile: personal details, organisational unit, grade and step, qualifications, and hire and promotion dates;
- reach HR self-services;
- manage the passkeys and devices linked to their account.

Success means an employee finds their own data and completes an HR request on the phone, without paperwork or a trip to HR, and trusts the app with bank-grade credentials.

## Positioning

It is the Central Bank's own internal HR channel, tied to the bank's Entra ID tenant and HR backend. Passwordless, hardware-backed sign-in is a core feature, not an add-on.

## Operating Context

- Identity: Microsoft Entra ID single sign-on; passkeys registered against the bank's relying-party server.
- Session tokens are stored in the Android Keystore / iOS Keychain (`flutter_secure_storage`).
- The HR backend supplies the profile and a per-account list of services (`lib/src/api/hr_api_client.dart`).
- Run configuration comes from `env.json` via `--dart-define-from-file`.

## Capabilities and Constraints

- **Services:** most of the HR services in the Services tab exist on the backend, but the UI is not yet connected to them: leave requests, leave balance, attendance/fingerprint log, payslip, advances and loans, continuation-of-service letter, salary certificate, and appreciation letters. They are real product scope. Until each one is wired up, the app must not show a fake success (for example "تم فتح نافذة") or invented values.
- **ID card / passport reader** (`lib/src/id_reader/`): MRZ camera scan, then an NFC chip read with BAC and secure messaging. **Experimental.** Its intended user (employee or staff) and where the read data goes are **undecided**. Don't present it as a finished, supported service until those are decided.
- **Language:** Arabic only (`Locale('ar')`), RTL throughout. Any new copy, including errors and copy in the ID-reader flow, must be Arabic and free of technical jargon.
- **Theme:** light and dark themes are both supported.
- **Stack:** Flutter (Dart ^3.12), Material 3.

## Brand Commitments

- Name: CBI HR / البنك المركزي العراقي — تطبيق الخدمات الذاتية للموارد البشرية.
- Mark: `logo2.png` (also the Android launcher icon).
- No colours, typefaces, or identity guidelines are binding. The user wants the most attractive design possible, so the visual identity is open and will be set during design work.

## Evidence on Hand

- `README.md` (Arabic product overview) and `PRIVACY_POLICY.md` (data handling; it states that raw biometrics are never collected). Note: the privacy policy does not yet cover ID-document capture.
- Prior UX critique: `.impeccable/critique/2026-10-14T21-10-00Z__lib-src-ui.md` (score 18/40).
- No real usage metrics, testimonials, or employee research exist. Do not invent any. Do not invent HR values such as leave balances or service status.

## Product Principles

1. **Never fake it.** Show only real data and real outcomes. A service that is not connected says so honestly and never pretends to succeed.
2. **Trust is the product.** This is a central-bank credential holder. Security states, sign-in, and device or passkey management must be clear, calm, and impossible to misread.
3. **Arabic first, not translated.** RTL layout, natural Arabic civil-service terms, and no English or technical leakage into user-facing text.
4. **Self-service over paperwork.** Each screen should shorten the path to an employee's own record or request.

## Accessibility & Inclusion

No formal standard has been mandated yet. Known needs from the prior critique: support system text scaling, label icon-only controls for screen readers, announce progress (NFC reads), respect reduce-motion, and keep contrast correct in both themes.
