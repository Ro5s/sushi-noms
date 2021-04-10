/// SPDX-License-Identifier: MIT
/*
▄▄█    ▄   ██   █▄▄▄▄ ▄█ 
██     █  █ █  █  ▄▀ ██ 
██ ██   █ █▄▄█ █▀▀▌  ██ 
▐█ █ █  █ █  █ █  █  ▐█ 
 ▐ █  █ █    █   █    ▐ 
   █   ██   █   ▀   
           ▀          */
/// Special thanks to Keno, Boring and Gonpachi for review and inspiration of early Inari patterns.
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
contract Inari {
    uint public count;
    mapping(uint => Offering) public offerings;
    
    event MakeOffering(address indexed to, bytes4 sig);
    
    struct Offering {
        address to;
        bytes4 sig;
    }

    function inari(
        uint[] calldata offering, // stored actions to take (`to` and `sig`)
        uint[] calldata value, // ETH value, if any, for actions
        bytes[] calldata param // parameters for actions
    ) external payable returns (bool success, bytes memory returnData) {
        for (uint i = 0; i < offering.length; i++) {
            bytes memory offer = abi.encode(offerings[offering[i]].sig, param[i]);
            (success, returnData) = offerings[offering[i]].to.call{value: value[i]}(offer);
            require(success, "!served");
        }
    }
    
    function makeOffering(address to, bytes4 sig) external {
        offerings[count].to = to;
        offerings[count].sig = sig;
        count++;
        emit MakeOffering(to, sig);
    }
}
