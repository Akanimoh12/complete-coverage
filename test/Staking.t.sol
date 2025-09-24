// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.26;

import  "forge-std/Test.sol";
import {StakingRewards, IERC20} from "src/Staking.sol";
import {MockERC20} from "test/MockErc20.sol";

contract StakingTest is Test {
    StakingRewards staking;
    MockERC20 stakingToken;
    MockERC20 rewardToken;

    address owner = makeAddr("owner");
    address bob = makeAddr("bob");
    address dso = makeAddr("dso");

    function setUp() public {
        vm.startPrank(owner);
        stakingToken = new MockERC20();
        rewardToken = new MockERC20();
        staking = new StakingRewards(address(stakingToken), address(rewardToken));
        vm.stopPrank();
    }

    function test_alwaysPass() public {
        assertEq(staking.owner(), owner, "Wrong owner set");
        assertEq(address(staking.stakingToken()), address(stakingToken), "Wrong staking token address");
        assertEq(address(staking.rewardsToken()), address(rewardToken), "Wrong reward token address");

        assertTrue(true);
    }

    function test_cannot_stake_amount0() public {
        deal(address(stakingToken), bob, 10e18);
        // start prank to assume user is making subsequent calls
        vm.startPrank(bob);
        IERC20(address(stakingToken)).approve(address(staking), type(uint256).max);

        // we are expecting a revert if we deposit/stake zero
        vm.expectRevert("amount = 0");
        staking.stake(0);
        vm.stopPrank();
    }

    function test_can_stake_successfully() public {
        deal(address(stakingToken), bob, 10e18);
        // start prank to assume user is making subsequent calls
        vm.startPrank(bob);
        IERC20(address(stakingToken)).approve(address(staking), type(uint256).max);
        uint256 _totalSupplyBeforeStaking = staking.totalSupply();
        staking.stake(5e18);
        assertEq(staking.balanceOf(bob), 5e18, "Amounts do not match");
        assertEq(staking.totalSupply(), _totalSupplyBeforeStaking + 5e18, "totalsupply didnt update correctly");
    }

    function  test_cannot_withdraw_amount0() public {
        vm.prank(bob);
        vm.expectRevert("amount = 0");
        staking.withdraw(0);
    }

    function test_can_withdraw_deposited_amount() public {
        test_can_stake_successfully();

        uint256 userStakebefore = staking.balanceOf(bob);
        uint256 totalSupplyBefore = staking.totalSupply();
        staking.withdraw(2e18);
        assertEq(staking.balanceOf(bob), userStakebefore - 2e18, "Balance didnt update correctly");
        assertLt(staking.totalSupply(), totalSupplyBefore, "total supply didnt update correctly");

    }

    function test_notify_Rewards() public {
        // check that it reverts if non owner tried to set duration
        vm.expectRevert("not authorized");
        staking.setRewardsDuration(1 weeks);

        // simulate owner calls setReward successfully
        vm.prank(owner);
        staking.setRewardsDuration(1 weeks);
        assertEq(staking.duration(), 1 weeks, "duration not updated correctly");
        // log block.timestamp
        console.log("current time", block.timestamp);
        // move time foward 
        vm.warp(block.timestamp + 200);
        // notify rewards 
        deal(address(rewardToken), owner, 100 ether);
        vm.startPrank(owner); 
        IERC20(address(rewardToken)).transfer(address(staking), 100 ether);
        
        // trigger revert
        vm.expectRevert("reward rate = 0");
        staking.notifyRewardAmount(1);
    
        // trigger second revert
        vm.expectRevert("reward amount > balance");
        staking.notifyRewardAmount(200 ether);

        // trigger first type of flow success
        staking.notifyRewardAmount(100 ether);
        assertEq(staking.rewardRate(), uint256(100 ether)/uint256(1 weeks));
        assertEq(staking.finishAt(), uint256(block.timestamp) + uint256(1 weeks));
        assertEq(staking.updatedAt(), block.timestamp);
    
        // trigger setRewards distribution revert
        vm.expectRevert("reward duration not finished");
        staking.setRewardsDuration(1 weeks);
    
    }

    function test_getReward_with_no_rewards() public {
        // test getReward when user has no rewards
        vm.prank(bob);
        staking.getReward();
        assertEq(staking.rewards(bob), 0, "Rewards should be 0");
    }

    function test_getReward_with_rewards() public {
        // Setup staking and rewards first
        vm.prank(owner);
        staking.setRewardsDuration(1 weeks);
        
        // Bob stakes some tokens
        deal(address(stakingToken), bob, 10e18);
        vm.startPrank(bob);
        IERC20(address(stakingToken)).approve(address(staking), type(uint256).max);
        staking.stake(5e18);
        vm.stopPrank();
        
        // Setup rewards
        deal(address(rewardToken), owner, 100 ether);
        vm.startPrank(owner); 
        IERC20(address(rewardToken)).transfer(address(staking), 100 ether);
        staking.notifyRewardAmount(100 ether);
        vm.stopPrank();
        
        // Move time forward to accrue rewards
        vm.warp(block.timestamp + 1 days);
        
        // Check earned rewards before claiming
        uint256 earnedBefore = staking.earned(bob);
        assertGt(earnedBefore, 0, "Should have earned some rewards");
        
        // Claim rewards
        uint256 bobRewardBalanceBefore = IERC20(address(rewardToken)).balanceOf(bob);
        vm.prank(bob);
        staking.getReward();
        
        // Verify rewards were transferred
        uint256 bobRewardBalanceAfter = IERC20(address(rewardToken)).balanceOf(bob);
        assertGt(bobRewardBalanceAfter, bobRewardBalanceBefore, "Reward balance should increase");
        assertEq(staking.rewards(bob), 0, "Rewards should be reset to 0");
    }

    function test_earned_function() public {
        // Test earned function with no stake
        assertEq(staking.earned(bob), 0, "Should have 0 earned with no stake");
        
        // Setup staking and rewards
        vm.prank(owner);
        staking.setRewardsDuration(1 weeks);
        
        deal(address(stakingToken), bob, 10e18);
        vm.startPrank(bob);
        IERC20(address(stakingToken)).approve(address(staking), type(uint256).max);
        staking.stake(5e18);
        vm.stopPrank();
        
        // Setup rewards
        deal(address(rewardToken), owner, 100 ether);
        vm.startPrank(owner); 
        IERC20(address(rewardToken)).transfer(address(staking), 100 ether);
        staking.notifyRewardAmount(100 ether);
        vm.stopPrank();
        
        // Should still be 0 immediately after
        assertEq(staking.earned(bob), 0, "Should be 0 immediately after setup");
        
        // Move time forward and check earned increases
        vm.warp(block.timestamp + 1 days);
        assertGt(staking.earned(bob), 0, "Should have earned rewards after time passes");
    }

    function test_lastTimeRewardApplicable() public {
        // Should return 0 when no rewards are set (since finishAt is 0)
        assertEq(staking.lastTimeRewardApplicable(), 0, "Should return 0 when finishAt is 0");
        
        // Setup rewards
        vm.prank(owner);
        staking.setRewardsDuration(1 weeks);
        
        deal(address(rewardToken), owner, 100 ether);
        vm.startPrank(owner); 
        IERC20(address(rewardToken)).transfer(address(staking), 100 ether);
        staking.notifyRewardAmount(100 ether);
        vm.stopPrank();
        
        // Should return current timestamp when within reward period
        assertEq(staking.lastTimeRewardApplicable(), block.timestamp, "Should return current timestamp during reward period");
        
        // Move time past finish time
        vm.warp(block.timestamp + 2 weeks);
        assertEq(staking.lastTimeRewardApplicable(), staking.finishAt(), "Should return finishAt when past reward period");
    }

    function test_rewardPerToken_with_zero_totalSupply() public {
        // Test rewardPerToken when totalSupply is 0
        assertEq(staking.rewardPerToken(), 0, "Should return rewardPerTokenStored when totalSupply is 0");
    }

    function test_rewardPerToken_with_stakers() public {
        // Setup staking
        deal(address(stakingToken), bob, 10e18);
        vm.startPrank(bob);
        IERC20(address(stakingToken)).approve(address(staking), type(uint256).max);
        staking.stake(5e18);
        vm.stopPrank();
        
        // Setup rewards
        vm.prank(owner);
        staking.setRewardsDuration(1 weeks);
        
        deal(address(rewardToken), owner, 100 ether);
        vm.startPrank(owner); 
        IERC20(address(rewardToken)).transfer(address(staking), 100 ether);
        staking.notifyRewardAmount(100 ether);
        vm.stopPrank();
        
        uint256 rewardPerTokenBefore = staking.rewardPerToken();
        
        // Move time forward
        vm.warp(block.timestamp + 1 days);
        
        uint256 rewardPerTokenAfter = staking.rewardPerToken();
        assertGt(rewardPerTokenAfter, rewardPerTokenBefore, "rewardPerToken should increase over time");
    }

    function test_notifyRewardAmount_with_remaining_rewards() public {
        // Setup initial rewards
        vm.prank(owner);
        staking.setRewardsDuration(1 weeks);
        
        deal(address(rewardToken), owner, 200 ether);
        vm.startPrank(owner); 
        IERC20(address(rewardToken)).transfer(address(staking), 200 ether);
        staking.notifyRewardAmount(100 ether);
        
        // Move time forward but not past finish
        vm.warp(block.timestamp + 3 days);
        
        // Add more rewards while previous period is still active
        staking.notifyRewardAmount(100 ether);
        
        // Verify the rate was updated correctly (should include remaining rewards)
        assertGt(staking.rewardRate(), 0, "Reward rate should be set");
        assertEq(staking.finishAt(), block.timestamp + 1 weeks, "FinishAt should be updated");
        vm.stopPrank();
    }

    function test_setRewardsDuration_after_period_ends() public {
        // Setup and complete a reward period
        vm.prank(owner);
        staking.setRewardsDuration(1 weeks);
        
        deal(address(rewardToken), owner, 100 ether);
        vm.startPrank(owner); 
        IERC20(address(rewardToken)).transfer(address(staking), 100 ether);
        staking.notifyRewardAmount(100 ether);
        
        // Move time past the reward period
        vm.warp(block.timestamp + 2 weeks);
        
        // Should now be able to set new duration
        staking.setRewardsDuration(2 weeks);
        assertEq(staking.duration(), 2 weeks, "Duration should be updated");
        vm.stopPrank();
    }

    function test_updateReward_modifier_with_address_zero() public {
        // This tests the updateReward modifier with address(0)
        // which is called in notifyRewardAmount
        vm.prank(owner);
        staking.setRewardsDuration(1 weeks);
        
        deal(address(rewardToken), owner, 100 ether);
        vm.startPrank(owner); 
        IERC20(address(rewardToken)).transfer(address(staking), 100 ether);
        
        uint256 updatedAtBefore = staking.updatedAt();
        staking.notifyRewardAmount(100 ether);
        
        // Verify updatedAt was updated (this tests the modifier with address(0))
        assertGt(staking.updatedAt(), updatedAtBefore, "updatedAt should be updated");
        vm.stopPrank();
    }

    function test_min_function_both_branches() public {
        // This indirectly tests the _min function through lastTimeRewardApplicable
        
        // Setup rewards
        vm.prank(owner);
        staking.setRewardsDuration(1 weeks);
        
        deal(address(rewardToken), owner, 100 ether);
        vm.startPrank(owner); 
        IERC20(address(rewardToken)).transfer(address(staking), 100 ether);
        staking.notifyRewardAmount(100 ether);
        vm.stopPrank();
        
        // Test when block.timestamp < finishAt (should return block.timestamp)
        assertEq(staking.lastTimeRewardApplicable(), block.timestamp, "Should return block.timestamp when it's smaller");
        
        // Test when block.timestamp > finishAt (should return finishAt)
        vm.warp(block.timestamp + 2 weeks);
        assertEq(staking.lastTimeRewardApplicable(), staking.finishAt(), "Should return finishAt when block.timestamp is larger");
    }


}