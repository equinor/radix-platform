# Changelog

## [11.2.0](https://github.com/equinor/terraform-azurerm-key-vault/compare/v11.1.0...v11.2.0) (2023-08-31)


### Features

* set network ACLs default actions ([#68](https://github.com/equinor/terraform-azurerm-key-vault/issues/68)) ([6b49eff](https://github.com/equinor/terraform-azurerm-key-vault/commit/6b49effd5f3b131cffc554e3d9f4befaa387f4c3))

## [11.1.0](https://github.com/equinor/terraform-azurerm-key-vault/compare/v11.0.0...v11.1.0) (2023-08-21)


### Features

* enable public network access ([#66](https://github.com/equinor/terraform-azurerm-key-vault/issues/66)) ([c963c3d](https://github.com/equinor/terraform-azurerm-key-vault/commit/c963c3d2b42935f17b1d0e47ff2eba8e1c6d83c7))

## [11.0.0](https://github.com/equinor/terraform-azurerm-key-vault/compare/v10.0.0...v11.0.0) (2023-07-26)


### ⚠ BREAKING CHANGES

* simplify network configuration ([#64](https://github.com/equinor/terraform-azurerm-key-vault/issues/64))

### Code Refactoring

* simplify network configuration ([#64](https://github.com/equinor/terraform-azurerm-key-vault/issues/64)) ([a32b7c2](https://github.com/equinor/terraform-azurerm-key-vault/commit/a32b7c2e80b6d6b866f5a36bc8779b8a119721e4))

## [10.0.0](https://github.com/equinor/terraform-azurerm-key-vault/compare/v9.0.0...v10.0.0) (2023-07-26)


### ⚠ BREAKING CHANGES

* variable `enable_rbac_authorization` default value set to `true`.

### Features

* enable RBAC authorization by default ([#60](https://github.com/equinor/terraform-azurerm-key-vault/issues/60)) ([9066181](https://github.com/equinor/terraform-azurerm-key-vault/commit/906618197c8b8a62920b6ee7f93f7a9f5f79e6a8))


### Bug Fixes

* remove Log Analytics destination type variable ([#63](https://github.com/equinor/terraform-azurerm-key-vault/issues/63)) ([29fdcee](https://github.com/equinor/terraform-azurerm-key-vault/commit/29fdceec318d62963ac8dfefc24dcef3f4e11667)), closes [#62](https://github.com/equinor/terraform-azurerm-key-vault/issues/62)

## [9.0.0](https://github.com/equinor/terraform-azurerm-key-vault/compare/v8.3.0...v9.0.0) (2023-07-12)


### ⚠ BREAKING CHANGES

* remove variable `network_acls_default_action`

### Features

* enforce network ACLs default action ([#57](https://github.com/equinor/terraform-azurerm-key-vault/issues/57)) ([9b3d883](https://github.com/equinor/terraform-azurerm-key-vault/commit/9b3d8836c25e4625884e64d2f20ac2845617abbb))

## [8.3.0](https://github.com/equinor/terraform-azurerm-key-vault/compare/v8.2.1...v8.3.0) (2023-04-24)


### Features

* set diagnostic setting enabled log categories ([#53](https://github.com/equinor/terraform-azurerm-key-vault/issues/53)) ([a1369c7](https://github.com/equinor/terraform-azurerm-key-vault/commit/a1369c7fd6311472a7fe4bc77d6ab10b00a91a28))

## [8.2.1](https://github.com/equinor/terraform-azurerm-key-vault/compare/v8.2.0...v8.2.1) (2023-02-09)


### Bug Fixes

* remove disabled log block ([#48](https://github.com/equinor/terraform-azurerm-key-vault/issues/48)) ([422670b](https://github.com/equinor/terraform-azurerm-key-vault/commit/422670b3b2b675ad82cb1394ecec33d83869d435))

## [8.2.0](https://github.com/equinor/terraform-azurerm-key-vault/compare/v8.1.1...v8.2.0) (2023-02-08)


### Features

* set log analytics destination type and update min. provider version. ([#46](https://github.com/equinor/terraform-azurerm-key-vault/issues/46)) ([ea89e2d](https://github.com/equinor/terraform-azurerm-key-vault/commit/ea89e2d94fb7325716cfca81a684d6931401d168))

## [8.1.1](https://github.com/equinor/terraform-azurerm-key-vault/compare/v8.1.0...v8.1.1) (2023-02-06)


### Bug Fixes

* prevent diagnostic setting destination type update ([#43](https://github.com/equinor/terraform-azurerm-key-vault/issues/43)) ([636e268](https://github.com/equinor/terraform-azurerm-key-vault/commit/636e2683ae63cadbebfc8c4ee6e9d057c4b54beb)), closes [#42](https://github.com/equinor/terraform-azurerm-key-vault/issues/42)
