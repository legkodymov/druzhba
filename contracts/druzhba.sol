// SPDX-License-Identifier: UNLICENCED

pragma solidity ^0.8.0;
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/*
contract Escrow {
}
*/

contract Peer2Peer {
    using SafeERC20 for IERC20;
    IERC20 private token;

    enum DealState {
        ZERO,
        START,
        PAYMENT_COMPLETE,
        DISPUTE,
        CANCELED_ARBITER,
        CANCELED_TIMEOUT_ARBITER,
        CANCELED_BUYER,
        CANCELED_SELLER,
        CLEARED_SELLER,
        CLEARED_ARBITER
    }

    struct Deal {
        address seller;
        address buyer;
        uint256 locked_amount;
        DealState state;
        bool in_use;
    }
    // TODO Enumerable mapping (???)
    mapping(uint => Deal) dealMapping;

    // TODO add OpenZeppelin's EnumerableSet (set of arbiters)
    address arbiter;
    mapping(address => uint256) lockedBalanceMapping;

    constructor(address _token) {
        token = IERC20(_token);
        arbiter = msg.sender;
    }

    modifier inUse(uint id) {
        require(dealMapping[id].in_use == true, "Not in use");
        _;
    }

    modifier isArbiter() {
        require(arbiter == msg.sender, "Not a arbiter");
        _;
    }

    modifier isSeller(uint id) {
        require(dealMapping[id].seller == msg.sender, "Not a seller");
        _;
    }

    modifier isBuyer(uint id) {
        require(dealMapping[id].buyer == msg.sender, "Not a buyer");
        _;
    }

    // TODO Check for allowance
    function lockForAdvertiseSeller(uint256 amount) external {
        lockedBalanceMapping[msg.sender] += amount;
        token.safeTransferFrom(msg.sender, address(this), amount);
    }

    // TODO разработать план борьбы с блокировщиками
    function acceptDealBuyer(address seller, uint256 amount, uint id) external {
        require(seller != msg.sender, "seller == buyer");
        require(dealMapping[id].in_use == false, "id is in use");
        require(lockedBalanceMapping[seller] > amount, "Seller doesn't have enough funds locked");
        lockedBalanceMapping[seller] -= amount;
        dealMapping[id] = Deal(seller, msg.sender, amount, DealState.START, true);

    }

    function cancelTimeoutArbiter(uint id) external inUse(id) isArbiter {
        require(arbiter == msg.sender, "Not a arbiter");
        require(dealMapping[id].state == DealState.START, "Wrong deal state");
        lockedBalanceMapping[dealMapping[id].seller] += dealMapping[id].locked_amount;
        dealMapping[id].state = DealState.CANCELED_TIMEOUT_ARBITER;
        dealMapping[id].in_use = false;
    }

    function cancelDealBuyer(uint id) external inUse(id) isBuyer(id) {
        require(dealMapping[id].state == DealState.START, "Wrong deal state");
        lockedBalanceMapping[dealMapping[id].seller] += dealMapping[id].locked_amount;
        dealMapping[id].state = DealState.CANCELED_BUYER;
        dealMapping[id].in_use = false;
    }

    function completePaymentBuyer(uint id) external inUse(id) isBuyer(id) {
        require(dealMapping[id].state == DealState.START, "Wrong deal state");
        dealMapping[id].state = DealState.PAYMENT_COMPLETE;
    }

    function clearDealSeller(uint id) external inUse(id) isSeller(id) {
        require(dealMapping[id].state == DealState.PAYMENT_COMPLETE, "Wrong deal state");
        lockedBalanceMapping[dealMapping[id].buyer] += dealMapping[id].locked_amount;
        dealMapping[id].state = DealState.CLEARED_SELLER;
        dealMapping[id].in_use = false;
    }

    function callHelpSeller(uint id) external inUse(id) isSeller(id) {
        require(dealMapping[id].state == DealState.PAYMENT_COMPLETE, "Wrong deal state");
        dealMapping[id].state = DealState.DISPUTE;
    }

    function callHelpBuyer(uint id) external inUse(id) isBuyer(id) {
        require(dealMapping[id].state == DealState.PAYMENT_COMPLETE, "Wrong deal state");
        dealMapping[id].state = DealState.DISPUTE;
    }

    function cancelDealArbiter(uint id) external inUse(id) isArbiter() {
        require(dealMapping[id].state == DealState.DISPUTE, "Wrong deal state");
        lockedBalanceMapping[dealMapping[id].seller] += dealMapping[id].locked_amount;
        dealMapping[id].state = DealState.CANCELED_ARBITER;
        dealMapping[id].in_use = false;
    }

    function clearDealArbiter(uint id) external inUse(id) isArbiter {
        require(dealMapping[id].state == DealState.DISPUTE, "Wrong deal state");
        lockedBalanceMapping[dealMapping[id].buyer] += dealMapping[id].locked_amount;
        dealMapping[id].state = DealState.CLEARED_ARBITER;
        dealMapping[id].in_use = false;
    }

    function claimableBalance(address recipient) external view returns (uint256) {
        return lockedBalanceMapping[recipient];
    }

    function getDealState(uint id) external view returns (DealState) {
        return dealMapping[id].state;
    }

    function claim() external {
        uint256 amount = lockedBalanceMapping[msg.sender];
        lockedBalanceMapping[msg.sender] = 0;
        token.safeTransfer(msg.sender, amount);
    }

}

/*
helperGetDealStateById
*/
