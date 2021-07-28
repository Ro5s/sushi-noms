// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.0;

import "../interfaces/IBentoBridge.sol";

contract BentoWithdrawTest {
    IBentoBridge public bento;
    
    constructor(IBentoBridge _bento) {
        _bento.registerProtocol();
        bento = _bento;
    }
    
    function fromBento(address token, uint256 amount) external {
        bento.withdraw(token, msg.sender, msg.sender, amount, 0);
    }
}
