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

### Some outputs

This is the inheritance tree  (last updated 2025-07-28):

```
❯ wake print inheritance-tree -n Vault
[15:45:27] Found 2 *.sol files in 0.07 s                                                 print.py:466
           Loaded previous build in 0.28 s                                            compiler.py:862
           Compiled 0 files using 0 solc runs in 0.00 s                              compiler.py:1242
           Processed compilation results in 0.00 s                                   compiler.py:1495
Vault inheritance tree
├── UUPSUpgradeable
│   ├── Initializable
│   └── IERC1822Proxiable
└── AccessControlEnumerableUpgradeable
    ├── Initializable
    ├── IAccessControlEnumerable
    │   └── IAccessControl
    └── AccessControlUpgradeable
        ├── Initializable
        ├── ContextUpgradeable
        │   └── Initializable
        ├── IAccessControl
        └── ERC165Upgradeable
            ├── Initializable
            └── IERC165
```

giving rise to this inheritance chain (last updated 2025-07-28):

```
❯ wake print c3-linearization src/Vault.sol
[15:47:15] Found 2 *.sol files in 0.08 s                                                 print.py:466
[15:47:16] Loaded previous build in 0.28 s                                            compiler.py:862
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

This is the storage layout (last updated 2025-07-28):

```
❯ wake print storage-layout
[15:44:28] Found 2 *.sol files in 0.10 s                                                 print.py:466
           Loaded previous build in 0.28 s                                            compiler.py:862
           Compiled 0 files using 0 solc runs in 0.00 s                              compiler.py:1242
           Processed compilation results in 0.00 s                                   compiler.py:1495
                                    Vault storage layout
┏━━━━━━┳━━━━━━━━┳━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┓
┃ Slot ┃ Offset ┃ Name        ┃ Type                                            ┃ Contract ┃
┡━━━━━━╇━━━━━━━━╇━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━┩
│ 0    │ 0      │ wards       │ mapping(address => uint256)                     │ Vault    │
│ 1    │ 0      │ name        │ string                                          │ Vault    │
│ 2    │ 0      │ symbol      │ string                                          │ Vault    │
│ 3    │ 0      │ totalSupply │ uint256                                         │ Vault    │
│ 4    │ 0      │ balanceOf   │ mapping(address => uint256)                     │ Vault    │
│ 5    │ 0      │ allowance   │ mapping(address => mapping(address => uint256)) │ Vault    │
│ 6    │ 0      │ nonces      │ mapping(address => uint256)                     │ Vault    │
│ 7    │ 0      │ chi         │ uint192                                         │ Vault    │
│      │ 24     │ rho         │ uint64                                          │ Vault    │
│ 8    │ 0      │ ssr         │ uint256                                         │ Vault    │
└──────┴────────┴─────────────┴─────────────────────────────────────────────────┴──────────┘
```


