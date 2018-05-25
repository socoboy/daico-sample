pragma solidity ^0.4.21;

import './poll/BasePoll.sol';
import './fund/IPollManagedFund.sol';

/**
 * @title RefundPoll
 * @dev Enables fund refund mode
 */
contract RefundPoll is BasePoll {

    /**
     * RefundPoll constructor
     * @param _tokenAddress ERC20 compatible token contract address
     * @param _fundAddress Fund contract address
     * @param _startTime Poll start time
     * @param _endTime Poll end time
     */
    function RefundPoll(
        address _tokenAddress,
        address _fundAddress,
        uint256 _startTime,
        uint256 _endTime,
        bool _checkTransfersAfterEnd
    ) public
        BasePoll(_tokenAddress, _fundAddress, _startTime, _endTime, _checkTransfersAfterEnd)
    {

    }

    function tryToFinalize() public returns(bool) {
        require(now >= endTime);

        finalized = true;
        onPollFinish(isSubjectApproved());
        return true;
    }

    function isSubjectApproved() internal view returns(bool) {
        return yesCounter > noCounter && yesCounter >= safeDiv(token.totalSupply(), 3);
    }

    function onPollFinish(bool agree) internal {
        IPollManagedFund fund = IPollManagedFund(fundAddress);
        fund.onRefundPollFinish(agree);
    }

}
