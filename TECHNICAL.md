# Technical docs

The code of the [vault](./src/Vault.sol) is based on the [ISUsds][ISUsds] and [SUsds][SUsds] files in the [sdai][sdai] repository.

[ISUsds]: https://github.com/sky-ecosystem/sdai/blob/dfc7f41cb7599afcb0f0eb1ddaadbf9dd4015dce/src/ISUsds.sol
[SUsds]: https://github.com/sky-ecosystem/sdai/blob/dfc7f41cb7599afcb0f0eb1ddaadbf9dd4015dce/src/SUsds.sol
[sdai]: https://github.com/sky-ecosystem/sdai

## `contract SparkVault`

### Access Control

The thing to know about `AccessControlEnumerableUpgradeable`, generally there is two important things to take into account:

* For a role, who is allowed to *change* the role's admin role.
* For an admin role, what state transitions lead to changes in its membership set.

A role's admin [aka, a member of a role's admin role] can grant and revoke the role (users can also revoke their own
role), but but default cannot change the value of the admin role itself [that is possible with the `_setRoleAdmin`
function which is internal and not used by default].

### Reentrancy protection

These functions interact with external contracts:

* `take` - pushes assets to the Taker
* `_mint` - pulls assets from the user
* `_burn` - pushes assets to the user

For `take` and `_mint`, interaction with the asset is the first state change, hence reentering will be equivalent to merely entering before they are called.

Analogously, `_burn` interacts with the asset as the last state change, hence reentering will be equivalent to merely entering after `_burn` has finished.
