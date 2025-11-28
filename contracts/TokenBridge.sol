// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title TokenBridgeX
 * @notice Cross-chain token bridge using lock & mint mechanism.
 * @dev Validator/Oracle confirms deposit events from source chain.
 */

interface IERC20 {
    function transferFrom(address, address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function mint(address, uint256) external;
    function burn(address, uint256) external;
}

contract TokenBridgeX {
    address public admin;
    address public validator; // confirms cross-chain event
    IERC20 public token;

    // Track processed deposits to avoid double minting
    mapping(bytes32 => bool) public processedDeposits;

    event Locked(address indexed user, uint256 amount, uint256 toChainId);
    event Minted(address indexed user, uint256 amount, bytes32 depositHash);
    event Burned(address indexed user, uint256 amount, uint256 toChainId);
    event Released(address indexed user, uint256 amount, bytes32 burnHash);

    modifier onlyValidator() {
        require(msg.sender == validator, "Not validator");
        _;
    }

    constructor(address _token, address _validator) {
        token = IERC20(_token);
        validator = _validator;
        admin = msg.sender;
    }

    /**
     * @notice Lock tokens on current chain to be minted on another chain
     */
    function lockTokens(uint256 amount, uint256 toChainId) external {
        require(token.transferFrom(msg.sender, address(this), amount), "Lock failed");
        emit Locked(msg.sender, amount, toChainId);
    }

    /**
     * @notice Mint wrapped token (on destination chain) after validator confirmation
     */
    function mintWrappedToken(
        address user,
        uint256 amount,
        bytes32 depositHash
    ) external onlyValidator {
        require(!processedDeposits[depositHash], "Already processed");
        processedDeposits[depositHash] = true;
        token.mint(user, amount);
        emit Minted(user, amount, depositHash);
    }

    /**
     * @notice Burn tokens on wrapped chain to release original tokens
     */
    function burnTokens(uint256 amount, uint256 toChainId) external {
        token.burn(msg.sender, amount);
        emit Burned(msg.sender, amount, toChainId);
    }

    /**
     * @notice Release locked tokens (on original chain) after validator confirmation
     */
    function releaseTokens(
        address user,
        uint256 amount,
        bytes32 burnHash
    ) external onlyValidator {
        require(!processedDeposits[burnHash], "Already processed");
        processedDeposits[burnHash] = true;
        require(token.transfer(user, amount), "Release failed");
        emit Released(user, amount, burnHash);
    }

    /**
     * @notice Update validator for security rotation
     */
    function updateValidator(address newValidator) external {
        require(msg.sender == admin, "Only admin");
        validator = newValidator;
    }
}
