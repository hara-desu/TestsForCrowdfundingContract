// Code from the youtube tutorial: https://www.youtube.com/watch?v=ekZbK42Ukvs
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract LowkickStarter {
    struct LowkickCampaign {
        Campaign targetContract;
        bool claimed;
    }
    mapping(uint => LowkickCampaign) public campaigns;
    uint public currentCampaign;
    address owner;
    uint public constant MAX_DURATION = 30 days;
    uint public constant MIN_DURATION = 60;
    event CampaignStarted(uint id, uint endsAt, uint goal, address organizer);

    function start(uint _goal, uint _endsAt) external {
        require(_goal > 0);
        require(
            _endsAt < block.timestamp + MAX_DURATION &&
                _endsAt > block.timestamp + MIN_DURATION
        );
        currentCampaign += 1;

        Campaign newCampaign = new Campaign(
            _endsAt,
            _goal,
            msg.sender,
            address(this),
            currentCampaign
        );

        campaigns[currentCampaign] = LowkickCampaign({
            targetContract: newCampaign,
            claimed: false
        });

        emit CampaignStarted(currentCampaign, _endsAt, _goal, msg.sender);
    }

    function onClaimed(uint _id) external {
        LowkickCampaign storage targetCampaign = campaigns[_id];
        require(
            msg.sender == address(targetCampaign.targetContract),
            "Sender is not target contract"
        );
        targetCampaign.claimed = true;
    }
}

contract Campaign {
    uint public endsAt;
    uint public goal;
    uint256 public pledged;
    uint public id;
    address public organizer;
    LowkickStarter parent;
    mapping(address => uint) public pledges;
    bool claimed;

    event Pledged(uint amount, address pledger);

    constructor(
        uint _endsAt,
        uint _goal,
        address _organizer,
        address _parent,
        uint _id
    ) {
        endsAt = _endsAt;
        goal = _goal;
        organizer = _organizer;
        parent = LowkickStarter(msg.sender);
        id = _id;
    }

    function pledge() external payable {
        require(block.timestamp <= endsAt, "Out of time");
        require(msg.value > 0, "Please send funds");
        pledged += msg.value;
        pledges[msg.sender] += msg.value;
        emit Pledged(msg.value, msg.sender);
    }

    function refundPledge(uint _amount) external {
        require(block.timestamp <= endsAt, "Campaign has ended");

        pledges[msg.sender] -= _amount;
        pledged -= _amount;
    }

    function claim() external {
        require(block.timestamp > endsAt, "Campaign hasn't ended");
        require(msg.sender == organizer, "Can only be called by organizer");
        require(pledged >= goal, "Pledged amount should exceed the goal");
        require(!claimed, "Already claimed");

        claimed = true;

        payable(organizer).transfer(pledged);

        parent.onClaimed(id);
    }

    function fullRefund() external {
        require(block.timestamp < endsAt, "Campaign has ended");
        require(pledged < goal, "Pledged amount should be less than goal");

        uint refundAmount = pledges[msg.sender];
        pledges[msg.sender] = 0;
        payable(msg.sender).transfer(refundAmount);
    }
}
