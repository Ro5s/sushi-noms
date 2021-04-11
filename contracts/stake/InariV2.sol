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
    address public dao = msg.sender; // initialize governance with Inari summoner
    uint public offerings; // strategies offered into Kitsune and `inari()` calls
    mapping(uint => Kitsune) kitsune; // internal Kitsune mapping to `offerings`
    
    event Zushi(address server, address[] to, bytes4[] sig, bytes32 descr, uint indexed offering);
    event Torii(address[] token, address[] indexed approveTo);
    event Inori(address indexed dao, uint indexed kit, bool zenko);
    
    /// @notice Holds Inari strategies with minimal `zenko` governance.
    struct Kitsune {
        address[] to;
        bytes4[] sig;
        bytes32 descr;
        bool zenko;
    }
    
    /// @notice Inspect a Kitsune offering (`kit`).
    function offering(uint kit) external view returns (address[] memory to, bytes4[] memory sig, string memory descr, bool zenko) {
        to = kitsune[kit].to;
        sig = kitsune[kit].sig;
        descr = string(abi.encodePacked(kitsune[kit].descr));
        zenko = kitsune[kit].zenko;
    }
    
    /// @notice Offer Kitsune strategy that can be called by `inari()`.
    /// @param to The contract(s) to be called in strategy. 
    /// @param sig The function signature(s) involved (completed by `inari()` `param`).
    function zushi(address[] calldata to, bytes4[] calldata sig, bytes32 descr) external { 
        uint kit = offerings;
        kitsune[kit] = Kitsune(to, sig, descr, false);
        offerings++;
        emit Zushi(msg.sender, to, sig, descr, kit);
    }
    
    /// @notice Batch Inari strategies into single call.
    /// @param kit Kitsune strategy 'offerings' ID.
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
    
    /// @notice Batch Inari strategies into single call with `zenko` check.
    /// @param kit Kitsune strategy 'offerings' ID.
    /// @param value ETH value (if any) for call.
    /// @param param Parameters for call data after Kitsune `sig`.
    function zenko(uint[] calldata kit, uint[] calldata value, bytes[] calldata param) 
        external payable returns (bool success, bytes memory returnData) {
        for (uint i = 0; i < kit.length; i++) {
            require(kitsune[kit[i]].zenko, "!zenko");
            (success, returnData) = kitsune[kit[i]].to[i].call{value: value[i]}
            (abi.encodePacked(kitsune[kit[i]].sig[i], param[i]));
            require(success, '!served');
        }
    }

    /// @notice Approve token for Inari to spend among contracts.
    /// @param token ERC20 contract(s) to register approval for.
    /// @param approveTo Spender contract(s) to pull `token` in `inari()` calls.
    function torii(address[] calldata token, address[] calldata approveTo) external returns (bool success) {
        for (uint i = 0; i < token.length; i++) {
            emit Torii(token, approveTo);
            (success, ) = token[i].call(abi.encodeWithSelector(0x095ea7b3, approveTo[i], type(uint).max));
        }
    }
    
    /// @notice Update Inari `dao` and Kitsune `zenko` status.
    /// @param dao_ Address to grant Kitsune governance.
    /// @param kit Kitsune strategy 'offerings' ID.
    /// @param zen `kit` approval. 
    function inori(address dao_, uint kit, bool zen) external {
        require(msg.sender == dao, "!dao");
        dao = dao_;
        kitsune[kit].zenko = zen;
        emit Inori(dao_, kit, zen);
    }
}
