# -------- Standard library imports --------
import os, sys
import pathlib; from pathlib import Path
import argparse
import enum; from enum import Enum
import logging
import itertools
import json
import re
import csv
import signal
import time
from dataclasses import dataclass, field, fields
from collections import defaultdict
import datetime; from datetime import datetime
import math
import decimal; from decimal import Decimal
import bisect
import functools

# -------- Specifically typing imports --------
import typing; from typing import List, Union, Dict, Any, Optional, Tuple, Type, TypeVar, Generic, Set, cast, Iterable, Iterator, Callable, Sequence, Deque, Mapping, NamedTuple, Literal, TypedDict
try:
    import typing_extensions; from typing_extensions import TypeAlias, override # python <3.11
except ImportError:
    from typing import Type as TypeAlias # python 3.11+
try:
    import typing_extensions; from typing_extensions import NotRequired # python <3.11
except ImportError:
    from typing import NotRequired # python 3.11+

# -------- Third-party imports --------
from wake.testing import *
from wake.testing.fuzzing import *
import pytest

# By default PyTest only applies its syntactic changes to test files.
# This ensures that this is applied eg. in wake_model/fuzz_slashes/flows.py and not only in test_.py
pytest.register_assert_rewrite("wake_model")

# -------- Local imports --------
# Import OpenZeppelin interfaces
from pytypes.lib.core.lib.openzeppelincontracts.contracts.access.IAccessControl import IAccessControl
from pytypes.lib.core.lib.openzeppelincontracts.contracts.token.ERC20.extensions.IERC20Metadata import IERC20Metadata
from pytypes.lib.core.lib.openzeppelincontracts.contracts.token.ERC20.IERC20 import IERC20
from pytypes.lib.core.lib.openzeppelincontractsupgradeable.contracts.access.OwnableUpgradeable import OwnableUpgradeable

# -------- Constants --------
# Testing constants
# S_FORK_URL = os.environ.get("MAINNET_RPC_URL") + "@22698495"
P_FLOWS_AND_TRANSACTIONS = Path("gitignore/flows_and_transactions.csv")

# -------- Utils --------
def adjusted_scientific_notation(val, num_decimals=2, exponent_pad=2):
    # https://stackoverflow.com/a/62561794/4204961
    exponent_template = "{:0>%d}" % exponent_pad
    mantissa_template = "{:.%df}" % num_decimals

    order_of_magnitude = math.floor(math.log10(abs(val)))
    nearest_lower_third = 3 * (order_of_magnitude // 3)
    adjusted_mantissa = val * 10 ** (-nearest_lower_third)
    adjusted_mantissa_string = mantissa_template.format(adjusted_mantissa)
    adjusted_exponent_string = ("-" if nearest_lower_third < 0 else "") + exponent_template.format(
        abs(nearest_lower_third)
    )
    return adjusted_mantissa_string + "e" + adjusted_exponent_string

def format_int(x: int) -> str:
    # For large integers (eg. token values), this will display 18.45e18 (18_446_744_073_709_551_615)
    # instead of 18446744073709551615.
    if abs(x) < 10**5:
        return f"{x:_}"
    return f"{adjusted_scientific_notation(x)} ({x:_})"

def format_bytes(bs: bytes) -> str:
    if len(bs) == 0:
        return 'b""'
    return f'b"{bs.hex()}" ({len(bs)} bytes)'

def bytes_to_hex(obj):
    """
    Loops over an object and converts any 'bytes' members to their hexadecimal string representation.
    """
    if isinstance(obj, bytes):
        # If the object is a bytes instance, convert it to a hex string.
        return "0x" + obj.hex()
    elif isinstance(obj, list):
        # If the object is a list, apply the conversion to each item in the list.
        return [bytes_to_hex(item) for item in obj]
    elif isinstance(obj, dict):
        # If the object is a dictionary, apply the conversion to each value in the dictionary.
        return {key: bytes_to_hex(value) for key, value in obj.items()}
    elif hasattr(obj, '__dataclass_fields__'):
        # If the object is a dataclass instance, convert its fields.
        for field in fields(obj):
            # Get the current value of the field from the instance.
            setattr(obj, field.name, bytes_to_hex(getattr(obj, field.name)))
    return obj

def label_and_format(val):
    if isinstance(val, Account):
        addr = val.address
    elif isinstance(val, Address):
        addr = val
    elif isinstance(val, str) and re.match(r"^(0x)?[a-fA-F0-9]{40}$", val):
        addr = Address(val)
    elif isinstance(val, int):
        return format_int(val)
    elif isinstance(val, tuple):
        return tuple(label_and_format(el) for el in val)
    else:
        return val
    assert isinstance(addr, Address)
    if addr in chain._labels:
        return chain._labels[addr]
    return val

def label_and_format_events(events):
    for event in events:
        if event is not None:
            bytes_to_hex(event)
        for field in fields(event):
            if field.init == True:
                val = getattr(event, field.name)
                setattr(event, field.name, label_and_format(val))

def on_revert_handler(e: TransactionRevertedError):
    if e.tx is not None:
        print(f"\nREVERTED TRANSACTION!! block #{e.tx.block_number}; from={e.tx.from_}; to={e.tx.to}.\nreturn_value == {e.tx.return_value}")
        print(e.tx.call_trace)
        print(e.tx.console_logs)

def tx_callback(tx: TransactionAbc):
    print(f"\nSUCCESSFUL TRANSACTION!! block #{tx.block_number}; from={tx.from_}; to={tx.to}.\nreturn_value == {tx.return_value}")
    label_and_format_events(tx.events)
    print(tx.events)
    print(f"Trasaction console logs: {tx.console_logs}")

    with open(P_FLOWS_AND_TRANSACTIONS, 'a') as f:
        csv_writer = csv.writer(f)
        from_ = getattr(tx.from_, "label", tx.from_.address)
        to = getattr(tx.to, "label", getattr(tx.to, "address", None))

        return_value = label_and_format(tx.return_value)
        csv_writer.writerow([None, None, None, tx.block_number, tx.block.timestamp, from_, to, return_value, tx.console_logs])
        for event in tx.events:
            _fields = []
            for field in fields(event):
                if field.init == True:
                    val = getattr(event, field.name)
                    _fields.append(f"{field.name}={val}")
            if len(_fields) < 4:
                _fields += [None] * (4 - len(_fields))
            # UnknownEvents do not have .original_name attribute, so we use the class name instead
            try:
                s_event_name = event.__class__.original_name
            except AttributeError:
                s_event_name = event.__class__.__name__
            csv_writer.writerow([None, None, None, None, s_event_name, _fields[0], _fields[1], _fields[2], _fields[3:]])

