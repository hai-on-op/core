// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {RewardPoolFactoryForTest, IRewardPoolFactory} from '@test/mocks/RewardPoolFactoryForTest.sol';
import {RewardPoolChild} from '@contracts/factories/RewardPoolChild.sol';
import {IRewardPool} from '@interfaces/tokens/IRewardPool.sol';
import {IStakingManager} from '@interfaces/tokens/IStakingManager.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {HaiTest} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  IStakingManager mockStakingManager = IStakingManager(mockContract('StakingManager'));
  IERC20 mockRewardToken = IERC20(mockContract('RewardToken'));
  IERC20 mockRewardTokenAdditional = IERC20(mockContract('RewardTokenAdditional'));

  RewardPoolFactoryForTest rewardPoolFactory;
  RewardPoolChild rewardPoolChild = RewardPoolChild(
    label(address(0x0000000000000000000000007f85e9e000597158aed9320b5a5e11ab8cc7329a), 'RewardPoolChild')
  );
  RewardPoolChild rewardPoolChildAdditional = RewardPoolChild(
    label(address(0x0000000000000000000000007f85e9e000597158aed9320b5a5e11ab8cc7329b), 'RewardPoolChildAdditional')
  );

  // RewardPool params
  uint256 constant DURATION = 7 days;
  uint256 constant NEW_REWARD_RATIO = 420;

  IRewardPool.RewardPoolParams rewardPoolParams;

  function setUp() public virtual {
    vm.startPrank(deployer);

    rewardPoolParams = IRewardPool.RewardPoolParams({
      stakingManager: address(mockStakingManager),
      duration: DURATION,
      newRewardRatio: NEW_REWARD_RATIO
    });

    rewardPoolFactory = new RewardPoolFactoryForTest();
    label(address(rewardPoolFactory), 'RewardPoolFactory');

    rewardPoolFactory.addAuthorization(authorizedAccount);

    rewardPoolFactory.addRewardPool(address(rewardPoolChild));
    rewardPoolFactory.addRewardPool(address(rewardPoolChildAdditional));

    vm.stopPrank();
  }

  function _mockRewardPool(address _rewardPool) internal {
    rewardPoolFactory.addRewardPool(_rewardPool);
  }
}

contract Unit_RewardPoolFactory_Constructor is Base {
  function test_Constructor() public {
    assertEq(rewardPoolFactory.authorizedAccounts(deployer), true);
  }
}

contract Unit_RewardPoolFactory_DeployRewardPool is Base {
  event DeployRewardPool(
    address indexed _rewardPool,
    address indexed _rewardToken,
    address indexed _stakingManager,
    uint256 _duration,
    uint256 _newRewardRatio
  );

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Revert_Unauthorized() public {
    vm.startPrank(user);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    rewardPoolFactory.deployRewardPool(
      address(mockRewardToken), address(mockStakingManager), DURATION, NEW_REWARD_RATIO
    );
  }

  function test_Revert_NullRewardToken() public happyPath {
    vm.expectRevert(IRewardPoolFactory.RewardPoolFactory_NullRewardToken.selector);

    rewardPoolFactory.deployRewardPool(address(0), address(mockStakingManager), DURATION, NEW_REWARD_RATIO);
  }

  function test_Revert_NullStakingManager() public happyPath {
    vm.expectRevert(IRewardPoolFactory.RewardPoolFactory_NullStakingManager.selector);
    rewardPoolFactory.deployRewardPool(address(mockRewardToken), address(0), DURATION, NEW_REWARD_RATIO);
  }

  function test_Deploy_RewardPoolChild() public happyPath {
    rewardPoolFactory.deployRewardPool(
      address(mockRewardToken), address(mockStakingManager), DURATION, NEW_REWARD_RATIO
    );

    // params
    assertEq(address(rewardPoolChild).code, type(RewardPoolChild).runtimeCode);
    assertEq(address(rewardPoolChild.rewardToken()), address(mockRewardToken));
    assertEq(abi.encode(rewardPoolChild.params()), abi.encode(rewardPoolParams));
  }

  function test_Set_RewardPools() public happyPath {
    rewardPoolFactory.deployRewardPool(
      address(mockRewardToken), address(mockStakingManager), DURATION, NEW_REWARD_RATIO
    );

    assertEq(rewardPoolFactory.rewardPoolsList()[0], address(rewardPoolChild));
  }

  function test_Multiple_Deployments() public happyPath {
    // Check both are in the list
    address[] memory pools = rewardPoolFactory.rewardPoolsList();
    assertEq(pools.length, 2);
    assertEq(pools[0], address(rewardPoolChild));
    assertEq(pools[1], address(rewardPoolChildAdditional));
    // Verify they are different addresses
    assertTrue(address(rewardPoolChild) != address(rewardPoolChildAdditional));
  }

  function test_Emit_DeployRewardPool() public happyPath {
    vm.expectEmit();
    emit DeployRewardPool(
      address(rewardPoolChild), address(mockRewardToken), address(mockStakingManager), DURATION, NEW_REWARD_RATIO
    );
    rewardPoolFactory.deployRewardPool(
      address(mockRewardToken), address(mockStakingManager), DURATION, NEW_REWARD_RATIO
    );
  }
}
