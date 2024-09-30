// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.26;

import "./IERC20.sol";

error SafeERC20FailedOperation(
    address token
);

contract SafeERC20 {

    /**
     * @dev Allows to execute transfer for a token
     */
    function safeTransfer(
        IERC20 _token,
        address _to,
        uint256 _value
    )
        internal
    {
        _callOptionalReturn(
            _token,
            abi.encodeWithSelector(
                _token.transfer.selector,
                _to,
                _value
            )
        );
    }

    /**
     * @dev Allows to execute transferFrom for a token
     */
    function safeTransferFrom(
        IERC20 _token,
        address _from,
        address _to,
        uint256 _value
    )
        internal
    {
        _callOptionalReturn(
            _token,
            abi.encodeWithSelector(
                _token.transferFrom.selector,
                _from,
                _to,
                _value
            )
        );
    }

    function _callOptionalReturn(
        IERC20 _token,
        bytes memory _data
    )
        private
    {
        uint256 returnSize;
        uint256 returnValue;

        assembly ("memory-safe") {

            let success := call(
                gas(),
                _token,
                0,
                add(_data, 0x20),
                mload(_data),
                0,
                0x20
            )

            // bubble errors
            if iszero(success) {
                let ptr := mload(0x40)
                returndatacopy(
                    ptr,
                    0,
                    returndatasize()
                )
                revert(
                    ptr,
                    returndatasize()
                )
            }
            returnSize := returndatasize()
            returnValue := mload(0)
        }

        if (returnSize == 0
            ? address(_token).code.length == 0
            : returnValue != 1
        ) {
            revert SafeERC20FailedOperation(
                address(_token)
            );
        }
    }
}
