from ..common import *
from .c_invariants import *

@chain.connect(
    # chain_id=1,  # Mainnet
    # fork=S_FORK_URL,
)
@on_revert(on_revert_handler)
def test():
    chain.tx_callback = tx_callback
    try:
        chain.optimistic_events_processing = True
    except AttributeError:
        pass

    P_FLOWS_AND_TRANSACTIONS.parent.mkdir(parents=True, exist_ok=True)
    P_FLOWS_AND_TRANSACTIONS.write_text(
        'sequence_number,flow_number,flow_name,block_number,block_timestamp,from,to,return_value,console_logs\n'
    )
    Invariants.run(
        sequences_count=10,
        flows_count=10000,
    )
