
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NodeOps {
    using SafeERC20 for IERC20;

    mapping(bytes32 => address) public _operators;
    address public _tokenAddress;
    bytes32[] public _ed25519Keys;
    uint248 public _minRequiredSignatures;
    uint248 public _nonce;
    uint248 public _cancellationPeriod;

    struct UnstakeRequest {
        uint256 timestamp;
    }

    mapping(address => UnstakeRequest) public unstakeRequests;

    event NodeRegistered(bytes32 nodePublicKey, address operator);
    event NodeUnregistered(bytes32 nodePublicKey);
    event Staked(bytes32[] nodes, address staker, uint248 amount);
    event UnstakeInitiated(address staker);
    event UnstakeCompleted(uint248 amount, address staker);
    event UnstakeCancelled(address staker);
    event Nominate(bytes32[] nodes, address nominator);
    event UnstakeRequestProcessed(address staker);

    error NotValidNodeOperator();
    error ValueExceedsUint248Limit();
    error InvalidNonce();
    error InvalidSignature();
    error NotEnoughSignatures();
    error InvalidAmount();
    error ExistingUnstakeRequest();
    error NoUnstakeRequestFound();
    error CancellationPeriodExpired();
    error CancellationPeriodNotPassed();

    constructor(
        address tokenAddress,
        bytes32[] memory ed25519Keys,
        uint248 minRequiredSignatures,
        uint248 cancellationPeriod
    ) {
        _tokenAddress = tokenAddress;
        _ed25519Keys = ed25519Keys;
        _minRequiredSignatures = minRequiredSignatures;
        _nonce = 0;
        _cancellationPeriod = cancellationPeriod;
    }

    function getCancellationPeriod() external view returns (uint248) {
        return _cancellationPeriod;
    }

    function setCancellationPeriod(uint248 newPeriod) external {
        _cancellationPeriod = newPeriod;
    }

    function registerNode(bytes32 nodePublicKey, address operator) public {
        _operators[nodePublicKey] = operator;
        emit NodeRegistered(nodePublicKey, operator);
    }

    function unregisterNode(bytes32 nodePublicKey) public {
        if (msg.sender != _operators[nodePublicKey]) {
            revert NotValidNodeOperator();
        }

        delete _operators[nodePublicKey];

        emit NodeUnregistered(nodePublicKey);
    }

    function stake(bytes32[] calldata nodes, uint248 amount) external {
        if (amount > type(uint248).max) revert ValueExceedsUint248Limit();

        IERC20(_tokenAddress).safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(nodes, msg.sender, amount);
    }

    function nominate(bytes32[] calldata nodes) external {
        emit Nominate(nodes, msg.sender);
    }

    function unstake() external {
        if (unstakeRequests[msg.sender].timestamp > 0) {
            revert ExistingUnstakeRequest();
        }
        unstakeRequests[msg.sender] = UnstakeRequest({timestamp: block.timestamp});

        emit UnstakeInitiated(msg.sender);
    }

    function cancelUnstake() external {
        UnstakeRequest storage request = unstakeRequests[msg.sender];
        if (request.timestamp == 0) revert NoUnstakeRequestFound();
        if (block.timestamp > request.timestamp + _cancellationPeriod) revert CancellationPeriodExpired();
        delete unstakeRequests[msg.sender];

        emit UnstakeCancelled(msg.sender);
    }

    function requestProcessUnstake() external {
        UnstakeRequest storage request = unstakeRequests[msg.sender];
        if (request.timestamp == 0) revert NoUnstakeRequestFound();
        if (block.timestamp <= request.timestamp + _cancellationPeriod) revert CancellationPeriodNotPassed();

        emit UnstakeRequestProcessed(msg.sender);
    }

    function processUnstake(address staker, uint248 amount, bytes32[] calldata ed25519signatures) external {
        if (ed25519signatures.length < _minRequiredSignatures) {
            revert NotEnoughSignatures();
        }

        UnstakeRequest storage request = unstakeRequests[staker];
        if (block.timestamp <= request.timestamp + _cancellationPeriod) {
            revert CancellationPeriodNotPassed();
        }

        IERC20(_tokenAddress).safeTransfer(staker, amount);
        emit UnstakeCompleted(amount, staker);

        _nonce++;
    }
}
