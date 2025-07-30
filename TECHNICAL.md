# Technical docs

The code of the [vault](./src/Vault.sol) is based on the [ISUsds][ISUsds] and [SUsds][SUsds] files in the [sdai][sdai] repository.

[ISUsds]: https://github.com/sky-ecosystem/sdai/blob/dfc7f41cb7599afcb0f0eb1ddaadbf9dd4015dce/src/ISUsds.sol
[SUsds]: https://github.com/sky-ecosystem/sdai/blob/dfc7f41cb7599afcb0f0eb1ddaadbf9dd4015dce/src/SUsds.sol
[sdai]: https://github.com/sky-ecosystem/sdai

## `contract Vault`

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

### Upgradeability

### Some outputs

Llast updated when line was `contract Vault is Initializable, UUPSUpgradeable, AccessControlEnumerableUpgradeable, IVault {`):

This is the inheritance tree:

```
❯ wake print inheritance-tree -n Vault
[12:22:26] Found 2 *.sol files in 0.09 s                                                 print.py:466
           Loaded previous build in 0.27 s                                            compiler.py:862
[12:22:27] Compiled 33 files using 1 solc runs in 0.46 s                             compiler.py:1242
[12:22:28] Processed compilation results in 0.26 s                                   compiler.py:1495
           Wrote build artifacts in 0.19 s                                           compiler.py:1622
Vault inheritance tree
├── Initializable
├── UUPSUpgradeable
│   ├── Initializable
│   └── IERC1822Proxiable
├── AccessControlEnumerableUpgradeable
│   ├── Initializable
│   ├── IAccessControlEnumerable
│   │   └── IAccessControl
│   └── AccessControlUpgradeable
│       ├── Initializable
│       ├── ContextUpgradeable
│       │   └── Initializable
│       ├── IAccessControl
│       └── ERC165Upgradeable
│           ├── Initializable
│           └── IERC165
└── IVault
    ├── IERC20Metadata
    │   └── IERC20
    ├── IERC20Permit
    └── IERC4626
        ├── IERC20
        └── IERC20Metadata
            └── IERC20
```

giving rise to this inheritance chain:

```
❯ wake print c3-linearization src/Vault.sol
[12:23:02] Found 2 *.sol files in 0.08 s                                                 print.py:466
           Loaded previous build in 0.25 s                                            compiler.py:862
           Compiled 0 files using 0 solc runs in 0.00 s                              compiler.py:1242
           Processed compilation results in 0.00 s                                   compiler.py:1495
Vault C3 linearization ordered
.
├──  1.Vault
├──  2.AccessControlEnumerableUpgradeable
├──  3.AccessControlUpgradeable
├──  4.ERC165Upgradeable
├──  5.ContextUpgradeable
├──  6.UUPSUpgradeable
└──  7.Initializable
```

This is the storage layout:

```
❯ wake print storage-layout
[12:23:21] Found 2 *.sol files in 0.09 s                                                 print.py:466
           Loaded previous build in 0.25 s                                            compiler.py:862
           Compiled 0 files using 0 solc runs in 0.00 s                              compiler.py:1242
           Processed compilation results in 0.00 s                                   compiler.py:1495
                                    Vault storage layout                                    
┏━━━━━━┳━━━━━━━━┳━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┓
┃ Slot ┃ Offset ┃ Name        ┃ Type                                            ┃ Contract ┃
┡━━━━━━╇━━━━━━━━╇━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━┩
│ 0    │ 0      │ name        │ string                                          │ Vault    │
│ 1    │ 0      │ symbol      │ string                                          │ Vault    │
│ 2    │ 0      │ totalSupply │ uint256                                         │ Vault    │
│ 3    │ 0      │ balanceOf   │ mapping(address => uint256)                     │ Vault    │
│ 4    │ 0      │ allowance   │ mapping(address => mapping(address => uint256)) │ Vault    │
│ 5    │ 0      │ nonces      │ mapping(address => uint256)                     │ Vault    │
│ 6    │ 0      │ chi         │ uint192                                         │ Vault    │
│      │ 24     │ rho         │ uint64                                          │ Vault    │
│ 7    │ 0      │ ssr         │ uint256                                         │ Vault    │
└──────┴────────┴─────────────┴─────────────────────────────────────────────────┴──────────┘
```


