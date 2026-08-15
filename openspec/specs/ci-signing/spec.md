# CI Signing Specification

## Purpose

Release APK signing via GitHub Actions: keystore generation recipe (manual repo-admin step), GitHub secrets structure, and `release.yml` updates to decode the keystore and sign the release APK. Keystore material is NEVER committed to the repository.

## Requirements

### Requirement: Keystore Generation Recipe

The system SHALL document a keystore generation recipe as a manual prerequisite for repo admins.

#### Scenario: Keystore generation command

- GIVEN a repo admin needs to provision signing credentials
- WHEN they run the documented `keytool` command
- THEN a `keystore.jks` file is generated with the specified alias
- AND the keystore is base64-encoded for GitHub secret storage

#### Scenario: Keystore not committed

- GIVEN `keystore.jks` is generated
- WHEN the repo admin provisions GitHub secrets
- THEN `keystore.jks` is NOT committed to the repository
- AND `.gitignore` excludes keystore files

### Requirement: GitHub Secrets Structure

The system SHALL use the following GitHub secrets for release signing: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.

#### Scenario: Secrets are configured

- GIVEN the GitHub repository has release signing enabled
- WHEN a maintainer inspects repository secrets
- THEN `KEYSTORE_BASE64` contains the base64-encoded keystore
- AND `KEYSTORE_PASSWORD` contains the keystore password
- AND `KEY_ALIAS` contains the key alias
- AND `KEY_PASSWORD` contains the key password

### Requirement: release.yml Signing Steps

The system SHALL update `.github/workflows/release.yml` to decode the keystore and sign the release APK.

#### Scenario: Release build signs APK

- GIVEN a tag push triggers `release.yml`
- WHEN the build job runs
- THEN the keystore is decoded from `KEYSTORE_BASE64` to a temporary file
- AND the release APK is signed with `apksigner` using the decoded keystore
- AND the signed APK is attached to the GitHub Release

#### Scenario: Signing uses correct flags

- GIVEN the APK is being signed
- WHEN `apksigner sign` executes
- THEN it uses `--ks`, `--ks-pass`, `--ks-key-alias`, and `--key-pass` flags
- AND the signing algorithm is v2+v3 compatible

#### Scenario: Unsigned APK not published

- GIVEN the signing step fails
- WHEN the release job completes
- THEN no APK is attached to the GitHub Release
- AND the workflow fails with a clear error message

### Requirement: No Keystore Material in Repository

The system SHALL NOT commit any keystore material (`.jks`, `.keystore`, `.p12`) to the repository.

#### Scenario: Keystore in gitignore

- GIVEN the repository has a `.gitignore`
- WHEN a keystore file is present in the working directory
- THEN git does not track the keystore file
- AND `git status` does not show the keystore as untracked

## Verification

- **Keystore recipe**: Manual review — recipe produces a valid keystore
- **Secrets structure**: Manual review — GitHub secrets match documented names
- **release.yml signing**: CI workflow check — `release.yml` produces signed APK on tag push
- **No keystore committed**: `flutter analyze` + manual review — no keystore files tracked
