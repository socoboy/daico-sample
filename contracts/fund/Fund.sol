pragma solidity ^0.4.21;

import './ICrowdsaleFund.sol';
import '../utilities/SafeMath.sol';
import '../utilities/MultiOwnable.sol';
import '../token/ManagedToken.sol';


contract Fund is ICrowdsaleFund, SafeMath, MultiOwnable {
    enum FundState {
        Crowdsale,
        TeamWithdraw,
        Refund
    }

    FundState public state = FundState.Crowdsale;
    ManagedToken public token;

    uint256 public constant INITIAL_TAP = 19290123456790; // (wei/sec) == 50 ether/month

    address public teamWallet;
    uint256 public crowdsaleEndDate;

    address public teamTokenWallet;
    address public lockedTokenAddress;

    uint256 public tap;
    uint256 public lastWithdrawTime = 0;
    uint256 public firstWithdrawAmount = 0;

    address public crowdsaleAddress;
    mapping(address => uint256) public contributions;

    event RefundContributor(address tokenHolder, uint256 amountWei, uint256 timestamp);
    event RefundHolder(address tokenHolder, uint256 amountWei, uint256 tokenAmount, uint256 timestamp);
    event Withdraw(uint256 amountWei, uint256 timestamp);
    event RefundEnabled(address initiatorAddress);

    /**
     * @dev Fund constructor
     * @param _teamWallet Withdraw functions transfers ether to this address
     * @param _teamTokenWallet Company wallet address
     * @param _owners Contract owners
     */
    function Fund(
        address _teamWallet,
        address _teamTokenWallet,
        address[] _owners
    ) public
    {
        teamWallet = _teamWallet;
        teamTokenWallet = _teamTokenWallet;
        _setOwners(_owners);
    }

    modifier withdrawEnabled() {
        require(canWithdraw());
        _;
    }

    modifier onlyCrowdsale() {
        require(msg.sender == crowdsaleAddress);
        _;
    }

    function canWithdraw() public returns(bool);

    function setCrowdsaleAddress(address _crowdsaleAddress) public onlyOwner {
        require(crowdsaleAddress == address(0));
        crowdsaleAddress = _crowdsaleAddress;
    }

    function setTokenAddress(address _tokenAddress) public onlyOwner {
        require(address(token) == address(0));
        token = ManagedToken(_tokenAddress);
    }

    function setLockedTokenAddress(address _lockedTokenAddress) public onlyOwner {
        require(address(lockedTokenAddress) == address(0));
        lockedTokenAddress = _lockedTokenAddress;
    }

    /**
     * @dev Process crowdsale contribution
     */
    function processContribution(address contributor) external payable onlyCrowdsale {
        require(state == FundState.Crowdsale);
        uint256 totalContribution = safeAdd(contributions[contributor], msg.value);
        contributions[contributor] = totalContribution;
    }

    /**
     * @dev Callback is called after crowdsale finalization if soft cap is reached
     */
    function onCrowdsaleEnd() external onlyCrowdsale {
        state = FundState.TeamWithdraw;
        firstWithdrawAmount = 0;
        lastWithdrawTime = now;
        tap = INITIAL_TAP;
        crowdsaleEndDate = now;
    }

    /**
     * @dev Decrease tap amount
     * @param _tap New tap value
     */
    function decTap(uint256 _tap) external onlyOwner {
        require(state == FundState.TeamWithdraw);
        require(_tap < tap);
        tap = _tap;
    }

    function getCurrentTapAmount() public constant returns(uint256) {
        if(state != FundState.TeamWithdraw) {
            return 0;
        }
        return calcTapAmount();
    }

    function calcTapAmount() internal view returns(uint256) {
        uint256 amount = safeMul(safeSub(now, lastWithdrawTime), tap);
        if(address(this).balance < amount) {
            amount = address(this).balance;
        }
        return amount;
    }

    function firstWithdraw() public onlyOwner withdrawEnabled {
        require(firstWithdrawAmount > 0);
        uint256 amount = firstWithdrawAmount;
        firstWithdrawAmount = 0;
        teamWallet.transfer(amount);
        Withdraw(amount, now);
    }

    /**
     * @dev Withdraw tap amount
     */
    function withdraw() public onlyOwner withdrawEnabled {
        require(state == FundState.TeamWithdraw);
        uint256 amount = calcTapAmount();
        lastWithdrawTime = now;
        teamWallet.transfer(amount);
        Withdraw(amount, now);
    }

    // Refund
    /**
     * @dev Called to start refunding
     */
    function enableRefund() internal {
        require(state == FundState.TeamWithdraw);
        state = FundState.Refund;
        token.destroy(lockedTokenAddress, token.balanceOf(lockedTokenAddress));
        token.destroy(teamTokenWallet, token.balanceOf(teamTokenWallet));
        RefundEnabled(msg.sender);
    }

    /**
    * @dev Function is called by contributor to refund
    * Buy user tokens for refundTokenPrice and destroy them
    */
    function refundTokenHolder() public {
        require(state == FundState.Refund);

        uint256 tokenBalance = token.balanceOf(msg.sender);
        require(tokenBalance > 0);
        uint256 refundAmount = safeDiv(safeMul(tokenBalance, address(this).balance), token.totalSupply());
        require(refundAmount > 0);

        token.destroy(msg.sender, tokenBalance);
        msg.sender.transfer(refundAmount);

        RefundHolder(msg.sender, refundAmount, tokenBalance, now);
    }
}
