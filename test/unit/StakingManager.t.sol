// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {StakingManager, IStakingManager} from '@contracts/tokens/StakingManager.sol';
import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';
import {IStakingToken} from '@interfaces/tokens/IStakingToken.sol';
import {IRewardPool} from '@interfaces/tokens/IRewardPool.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {Assertions} from '@libraries/Assertions.sol';

abstract contract Base is HaiTest {
  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  IProtocolToken mockProtocolToken = IProtocolToken(mockContract('ProtocolToken'));
  IStakingToken mockStakingToken = IStakingToken(mockContract('StakingToken'));
  IRewardPool mockRewardPool = IRewardPool(mockContract('RewardPool'));
  IERC20 mockRewardToken = IERC20(mockContract('RewardToken'));

  StakingManager stakingManager;

  uint256 constant COOLDOWN_PERIOD = 7 days;

  function setUp() public virtual {
    vm.startPrank(deployer);

    stakingManager = new StakingManager(address(mockProtocolToken), address(mockStakingToken), COOLDOWN_PERIOD);
    label(address(stakingManager), 'StakingManager');

    stakingManager.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  modifier mockProtocolTokenApproval(address _owner, uint256 _amount) {
    vm.mockCall(
      address(mockProtocolToken),
      abi.encodeWithSelector(IERC20.allowance.selector, _owner, address(stakingManager)),
      abi.encode(_amount)
    );
    _;
  }

  modifier authorized() {
    vm.startPrank(authorizedAccount);
    _;
    vm.stopPrank();
  }
}

contract Unit_StakingManager_Constructor is Base {
  function test_Set_Parameters() public {
    assertEq(address(stakingManager.protocolToken()), address(mockProtocolToken));
    assertEq(address(stakingManager.stakingToken()), address(mockStakingToken));
    assertEq(stakingManager.params().cooldownPeriod, COOLDOWN_PERIOD);
  }

  function test_Revert_NullProtocolToken() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));
    new StakingManager(address(0), address(mockStakingToken), COOLDOWN_PERIOD);
  }

  function test_Revert_NullStakingToken() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));
    new StakingManager(address(mockProtocolToken), address(0), COOLDOWN_PERIOD);
  }
}

contract Unit_StakingManager_ModifyParameters is Base {
  function test_ModifyParameters(uint256 _cooldownPeriod) public authorized {
    vm.assume(_cooldownPeriod > 0);

    stakingManager.modifyParameters('cooldownPeriod', abi.encode(_cooldownPeriod));

    IStakingManager.StakingManagerParams memory _params = stakingManager.params();
    assertEq(_params.cooldownPeriod, _cooldownPeriod);
  }

  function test_Revert_ModifyParameters_NullCooldownPeriod() public authorized {
    vm.expectRevert(Assertions.NullAmount.selector);
    stakingManager.modifyParameters('cooldownPeriod', abi.encode(0));
  }
}

contract Unit_StakingManager_Stake is Base {
  event StakingManagerStaked(address indexed _account, uint256 _amount);
  event StakingManagerAddRewardType(uint256 indexed _id, address indexed _rewardToken, address indexed _rewardPool);
  event StakingManagerActivateRewardType(uint256 indexed _id);

  modifier setupRewardPool() {
    vm.startPrank(authorizedAccount);
    stakingManager.addRewardType(address(mockRewardToken), address(mockRewardPool));
    vm.stopPrank();
    _;
  }

  function test_Revert_StakeNullReceiver() public {
    vm.expectRevert(IStakingManager.StakingManager_StakeNullReceiver.selector);
    stakingManager.stake(address(0), 1e18);
  }

  function test_Revert_StakeNullAmount() public {
    vm.expectRevert(IStakingManager.StakingManager_StakeNullAmount.selector);
    stakingManager.stake(user, 0);
  }

  function test_Stake(uint256 _amount) public mockProtocolTokenApproval(user, _amount) {
    vm.assume(_amount > 0 && _amount <= type(uint256).max);

    // Mock token transfer
    vm.mockCall(
      address(mockProtocolToken),
      abi.encodeWithSelector(IERC20.transferFrom.selector, user, address(stakingManager), _amount),
      abi.encode(true)
    );

    // Mock staking token minting
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IStakingToken.mint.selector, user, _amount), abi.encode()
    );

    vm.prank(user);
    // vm.expectEmit(true, true, true, true);
    vm.expectEmit();
    emit StakingManagerStaked(user, _amount);

    stakingManager.stake(user, _amount);

    assertEq(stakingManager.stakedBalances(user), _amount);
  }

  function _mockTokenApproval(uint256 _amount) internal {
    vm.mockCall(
      address(mockProtocolToken),
      abi.encodeWithSelector(IERC20.approve.selector, address(stakingManager), _amount),
      abi.encode(true)
    );
  }

  function _mockTokenTransfer(address _account, uint256 _amount) internal {
    vm.mockCall(
      address(mockProtocolToken),
      abi.encodeWithSelector(IERC20.transferFrom.selector, _account, address(stakingManager), _amount),
      abi.encode(true)
    );
  }

  function _mockTokenMint(address _account, uint256 _amount) internal {
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IStakingToken.mint.selector, _account, _amount), abi.encode()
    );
  }

  function _mockTokenBalance(address _token, address _account, uint256 _amount) internal {
    vm.mockCall(_token, abi.encodeWithSelector(IERC20.balanceOf.selector, _account), abi.encode(_amount));
  }

  function test_Stake_WithRewardPool(uint256 _amount) public setupRewardPool {
    vm.assume(_amount > 0 && _amount <= type(uint256).max);

    _mockTokenApproval(_amount);
    _mockTokenTransfer(user, _amount);
    _mockTokenMint(user, _amount);

    // Balanceo of staking token on user
    _mockTokenBalance(address(mockStakingToken), user, _amount);
    // Balance of protocol token on staking manager
    _mockTokenBalance(address(mockProtocolToken), address(stakingManager), _amount);

    vm.expectEmit();

    emit StakingManagerStaked(user, _amount);

    vm.startPrank(user);
    stakingManager.stake(user, _amount);
    vm.stopPrank();

    assertEq(mockProtocolToken.balanceOf(address(stakingManager)), _amount);
    assertEq(mockStakingToken.balanceOf(user), _amount);

    assertEq(stakingManager.stakedBalances(user), _amount);
  }
}
