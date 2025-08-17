// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

interface IPermit2 {
    struct TokenPermissions {
        address token;
        uint256 amount;
    }
    
    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }
    
    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }
    
    function approve(
        address token,
        address spender,
        uint160 amount,
        uint48 expiration
    ) external;
    
    function transferFrom(
        address from,
        address to,
        uint160 amount,
        address token
    ) external;
}
