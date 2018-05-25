pragma solidity ^0.4.21;

import './utilities/DateTime.sol';
import './fund/Fund.sol';
import './TapPoll.sol';
import './RefundPoll.sol';
import './fund/IPollManagedFund.sol';
import './token/ITokenEventListener.sol';

/**
 * @title PollManagedFund
 * @dev Fund controlled by users
 */
contract PollManagedFund is Fund, DateTime, ITokenEventListener {
    uint256 public constant TAP_POLL_DURATION = 3 days;
    uint256 public constant REFUND_POLL_DURATION = 7 days;
    uint256 public constant MAX_VOTED_TOKEN_PERC = 10;

    TapPoll public tapPoll;
    RefundPoll public refundPoll;

    uint256 public minVotedTokensPerc = 0;
    bool public isWithdrawEnabled = true;

    modifier onlyTokenHolder() {
        require(token.balanceOf(msg.sender) > 0);
        _;
    }

    event TapPollCreated();
    event TapPollFinished(bool approved, uint256 _tap);
    event RefundPollCreated();
    event RefundPollFinished(bool approved);

    /**
     * @dev PollManagedFund constructor
     * params - see Fund constructor
     */
    function PollManagedFund(
        address _teamWallet,
        address _teamTokenWallet,
        address[] _owners
        ) public
        Fund(_teamWallet, _teamTokenWallet, _owners)
    {
    }

    function canWithdraw() public returns(bool) {
        if(
            address(refundPoll) != address(0) &&
            !refundPoll.finalized() &&
            refundPoll.isNowApproved()
        ) {
            return false;
        }
        return isWithdrawEnabled;
    }

    /**
     * @dev ITokenEventListener implementation. Notify active poll contracts about token transfers
     */
    function onTokenTransfer(address _from, uint256 _value) external {
        require(msg.sender == address(token));
        if(address(tapPoll) != address(0) && !tapPoll.finalized()) {
            tapPoll.onTokenTransfer(_from, _value);
        }
         if(address(refundPoll) != address(0) && !refundPoll.finalized()) {
            refundPoll.onTokenTransfer(_from, _value);
        }
    }

    /**
     * @dev Update minVotedTokensPerc value after tap poll.
     * Set new value == 50% from current voted tokens amount
     */
    function updateMinVotedTokens(uint256 _minVotedTokensPerc) internal {
        uint256 newPerc = safeDiv(_minVotedTokensPerc, 2);
        if(newPerc > MAX_VOTED_TOKEN_PERC) {
            minVotedTokensPerc = MAX_VOTED_TOKEN_PERC;
            return;
        }
        minVotedTokensPerc = newPerc;
    }

    // Tap poll
    function createTapPoll(uint8 tapIncPerc) public onlyOwner {
        require(state == FundState.TeamWithdraw);
        require(tapPoll == address(0));
        require(getDay(now) == 10);
        require(tapIncPerc <= 50);
        uint256 _tap = safeAdd(tap, safeDiv(safeMul(tap, tapIncPerc), 100));
        uint256 startTime = now;
        uint256 endTime = startTime + TAP_POLL_DURATION;
        tapPoll = new TapPoll(_tap, token, this, startTime, endTime, minVotedTokensPerc);
        TapPollCreated();
    }

    function onTapPollFinish(bool agree, uint256 _tap) external {
        require(msg.sender == address(tapPoll) && tapPoll.finalized());
        if(agree) {
            tap = _tap;
        }
        updateMinVotedTokens(tapPoll.getVotedTokensPerc());
        TapPollFinished(agree, _tap);
        delete tapPoll;
    }

    function createRefundPoll() public onlyTokenHolder {
        require(state == FundState.TeamWithdraw);
        require(address(refundPoll) == address(0));

        uint256 startTime = now;
        uint256 endTime = startTime + REFUND_POLL_DURATION;

        refundPoll = new RefundPoll(token, this, startTime, endTime, true);
        RefundPollCreated();
    }

    function onRefundPollFinish(bool agree) external {
        require(msg.sender == address(refundPoll) && refundPoll.finalized());
        if(agree) {
            isWithdrawEnabled = false;
            enableRefund();
        } else {
            isWithdrawEnabled = true;
        }
        RefundPollFinished(agree);

        delete refundPoll;
    }
}
