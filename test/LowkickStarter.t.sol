// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {LowkickStarter, Campaign} from "../src/LowkickStarter.sol";

contract LowkickStarterTest is Test {
    LowkickStarter public lowkickStarter;
    address USER = makeAddr("USER");
    uint256 public DURATION = 800;
    uint256 public FUND_VALUE = 1e15;
    uint256 public GOAL = 12340000;
    uint256 public SEND_VALUE = 1234;

    function setUp() public {
        lowkickStarter = new LowkickStarter();
        vm.deal(address(lowkickStarter), FUND_VALUE);
        vm.deal(USER, FUND_VALUE);
    }

    ///////////////////////////
    /* LowkickStarter: start */
    ///////////////////////////
    function testStartRevertsIfGoalIsZero() public {
        // Arrange
        uint256 endsAt = block.timestamp + DURATION;

        // Act / Assert
        vm.expectRevert();
        vm.prank(USER);
        lowkickStarter.start(0, endsAt);
    }

    function testStartRevertsIfDurationIsOutOfRange() public {
        // Arrange
        uint256 endsAt = block.timestamp +
            lowkickStarter.MAX_DURATION() +
            1 days;

        // Act / Assert
        vm.expectRevert();
        vm.prank(USER);
        lowkickStarter.start(GOAL, endsAt);
    }

    function testStartCreatesANewCampaignContract() public {
        // Arrange
        uint256 endsAt = block.timestamp + DURATION;

        // Act
        vm.prank(USER);
        lowkickStarter.start(GOAL, endsAt);
        uint256 currentCampaign = lowkickStarter.currentCampaign();
        (Campaign target, bool claimed) = lowkickStarter.campaigns(
            currentCampaign
        );

        // Assert
        assert(address(target) != address(0));
    }

    function testStartEmitsCampaignStarted() public {
        // Arrange
        uint endsAt = block.timestamp + DURATION;
        uint expectedId = lowkickStarter.currentCampaign() + 1;

        vm.expectEmit(address(lowkickStarter));
        emit LowkickStarter.CampaignStarted(expectedId, endsAt, GOAL, USER);

        // Act / Assert
        vm.prank(USER);
        lowkickStarter.start(GOAL, endsAt);
    }

    ///////////////////////////////
    /* LowkickStarter: onClaimed */
    ///////////////////////////////
    function testOnClaimedRevertsIfSenderIsNotTargetContract() public {
        // Arrange
        uint256 endsAt = block.timestamp + DURATION;

        // Act
        vm.prank(USER);
        lowkickStarter.start(GOAL, endsAt);
        uint256 id = lowkickStarter.currentCampaign();
        (Campaign campaign, ) = lowkickStarter.campaigns(id);

        // Assert
        assertTrue(address(campaign) != address(0), "campaign not stored");
        assertTrue(address(campaign) != address(this), "test is campaign?");

        vm.expectRevert("Sender is not target contract");
        lowkickStarter.onClaimed(id);
    }

    function testOnClaimedWorks() public {
        // Arrange
        uint256 endsAt = block.timestamp + DURATION;

        // Act
        vm.prank(USER);
        lowkickStarter.start(GOAL, endsAt);
        uint256 id = lowkickStarter.currentCampaign();
        (Campaign campaign, bool claimed) = lowkickStarter.campaigns(id);
        vm.prank(address(campaign));
        lowkickStarter.onClaimed(id);
        (Campaign campaign_final, bool claimed_final) = lowkickStarter
            .campaigns(id);

        // Assert
        assert(claimed_final);
    }

    //////////////////////
    /* Campaign: pledge */
    //////////////////////
    function testPledgeRevertsIfTimeExceedsCampaignDuration() public {
        // Arrange
        uint256 endsAt = block.timestamp + DURATION;
        address user2 = address(0x5);
        vm.deal(user2, FUND_VALUE);

        // Act / Assert
        vm.prank(USER);
        lowkickStarter.start(GOAL, endsAt);
        uint256 id = lowkickStarter.currentCampaign();
        (Campaign campaign, bool claimed) = lowkickStarter.campaigns(id);
        vm.warp(block.timestamp + DURATION + 10);

        vm.expectRevert("Out of time");
        vm.prank(user2);
        campaign.pledge{value: SEND_VALUE}();
    }

    function testPledgeRevertsIfValueNotSent() public {
        // Arrange
        uint256 endsAt = block.timestamp + DURATION;
        address user2 = address(0x5);
        vm.deal(user2, FUND_VALUE);

        // Act / Assert
        vm.prank(USER);
        lowkickStarter.start(GOAL, endsAt);
        uint256 id = lowkickStarter.currentCampaign();
        (Campaign campaign, bool claimed) = lowkickStarter.campaigns(id);

        vm.expectRevert("Please send funds");
        vm.prank(user2);
        campaign.pledge{value: 0}();
    }

    function testPledgeWorks() public {
        // Arrange
        uint256 endsAt = block.timestamp + DURATION;
        address user2 = address(0x5);
        vm.deal(user2, FUND_VALUE);

        // Act
        vm.prank(USER);
        lowkickStarter.start(GOAL, endsAt);
        uint256 id = lowkickStarter.currentCampaign();
        (Campaign campaign, bool claimed) = lowkickStarter.campaigns(id);

        vm.prank(user2);
        campaign.pledge{value: SEND_VALUE}();

        uint256 pledgedValue = campaign.pledged();
        uint256 pledges = campaign.pledges(user2);

        // Assert
        assertEq(pledgedValue, SEND_VALUE);
        assertEq(pledges, SEND_VALUE);
    }

    function testPledgeEmitsEvent() public {
        // Arrange
        uint256 endsAt = block.timestamp + DURATION;
        address user2 = address(0x5);
        vm.deal(user2, FUND_VALUE);

        // Act
        vm.prank(USER);
        lowkickStarter.start(GOAL, endsAt);
        uint256 id = lowkickStarter.currentCampaign();
        (Campaign campaign, bool claimed) = lowkickStarter.campaigns(id);

        vm.expectEmit(address(campaign));
        emit Campaign.Pledged(SEND_VALUE, user2);

        vm.prank(user2);
        campaign.pledge{value: SEND_VALUE}();
    }

    ////////////////////////////
    /* Campaign: refundPledge */
    ////////////////////////////
    function testRefundPledgeRevertsIfCampaignEnded() public {
        // Arrange
        uint256 endsAt = block.timestamp + DURATION;
        address user2 = address(0x5);
        vm.deal(user2, FUND_VALUE);

        // Act
        vm.prank(USER);
        lowkickStarter.start(GOAL, endsAt);
        uint256 id = lowkickStarter.currentCampaign();
        (Campaign campaign, bool claimed) = lowkickStarter.campaigns(id);

        vm.prank(user2);
        campaign.pledge{value: SEND_VALUE}();

        vm.warp(block.timestamp + DURATION + 10);
        vm.expectRevert("Campaign has ended");
        vm.prank(user2);
        campaign.refundPledge(SEND_VALUE);
    }

    function testRefundPledgeWorks() public {
        // Arrange
        uint256 endsAt = block.timestamp + DURATION;
        address user2 = address(0x5);
        vm.deal(user2, FUND_VALUE);

        // Act
        vm.prank(USER);
        lowkickStarter.start(GOAL, endsAt);
        uint256 id = lowkickStarter.currentCampaign();
        (Campaign campaign, bool claimed) = lowkickStarter.campaigns(id);

        vm.prank(user2);
        campaign.pledge{value: SEND_VALUE}();

        uint256 pledgedBeforeRefund = campaign.pledged();
        uint pledgesBeforeRefund = campaign.pledges(user2);

        vm.prank(user2);
        campaign.refundPledge(SEND_VALUE);

        uint256 pledgedAfterRefund = campaign.pledged();
        uint pledgesAfterRefund = campaign.pledges(user2);

        // Assert
        assertEq(pledgedAfterRefund, pledgedBeforeRefund - SEND_VALUE);
        assertEq(pledgesAfterRefund, pledgesBeforeRefund - SEND_VALUE);
    }

    /////////////////////
    /* Campaign: claim */
    /////////////////////
    function testClaimRevertsIfCampaignNotEnded() public {
        // Arrange
        uint256 endsAt = block.timestamp + DURATION;
        address user2 = address(0x5);
        vm.deal(user2, FUND_VALUE);

        // Act
        vm.prank(USER);
        lowkickStarter.start(GOAL, endsAt);
        uint256 id = lowkickStarter.currentCampaign();
        (Campaign campaign, bool claimed) = lowkickStarter.campaigns(id);

        vm.prank(user2);
        campaign.pledge{value: GOAL + SEND_VALUE}();

        address organizer = campaign.organizer();

        vm.expectRevert("Campaign hasn't ended");
        vm.prank(organizer);
        campaign.claim();
    }

    function testClaimRevertsIfCalledByNonOrganizer() public {
        // Arrange
        uint256 endsAt = block.timestamp + DURATION;
        address user2 = address(0x5);
        vm.deal(user2, FUND_VALUE);

        // Act
        vm.prank(USER);
        lowkickStarter.start(GOAL, endsAt);
        uint256 id = lowkickStarter.currentCampaign();
        (Campaign campaign, bool claimed) = lowkickStarter.campaigns(id);

        vm.prank(user2);
        campaign.pledge{value: GOAL + SEND_VALUE}();

        address organizer = campaign.organizer();

        vm.warp(block.timestamp + DURATION + 10);
        vm.expectRevert("Can only be called by organizer");
        campaign.claim();
    }

    function testClaimRevertsIfPledgedAmountNotExceedsGoal() public {
        // Arrange
        uint256 endsAt = block.timestamp + DURATION;
        address user2 = address(0x5);
        vm.deal(user2, FUND_VALUE);

        // Act
        vm.prank(USER);
        lowkickStarter.start(GOAL, endsAt);
        uint256 id = lowkickStarter.currentCampaign();
        (Campaign campaign, bool claimed) = lowkickStarter.campaigns(id);

        vm.prank(user2);
        campaign.pledge{value: SEND_VALUE}();

        address organizer = campaign.organizer();

        vm.warp(block.timestamp + DURATION + 10);
        vm.expectRevert("Pledged amount should exceed the goal");
        vm.prank(organizer);
        campaign.claim();
    }

    function testClaimRevertsIfAlreadyClaimed() public {
        // Arrange
        uint256 endsAt = block.timestamp + DURATION;
        address user2 = address(0x5);
        vm.deal(user2, FUND_VALUE);

        // Act
        vm.prank(USER);
        lowkickStarter.start(GOAL, endsAt);
        uint256 id = lowkickStarter.currentCampaign();
        (Campaign campaign, bool claimed) = lowkickStarter.campaigns(id);

        vm.prank(user2);
        campaign.pledge{value: GOAL + SEND_VALUE}();

        address organizer = campaign.organizer();

        vm.warp(block.timestamp + DURATION + 10);
        vm.prank(organizer);
        campaign.claim();

        vm.expectRevert("Already claimed");
        vm.prank(organizer);
        campaign.claim();
    }

    //////////////////////////
    /* Campaign: fullRefund */
    //////////////////////////
    function testFullRefundRevertsIfCampaignEnded() public {
        // Arrange
        uint256 endsAt = block.timestamp + DURATION;
        address user2 = makeAddr("USER2");
        vm.deal(user2, FUND_VALUE);

        // Act
        vm.prank(USER);
        lowkickStarter.start(GOAL, endsAt);
        uint256 id = lowkickStarter.currentCampaign();
        (Campaign campaign, bool claimed) = lowkickStarter.campaigns(id);

        vm.prank(user2);
        campaign.pledge{value: SEND_VALUE}();

        vm.warp(block.timestamp + DURATION + 10);
        vm.expectRevert("Campaign has ended");
        vm.prank(user2);
        campaign.fullRefund();
    }

    function testFullRefundRevertsIfPledgedAmountMoreThanGoal() public {
        // Arrange
        uint256 endsAt = block.timestamp + DURATION;
        address user2 = makeAddr("USER2");
        vm.deal(user2, FUND_VALUE);

        // Act
        vm.prank(USER);
        lowkickStarter.start(GOAL, endsAt);
        uint256 id = lowkickStarter.currentCampaign();
        (Campaign campaign, bool claimed) = lowkickStarter.campaigns(id);

        vm.prank(user2);
        campaign.pledge{value: GOAL + SEND_VALUE}();

        vm.expectRevert("Pledged amount should be less than goal");
        vm.prank(user2);
        campaign.fullRefund();
    }

    function testFullRefundWorks() public {
        // Arrange
        uint256 endsAt = block.timestamp + DURATION;
        address user2 = makeAddr("USER2");
        vm.deal(user2, FUND_VALUE);

        // Act
        vm.prank(USER);
        lowkickStarter.start(GOAL, endsAt);
        uint256 id = lowkickStarter.currentCampaign();
        (Campaign campaign, bool claimed) = lowkickStarter.campaigns(id);

        vm.prank(user2);
        campaign.pledge{value: SEND_VALUE}();

        vm.prank(user2);
        campaign.fullRefund();

        uint pledgesAfterRefund = campaign.pledges(user2);
        assertEq(pledgesAfterRefund, 0);
    }
}
