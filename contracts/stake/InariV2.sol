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
/// @notice Inari registers and batches contract calls for crafty strategies.
contract Inari {
    address public dao = msg.sender;
    uint public offerings;
    mapping(uint => Kitsune) private kitsune;
    
    event Zushi(address[] to, bytes4[] sig, uint indexed offering);
    event Torii(address[] token, address[] indexed approveTo);
    event Inori(address indexed dao, uint indexed kit, bool zenko);
    
    /// @notice Holds strategies and minimal governance (`summoner` for potential rewards / `zenko` to flag status)
    struct Kitsune {
        address summoner;
        address[] to;
        bytes4[] sig;
        bool zenko;
    }
    
    /// @notice Batch Inari strategies into single call.
    /// @param kit Kitsune strategy (`to` / `sig`) 'offerings' ID.
    /// @param value ETH value (if any) for call.
    /// @param param Parameters for call data after Kitsune `sig`.
    function inari(uint[] calldata kit, uint[] calldata value, bytes[] calldata param) 
        external payable returns (bool success, bytes memory returnData) {
        for (uint i = 0; i < kit.length; i++) {
            (success, returnData) = kitsune[kit[i]].to[i].call{value: value[i]}
            (abi.encodePacked(kitsune[kit[i]].sig[i], param[i]));
            require(success, '!served');
        }
    }
    
    /// @notice Offer Kitsune strategy that can be called by `inari()`. If caller is `dao`, strategy is `zenko`.
    /// @param to The contract(s) to be called in strategy. 
    /// @param sig  The function signature(s) involved (completed by `inari()` `param`).
    function zushi(address[] calldata to, bytes4[] calldata sig) external { 
        uint offering = offerings;
        kitsune[offering] = Kitsune(msg.sender, to, sig, false);
        if (msg.sender == dao) {
            kitsune[offering].zenko = true;
        }
        offerings++;
        emit Zushi(to, sig, offering++);
    }

    /// @notice Approve token for Inari to spend among contracts.
    /// @param token ERC20 contract(s) to register approval for.
    /// @param approveTo Spender contract(s) to pull `token` in an `inari()` call.
    function torii(address[] calldata token, address[] calldata approveTo) external returns (bool success) {
        for (uint i = 0; i < token.length; i++) {
            emit Torii(token, approveTo);
            (success, ) = token[i].call(abi.encodeWithSelector(0x095ea7b3, approveTo[i], type(uint).max));
        }
    }
    
    /// @notice Update Inari `dao` and Kitsune `zenko` status.
    /// @param dao_ Address to grant governance.
    /// @param kit Kitsune strategy (`to` / `sig`) 'offerings' ID.
    /// @param zenko `kit` approval. 
    function inori(address dao_, uint kit, bool zenko) external {
        require(msg.sender == dao, "!dao");
        dao = dao_;
        kitsune[kit].zenko = zenko;
        emit Inori(dao_, kit, zenko);
    }
}
