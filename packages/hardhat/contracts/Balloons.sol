pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Balloons is ERC20 {
    //@title : Mints 1000 Balloons to the deployer if contract
    
    constructor() ERC20("Balloons", "BAL") {
        _mint(msg.sender, 1000 ether); 
    }
}
