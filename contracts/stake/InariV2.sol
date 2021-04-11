/// SPDX-License-Identifier: MIT
/*
▄▄█    ▄   ██   █▄▄▄▄ ▄█ 
██     █  █ █  █  ▄▀ ██ 
██ ██   █ █▄▄█ █▀▀▌  ██ 
▐█ █ █  █ █  █ █  █  ▐█ 
 ▐ █  █ █    █   █    ▐ 
   █   ██   █   ▀   
           ▀          */
/// Special thanks to Keno, Boring and Gonpachi for review and inspiration.
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

/// @notice Interface for Dai Stablecoin (DAI) `permit()` primitive.
interface IDaiPermit {
    function permit(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

// File @boringcrypto/boring-solidity/contracts/interfaces/IERC20.sol@v1.2.0
/// License-Identifier: MIT

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice EIP 2612
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

// File @boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol@v1.2.0
/// License-Identifier: MIT

library BoringERC20 {
    bytes4 private constant SIG_SYMBOL = 0x95d89b41; // symbol()
    bytes4 private constant SIG_NAME = 0x06fdde03; // name()
    bytes4 private constant SIG_DECIMALS = 0x313ce567; // decimals()
    bytes4 private constant SIG_TRANSFER = 0xa9059cbb; // transfer(address,uint256)
    bytes4 private constant SIG_TRANSFER_FROM = 0x23b872dd; // transferFrom(address,address,uint256)

    /// @notice Provides a safe ERC20.transfer version for different ERC-20 implementations.
    /// Reverts on a failed transfer.
    /// @param token The address of the ERC-20 token.
    /// @param to Transfer tokens to.
    /// @param amount The token amount.
    function safeTransfer(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(SIG_TRANSFER, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BoringERC20: Transfer failed");
    }

    /// @notice Provides a safe ERC20.transferFrom version for different ERC-20 implementations.
    /// Reverts on a failed transfer.
    /// @param token The address of the ERC-20 token.
    /// @param from Transfer tokens from.
    /// @param to Transfer tokens to.
    /// @param amount The token amount.
    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(SIG_TRANSFER_FROM, from, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "BoringERC20: TransferFrom failed");
    }
}

// File @boringcrypto/boring-solidity/contracts/BoringBatchable.sol@v1.2.0
/// License-Identifier: MIT

contract BaseBoringBatchable {
    /// @dev Helper function to extract a useful revert message from a failed call.
    /// If the returned data is malformed or not correctly abi encoded then this call can fail itself.
    function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

    /// @notice Allows batched call to self (this contract).
    /// @param calls An array of inputs for each call.
    /// @param revertOnFail If True then reverts after a failed call and stops doing further calls.
    /// @return successes An array indicating the success of a call, mapped one-to-one to `calls`.
    /// @return results An array with the returned data of each function call, mapped one-to-one to `calls`.
    // F1: External is ok here because this is the batch function, adding it to a batch makes no sense
    // F2: Calls in the batch may be payable, delegatecall operates in the same context, so each call in the batch has access to msg.value
    // C3: The length of the loop is fully under user control, so can't be exploited
    // C7: Delegatecall is only used on the same contract, so it's safe
    function batch(bytes[] calldata calls, bool revertOnFail) external payable returns (bool[] memory successes, bytes[] memory results) {
        successes = new bool[](calls.length);
        results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(calls[i]);
            require(success || !revertOnFail, _getRevertMsg(result));
            successes[i] = success;
            results[i] = result;
        }
    }
}

/// @notice Extends `BoringBatchable` with Dai `permit()`.
contract BoringBatchableWithDai is BaseBoringBatchable {
    IDaiPermit constant dai = IDaiPermit(0x6B175474E89094C44Da98b954EedeAC495271d0F); // DAI token contract
    
    /// @notice Call wrapper that performs `ERC20.permit` on `token`.
    /// Lookup `IERC20.permit`.
    // F6: Parameters can be used front-run the permit and the user's permit will fail (due to nonce or other revert)
    //     if part of a batch this could be used to grief once as the second call would not need the permit
    function permitToken(
        IERC20 token,
        address from,
        address to,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        token.permit(from, to, amount, deadline, v, r, s);
    }
    
    /// @notice Call wrapper that performs `ERC20.permit` on `dai` using primitive.
    /// Lookup `IDaiPermit.permit`.
    function permitDai(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        dai.permit(holder, spender, nonce, expiry, allowed, v, r, s);
    }
}

/// @notice Inari registers and batches contract calls for crafty strategies.
contract Inari is BoringBatchableWithDai {
    address public dao = msg.sender; // initialize governance with Inari summoner
    uint public offerings; // strategies offered into Kitsune and `inari()` calls
    mapping(uint => Kitsune) kitsune; // internal Kitsune mapping to `offerings`
    
    event Zushi(address indexed server, address[] to, bytes4[] sig, bytes32 descr, uint indexed offering);
    event Torii(IERC20[] token, address[] approveTo);
    event Inori(address indexed dao, uint indexed kit, bool zenko);
    
    /// @notice Stores Inari strategies with `zenko` flagged by `dao`.
    struct Kitsune {
        address[] to;
        bytes4[] sig;
        bytes32 descr;
        bool zenko;
    }
    
    /*********
    CALL INARI 
    *********/
    /// @notice Batch Inari strategies and perform calls.
    /// @param kit Kitsune strategy 'offerings' ID.
    /// @param value ETH value (if any) for call.
    /// @param param Parameters for call data after Kitsune `sig`.
    function inari(uint[] calldata kit, uint[] calldata value, bytes[] calldata param) 
        external payable returns (bool success, bytes memory returnData) {
        for (uint i = 0; i < kit.length; i++) {
            Kitsune storage ki = kitsune[kit[i]];
            (success, returnData) = ki.to[i].call{value: value[i]}
            (abi.encodePacked(ki.sig[i], param[i]));
            require(success, '!served');
        }
    }
    
    /// @notice Batch Inari strategies into single call with `zenko` check.
    /// @param kit Kitsune strategy 'offerings' ID.
    /// @param value ETH value (if any) for call.
    /// @param param Parameters for call data after Kitsune `sig`.
    function inariZushi(uint[] calldata kit, uint[] calldata value, bytes[] calldata param) 
        external payable returns (bool success, bytes memory returnData) {
        for (uint i = 0; i < kit.length; i++) {
            Kitsune storage ki = kitsune[kit[i]];
            require(ki.zenko, "!zenko");
            (success, returnData) = ki.to[i].call{value: value[i]}
            (abi.encodePacked(ki.sig[i], param[i]));
            require(success, '!served');
        }
    }
    
    /********
    OFFERINGS 
    ********/
    /// @notice Inspect a Kitsune offering (`kit`).
    function checkOffering(uint kit) external view returns (address[] memory to, bytes4[] memory sig, string memory descr, bool zenko) {
        Kitsune storage ki = kitsune[kit];
        to = ki.to;
        sig = ki.sig;
        descr = string(abi.encodePacked(ki.descr));
        zenko = ki.zenko;
    }
    
    /// @notice Offer Kitsune strategy that can be called by `inari()`.
    /// @param to The contract(s) to be called in strategy. 
    /// @param sig The function signature(s) involved (completed by `inari()` `param`).
    function makeOffering(address[] calldata to, bytes4[] calldata sig, bytes32 descr) external { 
        uint kit = offerings;
        kitsune[kit] = Kitsune(to, sig, descr, false);
        offerings++;
        emit Zushi(msg.sender, to, sig, descr, kit);
    }
    
    /*********
    GOVERNANCE 
    *********/
    /// @notice Approve token for Inari to spend among contracts.
    /// @param token ERC20 contract(s) to register approval for.
    /// @param approveTo Spender contract(s) to pull `token` in `inari()` calls.
    function bridge(IERC20[] calldata token, address[] calldata approveTo) external {
        for (uint i = 0; i < token.length; i++) {
            token[i].approve(approveTo[i], type(uint).max);
            emit Torii(token, approveTo);
        }
    }
    
    /// @notice Update Inari `dao` and Kitsune `zenko` status.
    /// @param dao_ Address to grant Kitsune governance.
    /// @param kit Kitsune strategy 'offerings' ID.
    /// @param zen `kit` approval. 
    function govern(address dao_, uint kit, bool zen) external {
        require(msg.sender == dao, "!dao");
        dao = dao_;
        kitsune[kit].zenko = zen;
        emit Inori(dao_, kit, zen);
    }
}
