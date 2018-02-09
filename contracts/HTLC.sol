pragma solidity ^0.4.18;

/**
* Hash Time Lock Contract
*/
contract HTLC
{
	uint256 constant MAX_TIMEOUT = 60 * 60 * 24;

	struct LockState {
		uint timeout;
		bytes32 hash;
		address recipient;
		address owner;
		uint256 value;
	}

	mapping(bytes32 => LockState) internal m_locks;

	uint256 internal m_ctr;


	event OnDeposit( bytes32 lock_id, address recipient );

	event OnClaim( bytes32 lock_id, bytes32 preimage );


	/**
	* Alice deposits her funds (the Input, or side A)
	*
	* These can only be withdrawn by the intended `recipient` if they provide
	* the `preimage` which results in `hash`.
	*
	* On side `B` alice reveals her secret `preimage`
	*
	* If the timeout has been reached Alice (the `owner`) can request a Refund.
	*/
	function Deposit (uint256 timeout, bytes32 hash, address recipient)
		public payable returns (bytes32)
	{
		require( timeout >= now );
		require( timeout < (now + MAX_TIMEOUT) );
		require( msg.value > 0 );

		var lock_id = bytes32(m_ctr);
		m_ctr += 1;
		m_locks[lock_id] = LockState(timeout, hash, recipient, msg.sender, msg.value);

		return lock_id;
	}


	function Claim (bytes32 lock_id, bytes32 preimage, uint8 v, bytes32 r, bytes32 s)
		public
	{
		LockState storage lock = m_locks[lock_id];

		require( lock.timeout >= now );
		require( keccak256(preimage) == lock.hash );

		address recipient = ecrecover(keccak256(lock_id, msg.sender), v, r, s);
		require( recipient == lock.recipient );

		var value = lock.value;
		delete m_locks[lock_id];

		msg.sender.transfer(value);
	}


	function Refund (bytes32 lock_id, uint8 v, bytes32 r, bytes32 s)
		public
	{
		LockState storage lock = m_locks[lock_id];

		require( lock.timeout < now );

		// Lock owner must authorise msg.sender to retrieve refund
		address owner = ecrecover(keccak256(lock_id, msg.sender), v, r, s);
		require( owner == lock.owner );

		var value = lock.value;
		delete m_locks[lock_id];

		msg.sender.transfer(value);
	}
}