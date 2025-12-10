// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title TokenBridgeX
 * @notice A simple and secure token bridge that locks tokens on Chain A
 *         and allows unlocking on Chain B using authorized bridge operators.
 */

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract TokenBridgeX {
    address public owner;
    mapping(address => bool) public bridgeOperators;

    struct BridgeTransfer {
        address user;
        address token;
        uint256 amount;
        uint256 timestamp;
        bytes32 transferId;
        bool processed;
    }

    mapping(bytes32 => BridgeTransfer) public transfers;

    event TokensLocked(
        address indexed user,
        address indexed token,
        uint256 amount,
        bytes32 transferId
    );

    event TokensReleased(
        address indexed user,
        address indexed token,
        uint256 amount,
        bytes32 transferId
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyOperator() {
        require(bridgeOperators[msg.sender], "Not bridge operator");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // ─────────────────────────────────────────────
    // ⭐ ADD / REMOVE BRIDGE OPERATORS
    // ─────────────────────────────────────────────
    function addOperator(address operator) external onlyOwner {
        bridgeOperators[operator] = true;
    }

    function removeOperator(address operator) external onlyOwner {
        bridgeOperators[operator] = false;
    }

    // ─────────────────────────────────────────────
    // ⭐ LOCK TOKENS ON SOURCE CHAIN
    // ─────────────────────────────────────────────
    function lockTokens(address token, uint256 amount) external {
        require(token != address(0), "Token required");
        require(amount > 0, "Invalid amount");

        // Lock on-chain (bridge holds tokens)
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // Generate unique transfer ID
        bytes32 transferId = keccak256(
            abi.encodePacked(msg.sender, token, amount, block.timestamp, block.number)
        );

        transfers[transferId] = BridgeTransfer(
            msg.sender,
            token,
            amount,
            block.timestamp,
            transferId,
            false
        );

        emit TokensLocked(msg.sender, token, amount, transferId);
    }

    // ─────────────────────────────────────────────
    // ⭐ RELEASE TOKENS ON DESTINATION CHAIN
    // ─────────────────────────────────────────────
    function releaseTokens(bytes32 transferId, address user, address token, uint256 amount)
        external
        onlyOperator
    {
        BridgeTransfer storage record = transfers[transferId];
        require(!record.processed, "Already released");
        require(user != address(0), "Invalid user");
        require(amount > 0, "Invalid amount");

        record.processed = true;

        // Send tokens from bridge vault to user
        IERC20(token).transfer(user, amount);

        emit TokensReleased(user, token, amount, transferId);
    }

    // ─────────────────────────────────────────────
    // ⭐ VIEW HELPERS
    // ─────────────────────────────────────────────
    function getTransfer(bytes32 transferId) external view returns (BridgeTransfer memory) {
        return transfers[transferId];
    }
}
