pragma solidity ^0.4.21;

import './token/TransferLimitedToken.sol';


contract DAICOToken is TransferLimitedToken {
    uint256 public constant SALE_END_TIME = 1527282000; // 05/26/2018 @ 2:00am UTC

    function DAICOToken(address _listener, address[] _owners, address manager) public
        TransferLimitedToken(SALE_END_TIME, _listener, _owners, manager)
    {
        name = "DAICO Token";
        symbol = "DTK";
        decimals = 18;
    }
}